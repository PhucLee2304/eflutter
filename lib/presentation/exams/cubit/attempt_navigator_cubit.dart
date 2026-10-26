import 'dart:async';

import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/attempt_page.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Trạng thái một ô trên bảng câu hỏi. [correct]/[wrong] chỉ dùng ở màn lịch sử.
enum PaletteStatus { empty, answered, current, locked, correct, wrong }

class AttemptNavigatorState {
  final AttemptNavigator? navigator;

  /// Trang đang xem. Khi đang nghe luôn bằng trang nghe hiện tại.
  final int? viewingPage;

  /// Trang phần đọc đã tải (trang nghe không cache vì elapsedMs đổi theo thời gian).
  final Map<int, AttemptPage> pages;

  /// Đáp án local từ AttemptSessionCubit; câu chưa có ở đây lấy `answered` của server.
  final Map<int, int?> selectedOptions;
  final bool isLoading;
  final bool isPageLoading;
  final Failure? failure;

  const AttemptNavigatorState({
    this.navigator,
    this.viewingPage,
    this.pages = const {},
    this.selectedOptions = const {},
    this.isLoading = false,
    this.isPageLoading = false,
    this.failure,
  });

  bool get isListening => navigator?.isListening ?? false;

  AttemptPage? get currentPage =>
      viewingPage == null ? null : pages[viewingPage];

  /// Quy tắc mục 1.4: đang nghe chỉ mở trang nghe hiện tại; sang phần đọc thì mở mọi
  /// trang đọc, trang nghe khóa vĩnh viễn. Flow FREE mở mọi trang.
  bool isPageOpen(int index) {
    final nav = navigator;
    if (nav == null || index < 0 || index >= nav.pages.length) return false;
    if (nav.flow != 'TOEIC_STRICT') return true;
    if (nav.pages[index].isListening) {
      return nav.isListening && index == nav.currentPage;
    }
    return !nav.isListening;
  }

  bool isAnswered(AttemptNavigatorQuestion question) =>
      selectedOptions.containsKey(question.id)
      ? selectedOptions[question.id] != null
      : question.answered;

  PaletteStatus statusOf(int pageIndex, AttemptNavigatorQuestion question) {
    if (pageIndex == viewingPage) return PaletteStatus.current;
    if (!isPageOpen(pageIndex)) return PaletteStatus.locked;
    return isAnswered(question) ? PaletteStatus.answered : PaletteStatus.empty;
  }

  int get answeredCount {
    final nav = navigator;
    if (nav == null) return 0;
    var count = 0;
    for (final page in nav.pages) {
      for (final question in page.questions) {
        if (isAnswered(question)) count++;
      }
    }
    return count;
  }

  AttemptNavigatorState copyWith({
    AttemptNavigator? navigator,
    Object? viewingPage = _sentinel,
    Map<int, AttemptPage>? pages,
    Map<int, int?>? selectedOptions,
    bool? isLoading,
    bool? isPageLoading,
    Object? failure = _sentinel,
  }) => AttemptNavigatorState(
    navigator: navigator ?? this.navigator,
    viewingPage: identical(viewingPage, _sentinel)
        ? this.viewingPage
        : viewingPage as int?,
    pages: pages ?? this.pages,
    selectedOptions: selectedOptions ?? this.selectedOptions,
    isLoading: isLoading ?? this.isLoading,
    isPageLoading: isPageLoading ?? this.isPageLoading,
    failure: identical(failure, _sentinel) ? this.failure : failure as Failure?,
  );
}

const _sentinel = Object();

/// Bảng câu hỏi + trang đang xem của attempt (PLAN_TOEIC_ATTEMPT.md T5). Đáp án vẫn
/// nằm ở [AttemptSessionCubit]; cubit này chỉ đọc để tô màu và nạp đáp án của trang.
class AttemptNavigatorCubit extends Cubit<AttemptNavigatorState> {
  AttemptNavigatorCubit(this._repository, this._session, this.attemptId)
    : super(const AttemptNavigatorState()) {
    _sessionSubscription = _session.stream.listen(_handleSession);
  }

  final ExamRepository _repository;
  final AttemptSessionCubit _session;
  final int attemptId;
  StreamSubscription<AttemptSessionState>? _sessionSubscription;
  Map<int, AnswerSyncStatus> _lastStatuses = const {};

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, failure: null));
    await refresh();
  }

  /// Tải lại navigator (sau khi tiến trang nghe, bị từ chối vì khóa…). Trả null nếu lỗi.
  Future<AttemptNavigator?> refresh() async {
    final result = await _repository.getAttemptNavigator(attemptId);
    if (isClosed) return null;
    switch (result) {
      case Success(data: final navigator):
        emit(
          state.copyWith(
            navigator: navigator,
            viewingPage: _viewingFor(navigator, state.viewingPage),
            isLoading: false,
            selectedOptions: _session.state.selectedOptions,
          ),
        );
        return navigator;
      case Failure():
        emit(state.copyWith(isLoading: false, failure: result));
        return null;
      case Cancelled():
        emit(state.copyWith(isLoading: false));
        return null;
    }
  }

  /// Áp trạng thái nghe mới (ACK của ATTEMPT_LISTENING_ADVANCE) mà không gọi lại API.
  void applyListening(AttemptListeningState listening) {
    final nav = state.navigator;
    if (nav == null) return;
    final updated = AttemptNavigator(
      flow: nav.flow,
      stage: listening.stage,
      currentPage: listening.currentPage,
      pageStartedAt: listening.pageStartedAt,
      serverTime: listening.serverTime ?? nav.serverTime,
      expiresAt: nav.expiresAt,
      totalQuestions: nav.totalQuestions,
      answeredCount: nav.answeredCount,
      pages: nav.pages,
    );
    emit(
      state.copyWith(
        navigator: updated,
        viewingPage: _viewingFor(updated, state.viewingPage),
      ),
    );
  }

  /// Mở một trang phần đọc (hoặc trang bất kỳ ở flow FREE). Trang khóa bị bỏ qua.
  Future<void> openPage(int index) async {
    if (!state.isPageOpen(index) || state.isListening) return;
    emit(state.copyWith(viewingPage: index, failure: null));
    if (state.pages.containsKey(index)) return;
    emit(state.copyWith(isPageLoading: true));
    final result = await _repository.getAttemptPage(attemptId, index);
    if (isClosed) return;
    switch (result) {
      case Success(data: final page):
        registerPage(page);
        emit(state.copyWith(isPageLoading: false));
      case Failure():
        emit(state.copyWith(isPageLoading: false, failure: result));
        if (result.code == 409) await refresh();
      case Cancelled():
        emit(state.copyWith(isPageLoading: false));
    }
  }

  /// Trang mở liền trước (delta = -1) hoặc liền sau (delta = 1) trang đang xem, null nếu hết.
  int? adjacentPage(int delta) {
    final nav = state.navigator;
    final current = state.viewingPage;
    if (nav == null || current == null) return null;
    for (var i = current + delta; i >= 0 && i < nav.pages.length; i += delta) {
      if (state.isPageOpen(i)) return i;
    }
    return null;
  }

  Future<void> openAdjacent(int delta) async {
    final index = adjacentPage(delta);
    if (index != null) await openPage(index);
  }

  Future<void> openQuestion(int questionId) async {
    final index = state.navigator?.pageOfQuestion(questionId) ?? -1;
    if (index >= 0) await openPage(index);
  }

  /// Nạp đáp án đã lưu của trang vào session; trang đọc được cache.
  void registerPage(AttemptPage page) {
    _session.mergeAnswers({
      for (final question in page.questions)
        question.id: question.selectedOptionId,
    });
    if (page.isListening) return;
    emit(state.copyWith(pages: {...state.pages, page.index: page}));
  }

  void _handleSession(AttemptSessionState session) {
    if (!identical(session.selectedOptions, state.selectedOptions)) {
      emit(state.copyWith(selectedOptions: session.selectedOptions));
    }
    // Câu bị QUESTION_LOCKED nghĩa là bảng câu hỏi đã cũ: tải lại.
    final newlyRejected = session.syncStatuses.entries.any(
      (e) =>
          e.value == AnswerSyncStatus.rejected &&
          _lastStatuses[e.key] != AnswerSyncStatus.rejected,
    );
    _lastStatuses = session.syncStatuses;
    if (newlyRejected) unawaited(refresh());
  }

  /// Đang nghe thì xem trang nghe hiện tại; sang phần đọc mà đang đứng ở trang khóa
  /// (hoặc chưa xem trang nào) thì về trang đọc đầu tiên.
  static int? _viewingFor(AttemptNavigator navigator, int? current) {
    if (navigator.isListening) return navigator.currentPage;
    final open = navigator.pages.where(
      (page) => navigator.flow != 'TOEIC_STRICT' || !page.isListening,
    );
    if (current != null && open.any((page) => page.index == current)) {
      return current;
    }
    return open.isEmpty ? null : open.first.index;
  }

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }
}
