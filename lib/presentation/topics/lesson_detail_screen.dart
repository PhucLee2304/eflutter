import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/topic_lesson_detail.dart';
import 'package:eflutter/data/models/topic_transcript.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/topics/cubit/lesson_detail_cubit.dart';
import 'package:eflutter/presentation/topics/widgets/lesson_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class LessonDetailScreen extends StatefulWidget {
  const LessonDetailScreen({
    required this.lessonId,
    super.key,
  });

  final int lessonId;

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  late final LessonVideoController _videoController;
  late final ValueNotifier<int?> _selectedTranscriptIdNotifier;
  late final ScrollController _transcriptScrollController;
  final Map<int, GlobalKey> _transcriptKeys = {};

  @override
  void initState() {
    super.initState();
    _videoController = LessonVideoController();
    _selectedTranscriptIdNotifier = ValueNotifier<int?>(null);
    _transcriptScrollController = ScrollController();
    _videoController.setPositionListener(_handleVideoPositionChanged);
    context.read<LessonDetailCubit>().load(widget.lessonId);
  }

  @override
  void dispose() {
    _videoController.setPositionListener(null);
    _selectedTranscriptIdNotifier.dispose();
    _transcriptScrollController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _handleVideoPositionChanged(double seconds) {
    final lesson = context.read<LessonDetailCubit>().state.lesson;
    if (lesson == null || lesson.transcripts.isEmpty) {
      return;
    }

    TopicTranscript? activeTranscript;
    for (final transcript in lesson.transcripts) {
      if (seconds >= transcript.timeStart && seconds < transcript.timeEnd) {
        activeTranscript = transcript;
        break;
      }
    }

    if (activeTranscript == null && lesson.transcripts.isNotEmpty) {
      final lastTranscript = lesson.transcripts.last;
      if (seconds >= lastTranscript.timeStart) {
        activeTranscript = lastTranscript;
      }
    }

    final nextTranscriptId = activeTranscript?.id;
    if (!mounted || nextTranscriptId == _selectedTranscriptIdNotifier.value) {
      return;
    }

    _selectedTranscriptIdNotifier.value = nextTranscriptId;

    if (nextTranscriptId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureTranscriptVisible(nextTranscriptId);
      });
    }
  }

  void _ensureTranscriptVisible(int transcriptId) {
    if (!mounted) return;
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

  GlobalKey _keyForTranscript(int transcriptId) {
    return _transcriptKeys.putIfAbsent(transcriptId, GlobalKey.new);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LessonDetailCubit, LessonDetailState>(
      listener: (context, state) {
        if (state.failure != null) {
          context.handleFailure(state.failure);
        }
      },
      builder: (context, state) {
        final lesson = state.lesson;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              child: state.isLoading && lesson == null
                  ? const Center(child: CircularProgressIndicator())
                  : lesson == null
                  ? const _EmptyLessonState()
                  : _LessonDetailContent(
                      lesson: lesson,
                      isLoading: state.isLoading,
                      videoController: _videoController,
                      selectedTranscriptIdListenable: _selectedTranscriptIdNotifier,
                      transcriptScrollController: _transcriptScrollController,
                      transcriptKeyBuilder: _keyForTranscript,
                      onTranscriptTap: (transcript) async {
                        _selectedTranscriptIdNotifier.value = transcript.id;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _ensureTranscriptVisible(transcript.id);
                        });
                        await _videoController.seekToAndPlay(
                          transcript.timeStart,
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _LessonDetailContent extends StatelessWidget {
  const _LessonDetailContent({
    required this.lesson,
    required this.isLoading,
    required this.videoController,
    required this.selectedTranscriptIdListenable,
    required this.transcriptScrollController,
    required this.transcriptKeyBuilder,
    required this.onTranscriptTap,
  });

  final TopicLessonDetail lesson;
  final bool isLoading;
  final LessonVideoController videoController;
  final ValueListenable<int?> selectedTranscriptIdListenable;
  final ScrollController transcriptScrollController;
  final GlobalKey Function(int transcriptId) transcriptKeyBuilder;
  final ValueChanged<TopicTranscript> onTranscriptTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 960;
        return ListView(
          padding: EdgeInsets.only(
            right: isCompact ? 18 : 24,
            bottom: 16,
          ),
          children: [
            _LessonTopBar(
              title: lesson.title.isEmpty ? 'Lesson detail' : lesson.title,
            ),
            const SizedBox(height: 16),
            _LessonSummaryCard(lesson: lesson),
            const SizedBox(height: 16),
            if (isCompact) ...[
              _VideoPanel(
                lessonUrl: lesson.url,
                controller: videoController,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 420,
                child: ValueListenableBuilder<int?>(
                  valueListenable: selectedTranscriptIdListenable,
                  builder: (context, selectedTranscriptId, child) {
                    return _TranscriptPanel(
                      transcripts: lesson.transcripts,
                      isRefreshing: isLoading,
                      scrollController: transcriptScrollController,
                      selectedTranscriptId: selectedTranscriptId,
                      transcriptKeyBuilder: transcriptKeyBuilder,
                      onTranscriptTap: onTranscriptTap,
                    );
                  },
                ),
              ),
            ] else
              SizedBox(
                height: 680,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _VideoPanel(
                        lessonUrl: lesson.url,
                        controller: videoController,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ValueListenableBuilder<int?>(
                          valueListenable: selectedTranscriptIdListenable,
                          builder: (context, selectedTranscriptId, child) {
                            return _TranscriptPanel(
                              transcripts: lesson.transcripts,
                              isRefreshing: isLoading,
                              scrollController: transcriptScrollController,
                              selectedTranscriptId: selectedTranscriptId,
                              transcriptKeyBuilder: transcriptKeyBuilder,
                              onTranscriptTap: onTranscriptTap,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VideoPanel extends StatelessWidget {
  const _VideoPanel({
    required this.lessonUrl,
    required this.controller,
  });

  final String lessonUrl;
  final LessonVideoController controller;

  @override
  Widget build(BuildContext context) {
    final hasUrl = lessonUrl.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Video',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ColorName.labelPrimary,
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: hasUrl
                ? LessonVideoPlayer(
                    url: lessonUrl,
                    controller: controller,
                  )
                : const Center(
                    child: Text(
                      'Video unavailable',
                      style: TextStyle(color: ColorName.labelSecondary),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LessonTopBar extends StatelessWidget {
  const _LessonTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(AppRoutes.topic.path);
          },
          icon: const Icon(SolarIconsOutline.arrowLeft),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ColorName.labelPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _LessonSummaryCard extends StatelessWidget {
  const _LessonSummaryCard({required this.lesson});

  final TopicLessonDetail lesson;

  @override
  Widget build(BuildContext context) {
    final subtitle = lesson.subtitle.trim();
    final description = lesson.description.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: ColorName.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  SolarIconsBold.playCircle,
                  color: ColorName.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title.isEmpty ? 'Untitled lesson' : lesson.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ColorName.labelPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: ColorName.labelSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (description.isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: ColorName.labelPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: ColorName.labelSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: SolarIconsOutline.documentText,
                label: 'Lesson #${lesson.id}',
              ),
              _InfoChip(
                icon: SolarIconsOutline.layers,
                label: 'Section #${lesson.sectionId}',
              ),
              _InfoChip(
                icon: SolarIconsOutline.chatRoundDots,
                label: '${lesson.transcripts.length} transcripts',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({
    required this.transcripts,
    required this.isRefreshing,
    required this.scrollController,
    required this.selectedTranscriptId,
    required this.onTranscriptTap,
    required this.transcriptKeyBuilder,
  });

  final List<TopicTranscript> transcripts;
  final bool isRefreshing;
  final ScrollController scrollController;
  final int? selectedTranscriptId;
  final ValueChanged<TopicTranscript> onTranscriptTap;
  final GlobalKey Function(int transcriptId) transcriptKeyBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Transcripts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ColorName.labelPrimary,
                    ),
                  ),
                ),
                if (isRefreshing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: ColorName.gray5),
          Expanded(
            child: transcripts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No transcripts found',
                        style: TextStyle(color: ColorName.labelSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: transcripts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final transcript = transcripts[index];
                      return _TranscriptTile(
                        key: transcriptKeyBuilder(transcript.id),
                        transcript: transcript,
                        isSelected: transcript.id == selectedTranscriptId,
                        onTap: () => onTranscriptTap(transcript),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptTile extends StatelessWidget {
  const _TranscriptTile({
    required super.key,
    required this.transcript,
    required this.isSelected,
    required this.onTap,
  });

  final TopicTranscript transcript;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? ColorName.primary.withValues(alpha: 0.08) : null,
          border: Border.all(
            color: isSelected ? ColorName.primary : ColorName.gray5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TimeBadge(
                  label:
                      '${_formatSeconds(transcript.timeStart)} - ${_formatSeconds(transcript.timeEnd)}',
                ),
                const SizedBox(width: 8),
                Text(
                  '#${transcript.order}',
                  style: const TextStyle(
                    color: ColorName.labelSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  SolarIconsOutline.play,
                  size: 18,
                  color: isSelected
                      ? ColorName.primary
                      : ColorName.labelSecondary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              transcript.content.isEmpty
                  ? 'No transcript content'
                  : transcript.content,
              style: const TextStyle(
                color: ColorName.labelPrimary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBadge extends StatelessWidget {
  const _TimeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ColorName.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: ColorName.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColorName.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ColorName.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: ColorName.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
  final totalSeconds = value.round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
