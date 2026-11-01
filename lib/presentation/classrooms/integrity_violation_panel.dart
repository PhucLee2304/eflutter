import 'dart:async';

import 'package:eflutter/data/models/attempt_integrity.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Panel "cần quyết định ngay" ở gradebook (Figma T2): chỉ học sinh còn đang làm bài có vi
/// phạm chưa xử lý, mỗi học sinh một dòng (vi phạm mới nhất). "Don't count it" bỏ các vi phạm
/// chờ xử lý (CONTINUE), "Keep it" giữ (KEEP); Cấm nằm trong log để xem đủ bối cảnh.
class IntegrityViolationPanel extends StatelessWidget {
  const IntegrityViolationPanel({
    super.key,
    required this.events,
    required this.submissions,
    required this.maxViolations,
    required this.onDontCount,
    required this.onKeep,
    required this.onOpenLog,
    this.busyEventIds = const {},
  });

  final List<IntegrityEventRecord> events;
  final List<AssignmentSubmission> submissions;
  final int maxViolations;
  final ValueChanged<List<IntegrityEventRecord>> onDontCount;
  final ValueChanged<List<IntegrityEventRecord>> onKeep;
  final ValueChanged<AssignmentSubmission> onOpenLog;
  final Set<String> busyEventIds;

  static const _border = Color(0xFFE4E6EB);
  static const _orange = Color(0xFFB26A00);

  AssignmentSubmission? _submissionOf(String studentId) =>
      submissions.where((item) => item.student?.id == studentId).firstOrNull;

  /// Vi phạm chờ xử lý theo học sinh, mới nhất trước; học sinh có vi phạm mới
  /// nhất đứng đầu.
  List<List<IntegrityEventRecord>> get _byStudent {
    final groups = <String, List<IntegrityEventRecord>>{};
    for (final event in events) {
      groups.putIfAbsent(event.studentId, () => []).add(event);
    }
    final result = [
      for (final group in groups.values)
        group..sort((a, b) => b.receivedAt.compareTo(a.receivedAt)),
    ];
    result.sort((a, b) => b.first.receivedAt.compareTo(a.first.receivedAt));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _byStudent;
    if (groups.isEmpty) return const SizedBox.shrink();
    final count = groups.length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF4E5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.circle, size: 8, color: _orange),
                    ),
                    Text(
                      '$count ${count == 1 ? 'student needs' : 'students need'} a decision now',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  'Still taking the exam · $maxViolations '
                  '${maxViolations == 1 ? 'violation' : 'violations'} allowed',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF65676B)),
                ),
              ],
            ),
          ),
          for (final group in groups)
            _DecisionRow(
              event: group.first,
              pending: group,
              submission: _submissionOf(group.first.studentId),
              maxViolations: maxViolations,
              busy: group.any((item) => busyEventIds.contains(item.eventId)),
              onDontCount: () => onDontCount(group),
              onKeep: () => onKeep(group),
              onOpenLog: onOpenLog,
            ),
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({
    required this.event,
    required this.pending,
    required this.submission,
    required this.maxViolations,
    required this.busy,
    required this.onDontCount,
    required this.onKeep,
    required this.onOpenLog,
  });

  final IntegrityEventRecord event;
  final List<IntegrityEventRecord> pending;
  final AssignmentSubmission? submission;
  final int maxViolations;
  final bool busy;
  final VoidCallback onDontCount;
  final VoidCallback onKeep;
  final ValueChanged<AssignmentSubmission> onOpenLog;

  static const _muted = Color(0xFF65676B);
  static const _orange = Color(0xFFB26A00);
  static const _red = Color(0xFFD93025);

  @override
  Widget build(BuildContext context) {
    final student = submission?.student;
    final name = student?.name ?? 'Student';
    final count = submission?.violationCount ?? event.violationNo ?? 0;
    final atLimit = maxViolations > 0 && count >= maxViolations;
    final color = atLimit ? _red : _orange;
    final seconds = event.serverDurationMs == null
        ? null
        : (event.serverDurationMs! / 1000).round();
    final what = [
      'Left the exam${seconds == null ? '' : ' for ${seconds}s'}',
      _ago(event.receivedAt),
      if (pending.length > 1) '${pending.length} new',
    ].join(' · ');
    final info = Row(
      spacing: 12,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFEEF7FD),
          foregroundImage: student?.avatar == null ? null : NetworkImage(student!.avatar!),
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColorName.primary,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              Text(what, style: const TextStyle(fontSize: 12, color: _muted)),
              Row(
                spacing: 8,
                children: [
                  _Meter(count: count, max: maxViolations, color: color),
                  Flexible(
                    child: Text(
                      atLimit
                          ? 'Limit reached'
                          : '$count ${count == 1 ? 'violation' : 'violations'}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        FilledButton(
          onPressed: busy ? null : onDontCount,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEEF7FD),
            foregroundColor: ColorName.primary,
            padding: padding,
            shape: shape,
          ),
          child: const Text("Don't count it"),
        ),
        OutlinedButton(
          onPressed: busy ? null : onKeep,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1C1E21),
            side: const BorderSide(color: Color(0xFFE4E6EB)),
            padding: padding,
            shape: shape,
          ),
          child: const Text('Keep it'),
        ),
        TextButton(
          onPressed: submission == null ? null : () => onOpenLog(submission!),
          child: const Text('Open log'),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE4E6EB))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 620
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  info,
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              )
            : Row(
                spacing: 14,
                children: [
                  Expanded(child: info),
                  actions,
                ],
              ),
      ),
    );
  }

  static String _ago(DateTime at) {
    final diff = DateTime.now().difference(at.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    return DateFormat('HH:mm').format(at.toLocal());
  }
}

/// Ô "Proctoring" của một học sinh trong bảng điểm (Figma T1): thanh vạch theo số lần được
/// phép + chữ mô tả, nút "Review n new" khi còn vi phạm chưa xử lý, đồng hồ khi đang rời màn.
/// Bấm cả ô mở log giám sát.
class IntegrityStatusCell extends StatefulWidget {
  const IntegrityStatusCell({
    super.key,
    required this.submission,
    required this.maxViolations,
    this.awaySince,
    this.onTap,
  });

  final AssignmentSubmission submission;
  final int maxViolations;

  /// Khác null khi học sinh đang rời màn thi.
  final DateTime? awaySince;
  final VoidCallback? onTap;

  @override
  State<IntegrityStatusCell> createState() => _IntegrityStatusCellState();
}

class _IntegrityStatusCellState extends State<IntegrityStatusCell> {
  static const _orange = Color(0xFFB26A00);
  static const _red = Color(0xFFD93025);
  static const _green = Color(0xFF1E8E3E);
  static const _muted = Color(0xFF65676B);
  static const _faint = Color(0xFF8A8D91);

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(IntegrityStatusCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.awaySince != widget.awaySince) _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = widget.awaySince == null
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submission = widget.submission;
    if (!submission.proctored) {
      return const Text('Not proctored', style: TextStyle(fontSize: 12, color: _faint));
    }
    final count = submission.violationCount;
    final max = widget.maxViolations;
    final outcome = submission.integrityOutcome;
    final awaySince = widget.awaySince;
    final atLimit = max > 0 && count >= max;
    final color = atLimit ? _red : _orange;

    final List<Widget> children = switch (outcome) {
      // Kết quả quan trọng hơn số lần: thay luôn thanh vạch.
      'TERMINATED' => const [
        Icon(Icons.block, size: 15, color: _red),
        _Label('Suspended · score 0', color: _red, bold: true),
      ],
      'REINSTATED' => const [
        Icon(Icons.check, size: 15, color: _green),
        _Label('Reinstated', color: _green, bold: true),
      ],
      _ => [
        _Meter(count: count, max: max, color: color),
        if (awaySince != null)
          _Label('● Left the exam · ${_elapsed(awaySince)}', color: _orange, bold: true)
        else if (atLimit)
          _Label(count > max ? '$count violations' : 'Limit reached', color: _red, bold: true)
        else
          _Label(
            count == 0 ? 'No violations' : '$count ${count == 1 ? 'violation' : 'violations'}',
            color: count == 0 ? _muted : _orange,
            bold: count > 0,
          ),
        if (submission.pendingViolations > 0 &&
            submission.status == 'IN_PROGRESS' &&
            awaySince == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE7C2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Review ${submission.pendingViolations} new',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _orange),
            ),
          ),
      ],
    };
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );
  }

  static String _elapsed(DateTime since) {
    final seconds = DateTime.now().difference(since).inSeconds.clamp(0, 359999);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// Mỗi vạch là một lần vi phạm được phép; quá nhiều lần thì gộp thành một thanh tiến độ.
class _Meter extends StatelessWidget {
  const _Meter({required this.count, required this.max, required this.color});
  final int count;
  final int max;
  final Color color;

  static const _empty = Color(0xFFE4E6EB);

  @override
  Widget build(BuildContext context) {
    // Quá 5 lượt thì vạch quá dài: chỉ hiện chữ (giống badge của học sinh).
    if (max <= 0 || max > 5) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        for (var i = 1; i <= max; i++)
          Container(
            width: 14,
            height: 6,
            decoration: BoxDecoration(
              color: i <= count ? color : _empty,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color, this.bold = false});
  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      color: color,
    ),
  );
}
