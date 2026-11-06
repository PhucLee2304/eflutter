import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/topic_lesson.dart';
import 'package:eflutter/data/models/topic_section.dart';
import 'package:eflutter/data/models/topic_summary.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/topics/cubit/topic_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key});

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TopicCubit>().load();
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
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                // Cùng khung nội dung với Classrooms.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1224),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: switch ((
                      state.selectedTopic,
                      state.selectedSection,
                    )) {
                      (null, _) => _TopicListView(state: state),
                      (final topic?, null) => _SectionListView(
                        topic: topic,
                        state: state,
                      ),
                      (final topic?, final section?) => _LessonListView(
                        topic: topic,
                        section: section,
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

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.items});

  /// Mục cuối là trang hiện tại nên không có onTap.
  final List<(String, VoidCallback?)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (index, (label, onTap)) in items.indexed) ...[
            if (index > 0)
              const Icon(
                SolarIconsOutline.altArrowRight,
                size: 14,
                color: ColorName.gray1,
              ),
            if (onTap == null)
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ColorName.labelPrimary,
                ),
              )
            else
              InkWell(
                onTap: onTap,
                child: Text(
                  label,
                  style: const TextStyle(color: ColorName.primary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TopicHeader extends StatelessWidget {
  const _TopicHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        spacing: 12,
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: 'Back',
              style: IconButton.styleFrom(
                side: const BorderSide(color: ColorName.gray5),
              ),
              icon: const Icon(SolarIconsOutline.arrowLeft, size: 18),
            ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorName.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: ColorName.primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ColorName.labelPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: ColorName.labelSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicListView extends StatelessWidget {
  const _TopicListView({required this.state});

  final TopicState state;

  @override
  Widget build(BuildContext context) {
    final videoTopics = state.topics.where((topic) => !topic.isAudio).toList();
    final audioTopics = state.topics.where((topic) => topic.isAudio).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TopicHeader(
          icon: SolarIconsBold.notebook,
          title: 'Topics',
          subtitle: 'Choose a topic to start learning',
        ),
        const SizedBox(height: 24),
        if (state.isLoadingTopics)
          const SizedBox(height: 200, child: AppLoader())
        else if (state.topics.isEmpty)
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
                                context.read<TopicCubit>().selectTopic(topic),
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
  const _SectionListView({required this.topic, required this.state});

  final TopicSummary topic;
  final TopicState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TopicCubit>();
    final kind = topic.isAudio ? 'Audio topic' : 'Video topic';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Breadcrumb(items: [('Topics', cubit.clearTopic), (topic.name, null)]),
        _TopicHeader(
          icon: topic.isAudio
              ? SolarIconsOutline.microphone
              : SolarIconsOutline.videoFramePlayHorizontal,
          title: topic.name,
          subtitle: state.isLoadingSections
              ? kind
              : '$kind · ${state.sections.length} sections',
          onBack: cubit.clearTopic,
        ),
        const SizedBox(height: 24),
        if (state.isLoadingSections)
          const SizedBox(height: 200, child: AppLoader())
        else if (state.sections.isEmpty)
          const _EmptyLabel('No sections found')
        else
          _CardGrid(
            children: [
              for (final section in state.sections)
                _NavCard(
                  icon: SolarIconsOutline.layers,
                  title: section.name,
                  onTap: () => cubit.selectSection(section),
                ),
            ],
          ),
      ],
    );
  }
}

class _LessonListView extends StatelessWidget {
  const _LessonListView({
    required this.topic,
    required this.section,
    required this.state,
  });

  final TopicSummary topic;
  final TopicSection section;
  final TopicState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TopicCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Breadcrumb(
          items: [
            ('Topics', cubit.clearTopic),
            (topic.name, cubit.clearSection),
            (section.name, null),
          ],
        ),
        _TopicHeader(
          icon: SolarIconsOutline.layers,
          title: section.name,
          subtitle: state.isLoadingLessons
              ? topic.name
              : '${topic.name} · ${state.lessons.length} lessons',
          onBack: cubit.clearSection,
        ),
        const SizedBox(height: 24),
        if (state.isLoadingLessons)
          const SizedBox(height: 200, child: AppLoader())
        else if (state.lessons.isEmpty)
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
                for (final (index, lesson) in state.lessons.indexed) ...[
                  if (index > 0)
                    const Divider(height: 1, color: ColorName.gray6),
                  _LessonRow(index: index, lesson: lesson),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.index, required this.lesson});

  final int index;
  final TopicLesson lesson;

  @override
  Widget build(BuildContext context) {
    // description có dạng "29 parts · Vocab level: B1"; một số topic để trống.
    final detail = lesson.description.isNotEmpty
        ? lesson.description
        : lesson.subtitle;
    return InkWell(
      onTap: () => context.push(topicLessonPath(lesson.id)),
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
