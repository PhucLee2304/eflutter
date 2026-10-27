import 'package:eflutter/data/models/attempt_integrity.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Panel "Vi phạm chờ xử lý" ở gradebook (PLAN_ATTEMPT_INTEGRITY.md I4): mỗi học
/// sinh một thẻ, hiện vi phạm mới nhất. Cho tiếp tục làm bài đánh dấu mọi vi phạm
/// chờ xử lý của học sinh đó và (khi bài còn đang làm) trừ chúng khỏi số vi phạm;
/// Cấm áp lên vi phạm mới nhất.
class IntegrityViolationPanel extends StatelessWidget {
  const IntegrityViolationPanel({
    super.key,
    required this.events,
    required this.submissions,
    required this.maxViolations,
    required this.onBan,
    required this.onAllowContinue,
    this.busyEventIds = const {},
  });

  final List<IntegrityEventRecord> events;
  final List<AssignmentSubmission> submissions;
  final int maxViolations;
  final ValueChanged<IntegrityEventRecord> onBan;
  final ValueChanged<List<IntegrityEventRecord>> onAllowContinue;
  final Set<String> busyEventIds;

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
    if (events.isEmpty) return const SizedBox.shrink();
    final groups = _byStudent;
    return Card(
      color: ColorName.red.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.gpp_maybe_outlined, color: ColorName.red),
                const SizedBox(width: 8),
                Text(
                  'Pending violations (${groups.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final group in groups)
              _ViolationCard(
                event: group.first,
                pendingCount: group.length,
                submission: _submissionOf(group.first.studentId),
                maxViolations: maxViolations,
                busy: group.any((item) => busyEventIds.contains(item.eventId)),
                onBan: () => onBan(group.first),
                onAllowContinue: () => onAllowContinue(group),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViolationCard extends StatelessWidget {
  const _ViolationCard({
    required this.event,
    required this.pendingCount,
    required this.submission,
    required this.maxViolations,
    required this.busy,
    required this.onBan,
    required this.onAllowContinue,
  });

  final IntegrityEventRecord event;
  final int pendingCount;
  final AssignmentSubmission? submission;
  final int maxViolations;
  final bool busy;
  final VoidCallback onBan;
  final VoidCallback onAllowContinue;

  @override
  Widget build(BuildContext context) {
    final name = submission?.student?.name ?? event.studentId;
    final count = submission?.violationCount ?? event.violationNo ?? 0;
    final active = submission == null || submission!.status == 'IN_PROGRESS';
    final seconds = event.serverDurationMs == null
        ? null
        : (event.serverDurationMs! / 1000).toStringAsFixed(1);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  'Violation ${event.violationNo ?? '?'}/$maxViolations · '
                  'left the exam screen${seconds == null ? '' : ' for ${seconds}s'} · '
                  '${DateFormat('HH:mm:ss').format(event.receivedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (pendingCount > 1 || !active)
                  Text(
                    [
                      if (pendingCount > 1) '$pendingCount unreviewed',
                      if (!active) 'attempt already ended',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onAllowContinue,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(active ? 'Allow to continue' : 'Mark as reviewed'),
                      Text(
                        active
                            ? 'Removes it: $count → ${(count - pendingCount).clamp(0, count)}/$maxViolations'
                            : 'Still counts $count/$maxViolations',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                // Bài đã nộp/đình chỉ thì không Cấm được nữa (server trả 409).
                if (active)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ColorName.red,
                    ),
                    onPressed: busy ? null : onBan,
                    child: const Text('Ban'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô "Vi phạm" của một học sinh trong bảng điểm: x/N, chấm đỏ khi còn vi phạm chưa
/// xử lý, "Away" khi đang rời màn, nhãn Đình chỉ/Khôi phục.
class IntegrityStatusCell extends StatelessWidget {
  const IntegrityStatusCell({
    super.key,
    required this.submission,
    required this.maxViolations,
    required this.away,
    this.onTap,
  });

  final AssignmentSubmission submission;
  final int maxViolations;
  final bool away;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!submission.proctored) return const Text('—');
    final outcome = submission.integrityOutcome;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${submission.violationCount}/$maxViolations',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: submission.violationCount >= maxViolations
                    ? ColorName.red
                    : null,
              ),
            ),
            if (submission.pendingViolations > 0)
              const Icon(Icons.circle, size: 10, color: ColorName.red),
            if (away) const _Chip(label: 'Away', color: ColorName.orange),
            if (outcome == 'TERMINATED')
              const _Chip(label: 'Suspended', color: ColorName.red),
            if (outcome == 'REINSTATED')
              const _Chip(label: 'Reinstated', color: ColorName.green),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}
