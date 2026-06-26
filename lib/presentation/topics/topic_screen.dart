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
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 960;
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      _TopicHeader(selectedTopic: state.selectedTopic),
                      Expanded(
                        child: isCompact
                            ? _CompactTopicView(state: state)
                            : _WideTopicView(state: state),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TopicHeader extends StatelessWidget {
  const _TopicHeader({required this.selectedTopic});

  final TopicSummary? selectedTopic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorName.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              selectedTopic?.isAudio == true
                  ? SolarIconsBold.microphoneLarge
                  : SolarIconsBold.notebook,
              color: ColorName.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedTopic?.name ?? 'Topics',
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
                  selectedTopic == null
                      ? 'Browse topics, sections, and lessons.'
                      : selectedTopic!.isAudio
                      ? 'Audio topic'
                      : 'Reading topic',
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

class _WideTopicView extends StatelessWidget {
  const _WideTopicView({required this.state});

  final TopicState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: _TopicPanel<TopicSummary>(
            title: 'Topics',
            isLoading: state.isLoadingTopics,
            items: state.topics,
            selectedItem: state.selectedTopic,
            emptyLabel: 'No topics found',
            itemBuilder: (topic, selected) => _TopicTile(
              topic: topic,
              selected: selected,
              onTap: () => context.read<TopicCubit>().selectTopic(topic),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _TopicPanel<TopicSection>(
            title: 'Sections',
            isLoading: state.isLoadingSections,
            items: state.sections,
            selectedItem: state.selectedSection,
            emptyLabel: state.selectedTopic == null
                ? 'Select a topic'
                : 'No sections found',
            itemBuilder: (section, selected) => _SectionTile(
              section: section,
              selected: selected,
              onTap: () => context.read<TopicCubit>().selectSection(section),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: _TopicPanel<TopicLesson>(
            title: 'Lessons',
            isLoading: state.isLoadingLessons,
            items: state.lessons,
            selectedItem: null,
            emptyLabel: state.selectedSection == null
                ? 'Select a section'
                : 'No lessons found',
            itemBuilder: (lesson, _) => _LessonTile(lesson: lesson),
          ),
        ),
      ],
    );
  }
}

class _CompactTopicView extends StatelessWidget {
  const _CompactTopicView({required this.state});

  final TopicState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _CompactBlock(
          title: 'Topics',
          child: _TopicPanel<TopicSummary>(
            title: 'Topics',
            isLoading: state.isLoadingTopics,
            items: state.topics,
            selectedItem: state.selectedTopic,
            emptyLabel: 'No topics found',
            showTitle: false,
            itemBuilder: (topic, selected) => _TopicTile(
              topic: topic,
              selected: selected,
              onTap: () => context.read<TopicCubit>().selectTopic(topic),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CompactBlock(
          title: 'Sections',
          child: _TopicPanel<TopicSection>(
            title: 'Sections',
            isLoading: state.isLoadingSections,
            items: state.sections,
            selectedItem: state.selectedSection,
            emptyLabel: state.selectedTopic == null
                ? 'Select a topic'
                : 'No sections found',
            showTitle: false,
            itemBuilder: (section, selected) => _SectionTile(
              section: section,
              selected: selected,
              onTap: () => context.read<TopicCubit>().selectSection(section),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CompactBlock(
          title: 'Lessons',
          child: _TopicPanel<TopicLesson>(
            title: 'Lessons',
            isLoading: state.isLoadingLessons,
            items: state.lessons,
            selectedItem: null,
            emptyLabel: state.selectedSection == null
                ? 'Select a section'
                : 'No lessons found',
            showTitle: false,
            itemBuilder: (lesson, _) => _LessonTile(lesson: lesson),
          ),
        ),
      ],
    );
  }
}

class _CompactBlock extends StatelessWidget {
  const _CompactBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ColorName.labelPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 220, child: child),
      ],
    );
  }
}

class _TopicPanel<T> extends StatelessWidget {
  const _TopicPanel({
    required this.title,
    required this.isLoading,
    required this.items,
    required this.selectedItem,
    required this.emptyLabel,
    required this.itemBuilder,
    this.showTitle = true,
  });

  final String title;
  final bool isLoading;
  final List<T> items;
  final T? selectedItem;
  final String emptyLabel;
  final Widget Function(T item, bool selected) itemBuilder;
  final bool showTitle;

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
          if (showTitle)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorName.labelPrimary,
                ),
              ),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        emptyLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: ColorName.labelSecondary),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return itemBuilder(item, identical(item, selectedItem));
                  },
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemCount: items.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.topic,
    required this.selected,
    required this.onTap,
  });

  final TopicSummary topic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SelectableTile(
      selected: selected,
      onTap: onTap,
      leading: Icon(
        topic.isAudio ? SolarIconsOutline.microphone : SolarIconsOutline.book,
        color: selected ? ColorName.primary : ColorName.labelSecondary,
      ),
      title: topic.name,
      subtitle: topic.isAudio ? 'Audio' : 'Reading',
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final TopicSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SelectableTile(
      selected: selected,
      onTap: onTap,
      leading: Icon(
        SolarIconsOutline.layers,
        color: selected ? ColorName.primary : ColorName.labelSecondary,
      ),
      title: section.name,
      subtitle: 'Section #${section.id}',
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson});

  final TopicLesson lesson;

  @override
  Widget build(BuildContext context) {
    return _SelectableTile(
      selected: false,
      onTap: () => context.push(topicLessonPath(lesson.id)),
      leading: const Icon(
        SolarIconsOutline.playCircle,
        color: ColorName.labelSecondary,
      ),
      title: lesson.title.isEmpty ? 'Untitled lesson' : lesson.title,
      subtitle: lesson.subtitle.isNotEmpty
          ? lesson.subtitle
          : lesson.description.isNotEmpty
          ? lesson.description
          : 'Lesson #${lesson.id}',
      trailing: const Icon(SolarIconsOutline.arrowRight),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.selected,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final bool selected;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? ColorName.primary.withValues(alpha: 0.08) : null,
          border: Border.all(
            color: selected ? ColorName.primary : ColorName.gray5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? ColorName.primary
                          : ColorName.labelPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ColorName.labelSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ...switch (trailing) {
              final Widget trailingWidget => [trailingWidget],
              null => const <Widget>[],
            },
          ],
        ),
      ),
    );
  }
}
