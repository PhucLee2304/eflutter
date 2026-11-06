import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/topic_lesson.dart';
import 'package:eflutter/data/models/topic_lesson_detail.dart';
import 'package:eflutter/data/models/topic_transcript.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/topics/cubit/lesson_detail_cubit.dart';
import 'package:eflutter/presentation/topics/cubit/topic_cubit.dart';
import 'package:eflutter/presentation/topics/widgets/lesson_audio_player.dart';
import 'package:eflutter/presentation/topics/widgets/lesson_icon_button.dart';
import 'package:eflutter/presentation/topics/widgets/lesson_video_player.dart';
import 'package:eflutter/presentation/topics/widgets/topic_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class LessonDetailScreen extends StatefulWidget {
  const LessonDetailScreen({
    required this.topicId,
    required this.sectionId,
    required this.lessonId,
    super.key,
  });

  final int topicId;
  final int sectionId;
  final int lessonId;

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  late final LessonVideoController _videoController;
  final LessonAudioController _audioController = LessonAudioController();
  late final ValueNotifier<int?> _selectedTranscriptIdNotifier;
  late final ScrollController _transcriptScrollController;
  final Map<int, GlobalKey> _transcriptKeys = {};
  bool _autoScroll = true;

  /// Câu đang được lặp lại; null khi tắt "Repeat sentence".
  int? _repeatTranscriptId;
  bool _isSeeking = false;

  @override
  void initState() {
    super.initState();
    _videoController = LessonVideoController();
    _selectedTranscriptIdNotifier = ValueNotifier<int?>(null);
    _transcriptScrollController = ScrollController();
    _videoController.setPositionListener(_handlePositionChanged);
    _audioController.setPositionListener(_handlePositionChanged);
    context.read<LessonDetailCubit>().load(widget.lessonId);
    // Tên topic/section cho breadcrumb và các lesson cùng section cho nút
    // lesson trước/sau; đã có (đi từ danh sách vào) thì không tải lại.
    final topicCubit = context.read<TopicCubit>();
    topicCubit.loadTopics();
    topicCubit.loadSections(widget.topicId);
    topicCubit.loadLessons(widget.sectionId);
  }

  @override
  void dispose() {
    _videoController.setPositionListener(null);
    _selectedTranscriptIdNotifier.dispose();
    _transcriptScrollController.dispose();
    _videoController.dispose();
    _audioController.dispose();
    super.dispose();
  }

  void _handlePositionChanged(double seconds) {
    final lesson = context.read<LessonDetailCubit>().state.lesson;
    if (lesson == null || lesson.transcripts.isEmpty || _isSeeking) {
      return;
    }

    final repeated = lesson.transcripts
        .where((t) => t.id == _repeatTranscriptId)
        .firstOrNull;
    if (repeated != null && seconds >= repeated.timeEnd) {
      _seekTo(repeated);
      return;
    }

    TopicTranscript? activeTranscript;
    for (final transcript in lesson.transcripts) {
      if (seconds >= transcript.timeStart && seconds < transcript.timeEnd) {
        activeTranscript = transcript;
        break;
      }
    }

    if (activeTranscript == null) {
      final lastTranscript = lesson.transcripts.last;
      if (seconds >= lastTranscript.timeStart) {
        activeTranscript = lastTranscript;
      }
    }

    final nextTranscriptId = activeTranscript?.id;
    if (!mounted || nextTranscriptId == null) {
      return;
    }
    if (nextTranscriptId == _selectedTranscriptIdNotifier.value) {
      return;
    }

    _selectedTranscriptIdNotifier.value = nextTranscriptId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTranscriptVisible(nextTranscriptId);
    });
  }

  void _ensureTranscriptVisible(int transcriptId) {
    if (!mounted || !_autoScroll) return;
    if (!_transcriptScrollController.hasClients) return;

    final itemContext = _transcriptKeys[transcriptId]?.currentContext;
    if (itemContext == null) return;

    final renderObject = itemContext.findRenderObject();
    if (renderObject == null) return;

    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return;

    final position = _transcriptScrollController.position;
    final targetOffset = viewport.getOffsetToReveal(renderObject, 0.08).offset;

    final clampedOffset = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((clampedOffset - position.pixels).abs() < 1) {
      return;
    }

    _transcriptScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _seekTo(TopicTranscript transcript) async {
    _selectedTranscriptIdNotifier.value = transcript.id;
    if (_repeatTranscriptId != null && _repeatTranscriptId != transcript.id) {
      setState(() => _repeatTranscriptId = transcript.id);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTranscriptVisible(transcript.id);
    });
    _isSeeking = true;
    final isAudio =
        context.read<LessonDetailCubit>().state.lesson?.isAudio ?? false;
    if (isAudio) {
      await _audioController.seekToAndPlay(transcript.timeStart);
    } else {
      await _videoController.seekToAndPlay(transcript.timeStart);
    }
    _isSeeking = false;
  }

  void _goBack() =>
      context.go(topicLessonsPath(widget.topicId, widget.sectionId));

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LessonDetailCubit, LessonDetailState>(
      listener: (context, state) {
        if (state.failure != null) {
          context.handleFailure(state.failure);
        }
        if (state.lesson case final lesson? when lesson.isAudio) {
          _audioController.prepare(lesson.url);
        }
      },
      builder: (context, state) {
        final lesson = state.lesson;
        if (lesson == null) {
          return Scaffold(
            body: state.isLoading
                ? const AppLoader()
                : const _EmptyLessonState(),
          );
        }
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1224),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LessonHeader(
                          topicId: widget.topicId,
                          sectionId: widget.sectionId,
                          lesson: lesson,
                          onBack: _goBack,
                        ),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildMain(lesson, constraints.maxWidth),
                        ),
                        const SizedBox(height: 24),
                        _LessonNavigation(
                          topicId: widget.topicId,
                          sectionId: widget.sectionId,
                          lessonId: lesson.id,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMain(TopicLessonDetail lesson, double width) {
    const gap = 16.0;
    Widget listen(Widget Function(int? selectedId) builder) =>
        ValueListenableBuilder<int?>(
          valueListenable: _selectedTranscriptIdNotifier,
          builder: (context, selectedId, _) => builder(selectedId),
        );
    VoidCallback? toggleRepeat(int? selectedId) =>
        selectedId == null && _repeatTranscriptId == null
        ? null
        : () => setState(() {
            _repeatTranscriptId = _repeatTranscriptId == null
                ? selectedId
                : null;
          });
    GlobalKey transcriptKey(int id) =>
        _transcriptKeys.putIfAbsent(id, GlobalKey.new);

    if (lesson.isAudio) {
      final transcripts = lesson.transcripts;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          listen((selectedId) {
            final index = transcripts.indexWhere((t) => t.id == selectedId);
            return LessonAudioBar(
              controller: _audioController,
              onPrevious: index > 0
                  ? () => _seekTo(transcripts[index - 1])
                  : null,
              onNext: index + 1 < transcripts.length
                  ? () => _seekTo(transcripts[index + 1])
                  : null,
              isRepeating: _repeatTranscriptId != null,
              onToggleRepeat: toggleRepeat(selectedId),
              autoScroll: _autoScroll,
              onToggleAutoScroll: () =>
                  setState(() => _autoScroll = !_autoScroll),
            );
          }),
          SizedBox(
            height: 624,
            child: listen(
              (selectedId) => _AudioTranscriptList(
                transcripts: transcripts,
                selectedTranscriptId: selectedId,
                scrollController: _transcriptScrollController,
                transcriptKeyBuilder: transcriptKey,
                onTranscriptTap: _seekTo,
              ),
            ),
          ),
        ],
      );
    }

    final video = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: ColorName.black,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: lesson.url.trim().isEmpty
              ? const Center(
                  child: Text(
                    'Video unavailable',
                    style: TextStyle(color: ColorName.gray2),
                  ),
                )
              : LessonVideoPlayer(
                  url: lesson.url,
                  transcripts: lesson.transcripts,
                  controller: _videoController,
                ),
        ),
      ),
    );

    Widget panel(double height) => SizedBox(
      height: height,
      child: listen(
        (selectedId) => _TranscriptPanel(
          transcripts: lesson.transcripts,
          scrollController: _transcriptScrollController,
          selectedTranscriptId: selectedId,
          transcriptKeyBuilder: transcriptKey,
          autoScroll: _autoScroll,
          onToggleAutoScroll: () => setState(() => _autoScroll = !_autoScroll),
          isRepeating: _repeatTranscriptId != null,
          onToggleRepeat: toggleRepeat(selectedId),
          onTranscriptTap: _seekTo,
        ),
      ),
    );

    if (width < 880) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [video, panel(420)],
      );
    }
    final leftWidth = (width - gap) * 0.64;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: gap,
      children: [
        SizedBox(width: leftWidth, child: video),
        Expanded(child: panel(leftWidth * 9 / 16)),
      ],
    );
  }
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({
    required this.topicId,
    required this.sectionId,
    required this.lesson,
    required this.onBack,
  });

  final int topicId;
  final int sectionId;
  final TopicLessonDetail lesson;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topicState = context.watch<TopicCubit>().state;
    final topicName = topicState.topic(topicId)?.name ?? '';
    final sectionName = topicState.section(topicId, sectionId)?.name ?? '';
    final title = lesson.title.isEmpty ? 'Untitled lesson' : lesson.title;
    // description có dạng "29 parts · Vocab level: B1".
    final chips =
        (lesson.description.isNotEmpty ? lesson.description : lesson.subtitle)
            .split(' · ')
            .where((chip) => chip.trim().isNotEmpty)
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopicBreadcrumb(
          items: [
            ('Topics', () => context.go(AppRoutes.topic.path)),
            (topicName, () => context.go(topicSectionsPath(topicId))),
            (sectionName, onBack),
            (title, null),
          ],
        ),
        TopicHeader(
          icon: lesson.isAudio
              ? SolarIconsOutline.microphone
              : SolarIconsOutline.videoFramePlayHorizontal,
          title: title,
          subtitle: '$topicName · $sectionName',
          chips: chips,
          onBack: onBack,
        ),
      ],
    );
  }
}

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({
    required this.transcripts,
    required this.scrollController,
    required this.selectedTranscriptId,
    required this.onTranscriptTap,
    required this.transcriptKeyBuilder,
    required this.autoScroll,
    required this.onToggleAutoScroll,
    required this.isRepeating,
    required this.onToggleRepeat,
  });

  final List<TopicTranscript> transcripts;
  final ScrollController scrollController;
  final int? selectedTranscriptId;
  final ValueChanged<TopicTranscript> onTranscriptTap;
  final GlobalKey Function(int transcriptId) transcriptKeyBuilder;
  final bool autoScroll;
  final VoidCallback onToggleAutoScroll;
  final bool isRepeating;
  final VoidCallback? onToggleRepeat;

  @override
  Widget build(BuildContext context) {
    final activeIndex = transcripts.indexWhere(
      (t) => t.id == selectedTranscriptId,
    );
    return Material(
      color: ColorName.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              spacing: 8,
              children: [
                LessonIconButton(
                  icon: SolarIconsBold.skipPrevious,
                  tooltip: 'Previous sentence',
                  onPressed: activeIndex > 0
                      ? () => onTranscriptTap(transcripts[activeIndex - 1])
                      : null,
                ),
                // Thứ tự câu đang phát; tổng số đã có ở chip "N parts" trên header.
                if (activeIndex >= 0)
                  Text(
                    '${activeIndex + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorName.labelPrimary,
                    ),
                  ),
                LessonIconButton(
                  icon: SolarIconsBold.skipNext,
                  tooltip: 'Next sentence',
                  onPressed: activeIndex + 1 < transcripts.length
                      ? () => onTranscriptTap(transcripts[activeIndex + 1])
                      : null,
                ),
                const Spacer(),
                LessonIconButton(
                  icon: SolarIconsOutline.repeat,
                  tooltip: 'Repeat sentence',
                  selected: isRepeating,
                  onPressed: onToggleRepeat,
                ),
                LessonIconButton(
                  icon: SolarIconsOutline.sortFromTopToBottom,
                  tooltip: 'Auto-scroll',
                  selected: autoScroll,
                  onPressed: onToggleAutoScroll,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ColorName.gray6),
          Expanded(
            child: transcripts.isEmpty
                ? const Center(
                    child: Text(
                      'No transcripts found',
                      style: TextStyle(color: ColorName.labelSecondary),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: transcripts.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: ColorName.gray6),
                    itemBuilder: (context, index) {
                      final transcript = transcripts[index];
                      final isActive = index == activeIndex;
                      return InkWell(
                        key: transcriptKeyBuilder(transcript.id),
                        onTap: () => onTranscriptTap(transcript),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? ColorName.primary.withValues(alpha: 0.08)
                                : null,
                            border: Border(
                              left: BorderSide(
                                width: 3,
                                color: isActive
                                    ? ColorName.primary
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? ColorName.primary
                                      : ColorName.gray6,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _formatSeconds(transcript.timeStart),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? ColorName.white
                                        : ColorName.labelSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                transcript.content.isEmpty
                                    ? 'No transcript content'
                                    : transcript.content,
                                style: TextStyle(
                                  height: 1.4,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isActive
                                      ? ColorName.primary
                                      : index < activeIndex
                                      ? ColorName.gray1
                                      : ColorName.labelPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AudioTranscriptList extends StatelessWidget {
  const _AudioTranscriptList({
    required this.transcripts,
    required this.selectedTranscriptId,
    required this.scrollController,
    required this.transcriptKeyBuilder,
    required this.onTranscriptTap,
  });

  final List<TopicTranscript> transcripts;
  final int? selectedTranscriptId;
  final ScrollController scrollController;
  final GlobalKey Function(int transcriptId) transcriptKeyBuilder;
  final ValueChanged<TopicTranscript> onTranscriptTap;

  @override
  Widget build(BuildContext context) {
    final activeIndex = transcripts.indexWhere(
      (t) => t.id == selectedTranscriptId,
    );
    return Material(
      color: ColorName.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: transcripts.isEmpty
          ? const Center(
              child: Text(
                'No transcripts found',
                style: TextStyle(color: ColorName.labelSecondary),
              ),
            )
          : ListView.separated(
              controller: scrollController,
              itemCount: transcripts.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: ColorName.gray6),
              itemBuilder: (context, index) {
                final transcript = transcripts[index];
                final isActive = index == activeIndex;
                final textColor = isActive
                    ? ColorName.primary
                    : index < activeIndex
                    ? ColorName.gray1
                    : ColorName.labelPrimary;
                return InkWell(
                  key: transcriptKeyBuilder(transcript.id),
                  onTap: () => onTranscriptTap(transcript),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? ColorName.primary.withValues(alpha: 0.08)
                          : null,
                      border: Border(
                        left: BorderSide(
                          width: 3,
                          color: isActive
                              ? ColorName.primary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Row(
                      spacing: 16,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}'.padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? ColorName.primary
                                  : ColorName.gray1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            transcript.content,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: textColor,
                            ),
                          ),
                        ),
                        Text(
                          _formatSeconds(transcript.timeStart),
                          style: const TextStyle(
                            fontSize: 13,
                            color: ColorName.labelSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _LessonNavigation extends StatelessWidget {
  const _LessonNavigation({
    required this.topicId,
    required this.sectionId,
    required this.lessonId,
  });

  final int topicId;
  final int sectionId;
  final int lessonId;

  @override
  Widget build(BuildContext context) {
    final lessons =
        context.watch<TopicCubit>().state.lessons[sectionId] ??
        const <TopicLesson>[];
    void open(TopicLesson lesson) =>
        context.go(topicLessonPath(topicId, sectionId, lesson.id));
    final index = lessons.indexWhere((lesson) => lesson.id == lessonId);
    if (index < 0) {
      return const SizedBox.shrink();
    }
    final previous = index > 0 ? lessons[index - 1] : null;
    final next = index + 1 < lessons.length ? lessons[index + 1] : null;
    return Row(
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: ColorName.labelPrimary,
            side: const BorderSide(color: ColorName.gray5),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onPressed: previous == null ? null : () => open(previous),
          icon: const Icon(SolarIconsOutline.altArrowLeft, size: 18),
          label: Text(
            previous == null
                ? 'Previous lesson'
                : 'Previous lesson: ${previous.title}',
          ),
        ),
        const Spacer(),
        if (next != null)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ColorName.primary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: () => open(next),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text('Next lesson: ${next.title}'),
                const Icon(SolarIconsOutline.altArrowRight, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyLessonState extends StatelessWidget {
  const _EmptyLessonState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Lesson detail is unavailable',
        style: TextStyle(color: ColorName.labelSecondary),
      ),
    );
  }
}

String _formatSeconds(double value) {
  final totalSeconds = value.floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
