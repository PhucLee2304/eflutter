import 'package:eflutter/core/loading/loading_widget.dart';
import 'dart:async';

import 'package:eflutter/core/attempt_lock/attempt_integrity_reporter.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/attempt/attempt_header.dart';
import 'package:eflutter/presentation/exams/attempt/attempt_session_scope.dart';
import 'package:eflutter/presentation/exams/attempt/listening_audio.dart';
import 'package:eflutter/presentation/exams/attempt/page_view_two_pane.dart';
import 'package:eflutter/presentation/exams/attempt/question_palette.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_navigator_cubit.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:eflutter/presentation/exams/cubit/listening_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solar_icons/solar_icons.dart';

/// Màn làm bài theo trang cho flow TOEIC_STRICT (PLAN_TOEIC_ATTEMPT.md T6). Đáp án,
/// socket, đồng hồ và nộp bài vẫn ở [AttemptSessionCubit]; bảng câu hỏi ở
/// [AttemptNavigatorCubit], con trỏ phần nghe ở [ListeningCubit].
class AttemptExamScreen extends StatefulWidget {
  const AttemptExamScreen({super.key, required this.attempt});

  final ExamAttempt attempt;

  @override
  State<AttemptExamScreen> createState() => _AttemptExamScreenState();
}

class _AttemptExamScreenState extends State<AttemptExamScreen> {
  late final AttemptSocketClient _socket;
  late final AttemptSessionCubit _session;
  late final AttemptNavigatorCubit _navigator;
  late final ListeningCubit _listening;
  final _preloader = ListeningAudioPreloader();
  StreamSubscription<ListeningState>? _listeningSubscription;

  /// Audio trang nghe hiện tại. Đổi theo stream của [ListeningCubit], không theo
  /// build: tab bị ẩn thì Flutter web không build nhưng audio vẫn phải phát tiếp.
  ListeningPlayback? _playback;
  int? _playbackPage;

  /// Vừa nghe xong trong phiên này: hiện màn chuyển trước khi vào phần đọc.
  bool _readingIntro = false;

  @override
  void initState() {
    super.initState();
    final repository = ExamRepository(getIt<RemoteDataBase>());
    _socket = AttemptSocketClient(getIt<LocalDataBase>());
    _session = AttemptSessionCubit(
      repository,
      _socket,
      reporter: getIt<AttemptIntegrityReporter>(),
    )..load(widget.attempt.id, initialAttempt: widget.attempt);
    _navigator = AttemptNavigatorCubit(repository, _session, widget.attempt.id);
    _listening = ListeningCubit(repository, _socket, _navigator);
    _listeningSubscription = _listening.stream.listen(_syncPlayback);
    _start();
  }

  Future<void> _start() async {
    await _navigator.load();
    if (!mounted) return;
    if (_navigator.state.isListening) {
      await _listening.start();
    } else {
      await _openViewingPage();
    }
  }

  Future<void> _openViewingPage() async {
    final index = _navigator.state.viewingPage;
    if (index != null) await _navigator.openPage(index);
  }

  void _syncPlayback(ListeningState listening) {
    final page = listening.phase == ListeningPhase.playing
        ? listening.page
        : null;
    if (page != null && page.index == _playbackPage) return;
    // Hết audio (gap/advancing) thì giữ player tới khi sang trang mới.
    if (page == null &&
        listening.phase != ListeningPhase.loading &&
        listening.phase != ListeningPhase.finished &&
        listening.phase != ListeningPhase.idle) {
      return;
    }
    _playback?.dispose();
    _playback = null;
    _playbackPage = page?.index;
    if (page == null) return;
    _preloader.preload(page.nextAudioUrl);
    _playback = ListeningPlayback(
      url: page.group?.audioUrl,
      durationMs: page.group?.audioDurationMs,
      startOffset: listening.startOffset,
      onCompleted: _listening.audioCompleted,
      preloader: _preloader,
    );
  }

  @override
  void dispose() {
    _listeningSubscription?.cancel();
    _playback?.dispose();
    _preloader.dispose();
    _listening.close();
    _navigator.close();
    _session.close();
    super.dispose();
  }

  void _openPalette() {
    showQuestionPalette(
      context,
      // Đang nghe thì bảng chỉ để xem.
      onSelect: _navigator.state.isListening ? null : _navigator.openQuestion,
      builder: (context, onTap) =>
          BlocBuilder<AttemptNavigatorCubit, AttemptNavigatorState>(
            bloc: _navigator,
            builder: (context, state) => QuestionPalette(
              groups: paletteGroupsFromNavigator(state),
              onTap: onTap,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AttemptSessionScope(
      cubit: _session,
      child: BlocListener<AttemptNavigatorCubit, AttemptNavigatorState>(
        bloc: _navigator,
        // Vừa hết phần nghe: mở trang đọc đầu tiên.
        listenWhen: (previous, current) =>
            previous.isListening && !current.isListening,
        listener: (context, state) {
          setState(() => _readingIntro = true);
          _openViewingPage();
        },
        child: BlocBuilder<AttemptSessionCubit, AttemptSessionState>(
          bloc: _session,
          builder: (context, session) =>
              BlocBuilder<AttemptNavigatorCubit, AttemptNavigatorState>(
                bloc: _navigator,
                builder: (context, navigator) =>
                    BlocBuilder<ListeningCubit, ListeningState>(
                      bloc: _listening,
                      builder: (context, listening) => Scaffold(
                        body: SafeArea(
                          child: _body(session, navigator, listening),
                        ),
                      ),
                    ),
              ),
        ),
      ),
    );
  }

  static bool _listeningOnlyDone(AttemptNavigatorState state) =>
      state.navigator != null &&
      !state.isListening &&
      !state.isLoading &&
      state.viewingPage == null;

  Widget? _listeningTop() {
    final playback = _playback;
    if (playback == null) return null;
    return ListeningResumeButton(
      key: ValueKey('audio-$_playbackPage'),
      playback: playback,
    );
  }

  Widget _body(
    AttemptSessionState session,
    AttemptNavigatorState navigator,
    ListeningState listening,
  ) {
    final attempt = session.attempt;
    if (attempt == null) {
      return session.isLoading
          ? const AppLoader()
          : const MissingAttempt();
    }
    final title = attempt.exam?.title.trim().isNotEmpty == true
        ? attempt.exam!.title
        : 'Attempt #${attempt.id}';
    final page = navigator.isListening ? listening.page : navigator.currentPage;
    final stageLabel = navigator.navigator == null
        ? null
        : [
            navigator.isListening ? 'Listening' : 'Reading',
            if (!_readingIntro) ?partLabel(page?.part),
          ].join(' · ');
    // Attempt chỉ có phần nghe (vd luyện Part 1): nghe xong thì server tự nộp bài
    // (ATTEMPT_SUBMITTED đưa sang trang kết quả); nút Submit chỉ để dự phòng.
    final noReadingPages = _listeningOnlyDone(navigator);
    void submit() => confirmSubmitAttempt(
      context,
      _session,
      message: navigator.isListening
          ? 'The listening section is not finished. Unanswered questions, '
                'including those not reached yet, will be scored as 0.'
          : 'Your current answers will be graded and cannot be changed.',
    );
    return Column(
      children: [
        AttemptHeader(
          title: title,
          subtitle: stageLabel,
          state: session,
          answeredCount: navigator.answeredCount,
          totalQuestions:
              navigator.navigator?.totalQuestions ?? attempt.totalQuestions,
          onOpenPalette: navigator.navigator == null ? null : _openPalette,
          onSubmit: submit,
          onCancel: attempt.isAssignment
              ? null
              : () => confirmCancelAttempt(context, _session),
        ),
        Expanded(
          child: noReadingPages
              ? _ListeningOnlyFinished(onSubmit: submit)
              : _readingIntro
              ? _ReadingIntro(
                  onStart: () => setState(() => _readingIntro = false),
                )
              : page == null
              ? Center(
                  child:
                      navigator.isLoading ||
                          navigator.isPageLoading ||
                          listening.phase == ListeningPhase.loading
                      ? const AppLoader()
                      : const Text('This page is not available.'),
                )
              : AttemptPageViewTwoPane(
                  key: ValueKey('page-${page.index}'),
                  page: page,
                  session: session,
                  locked: !navigator.isPageOpen(page.index),
                  onSelect: _session.selectAnswer,
                  top: navigator.isListening ? _listeningTop() : null,
                ),
        ),
        if (!navigator.isListening &&
            !_readingIntro &&
            !noReadingPages &&
            navigator.navigator != null)
          _PageNavigationBar(
            onPrevious: _navigator.adjacentPage(-1) == null
                ? null
                : () => _navigator.openAdjacent(-1),
            onNext: _navigator.adjacentPage(1) == null
                ? null
                : () => _navigator.openAdjacent(1),
            loading: navigator.isPageLoading,
          ),
      ],
    );
  }
}

/// Attempt chỉ có phần nghe đã nghe xong: chờ server nộp bài.
class _ListeningOnlyFinished extends StatelessWidget {
  const _ListeningOnlyFinished({required this.onSubmit});
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The listening section has ended',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Submitting your answers…',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColorName.labelSecondary),
          ),
          const SizedBox(height: 20),
          const AppLoader(),
          const SizedBox(height: 20),
          TextButton(
            key: const ValueKey('listening-only-submit'),
            onPressed: onSubmit,
            child: const Text('Submit now'),
          ),
        ],
      ),
    ),
  );
}

/// Màn chuyển "Kết thúc phần nghe — bắt đầu phần đọc".
class _ReadingIntro extends StatelessWidget {
  const _ReadingIntro({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The listening section has ended',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Listening answers are now locked. In the reading section you can move '
            'freely between questions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColorName.labelSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('start-reading'),
            onPressed: onStart,
            child: const Text('Start reading'),
          ),
        ],
      ),
    ),
  );
}

/// Nút Trước/Sau của phần đọc (T8).
class _PageNavigationBar extends StatelessWidget {
  const _PageNavigationBar({
    required this.onPrevious,
    required this.onNext,
    required this.loading,
  });

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: const BoxDecoration(
      color: ColorName.white,
      border: Border(top: BorderSide(color: ColorName.gray5)),
    ),
    child: Row(
      children: [
        OutlinedButton.icon(
          key: const ValueKey('page-previous'),
          onPressed: loading ? null : onPrevious,
          icon: const Icon(SolarIconsOutline.altArrowLeft),
          label: const Text('Previous'),
        ),
        const Spacer(),
        if (loading)
          const SizedBox.square(
            dimension: 18,
            child: AppLoader(),
          ),
        const Spacer(),
        OutlinedButton.icon(
          key: const ValueKey('page-next'),
          onPressed: loading ? null : onNext,
          icon: const Icon(SolarIconsOutline.altArrowRight),
          label: const Text('Next'),
        ),
      ],
    ),
  );
}
