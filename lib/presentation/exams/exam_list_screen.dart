import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/exam_summary.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/exams/cubit/exam_list_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key, required this.examType});

  final String examType;

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  late final ExamListCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ExamListCubit(
      ExamRepository(getIt<RemoteDataBase>()),
      examType: widget.examType,
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _ExamTypeProfile.fromType(widget.examType);
    return BlocConsumer<ExamListCubit, ExamListState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state.failure != null) {
          context.handleFailure(state.failure);
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _cubit.refresh,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ExamHeader(profile: profile, state: state),
                    ),
                  ),
                  if (state.isLoading && state.exams.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.exams.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyExams(profile: profile),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final columns = width >= 1180
                              ? 3
                              : width >= 760
                              ? 2
                              : 1;
                          return SliverGrid(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return _ExamCard(
                                exam: state.exams[index],
                                profile: profile,
                              );
                            }, childCount: state.exams.length),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 184,
                                ),
                          );
                        },
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverToBoxAdapter(
                        child: _ExamPager(cubit: _cubit, state: state),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExamHeader extends StatelessWidget {
  const _ExamHeader({required this.profile, required this.state});

  final _ExamTypeProfile profile;
  final ExamListState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final title = Row(
            children: [
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
                      profile.title,
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
                      profile.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColorName.labelSecondary),
                    ),
                  ],
                ),
              ),
            ],
          );

          final stats = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _MetricPill(
                icon: SolarIconsOutline.documentText,
                label: '${state.exams.length} shown',
              ),
              _MetricPill(
                icon: SolarIconsOutline.layers,
                label: profile.structure,
              ),
              _MetricPill(
                icon: SolarIconsOutline.playCircle,
                label: profile.duration,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [title, stats],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              stats,
            ],
          );
        },
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.profile});

  final ExamSummary exam;
  final _ExamTypeProfile profile;

  @override
  Widget build(BuildContext context) {
    final description = exam.description.trim();
    return Material(
      color: ColorName.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => context.push(examDetailPath(exam.type, exam.id)),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: profile.tintColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(profile.icon, color: profile.color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ColorName.labelPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exam.year == null
                              ? exam.type
                              : '${exam.type} ${exam.year}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ColorName.labelSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  description.isEmpty ? profile.emptyDescription : description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    height: 1.35,
                    color: ColorName.labelSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusPill(
                    label: exam.isPublic ? 'Public' : 'Private',
                    color: exam.isPublic ? ColorName.green : ColorName.orange,
                  ),
                  _StatusPill(
                    label: profile.questionCount,
                    color: profile.color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamPager extends StatelessWidget {
  const _ExamPager({required this.cubit, required this.state});

  final ExamListCubit cubit;
  final ExamListState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          tooltip: 'Previous page',
          onPressed: state.canGoPrevious && !state.isLoading
              ? cubit.previousPage
              : null,
          icon: const Icon(SolarIconsOutline.altArrowLeft),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Page ${state.page} of ${state.pageCounts}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: ColorName.labelSecondary,
              ),
            ),
          ),
        ),
        IconButton.outlined(
          tooltip: 'Next page',
          onPressed: state.canGoNext && !state.isLoading
              ? cubit.nextPage
              : null,
          icon: const Icon(SolarIconsOutline.altArrowRight),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColorName.gray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ColorName.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ColorName.labelPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

class _EmptyExams extends StatelessWidget {
  const _EmptyExams({required this.profile});

  final _ExamTypeProfile profile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(profile.icon, size: 44, color: ColorName.labelSecondary),
          const SizedBox(height: 12),
          Text(
            'No ${profile.title} exams found',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: ColorName.labelPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamTypeProfile {
  const _ExamTypeProfile({
    required this.title,
    required this.subtitle,
    required this.structure,
    required this.duration,
    required this.questionCount,
    required this.emptyDescription,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String structure;
  final String duration;
  final String questionCount;
  final String emptyDescription;
  final IconData icon;
  final Color color;

  Color get tintColor => color.withValues(alpha: 0.12);

  static _ExamTypeProfile fromType(String type) {
    return switch (type.toUpperCase()) {
      'TOEIC' => const _ExamTypeProfile(
        title: 'TOEIC',
        subtitle: 'Listening and reading test sets',
        structure: '2 sections',
        duration: '120 min',
        questionCount: '200 questions',
        emptyDescription: 'TOEIC listening and reading practice test.',
        icon: SolarIconsOutline.headphonesRound,
        color: ColorName.blue,
      ),
      _ => const _ExamTypeProfile(
        title: 'THPT',
        subtitle: 'National high school English exams',
        structure: 'Full test',
        duration: '60 min',
        questionCount: '50 questions',
        emptyDescription: 'THPT English practice exam.',
        icon: SolarIconsOutline.documentText,
        color: ColorName.primary,
      ),
    };
  }
}
