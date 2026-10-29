import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/attempt_integrity.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Log giám sát của một học sinh (PLAN_ATTEMPT_INTEGRITY.md I4): mọi mức, lọc
/// theo mức; Cấm, Giải phóng phiên, Khôi phục kết quả.
Future<void> showIntegrityLogDialog(
  BuildContext context, {
  required ClassroomRepository repository,
  required int classroomId,
  required int assignmentId,
  required AssignmentSubmission submission,
  required int maxViolations,
  required VoidCallback onChanged,
}) => showDialog<void>(
  context: context,
  builder: (context) => _IntegrityLogDialog(
    repository: repository,
    classroomId: classroomId,
    assignmentId: assignmentId,
    submission: submission,
    maxViolations: maxViolations,
    onChanged: onChanged,
  ),
);

/// Hỏi xác nhận Cấm. Trả null khi giáo viên hủy, chuỗi (có thể rỗng) là ghi chú.
Future<String?> confirmBanAttempt(BuildContext context, String studentName) {
  final note = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Ban $studentName?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The attempt is suspended immediately and submitted with a score '
            'of 0. You can reinstate the result later.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ColorName.red),
          onPressed: () => Navigator.pop(context, note.text.trim()),
          child: const Text('Ban'),
        ),
      ],
    ),
  ).whenComplete(note.dispose);
}

class _IntegrityLogDialog extends StatefulWidget {
  const _IntegrityLogDialog({
    required this.repository,
    required this.classroomId,
    required this.assignmentId,
    required this.submission,
    required this.maxViolations,
    required this.onChanged,
  });

  final ClassroomRepository repository;
  final int classroomId;
  final int assignmentId;
  final AssignmentSubmission submission;
  final int maxViolations;
  final VoidCallback onChanged;

  @override
  State<_IntegrityLogDialog> createState() => _IntegrityLogDialogState();
}

class _IntegrityLogDialogState extends State<_IntegrityLogDialog> {
  List<IntegrityEventRecord> events = const [];
  String? level;
  bool loading = true;
  bool busy = false;
  String? error;

  /// Trạng thái sau thao tác trong dialog (dữ liệu gradebook truyền vào có thể cũ).
  late String status = widget.submission.status;
  late String? outcome = widget.submission.integrityOutcome;

  String get studentId => widget.submission.student?.id ?? '';
  String get studentName => widget.submission.student?.name ?? 'Student';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await widget.repository.getIntegrityEvents(
      classroomId: widget.classroomId,
      assignmentId: widget.assignmentId,
      studentId: studentId,
      level: level,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      switch (result) {
        case Success(data: final page):
          events = page.items;
        case Failure(message: final message):
          error = message ?? 'Could not load the log';
        case Cancelled():
          break;
      }
    });
  }

  Future<void> run(
    Future<Result<void>> Function() action,
    String done, {
    VoidCallback? onSuccess,
  }) async {
    setState(() => busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        if (onSuccess != null) setState(onSuccess);
        context.showToast(done, type: ToastType.success);
        widget.onChanged();
        await load();
      case Failure(message: final message):
        context.showToast(message ?? 'Action failed', type: ToastType.error);
      case Cancelled():
        break;
    }
  }

  Future<void> ban() async {
    final note = await confirmBanAttempt(context, studentName);
    if (note == null || !mounted) return;
    await run(
      () => widget.repository.banAttempt(
        classroomId: widget.classroomId,
        assignmentId: widget.assignmentId,
        studentId: studentId,
        note: note.isEmpty ? null : note,
      ),
      '$studentName was banned',
      onSuccess: () {
        status = 'SUBMITTED';
        outcome = 'TERMINATED';
      },
    );
  }

  Future<void> releaseSession() => run(
    () => widget.repository.releaseAttemptSession(
      classroomId: widget.classroomId,
      assignmentId: widget.assignmentId,
      studentId: studentId,
    ),
    'Session released; $studentName can reopen the attempt',
  );

  Future<void> reinstate() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reinstate result?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The suspension is lifted and the attempt keeps the score it '
              'earned.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Reason (required)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Reinstate'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
    if (note == null || !mounted) return;
    await run(
      () => widget.repository.reinstateAttempt(
        classroomId: widget.classroomId,
        assignmentId: widget.assignmentId,
        studentId: studentId,
        note: note,
      ),
      'Result reinstated',
      onSuccess: () => outcome = 'REINSTATED',
    );
  }

  @override
  Widget build(BuildContext context) {
    final submission = widget.submission;
    final active = status == 'IN_PROGRESS';
    final terminated = outcome == 'TERMINATED';
    return AlertDialog(
      title: Text('Proctoring log · $studentName'),
      content: SizedBox(
        width: 640,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Violations ${submission.violationCount}/${widget.maxViolations}'
              '${terminated ? ' · Suspended' : ''}'
              '${outcome == 'REINSTATED' ? ' · Reinstated' : ''}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final option in const [
                  null,
                  IntegrityLevel.violation,
                  IntegrityLevel.warning,
                  IntegrityLevel.log,
                ])
                  ChoiceChip(
                    label: Text(option == null ? 'All' : _levelLabel(option)),
                    selected: level == option,
                    onSelected: (_) {
                      setState(() => level = option);
                      load();
                    },
                  ),
              ],
            ),
            const Divider(),
            Expanded(
              child: loading
                  ? const AppLoader()
                  : error != null
                  ? Center(child: Text(error!))
                  : events.isEmpty
                  ? const Center(child: Text('No records'))
                  : ListView.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => _EventRow(event: events[index]),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (active) ...[
          TextButton(onPressed: busy ? null : releaseSession, child: const Text('Release session')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ColorName.red),
            onPressed: busy ? null : ban,
            child: const Text('Ban'),
          ),
        ],
        if (terminated)
          FilledButton(onPressed: busy ? null : reinstate, child: const Text('Reinstate result')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final IntegrityEventRecord event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.level) {
      IntegrityLevel.violation => ColorName.red,
      IntegrityLevel.warning => ColorName.orange,
      _ => ColorName.gray1,
    };
    final details = [
      if (event.violationNo != null) 'violation #${event.violationNo}',
      if (event.serverDurationMs != null) '${(event.serverDurationMs! / 1000).toStringAsFixed(1)}s',
      if (event.replayed) 'sent late',
      if (event.stale) 'from an old session',
      if (event.review == 'CONTINUE_ALLOWED') 'allowed to continue',
      if (event.review == 'BANNED') 'banned',
      ?event.detail,
    ];
    return ListTile(
      dense: true,
      leading: Icon(Icons.circle, size: 12, color: color),
      title: Text(_typeLabel(event.type), style: TextStyle(color: color)),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      trailing: Text(DateFormat('HH:mm:ss').format(event.receivedAt)),
    );
  }
}

String _levelLabel(String level) => switch (level) {
  IntegrityLevel.violation => 'Violations',
  IntegrityLevel.warning => 'Warnings',
  _ => 'Logs',
};

String _typeLabel(String type) => switch (type) {
  'AWAY_START' => 'Left the exam screen',
  'AWAY_END' => 'Returned to the exam screen',
  'RELOAD' => 'Reloaded the page',
  'NAVIGATION_BLOCKED' => 'Tried to navigate away',
  'BACK_BLOCKED' => 'Pressed back',
  'COPY' => 'Copied',
  'PASTE' => 'Pasted',
  'SESSION_CONFLICT' => 'Opened in another tab or device',
  'SESSION_TAKEOVER' => 'Continued on another device',
  'SESSION_RELEASED' => 'Session released by teacher',
  'TEACHER_BANNED' => 'Banned by teacher',
  'CONTINUE_ALLOWED' => 'Allowed to continue',
  'RESULT_REINSTATED' => 'Result reinstated',
  _ => type,
};
