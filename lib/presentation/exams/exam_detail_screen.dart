import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/exam_detail.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/cubit/exam_detail_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class ExamDetailScreen extends StatefulWidget {
  const ExamDetailScreen({super.key, required this.examId});

  final int examId;

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  late final ExamDetailCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ExamDetailCubit(ExamRepository(getIt<RemoteDataBase>()))
      ..load(widget.examId);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExamDetailCubit, ExamDetailState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state.failure != null) {
          context.handleFailure(state.failure);
        }
      },
      builder: (context, state) {
        final exam = state.exam;
        return Scaffold(
          body: SafeArea(
            child: state.isLoading && exam == null
                ? const Center(child: CircularProgressIndicator())
                : exam == null
                ? _MissingExam(onBack: context.pop)
                : _ExamDetailBody(exam: exam),
          ),
        );
      },
    );
  }
}

class _ExamDetailBody extends StatelessWidget {
  const _ExamDetailBody({required this.exam});

  final ExamDetail exam;

  @override
  Widget build(BuildContext context) {
    final profile = _ExamTypeProfile.fromType(exam.type);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _DetailHeader(exam: exam, profile: profile),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              _MetricGrid(exam: exam),
              const SizedBox(height: 16),
              _SectionOverview(sections: exam.sections),
              const SizedBox(height: 16),
              _PartOverview(parts: exam.parts, type: exam.type),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.exam, required this.profile});

  final ExamDetail exam;
  final _ExamTypeProfile profile;

  @override
  Widget build(BuildContext context) {
    final description = exam.description.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.outlined(
                tooltip: 'Back',
                onPressed: context.pop,
                icon: const Icon(SolarIconsOutline.arrowLeft),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: profile.tintColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(profile.icon, color: profile.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ColorName.labelPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(label: exam.type, color: profile.color),
                        if (exam.year != null)
                          _Pill(
                            label: exam.year.toString(),
                            color: ColorName.labelSecondary,
                          ),
                        _Pill(
                          label: exam.isPublic ? 'Public' : 'Private',
                          color: exam.isPublic
                              ? ColorName.green
                              : ColorName.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            description.isEmpty ? profile.emptyDescription : description,
            style: const TextStyle(
              height: 1.4,
              color: ColorName.labelSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.exam});

  final ExamDetail exam;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 94,
          ),
          children: [
            _MetricCard(
              icon: SolarIconsOutline.playCircle,
              label: 'Duration',
              value: '${exam.duration} min',
            ),
            _MetricCard(
              icon: SolarIconsOutline.documentText,
              label: 'Questions',
              value: '${exam.totalQuestions}',
            ),
            _MetricCard(
              icon: SolarIconsOutline.layers,
              label: 'Sections',
              value: '${exam.totalSections}',
            ),
            _MetricCard(
              icon: SolarIconsOutline.book,
              label: 'Parts',
              value: exam.parts.isEmpty ? '-' : '${exam.parts.length}',
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorName.gray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: ColorName.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColorName.labelSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ColorName.labelPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionOverview extends StatelessWidget {
  const _SectionOverview({required this.sections});

  final List<ExamSectionSummary> sections;

  @override
  Widget build(BuildContext context) {
    return _OverviewBlock(
      title: 'Sections',
      children: sections
          .map(
            (section) => _OverviewRow(
              icon: SolarIconsOutline.layers,
              title: section.title,
              subtitle: [
                section.code,
                '${section.questionCount} questions',
                if (section.duration != null) '${section.duration} min',
              ].join(' · '),
            ),
          )
          .toList(),
    );
  }
}

class _PartOverview extends StatelessWidget {
  const _PartOverview({required this.parts, required this.type});

  final List<ExamPartSummary> parts;
  final String type;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return _OverviewBlock(
        title: 'Parts',
        children: [
          _OverviewRow(
            icon: SolarIconsOutline.documentText,
            title: type.toUpperCase() == 'THPT' ? 'Full test' : 'No parts',
            subtitle: type.toUpperCase() == 'THPT'
                ? 'THPT is organized as one full section.'
                : 'No part summary available.',
          ),
        ],
      );
    }

    return _OverviewBlock(
      title: 'Parts',
      children: parts
          .map(
            (part) => _OverviewRow(
              icon: SolarIconsOutline.book,
              title: part.part,
              subtitle: '${part.sectionCode} · ${part.questionCount} questions',
            ),
          )
          .toList(),
    );
  }
}

class _OverviewBlock extends StatelessWidget {
  const _OverviewBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorName.labelPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: ColorName.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ColorName.labelPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MissingExam extends StatelessWidget {
  const _MissingExam({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Exam not found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ColorName.labelPrimary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(SolarIconsOutline.arrowLeft),
            label: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

class _ExamTypeProfile {
  const _ExamTypeProfile({
    required this.icon,
    required this.color,
    required this.emptyDescription,
  });

  final IconData icon;
  final Color color;
  final String emptyDescription;

  Color get tintColor => color.withValues(alpha: 0.12);

  static _ExamTypeProfile fromType(String type) {
    return switch (type.toUpperCase()) {
      'TOEIC' => const _ExamTypeProfile(
        icon: SolarIconsOutline.headphonesRound,
        color: ColorName.blue,
        emptyDescription: 'TOEIC listening and reading practice test.',
      ),
      _ => const _ExamTypeProfile(
        icon: SolarIconsOutline.documentText,
        color: ColorName.primary,
        emptyDescription: 'THPT English practice exam.',
      ),
    };
  }
}
