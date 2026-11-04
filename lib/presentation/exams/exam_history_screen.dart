import 'dart:async';

import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/utils/extensions/date_time_extension.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/exams/cubit/exam_history_cubit.dart';
import 'package:eflutter/presentation/exams/exam_history_refresh.dart';
import 'package:eflutter/presentation/exams/self_study/self_study_header.dart';
import 'package:eflutter/presentation/exams/self_study/self_study_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const _thptAccent = Color(0xFFC2410C);
const _thptTint = Color(0xFFFFF4EC);

/// Lịch sử tự luyện TOEIC/THPT: tổng quan theo kỳ thi, lọc loại đề, tìm theo tên và bảng lượt làm.
class ExamHistoryScreen extends StatefulWidget {
  const ExamHistoryScreen({super.key});

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  late final ExamHistoryCubit _cubit;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _cubit = ExamHistoryCubit(ExamRepository(getIt<RemoteDataBase>()));
    SelfStudyStatsStore.instance.ensureLoaded();
    examHistoryRevision.addListener(_reloadAfterAttemptChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cubit.load();
    });
  }

  @override
  void dispose() {
    examHistoryRevision.removeListener(_reloadAfterAttemptChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _reloadAfterAttemptChanged() {
    if (!_cubit.isClosed) _cubit.load();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _cubit.setSearch(value));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExamHistoryCubit, ExamHistoryState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state.failure != null) context.handleFailure(state.failure);
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF1F3F7),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_cubit.refresh(), SelfStudyStatsStore.instance.reload()]);
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Centered(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: ValueListenableBuilder(
                        valueListenable: SelfStudyStatsStore.instance.stats,
                        builder: (context, stats, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 20,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => context.go(AppRoutes.examToeic.path),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Back'),
                              ),
                            ),
                            _SummaryRow(stats: stats),
                            _Toolbar(
                              examType: state.examType,
                              stats: stats,
                              controller: _searchController,
                              onTypeChanged: _cubit.setExamType,
                              onSearchChanged: _onSearchChanged,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (state.isLoading && state.attempts.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: AppLoader())
                  else if (state.attempts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyHistory(
                        filtered: state.search.isNotEmpty || state.examType != null,
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: _Centered(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: _AttemptTable(attempts: state.attempts),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _Centered(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: PageNumberBar(
                          page: state.page,
                          pageCounts: state.pageCounts,
                          enabled: !state.isLoading,
                          onSelect: _cubit.goToPage,
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(
                    child: _Centered(
                      padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: Text(
                        'Classroom assignments are not listed here — open them from the class’s '
                        'Classwork tab.',
                        style: TextStyle(fontSize: 12, color: selfStudyMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1048),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _TypeStyle {
  const _TypeStyle(this.accent, this.tint, this.subtitle);

  final Color accent;
  final Color tint;
  final String subtitle;

  static _TypeStyle of(String type) => type == 'THPT'
      ? const _TypeStyle(_thptAccent, _thptTint, 'English')
      : const _TypeStyle(ColorName.primary, selfStudyTint, 'Listening & Reading');
}

class _TypePill extends StatelessWidget {
  const _TypePill(this.type);

  final String type;

  @override
  Widget build(BuildContext context) {
    final style = _TypeStyle.of(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: style.tint, borderRadius: BorderRadius.circular(6)),
      child: Text(
        type,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: style.accent),
      ),
    );
  }
}

/// Hai thẻ tổng quan TOEIC / THPT với cùng bộ chỉ số.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.stats});

  final Map<String, SelfStudyStats> stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final type in selfStudyExamTypes) _SummaryCard(type: type, stats: stats[type]),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 720
          ? Column(spacing: 12, children: cards)
          : Row(spacing: 16, children: [for (final card in cards) Expanded(child: card)]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.type, required this.stats});

  final String type;
  final SelfStudyStats? stats;

  @override
  Widget build(BuildContext context) {
    final style = _TypeStyle.of(type);
    final stats = this.stats;
    final scale = type == 'THPT' ? '/ 10' : '/ 990';
    String score(double? value) => value == null ? '–' : formatSelfStudyScore(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: ColorName.white,
        border: Border.all(color: selfStudyBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Row(
            spacing: 8,
            children: [
              _TypePill(type),
              Text(style.subtitle, style: const TextStyle(fontSize: 12, color: selfStudyMuted)),
            ],
          ),
          Row(
            children: [
              _SummaryStat(label: 'Attempts', value: '${stats?.attempts ?? 0}'),
              _SummaryStat(
                label: 'Best',
                value: score(stats?.bestScore),
                unit: scale,
                color: style.accent,
              ),
              _SummaryStat(label: 'Average', value: score(stats?.averageScore), unit: scale),
              _SummaryStat(
                label: 'Tests done',
                value: '${stats?.testsDone ?? 0}',
                unit: stats?.examTotal == null ? null : '/ ${stats!.examTotal}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value, this.unit, this.color});

  final String label;
  final String value;
  final String? unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selfStudyMuted,
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color ?? ColorName.labelPrimary,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(fontSize: 12, color: selfStudyMuted),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.examType,
    required this.stats,
    required this.controller,
    required this.onTypeChanged,
    required this.onSearchChanged,
  });

  final String? examType;
  final Map<String, SelfStudyStats> stats;
  final TextEditingController controller;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: selfStudyBorder),
    );
    int count(String type) => stats[type]?.attempts ?? 0;
    final all = selfStudyExamTypes.fold(0, (sum, type) => sum + count(type));
    final segments = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ColorName.white,
        border: Border.all(color: selfStudyBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          _Segment(
            label: 'All · $all',
            selected: examType == null,
            onTap: () => onTypeChanged(null),
          ),
          for (final type in selfStudyExamTypes)
            _Segment(
              label: '$type · ${count(type)}',
              selected: examType == type,
              onTap: () => onTypeChanged(type),
            ),
        ],
      ),
    );
    final search = TextField(
      controller: controller,
      onChanged: onSearchChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search tests you practiced',
        hintStyle: const TextStyle(color: selfStudyMuted, fontSize: 14),
        prefixIcon: const Icon(SolarIconsOutline.magnifier, size: 18, color: selfStudyMuted),
        isDense: true,
        filled: true,
        fillColor: ColorName.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: ColorName.primary)),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 560
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [segments, search],
            )
          : Row(
              spacing: 12,
              children: [
                segments,
                Expanded(child: search),
              ],
            ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ColorName.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? ColorName.white : selfStudyMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bảng lượt làm; màn hẹp chuyển mỗi dòng thành thẻ gọn.
class _AttemptTable extends StatelessWidget {
  const _AttemptTable({required this.attempts});

  final List<ExamAttempt> attempts;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ColorName.white,
        border: Border.all(color: selfStudyBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return Column(
            children: [
              if (wide) const _HeaderRow(),
              for (var i = 0; i < attempts.length; i++) ...[
                if (i > 0 || wide) const Divider(height: 1, color: Color(0xFFEEF1F5)),
                wide ? _AttemptRow(attempt: attempts[i]) : _AttemptTile(attempt: attempts[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

const _flexes = [32, 9, 19, 11, 13, 12];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const labels = ['TEST', 'TYPE', 'SCORE', 'TIME SPENT', 'SUBMITTED', ''];
    return Container(
      color: const Color(0xFFF7F9FB),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: _flexes[i],
              child: Text(
                labels[i],
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: selfStudyMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.attempt});

  final ExamAttempt attempt;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 13, color: selfStudyMuted);
    final cells = <Widget>[
      _AttemptTitle(attempt: attempt),
      Align(alignment: Alignment.centerLeft, child: _TypePill(_typeOf(attempt))),
      _ScoreCell(attempt: attempt),
      Text(_timeSpent(attempt), style: muted),
      Text(_submitted(attempt), style: muted),
      Align(
        alignment: Alignment.centerRight,
        child: _ReviewButton(attempt: attempt),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: _flexes[i],
              child: Padding(
                padding: EdgeInsets.only(right: i == cells.length - 1 ? 0 : 12),
                child: cells[i],
              ),
            ),
        ],
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({required this.attempt});

  final ExamAttempt attempt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(child: _AttemptTitle(attempt: attempt)),
              _TypePill(_typeOf(attempt)),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 12,
            children: [
              Expanded(child: _ScoreCell(attempt: attempt)),
              _ReviewButton(attempt: attempt),
            ],
          ),
          Text(
            '${_submitted(attempt)} · ${_timeSpent(attempt)}',
            style: const TextStyle(fontSize: 12, color: selfStudyMuted),
          ),
        ],
      ),
    );
  }
}

class _AttemptTitle extends StatelessWidget {
  const _AttemptTitle({required this.attempt});

  final ExamAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final exam = attempt.exam;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 3,
      children: [
        Text(
          exam?.title.isNotEmpty == true ? exam!.title : 'Exam #${attempt.examId}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ColorName.labelPrimary,
          ),
        ),
        Text(
          _detail(attempt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: selfStudyMuted),
        ),
      ],
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.attempt});

  final ExamAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final score = attempt.score;
    if (score == null) return const Text('–', style: TextStyle(color: selfStudyMuted));
    final max = _maxScore(attempt);
    final ratio = max == null ? null : (score / max).clamp(0.0, 1.0);
    final color = ratio == null
        ? ColorName.primary
        : ratio >= 0.75
        ? const Color(0xFF16A34A)
        : ratio >= 0.6
        ? ColorName.primary
        : const Color(0xFFF59E0B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatSelfStudyScore(score),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorName.labelPrimary,
                ),
              ),
              if (max != null)
                TextSpan(
                  text: ' / ${formatSelfStudyScore(max)}',
                  style: const TextStyle(fontSize: 12, color: selfStudyMuted),
                ),
            ],
          ),
        ),
        if (ratio != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                color: color,
                backgroundColor: const Color(0xFFEEF1F5),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({required this.attempt});

  final ExamAttempt attempt;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => context.push(attemptHistoryDetailPath(attempt.id)),
      style: OutlinedButton.styleFrom(
        foregroundColor: ColorName.primary,
        side: const BorderSide(color: selfStudyBorder),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: Size.zero,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Review'),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const Icon(SolarIconsOutline.history, size: 44, color: ColorName.labelSecondary),
            Text(
              filtered ? 'No attempts match your filters' : 'No practice attempts yet',
              style: const TextStyle(fontWeight: FontWeight.w700, color: ColorName.labelPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

String _typeOf(ExamAttempt attempt) => attempt.exam?.type ?? 'TOEIC';

/// Thang điểm: THPT /10, TOEIC một kỹ năng /495, cả bài /990; luyện theo Part thì không có thang.
double? _maxScore(ExamAttempt attempt) {
  if (_typeOf(attempt) == 'THPT') return 10;
  if (attempt.parts.isNotEmpty) return null;
  final section = attempt.section;
  return section == 'LISTENING' || section == 'READING' ? 495 : 990;
}

String _detail(ExamAttempt attempt) {
  final parts = <String>[];
  final section = attempt.section;
  if (attempt.parts.isNotEmpty) {
    parts.add(attempt.parts.map((p) => p.replaceAll('_', ' ').toLowerCase()).join(', '));
  } else if (section == 'LISTENING' || section == 'READING') {
    parts.add(section![0] + section.substring(1).toLowerCase());
  } else {
    parts.add(_TypeStyle.of(_typeOf(attempt)).subtitle);
  }
  if (attempt.totalQuestions > 0) parts.add('${attempt.totalQuestions} questions');
  return parts.join(' · ');
}

String _timeSpent(ExamAttempt attempt) {
  final start = attempt.startedAt;
  final end = attempt.submittedAt;
  if (start == null || end == null || end.isBefore(start)) return '–';
  final d = end.difference(start);
  if (d.inMinutes < 1) return '${d.inSeconds}s';
  if (d.inHours < 1) return '${d.inMinutes}m';
  return '${d.inHours}h ${d.inMinutes % 60}m';
}

String _submitted(ExamAttempt attempt) {
  final at = attempt.submittedAt ?? attempt.updatedAt;
  return at == null ? '–' : at.toLocal().toFormatString(pattern: 'MMM d, yyyy');
}
