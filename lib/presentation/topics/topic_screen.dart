import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/topic_lesson.dart';
import 'package:eflutter/data/models/topic_summary.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/topics/cubit/topic_cubit.dart';
import 'package:eflutter/presentation/topics/widgets/topic_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Một màn cho cả ba cấp: [topicId] null → danh sách topic; có [topicId] →
/// section của topic; có thêm [sectionId] → lesson của section.
class TopicScreen extends StatefulWidget {
  const TopicScreen({this.topicId, this.sectionId, super.key});

  final int? topicId;
  final int? sectionId;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TopicScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topicId != widget.topicId ||
        oldWidget.sectionId != widget.sectionId) {
      _load();
    }
  }

  void _load() {
    final cubit = context.read<TopicCubit>();
    final topicId = widget.topicId;
    final sectionId = widget.sectionId;
    cubit.loadTopics(refresh: topicId == null);
    if (topicId != null) cubit.loadSections(topicId);
    if (sectionId != null) cubit.loadLessons(sectionId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TopicCubit, TopicState>(
      listener: (context, state) {
        if (state.failure != null) {
          context.handleFailure(state.failure);
        }
      },
      builder: (context, state) {
        final topicId = widget.topicId;
        final sectionId = widget.sectionId;
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                // Cùng khung nội dung với Classrooms.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1224),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: switch ((topicId, sectionId)) {
                      (null, _) => _TopicListView(topics: state.topics),
                      (final topicId?, null) => _SectionListView(
                        topicId: topicId,
                        state: state,
                      ),
                      (final topicId?, final sectionId?) => _LessonListView(
                        topicId: topicId,
                        sectionId: sectionId,
                        state: state,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopicListView extends StatelessWidget {
  const _TopicListView({required this.topics});

  /// null: đang tải.
  final List<TopicSummary>? topics;

  @override
  Widget build(BuildContext context) {
    final topics = this.topics ?? const <TopicSummary>[];
    final videoTopics = topics.where((topic) => !topic.isAudio).toList();
    final audioTopics = topics.where((topic) => topic.isAudio).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TopicHeader(
          icon: SolarIconsBold.notebook,
          title: 'Topics',
          subtitle: 'Choose a topic to start learning',
        ),
        const SizedBox(height: 24),
        if (this.topics == null)
          const SizedBox(height: 200, child: AppLoader())
        else if (topics.isEmpty)
          const _EmptyLabel('No topics found')
        else
          for (final (label, topics) in [
            ('Video', videoTopics),
            ('Audio', audioTopics),
          ])
            if (topics.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      spacing: 8,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: ColorName.labelPrimary,
                          ),
                        ),
                        Text(
                          '${topics.length} topics',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ColorName.labelSecondary,
                          ),
                        ),
                      ],
                    ),
                    _CardGrid(
                      children: [
                        for (final topic in topics)
                          _NavCard(
                            icon: topic.isAudio
                                ? SolarIconsOutline.microphone
                                : SolarIconsOutline.videoFramePlayHorizontal,
                            title: topic.name,
                            subtitle: topic.isAudio ? 'Audio' : 'Video',
                            onTap: () =>
                                context.go(topicSectionsPath(topic.id)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ],
    );
  }
}

class _SectionListView extends StatelessWidget {
  const _SectionListView({required this.topicId, required this.state});

  final int topicId;
  final TopicState state;

  @override
  Widget build(BuildContext context) {
    final topic = state.topic(topicId);
    final sections = state.sections[topicId];
    final isAudio = topic?.isAudio ?? false;
    final kind = isAudio ? 'Audio topic' : 'Video topic';
    void goBack() => context.go(AppRoutes.topic.path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopicBreadcrumb(items: [('Topics', goBack), (topic?.name ?? '', null)]),
        TopicHeader(
          icon: isAudio
              ? SolarIconsOutline.microphone
              : SolarIconsOutline.videoFramePlayHorizontal,
          title: topic?.name ?? '',
          subtitle: sections == null
              ? kind
              : '$kind · ${sections.length} sections',
          onBack: goBack,
        ),
        const SizedBox(height: 24),
        if (sections == null)
          const SizedBox(height: 200, child: AppLoader())
        else if (sections.isEmpty)
          const _EmptyLabel('No sections found')
        else
          _CardGrid(
            children: [
              for (final section in sections)
                _NavCard(
                  icon: SolarIconsOutline.layers,
                  title: section.name,
                  onTap: () =>
                      context.go(topicLessonsPath(topicId, section.id)),
                ),
            ],
          ),
      ],
    );
  }
}

class _LessonListView extends StatelessWidget {
  const _LessonListView({
    required this.topicId,
    required this.sectionId,
    required this.state,
  });

  final int topicId;
  final int sectionId;
  final TopicState state;

  @override
  Widget build(BuildContext context) {
    final topicName = state.topic(topicId)?.name ?? '';
    final sectionName = state.section(topicId, sectionId)?.name ?? '';
    final lessons = state.lessons[sectionId];
    void goBack() => context.go(topicSectionsPath(topicId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopicBreadcrumb(
          items: [
            ('Topics', () => context.go(AppRoutes.topic.path)),
            (topicName, goBack),
            (sectionName, null),
          ],
        ),
        TopicHeader(
          icon: SolarIconsOutline.layers,
          title: sectionName,
          subtitle: lessons == null
              ? topicName
              : '$topicName · ${lessons.length} lessons',
          onBack: goBack,
        ),
        const SizedBox(height: 24),
        if (lessons == null)
          const SizedBox(height: 200, child: AppLoader())
        else if (lessons.isEmpty)
          const _EmptyLabel('No lessons found')
        else
          Material(
            color: ColorName.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: ColorName.gray5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (final (index, lesson) in lessons.indexed) ...[
                  if (index > 0)
                    const Divider(height: 1, color: ColorName.gray6),
                  _LessonRow(
                    index: index,
                    lesson: lesson,
                    path: topicLessonPath(topicId, sectionId, lesson.id),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.index,
    required this.lesson,
    required this.path,
  });

  final int index;
  final TopicLesson lesson;
  final String path;

  @override
  Widget build(BuildContext context) {
    // description có dạng "29 parts · Vocab level: B1"; một số topic để trống.
    final detail = lesson.description.isNotEmpty
        ? lesson.description
        : lesson.subtitle;
    return InkWell(
      onTap: () => context.go(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          spacing: 16,
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: ColorName.gray1,
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ColorName.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                SolarIconsOutline.playCircle,
                color: ColorName.primary,
                size: 22,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    lesson.title.isEmpty ? 'Untitled lesson' : lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ColorName.labelPrimary,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ColorName.labelSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              SolarIconsOutline.altArrowRight,
              size: 20,
              color: ColorName.labelSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLabel extends StatelessWidget {
  const _EmptyLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: ColorName.labelSecondary),
        ),
      ),
    );
  }
}

/// Lưới card tự đổi số cột theo bề rộng (tối đa 3, giống Classrooms).
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 880
            ? 3
            : width >= 560
            ? 2
            : 1;
        final cardWidth = (width - 16 * (columns - 1)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorName.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: subtitle == null ? 72 : 88,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: ColorName.gray5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            spacing: 16,
            children: [
              Container(
                width: subtitle == null ? 40 : 44,
                height: subtitle == null ? 40 : 44,
                decoration: BoxDecoration(
                  color: ColorName.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: ColorName.primary,
                  size: subtitle == null ? 20 : 22,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ColorName.labelPrimary,
                      ),
                    ),
                    if (subtitle case final subtitle?)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ColorName.labelSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                SolarIconsOutline.altArrowRight,
                size: 20,
                color: ColorName.labelSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
