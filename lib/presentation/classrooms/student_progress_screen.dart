import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/classrooms/gradebook_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Tiến độ một học sinh trong lớp (Figma 17:1415). Thẻ hồ sơ tính trên mọi bài của lớp;
/// biểu đồ và dải số liệu dưới nó chỉ tính N bài có điểm gần nhất (10/20/50).
class StudentProgressScreen extends StatefulWidget {
  const StudentProgressScreen({
    super.key,
    required this.classroomId,
    required this.studentId,
    this.onBack,
    this.onOpenAssignment,
  });
  final int classroomId;
  final String studentId;

  /// Mở trong tab Classwork: Back quay về bảng điểm lớp. Null thì quay về trang lớp.
  final VoidCallback? onBack;

  /// Bấm một dòng trong bảng Assignments: mở gradebook của bài đó.
  final ValueChanged<int>? onOpenAssignment;

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

enum _AssignmentFilter { all, missing, submitted }

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  late final repository = ClassroomRepository(getIt<Dio>());
  StudentProgress? progress;
  ClassGradebook? gradebook;
  String? error;

  int recent = 20;
  _AssignmentFilter filter = _AssignmentFilter.all;
  String query = '';
  int page = 0;

  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    final (result, classResult) = await (
      repository.getStudentProgress(widget.classroomId, widget.studentId),
      repository.getClassGradebook(widget.classroomId),
    ).wait;
    if (!mounted) return;
    switch (result) {
      case Success(data: final data):
        setState(() {
          progress = data;
          gradebook = classResult.dataOrNull;
        });
      case Failure(message: final message):
        setState(() => error = message ?? 'Could not load student progress');
      case Cancelled():
        break;
    }
  }

  // Backend gán LATE cho cả bài quá hạn chưa nộp: không có điểm thì là Missing.
  static bool _missing(StudentAssignmentProgress item) =>
      item.score == null &&
      item.status != 'IN_PROGRESS' &&
      item.status != 'SUBMITTED' &&
      item.dueAt.isBefore(DateTime.now());

  static String _status(StudentAssignmentProgress item) => _missing(item)
      ? 'MISSING'
      : item.score != null && item.status == 'LATE'
      ? 'LATE'
      : item.score != null
      ? 'SUBMITTED'
      : item.status;

  /// Điểm trung bình lớp của từng bài, từ bảng điểm lớp.
  Map<int, double> get _classAverages {
    final sums = <int, (double, int)>{};
    for (final student in gradebook?.students ?? const <StudentProgress>[]) {
      for (final item in student.assignments) {
        final score = item.score;
        if (score == null) continue;
        final (sum, count) = sums[item.assignmentId] ?? (0, 0);
        sums[item.assignmentId] = (sum + score, count + 1);
      }
    }
    return {for (final entry in sums.entries) entry.key: entry.value.$1 / entry.value.$2};
  }

  Widget _profile(StudentProgress data) {
    final items = data.assignments;
    final graded = items.where((item) => item.score != null).length;
    final late = items.where((item) => item.status == 'LATE' && item.score != null).length;
    final missing = items.where(_missing).length;
    final completion = items.isEmpty ? 0 : graded / items.length * 100;
    final classAverage = gradebook?.averageScore;
    return GbCard(
      children: [
        Row(
          spacing: 16,
          children: [
            GbAvatar(name: data.student.name, url: data.student.avatar, size: 64),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    data.student.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  Text(data.student.email, style: const TextStyle(fontSize: 13, color: Gb.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GbStats(
          children: [
            GbStat(
              label: 'Average',
              value: Gb.scoreText(data.averageScore),
              sub: classAverage == null ? null : 'class avg ${classAverage.toStringAsFixed(1)}',
              color: ColorName.primary,
            ),
            GbStat(
              label: 'Completion',
              value: '${completion.round()}%',
              sub: '$graded of ${items.length} assignments',
            ),
            GbStat(label: 'Submitted', value: '$graded', color: Gb.green),
            GbStat(label: 'Late', value: '$late', color: Gb.orange),
            GbStat(
              label: 'Missing',
              value: '$missing',
              sub: 'past due, not submitted',
              color: Gb.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _segmented<T>(List<(T, String)> options, T selected, ValueChanged<T> onSelected) =>
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Gb.field, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            for (final (value, label) in options)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onSelected(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: value == selected ? Colors.white : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: value == selected ? FontWeight.w600 : FontWeight.w500,
                      color: value == selected ? ColorName.primary : Gb.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _trend(StudentProgress data) {
    final graded = data.assignments.where((item) => item.score != null).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final shown = graded.length > recent ? graded.sublist(graded.length - recent) : graded;
    final scores = shown.map((item) => item.score!).toList();
    final averages = _classAverages;
    Widget summary(String value, String label, Color color, {bool divider = true}) => Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: divider ? const Border(left: BorderSide(color: Gb.border)) : null,
        ),
        child: Column(
          spacing: 2,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
            ),
            Text(label, style: const TextStyle(fontSize: 11, color: Gb.muted)),
          ],
        ),
      ),
    );
    return GbCard(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const GbCardHead(
              'Score over time',
              'Most recent graded assignments, oldest → newest · grey line = class average',
            ),
            _segmented(
              const [(10, 'Last 10'), (20, 'Last 20'), (50, 'Last 50')],
              recent,
              (value) => setState(() => recent = value),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No graded assignments yet', style: TextStyle(color: Gb.muted)),
            ),
          )
        else ...[
          SizedBox(
            height: 200,
            child: _ScoreChart(items: shown, classAverages: averages),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            children: [
              _Legend(color: ColorName.primary, label: 'Score', dot: true),
              _Legend(color: Color(0xFFB0B6BD), label: 'Class average'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Gb.soft, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                summary(
                  scores.reduce(math.min).toStringAsFixed(1),
                  'Lowest score',
                  Gb.red,
                  divider: false,
                ),
                summary(scores.reduce(math.max).toStringAsFixed(1), 'Best score', Gb.green),
                summary(
                  (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(1),
                  'Average of shown',
                  ColorName.primary,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _assignments(StudentProgress data) {
    final normalized = query.trim().toLowerCase();
    final items = data.assignments.where((item) {
      final matchesFilter = switch (filter) {
        _AssignmentFilter.all => true,
        _AssignmentFilter.missing => _missing(item),
        _AssignmentFilter.submitted => item.score != null,
      };
      return matchesFilter && (normalized.isEmpty || item.title.toLowerCase().contains(normalized));
    }).toList()..sort((a, b) => b.dueAt.compareTo(a.dueAt));
    final pages = math.max(1, (items.length / _pageSize).ceil());
    final current = page.clamp(0, pages - 1);
    final visible = items.skip(current * _pageSize).take(_pageSize).toList();
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Gb.muted);
    return GbCard(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GbCardHead(
                'Assignments',
                '${data.assignments.length} assignments in this class · newest first',
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  GbSearchField(
                    hint: 'Search assignments',
                    width: 200,
                    onChanged: (value) => setState(() {
                      query = value;
                      page = 0;
                    }),
                  ),
                  _segmented(
                    const [
                      (_AssignmentFilter.all, 'All'),
                      (_AssignmentFilter.missing, 'Missing'),
                      (_AssignmentFilter.submitted, 'Submitted'),
                    ],
                    filter,
                    (value) => setState(() {
                      filter = value;
                      page = 0;
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
        _row(
          header: true,
          cells: const [
            Text('ASSIGNMENT', style: head),
            Text('DUE', style: head),
            Text('STATUS', style: head),
            Text('SCORE', style: head),
            SizedBox.shrink(),
          ],
        ),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('No matching assignments', style: TextStyle(color: Gb.muted)),
            ),
          ),
        for (final item in visible)
          _row(
            onTap: widget.onOpenAssignment == null
                ? null
                : () => widget.onOpenAssignment!(item.assignmentId),
            cells: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                DateFormat('MMM d, HH:mm').format(item.dueAt),
                style: const TextStyle(fontSize: 12, color: Gb.muted),
              ),
              _statusPill(item),
              _scoreChip(item.score),
              const Icon(Icons.chevron_right, size: 18, color: Gb.faint),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            spacing: 6,
            children: [
              Expanded(
                child: Text(
                  items.isEmpty
                      ? 'No assignments'
                      : 'Showing ${current * _pageSize + 1}–'
                            '${current * _pageSize + visible.length} of ${items.length}',
                  style: const TextStyle(fontSize: 12, color: Gb.faint),
                ),
              ),
              if (pages > 1) ...[
                _pageButton(
                  icon: Icons.chevron_left,
                  onTap: current > 0 ? () => setState(() => page = current - 1) : null,
                ),
                for (final index in _pageNumbers(current, pages))
                  index == null
                      ? const Text('…', style: TextStyle(color: Gb.muted))
                      : _pageButton(
                          label: '${index + 1}',
                          selected: index == current,
                          onTap: () => setState(() => page = index),
                        ),
                _pageButton(
                  icon: Icons.chevron_right,
                  onTap: current < pages - 1 ? () => setState(() => page = current + 1) : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Trang đầu, trang cuối và hai trang quanh trang hiện tại; null là dấu "…".
  static List<int?> _pageNumbers(int current, int pages) {
    final keep = {
      0,
      pages - 1,
      current - 1,
      current,
      current + 1,
    }.where((index) => index >= 0 && index < pages).toList()..sort();
    final result = <int?>[];
    for (final index in keep) {
      if (result.isNotEmpty && index - (result.last ?? index) > 1) result.add(null);
      result.add(index);
    }
    return result;
  }

  Widget _pageButton({String? label, IconData? icon, bool selected = false, VoidCallback? onTap}) =>
      InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 30),
          height: 28,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? ColorName.primary : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: selected ? null : Border.all(color: Gb.border),
          ),
          child: icon != null
              ? Icon(icon, size: 16, color: onTap == null ? Gb.border : Gb.muted)
              : Text(
                  label!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : Gb.muted,
                  ),
                ),
        ),
      );

  Widget _row({required List<Widget> cells, bool header = false, VoidCallback? onTap}) {
    const widths = [null, 120.0, 110.0, 80.0, 30.0];
    return Material(
      color: header ? Gb.soft : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: header ? 10 : 12),
          decoration: BoxDecoration(
            border: Border(
              top: header ? const BorderSide(color: Gb.border) : BorderSide.none,
              bottom: const BorderSide(color: Gb.border),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < cells.length; i++)
                if (widths[i] == null)
                  Expanded(child: cells[i])
                else
                  SizedBox(
                    width: widths[i],
                    child: Align(alignment: Alignment.centerLeft, child: cells[i]),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(StudentAssignmentProgress item) {
    final status = _status(item);
    if (status == 'MISSING') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFF5C2BE)),
        ),
        child: const Text(
          'Missing',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Gb.red),
        ),
      );
    }
    return GbPill.status(status);
  }

  Widget _scoreChip(double? score) {
    if (score == null) return const Text('—', style: TextStyle(color: Gb.faint));
    final (background, foreground) = score >= 8
        ? (Gb.greenBg, Gb.green)
        : score < 5
        ? (Gb.redBg, Gb.red)
        : (Gb.field, Gb.text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }

  Widget _sideList({
    required String title,
    required String subtitle,
    required List<StudentAssignmentProgress> items,
    required String empty,
    required Widget Function(StudentAssignmentProgress) builder,
  }) => GbCard(
    children: [
      GbCardHead(title, subtitle),
      const SizedBox(height: 4),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(empty, style: const TextStyle(fontSize: 13, color: Gb.faint)),
        ),
      for (final item in items) ...[const SizedBox(height: 10), builder(item)],
    ],
  );

  Widget _aside(StudentProgress data) {
    final now = DateTime.now();
    // Bài trễ gần nhất trước; bài sắp tới hạn gần nhất trước.
    final overdue = data.assignments.where(_missing).toList()
      ..sort((a, b) => b.dueAt.compareTo(a.dueAt));
    final upcoming =
        data.assignments.where((item) => item.score == null && item.dueAt.isAfter(now)).toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    String overdueLabel(DateTime due) {
      final days = now.difference(due).inDays;
      return days < 1 ? 'Overdue today' : '$days ${days == 1 ? 'day' : 'days'} overdue';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _sideList(
          title: 'Needs attention',
          subtitle: 'Past due and not submitted',
          items: overdue.take(5).toList(),
          empty: 'Nothing overdue',
          builder: (item) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF3F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              spacing: 10,
              children: [
                const Icon(Icons.circle, size: 8, color: Gb.red),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        overdueLabel(item.dueAt),
                        style: const TextStyle(fontSize: 12, color: Gb.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _sideList(
          title: 'Coming up',
          subtitle: 'Open or opening soon',
          items: upcoming.take(5).toList(),
          empty: 'No upcoming assignments',
          builder: (item) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Gb.soft, borderRadius: BorderRadius.circular(8)),
            child: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Due ${DateFormat('MMM d, HH:mm').format(item.dueAt)}',
                        style: const TextStyle(fontSize: 12, color: Gb.muted),
                      ),
                    ],
                  ),
                ),
                GbPill.status(item.status),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = progress;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        GbHeader(onBack: widget.onBack ?? () => context.go(classroomPath(widget.classroomId))),
        if (data != null) ...[
          _profile(data),
          LayoutBuilder(
            builder: (context, constraints) {
              final main = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [_trend(data), _assignments(data)],
              );
              if (constraints.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 20,
                  children: [_aside(data), main],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  Expanded(child: main),
                  SizedBox(width: 320, child: _aside(data)),
                ],
              );
            },
          ),
        ] else if (error != null)
          GbError(message: error!, onRetry: load)
        else
          const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: AppLoader()),
      ],
    );
    if (widget.onBack != null) {
      return Padding(padding: const EdgeInsets.only(top: 12, bottom: 32), child: content);
    }
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: content),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dot = false});
  final Color color;
  final String label;
  final bool dot;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      Container(
        width: dot ? 8 : 14,
        height: dot ? 8 : 2,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      ),
      Text(label, style: const TextStyle(fontSize: 11, color: Gb.muted)),
    ],
  );
}

/// Biểu đồ đường điểm từng bài (cũ → mới) kèm đường trung bình lớp nét đứt.
/// Rê chuột vào gần một điểm để xem tên bài, hạn nộp và điểm.
class _ScoreChart extends StatefulWidget {
  const _ScoreChart({required this.items, required this.classAverages});
  final List<StudentAssignmentProgress> items;
  final Map<int, double> classAverages;

  @override
  State<_ScoreChart> createState() => _ScoreChartState();
}

class _ScoreChartState extends State<_ScoreChart> {
  int? hovered;

  static const _left = 28.0;
  static const _bottom = 22.0;
  static const _top = 8.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final geometry = _ChartGeometry(size, widget.items.length);
      final index = hovered;
      final item = index == null ? null : widget.items[index];
      final classAverage = item == null ? null : widget.classAverages[item.assignmentId];
      return MouseRegion(
        onHover: (event) => setState(() => hovered = geometry.nearest(event.localPosition.dx)),
        onExit: (_) => setState(() => hovered = null),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: size,
              painter: _ScoreChartPainter(
                items: widget.items,
                classAverages: widget.classAverages,
                geometry: geometry,
                hovered: hovered,
              ),
            ),
            if (item != null && index != null)
              Positioned(
                left: math.min(math.max(0, geometry.x(index) - 100), math.max(0, size.width - 220)),
                top: geometry.y(item.score!) > size.height / 2
                    ? geometry.y(item.score!) - 62
                    : geometry.y(item.score!) + 14,
                child: IgnorePointer(
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Gb.text,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          [
                            'Due ${DateFormat('MMM d').format(item.dueAt)}',
                            '${item.score!.toStringAsFixed(1)} / 10',
                            if (classAverage != null)
                              'class avg ${classAverage.toStringAsFixed(1)}',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 11, color: Color(0xFFC9CCD1)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _ChartGeometry {
  _ChartGeometry(this.size, this.count);
  final Size size;
  final int count;

  double get _plotLeft => _ScoreChartState._left + 12;
  double get _plotRight => size.width - 12;

  double x(int index) => count <= 1
      ? (_plotLeft + _plotRight) / 2
      : _plotLeft + (_plotRight - _plotLeft) * index / (count - 1);

  double y(double score) =>
      _ScoreChartState._top +
      (size.height - _ScoreChartState._bottom - _ScoreChartState._top) *
          (1 - score.clamp(0, 10) / 10);

  int? nearest(double dx) {
    if (count == 0) return null;
    var best = 0;
    for (var i = 1; i < count; i++) {
      if ((x(i) - dx).abs() < (x(best) - dx).abs()) best = i;
    }
    return best;
  }
}

class _ScoreChartPainter extends CustomPainter {
  _ScoreChartPainter({
    required this.items,
    required this.classAverages,
    required this.geometry,
    required this.hovered,
  });
  final List<StudentAssignmentProgress> items;
  final Map<int, double> classAverages;
  final _ChartGeometry geometry;
  final int? hovered;

  void _label(Canvas canvas, String text, Offset offset, {TextAlign align = TextAlign.left}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: Gb.faint),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.center => offset.dx - painter.width / 2,
      TextAlign.right => offset.dx - painter.width,
      _ => offset.dx,
    };
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFEEF0F2)
      ..strokeWidth = 1;
    for (final value in [0.0, 5.0, 10.0]) {
      final y = geometry.y(value);
      canvas.drawLine(
        Offset(_ScoreChartState._left, y),
        Offset(size.width, y),
        value == 0 ? (Paint()..color = const Color(0xFFD5D8DC)) : grid,
      );
      _label(canvas, value.toStringAsFixed(0), Offset(0, y - 7));
    }

    // Trung bình lớp: nét đứt, bỏ qua bài chưa có dữ liệu lớp.
    final averagePaint = Paint()
      ..color = const Color(0xFFB0B6BD)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    Offset? previous;
    for (var i = 0; i < items.length; i++) {
      final average = classAverages[items[i].assignmentId];
      if (average == null) {
        previous = null;
        continue;
      }
      final point = Offset(geometry.x(i), geometry.y(average));
      if (previous != null) _dashed(canvas, previous, point, averagePaint);
      previous = point;
    }

    final line = Path();
    for (var i = 0; i < items.length; i++) {
      final point = Offset(geometry.x(i), geometry.y(items[i].score!));
      i == 0 ? line.moveTo(point.dx, point.dy) : line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = ColorName.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    if (hovered case final index?) {
      final x = geometry.x(index);
      canvas.drawLine(
        Offset(x, _ScoreChartState._top),
        Offset(x, geometry.y(0)),
        Paint()..color = const Color(0xFFD5D8DC),
      );
    }

    for (var i = 0; i < items.length; i++) {
      final score = items[i].score!;
      final center = Offset(geometry.x(i), geometry.y(score));
      final radius = i == items.length - 1 || i == hovered ? 5.0 : 4.0;
      canvas.drawCircle(center, radius + 1.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = score >= 8
              ? const Color(0xFF34A853)
              : score < 5
              ? const Color(0xFFEA4335)
              : ColorName.primary,
      );
    }

    // Nhãn ngày: bài đầu, giữa, cuối.
    final labelY = size.height - 14;
    final format = DateFormat('MMM d');
    final marks = {0, items.length ~/ 2, items.length - 1}.toList()..sort();
    for (final i in marks) {
      final align = i == 0
          ? TextAlign.left
          : i == items.length - 1
          ? TextAlign.right
          : TextAlign.center;
      final x = items.length == 1 ? geometry.x(0) : geometry.x(i);
      _label(canvas, format.format(items[i].dueAt), Offset(x, labelY), align: align);
    }
  }

  void _dashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 4.0;
    final distance = (to - from).distance;
    final direction = (to - from) / distance;
    for (var start = 0.0; start < distance; start += dash * 2) {
      final end = math.min(start + dash, distance);
      canvas.drawLine(from + direction * start, from + direction * end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter oldDelegate) =>
      oldDelegate.items != items ||
      oldDelegate.hovered != hovered ||
      oldDelegate.classAverages != classAverages ||
      oldDelegate.geometry.size != geometry.size;
}
