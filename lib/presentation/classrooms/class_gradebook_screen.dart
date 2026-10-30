import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:eflutter/presentation/classrooms/gradebook_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Bảng điểm cả lớp: mỗi hàng một học sinh, mỗi cột một bài (Figma 15:881).
class ClassGradebookScreen extends StatefulWidget {
  const ClassGradebookScreen({
    super.key,
    required this.classroomId,
    this.classroom,
    this.onBack,
    this.onOpenAssignment,
  });
  final int classroomId;
  final Classroom? classroom;

  /// Mở trong tab Classwork: Back quay về danh sách bài. Null thì quay về trang lớp.
  final VoidCallback? onBack;

  /// Bấm tiêu đề cột: mở gradebook của bài đó.
  final ValueChanged<int>? onOpenAssignment;

  @override
  State<ClassGradebookScreen> createState() => _ClassGradebookScreenState();
}

class _ClassGradebookScreenState extends State<ClassGradebookScreen> {
  late final repository = ClassroomRepository(getIt<Dio>());
  ClassGradebook? gradebook;
  String? error;
  DateTimeRange? range;
  String query = '';

  static const _studentWidth = 230.0;
  static const _averageWidth = 90.0;
  static const _cellWidth = 120.0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final result = await repository.getClassGradebook(
      widget.classroomId,
      from: range?.start,
      to: range?.end.add(const Duration(days: 1)),
    );
    if (!mounted) return;
    switch (result) {
      case Success(data: final data):
        setState(() {
          gradebook = data;
          error = null;
        });
      case Failure(message: final message):
        setState(() => error = message ?? 'Could not load the class gradebook');
      case Cancelled():
        break;
    }
  }

  Future<void> selectRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: range,
    );
    if (selected == null) return;
    setState(() => range = selected);
    await load();
  }

  void clearRange() {
    setState(() => range = null);
    load();
  }

  // Backend gán LATE cho cả bài quá hạn chưa nộp: không có điểm thì là Missing.
  static bool _missing(StudentAssignmentProgress item) =>
      item.score == null &&
      item.status != 'IN_PROGRESS' &&
      item.status != 'SUBMITTED' &&
      item.dueAt.isBefore(DateTime.now());

  Widget _summary(ClassGradebook data) {
    final items = [for (final student in data.students) ...student.assignments];
    final late = items.where((item) => item.status == 'LATE' && item.score != null).length;
    final missing = items.where(_missing).length;
    final classroom = widget.classroom;
    final meta = [
      if (classroom != null) ...[classroom.name, classroom.code],
      '${data.students.length} students',
      '${data.assignments.length} assignments',
    ].join(' · ');
    return GbCard(
      children: [
        const Text('Class gradebook', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(meta, style: const TextStyle(fontSize: 13, color: Gb.muted)),
        const SizedBox(height: 16),
        GbStats(
          children: [
            GbStat(
              label: 'Class average',
              value: Gb.scoreText(data.averageScore),
              sub: 'out of 10',
              color: ColorName.primary,
            ),
            GbStat(
              label: 'Completion',
              value: '${data.completionRate.toStringAsFixed(0)}%',
              sub: 'of all assigned work',
            ),
            GbStat(label: 'Late submissions', value: '$late', color: Gb.orange),
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

  Widget _cell(StudentAssignmentProgress? item) {
    if (item == null) return const Text('—', style: TextStyle(color: Gb.faint));
    final score = item.score;
    if (score != null) {
      final late = item.status == 'LATE';
      final (background, foreground) = late
          ? (Gb.orangeBg, Gb.orange)
          : score >= 8
          ? (Gb.greenBg, Gb.green)
          : score < 5
          ? (Gb.redBg, Gb.red)
          : (Gb.field, Gb.text);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text(
              score.toStringAsFixed(1),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground),
            ),
            if (late)
              Text(
                'late',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: foreground),
              ),
          ],
        ),
      );
    }
    if (item.status == 'IN_PROGRESS') {
      return const GbPill(
        'In progress',
        background: AppButtonStyles.tint,
        foreground: ColorName.primary,
      );
    }
    if (_missing(item)) {
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
    return const Text('—', style: TextStyle(color: Gb.faint));
  }

  Widget _matrix(ClassGradebook data) {
    final normalized = query.trim().toLowerCase();
    final students = data.students
        .where(
          (item) =>
              normalized.isEmpty ||
              item.student.name.toLowerCase().contains(normalized) ||
              item.student.email.toLowerCase().contains(normalized),
        )
        .toList();
    final columns = data.assignments;
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Gb.muted);
    Widget box(double width, Widget child) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
    Widget row({required bool header, required List<Widget> children, VoidCallback? onTap}) =>
        Material(
          color: header ? Gb.soft : Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: header ? const BorderSide(color: Gb.border) : BorderSide.none,
                  bottom: const BorderSide(color: Gb.border),
                ),
              ),
              child: Row(children: children),
            ),
          ),
        );
    final width = 24 + _studentWidth + _averageWidth + columns.length * _cellWidth;
    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          header: true,
          children: [
            box(_studentWidth, const Text('STUDENT', style: head)),
            box(_averageWidth, const Text('AVERAGE', style: head)),
            for (final column in columns)
              box(
                _cellWidth,
                InkWell(
                  onTap: widget.onOpenAssignment == null
                      ? null
                      : () => widget.onOpenAssignment!((column['id'] as num).toInt()),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        column['title'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ColorName.primary,
                        ),
                      ),
                      if (DateTime.tryParse(column['dueAt'] as String? ?? '') case final due?)
                        Text(
                          'Due ${DateFormat('MMM d').format(due.toLocal())}',
                          style: const TextStyle(fontSize: 11, color: Gb.faint),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (students.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('No matching students', style: TextStyle(color: Gb.muted)),
          ),
        for (final student in students)
          row(
            header: false,
            onTap: () => context.go(studentProgressPath(widget.classroomId, student.student.id)),
            children: [
              box(
                _studentWidth,
                Row(
                  spacing: 10,
                  children: [
                    GbAvatar(name: student.student.name, url: student.student.avatar, size: 28),
                    Expanded(
                      child: Text(
                        student.student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              box(
                _averageWidth,
                Text(
                  Gb.scoreText(student.averageScore),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Gb.score(student.averageScore),
                  ),
                ),
              ),
              for (final column in columns)
                box(
                  _cellWidth,
                  _cell(
                    student.assignments
                        .where((item) => item.assignmentId == (column['id'] as num?)?.toInt())
                        .firstOrNull,
                  ),
                ),
            ],
          ),
      ],
    );
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
              GbSearchField(onChanged: (value) => setState(() => query = value), width: 240),
              const Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  GbPill('≥ 8', background: Gb.greenBg, foreground: Gb.green),
                  GbPill('5 – 8', background: Gb.field, foreground: Gb.text),
                  GbPill('< 5', background: Gb.redBg, foreground: Gb.red),
                  GbPill('Late', background: Gb.orangeBg, foreground: Gb.orange),
                  GbPill('Missing', background: Colors.white, foreground: Gb.red),
                ],
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width < constraints.maxWidth ? constraints.maxWidth : width,
              child: table,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            'Click a student for their progress · click an assignment column to open its gradebook',
            style: TextStyle(fontSize: 12, color: Gb.faint),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = range;
    final header = GbHeader(
      onBack: widget.onBack ?? () => context.go(classroomPath(widget.classroomId)),
      actions: [
        OutlinedButton.icon(
          onPressed: selectRange,
          style: OutlinedButton.styleFrom(
            foregroundColor: Gb.text,
            side: const BorderSide(color: Gb.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          icon: const Icon(Icons.date_range_outlined, size: 16),
          label: Text(
            current == null
                ? 'Due: All time'
                : 'Due: ${DateFormat('MMM d').format(current.start)} – '
                      '${DateFormat('MMM d').format(current.end)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        if (current != null)
          IconButton(
            tooltip: 'Clear date filter',
            onPressed: clearRange,
            icon: const Icon(Icons.close, size: 18),
          ),
      ],
    );
    final data = gradebook;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        header,
        if (data != null) ...[
          _summary(data),
          _matrix(data),
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
