import 'package:eflutter/core/base/remote_data_base.dart';
import 'dart:async';

import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/date_time_extension.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/exams/cubit/exam_history_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class ExamHistoryScreen extends StatefulWidget {
  const ExamHistoryScreen({super.key});

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  late final ExamHistoryCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ExamHistoryCubit(ExamRepository(getIt<RemoteDataBase>()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cubit.load(status: ExamHistoryStatus.submitted);
    });
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExamHistoryCubit, ExamHistoryState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state.failure != null) {
          context.handleFailure(state.failure);
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cubit.refresh,
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: _HistoryHeader(cubit: _cubit, state: state),
                          ),
                        ),
                        if (state.isLoading && state.attempts.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (state.attempts.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyHistories(status: state.status),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverList.separated(
                              itemCount: state.attempts.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) => _AttemptCard(
                                attempt: state.attempts[index],
                                status: state.status,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _HistoryPager(cubit: _cubit, state: state),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.cubit, required this.state});

  final ExamHistoryCubit cubit;
  final ExamHistoryState state;

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
          final compact = constraints.maxWidth < 760;
          final title = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ColorName.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  SolarIconsOutline.documentText,
                  color: ColorName.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Histories',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ColorName.labelPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Exam attempts by status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ColorName.labelSecondary),
                    ),
                  ],
                ),
              ),
            ],
          );

          final tabs = SegmentedButton<ExamHistoryStatus>(
            segments: ExamHistoryStatus.values
                .map(
                  (status) =>
                      ButtonSegment(value: status, label: Text(status.label)),
                )
                .toList(),
            selected: {state.status},
            onSelectionChanged: state.isLoading
                ? null
                : (values) => cubit.selectStatus(values.first),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [title, tabs],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              tabs,
            ],
          );
        },
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({required this.attempt, required this.status});

  final ExamAttempt attempt;
  final ExamHistoryStatus status;

  @override
  Widget build(BuildContext context) {
    final profile = _AttemptStatusProfile.fromStatus(status);
    final exam = attempt.exam;
    final title = exam?.title.trim().isNotEmpty == true
        ? exam!.title
        : 'Exam #${attempt.examId}';
    final type = exam?.type.trim().isNotEmpty == true ? exam!.type : 'Exam';
    final year = exam?.year;
    final scope = _scopeLabel(attempt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorName.white,
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: profile.color.withValues(alpha: 0.12),
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
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ColorName.labelPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(label: year == null ? type : '$type $year'),
                        _Pill(label: _titleCase(attempt.mode)),
                        if (attempt.duration != null)
                          _Pill(label: '${attempt.duration} min'),
                        if (scope != null) _Pill(label: scope),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          _AttemptMetadata(attempt: attempt, status: status),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                if (status == ExamHistoryStatus.active) {
                  context.push(attemptPracticePath(attempt.id));
                } else {
                  context.push(attemptHistoryDetailPath(attempt.id));
                }
              },
              icon: Icon(
                status == ExamHistoryStatus.active
                    ? SolarIconsOutline.playCircle
                    : SolarIconsOutline.documentText,
              ),
              label: Text(
                status == ExamHistoryStatus.active
                    ? 'Continue attempt'
                    : 'View history',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _scopeLabel(ExamAttempt attempt) {
    if (attempt.section?.trim().isNotEmpty == true) {
      return 'Section ${attempt.section}';
    }
    if (attempt.parts.isNotEmpty) {
      return 'Parts ${attempt.parts.join(', ')}';
    }
    return null;
  }
}

class _AttemptMetadata extends StatelessWidget {
  const _AttemptMetadata({required this.attempt, required this.status});

  final ExamAttempt attempt;
  final ExamHistoryStatus status;

  @override
  Widget build(BuildContext context) {
    final items = switch (status) {
      ExamHistoryStatus.active => [
        _MetaItem(
          icon: SolarIconsOutline.playCircle,
          label: 'Started',
          value: _formatDateTime(attempt.startedAt),
        ),
        _MetaItem(
          icon: SolarIconsOutline.documentText,
          label: 'Progress',
          value: _formatProgress(attempt),
        ),
        if (attempt.expiresAt != null)
          _CountdownMetaItem(expiresAt: attempt.expiresAt!),
      ],
      ExamHistoryStatus.submitted => [
        _MetaItem(
          icon: SolarIconsOutline.playCircle,
          label: 'Started',
          value: _formatDateTime(attempt.startedAt),
        ),
        _MetaItem(
          icon: SolarIconsOutline.documentText,
          label: 'Submitted',
          value: _formatDateTime(
            attempt.submittedAt ?? attempt.updatedAt ?? attempt.expiresAt,
          ),
        ),
        _MetaItem(
          icon: SolarIconsOutline.documentText,
          label: 'Progress',
          value: _formatProgress(attempt),
        ),
        if (attempt.correctAnswers != null)
          _MetaItem(
            icon: SolarIconsOutline.documentText,
            label: 'Correct',
            value: '${attempt.correctAnswers}/${attempt.totalQuestions}',
          ),
        if (attempt.score != null)
          _MetaItem(
            icon: SolarIconsOutline.playCircle,
            label: 'Score',
            value: _formatScore(attempt.score!),
          ),
      ],
      ExamHistoryStatus.cancelled => [
        _MetaItem(
          icon: SolarIconsOutline.playCircle,
          label: 'Started',
          value: _formatDateTime(attempt.startedAt),
        ),
        _MetaItem(
          icon: SolarIconsOutline.documentText,
          label: 'Progress',
          value: _formatProgress(attempt),
        ),
      ],
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns.clamp(1, items.length),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 58,
          ),
          children: items,
        );
      },
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColorName.gray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ColorName.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColorName.labelSecondary,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
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

class _CountdownMetaItem extends StatefulWidget {
  const _CountdownMetaItem({required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<_CountdownMetaItem> createState() => _CountdownMetaItemState();
}

class _CountdownMetaItemState extends State<_CountdownMetaItem> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _calculateRemaining();
      });
    });
  }

  @override
  void didUpdateWidget(covariant _CountdownMetaItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _remaining = _calculateRemaining();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Duration _calculateRemaining() {
    final diff = widget.expiresAt.toLocal().difference(DateTime.now());
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    return _MetaItem(
      icon: SolarIconsOutline.playCircle,
      label: 'Remaining',
      value: _remaining == Duration.zero
          ? 'Expired'
          : _formatDuration(_remaining),
    );
  }
}

class _HistoryPager extends StatelessWidget {
  const _HistoryPager({required this.cubit, required this.state});

  final ExamHistoryCubit cubit;
  final ExamHistoryState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: ColorName.white,
        border: Border(top: BorderSide(color: ColorName.gray5)),
      ),
      child: Row(
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
      ),
    );
  }
}

class _EmptyHistories extends StatelessWidget {
  const _EmptyHistories({required this.status});

  final ExamHistoryStatus status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              SolarIconsOutline.documentText,
              size: 42,
              color: ColorName.labelSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No ${status.label.toLowerCase()} attempts',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorName.labelPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Attempts will appear here after you start taking exams.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColorName.labelSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ColorName.gray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ColorName.labelSecondary,
        ),
      ),
    );
  }
}

class _AttemptStatusProfile {
  const _AttemptStatusProfile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  static _AttemptStatusProfile fromStatus(ExamHistoryStatus status) {
    return switch (status) {
      ExamHistoryStatus.active => const _AttemptStatusProfile(
        icon: SolarIconsOutline.playCircle,
        color: ColorName.primary,
      ),
      ExamHistoryStatus.submitted => const _AttemptStatusProfile(
        icon: SolarIconsOutline.documentText,
        color: ColorName.green,
      ),
      ExamHistoryStatus.cancelled => const _AttemptStatusProfile(
        icon: SolarIconsOutline.documentText,
        color: ColorName.orange,
      ),
    };
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '-';
  return value.toLocal().toFormatString(pattern: 'dd/MM/yyyy HH:mm');
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
}

String _formatScore(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}

String _formatProgress(ExamAttempt attempt) {
  if (attempt.totalQuestions <= 0) return '-';
  return '${attempt.answeredCount}/${attempt.totalQuestions}';
}

String _titleCase(String value) {
  if (value.isEmpty) return '-';
  final lower = value.toLowerCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}
