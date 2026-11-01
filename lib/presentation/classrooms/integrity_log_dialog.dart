import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/attempt_integrity.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/classrooms/confirm_action_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Log giám sát của một học sinh (Figma T3): mỗi lần rời màn một dòng, quyết định của giáo
/// viên hiện ngay trên vi phạm; Cấm, cho mở lại, khôi phục kết quả.
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
/// [submitted]: bài đã nộp thì chỉ đình chỉ kết quả, không còn "nộp ngay".
Future<String?> confirmBanAttempt(
  BuildContext context,
  String studentName, {
  bool submitted = false,
}) => showConfirmAction(
  context,
  icon: Icons.block,
  color: ConfirmActionColors.red,
  tint: const Color(0xFFFDECEA),
  title: "Suspend $studentName's ${submitted ? 'result' : 'attempt'}?",
  message: submitted
      ? 'The submitted result is suspended and the score set to 0. '
            'You can reinstate it later.'
      : 'The attempt is suspended now and submitted with a score of 0. '
            'You can reinstate the result later.',
  field: 'Message to the student (optional)',
  hint: 'Shown on their result page',
  action: 'Suspend',
);

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
  static const _text = Color(0xFF1C1E21);
  static const _muted = Color(0xFF65676B);
  static const _faint = Color(0xFF8A8D91);
  static const _border = Color(0xFFE4E6EB);
  static const _soft = Color(0xFFF7F8FA);
  static const _tint = Color(0xFFEEF7FD);
  static const _green = Color(0xFF1E8E3E);
  static const _greenBg = Color(0xFFE7F6EC);
  static const _orange = Color(0xFFB26A00);
  static const _red = Color(0xFFD93025);
  static const _redBg = Color(0xFFFDECEA);

  /// Log do server ghi khi giáo viên quyết định: đã hiện thành nhãn trên dòng vi phạm.
  static const _decisionLogs = {'CONTINUE_ALLOWED', 'VIOLATION_KEPT'};

  List<IntegrityEventRecord> events = const [];
  bool loading = true;
  bool busy = false;
  String? error;

  /// Trạng thái sau thao tác trong dialog (dữ liệu gradebook truyền vào có thể cũ).
  late String status = widget.submission.status;
  late String? outcome = widget.submission.integrityOutcome;
  late String? terminationReason = widget.submission.terminationReason;
  late int violations = widget.submission.violationCount;

  String get studentId => widget.submission.student?.id ?? '';
  String get studentName => widget.submission.student?.name ?? 'Student';
  bool get active => status == 'IN_PROGRESS';

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

  Future<void> review(IntegrityEventRecord event, String action) => run(
    () => widget.repository.reviewIntegrityEvent(
      classroomId: widget.classroomId,
      assignmentId: widget.assignmentId,
      eventId: event.eventId,
      action: action,
    ),
    switch (action) {
      IntegrityReviewAction.allowContinue => 'Not counted',
      _ => 'Kept',
    },
    onSuccess: () {
      if (action == IntegrityReviewAction.allowContinue && active && violations > 0) {
        violations--;
      }
    },
  );

  Future<void> ban() async {
    final note = await confirmBanAttempt(context, studentName, submitted: !active);
    if (note == null || !mounted) return;
    await run(
      () => widget.repository.banAttempt(
        classroomId: widget.classroomId,
        assignmentId: widget.assignmentId,
        studentId: studentId,
        note: note.isEmpty ? null : note,
      ),
      active ? 'Attempt suspended' : 'Result suspended',
      onSuccess: () {
        status = 'SUBMITTED';
        outcome = 'TERMINATED';
        terminationReason = 'TEACHER_BANNED';
      },
    );
  }

  /// Hỏi trước vì tab đang mở của học sinh sẽ bị đóng ngay.
  Future<void> releaseSession() async {
    final ok = await showConfirmAction(
      context,
      icon: Icons.refresh,
      color: ColorName.primary,
      tint: const Color(0xFFEEF7FD),
      title: 'Let $studentName reopen the exam?',
      message:
          'The exam open on their current device will close. They can reopen it anywhere. '
          'Answers are kept, and this is not counted as a violation.',
      action: 'Let them reopen',
    );
    if (ok == null || !mounted) return;
    await run(
      () => widget.repository.releaseAttemptSession(
        classroomId: widget.classroomId,
        assignmentId: widget.assignmentId,
        studentId: studentId,
      ),
      '$studentName can reopen the exam',
    );
  }

  Future<void> reinstate() async {
    final note = await showConfirmAction(
      context,
      icon: Icons.check,
      color: const Color(0xFF1E8E3E),
      tint: const Color(0xFFE7F6EC),
      title: 'Reinstate the result?',
      message: 'The suspension is lifted and the attempt keeps the score it earned.',
      field: 'Reason (shown to the student)',
      hint: 'Shown on their result page',
      required: true,
      action: 'Reinstate',
    );
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

  /// Dòng hiển thị: gộp AWAY_END vào AWAY_START, bỏ log quyết định (đã thành nhãn).
  List<_LogEntry> get entries {
    final ends = {
      for (final event in events)
        if (event.type == 'AWAY_END' && event.startEventId != null) event.startEventId!: event,
    };
    final eventIds = {for (final event in events) event.eventId};
    return [
      for (final event in events)
        if (!_decisionLogs.contains(event.type) &&
            !(event.type == 'AWAY_END' && eventIds.contains(event.startEventId)))
          _LogEntry(event, ends[event.eventId]),
    ]..sort((a, b) => b.event.receivedAt.compareTo(a.event.receivedAt));
  }

  Duration get timeAway => Duration(
    milliseconds: events
        .where((event) => event.type == 'AWAY_START')
        .fold(0, (sum, event) => sum + (event.serverDurationMs ?? 0)),
  );

  int get warnings => events.where((event) => event.level == IntegrityLevel.warning).length;

  IntegrityEventRecord? _latest(String type) => events
      .where((event) => event.type == type)
      .fold<IntegrityEventRecord?>(
        null,
        (latest, event) =>
            latest == null || event.receivedAt.isAfter(latest.receivedAt) ? event : latest,
      );

  /// Ghi chú tự viết của giáo viên (không phải mã sự kiện server tự ghi).
  String? _note(IntegrityEventRecord? event) {
    final detail = event?.detail?.trim();
    if (detail == null || detail.isEmpty || events.any((item) => item.eventId == detail)) {
      return null;
    }
    return detail;
  }

  @override
  Widget build(BuildContext context) {
    final terminated = outcome == 'TERMINATED';
    final reinstated = outcome == 'REINSTATED';
    final list = entries;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(terminated: terminated, reinstated: reinstated),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    _stats(),
                    if (terminated) _outcomeNote(reinstated: false),
                    if (reinstated) _outcomeNote(reinstated: true),
                    if (loading)
                      const Padding(padding: EdgeInsets.all(32), child: AppLoader())
                    else if (error != null)
                      _empty(
                        error!,
                        action: TextButton(onPressed: load, child: const Text('Try again')),
                      )
                    else if (list.isEmpty)
                      _empty('Nothing recorded')
                    else
                      Column(children: [for (final entry in list) _row(entry)]),
                  ],
                ),
              ),
            ),
            _footer(terminated: terminated),
          ],
        ),
      ),
    );
  }

  Widget _header({required bool terminated, required bool reinstated}) {
    final avatar = widget.submission.student?.avatar;
    final (label, background, foreground) = terminated
        ? ('Suspended', _redBg, _red)
        : reinstated
        ? ('Reinstated', _greenBg, _green)
        : active
        ? ('In progress', _tint, ColorName.primary)
        : ('Submitted', _greenBg, _green);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        spacing: 12,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _tint,
            foregroundImage: avatar == null ? null : NetworkImage(avatar),
            child: Text(
              studentName.isEmpty ? '?' : studentName[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w600, color: ColorName.primary),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const Text('Integrity log', style: TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          _Pill(label, background: background, foreground: foreground),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: _tint,
              foregroundColor: ColorName.primary,
              fixedSize: const Size(32, 32),
              minimumSize: const Size(32, 32),
            ),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    final max = widget.maxViolations;
    final atLimit = max > 0 && violations >= max;
    final color = atLimit ? _red : _orange;
    final seconds = timeAway.inSeconds;
    final violationText = violations == 0
        ? 'No violations'
        : atLimit && violations == max
        ? 'Limit reached'
        : '$violations ${violations == 1 ? 'violation' : 'violations'}';
    Widget box(String label, Widget value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _muted),
            ),
            value,
          ],
        ),
      ),
    );
    const number = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text);
    return Row(
      spacing: 10,
      children: [
        box(
          'Violations',
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Meter(count: violations, max: max, color: color),
              Text(
                violationText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: violations == 0 ? _muted : color,
                ),
              ),
            ],
          ),
        ),
        box('Warnings', Text('$warnings', style: number)),
        box(
          'Time away',
          Text(seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m ${seconds % 60}s', style: number),
        ),
      ],
    );
  }

  Widget _outcomeNote({required bool reinstated}) {
    final IconData icon;
    final String title;
    final String message;
    final Color color, background;
    if (reinstated) {
      final event = _latest('RESULT_REINSTATED');
      final note = _note(event);
      icon = Icons.check;
      color = _green;
      background = _greenBg;
      title = 'Reinstated${event == null ? '' : ' · ${_time(event.receivedAt)}'}';
      message = '${note == null ? '' : '"$note". '}The attempt keeps the score it earned.';
    } else if (terminationReason == 'TEACHER_BANNED') {
      final event = _latest('TEACHER_BANNED');
      final note = _note(event);
      icon = Icons.block;
      color = _red;
      background = _redBg;
      title = 'Suspended by teacher${event == null ? '' : ' · ${_time(event.receivedAt)}'}';
      message = '${note == null ? '' : '"$note". '}Score set to 0.';
    } else {
      icon = Icons.block;
      color = _red;
      background = _redBg;
      title = 'Suspended automatically';
      message = 'Went over ${widget.maxViolations} violations. Score set to 0.';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(icon, size: 16, color: color),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
                Text(message, style: const TextStyle(fontSize: 12, color: _text)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String title, {String? hint, Widget? action}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      spacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _muted),
        ),
        if (hint != null)
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _faint),
          ),
        ?action,
      ],
    ),
  );

  Widget _row(_LogEntry entry) {
    final event = entry.event;
    final end = entry.end;
    final color = switch (event.level) {
      IntegrityLevel.violation => _red,
      IntegrityLevel.warning => _orange,
      _ => _faint,
    };
    final away = event.type == 'AWAY_START';
    final ms = event.serverDurationMs ?? end?.serverDurationMs;
    final title = away
        ? 'Left the exam${ms == null ? '' : ' for ${(ms / 1000).round()}s'}'
        : _typeLabel(event.type);
    final sub = [
      if (away)
        end == null
            ? '${_clock(event.receivedAt)} → still away'
            : '${_clock(event.receivedAt)} → ${_clock(end.receivedAt)}',
      if (event.violationNo != null) 'violation ${event.violationNo}',
      if (!away && event.level == IntegrityLevel.warning) 'Warning',
      if (event.replayed) 'sent late',
      if (event.stale) 'from an old session',
      if (event.type == 'TEACHER_BANNED' || event.type == 'RESULT_REINSTATED') ?_note(event),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        spacing: 12,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              DateFormat('HH:mm').format(event.receivedAt),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _faint),
            ),
          ),
          Icon(Icons.circle, size: 8, color: color),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _text),
                ),
                if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          if (event.isViolation) _decision(event),
        ],
      ),
    );
  }

  /// Nhãn cho ngoại lệ (không tính / dẫn tới đình chỉ), hoặc nút quyết định khi đang làm bài.
  Widget _decision(IntegrityEventRecord event) {
    switch (event.review) {
      case 'CONTINUE_ALLOWED':
        return const _Pill('Not counted', background: _greenBg, foreground: _green);
      case 'BANNED':
        return const _Pill('Led to suspension', background: _redBg, foreground: _red);
    }
    // Vi phạm được tính là mặc định nên không gắn nhãn; bài đã nộp thì không quyết định từng cái.
    if (event.review == 'KEPT' || !active) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        _SmallButton(
          "Don't count it",
          tinted: true,
          onPressed: busy ? null : () => review(event, IntegrityReviewAction.allowContinue),
        ),
        _SmallButton(
          'Keep it',
          onPressed: busy ? null : () => review(event, IntegrityReviewAction.keep),
        ),
      ],
    );
  }

  Widget _footer({required bool terminated}) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final outline = OutlinedButton.styleFrom(
      foregroundColor: _text,
      side: const BorderSide(color: _border),
      shape: shape,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Bài đã nộp vẫn Cấm được (đình chỉ kết quả); đang bị đình chỉ thì chỉ Khôi phục.
          if (!terminated)
            FilledButton(
              onPressed: busy ? null : ban,
              style: FilledButton.styleFrom(
                backgroundColor: _redBg,
                foregroundColor: _red,
                shape: shape,
              ),
              child: Text(active ? 'Suspend attempt' : 'Suspend result'),
            )
          else
            const SizedBox.shrink(),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              if (active)
                Tooltip(
                  message: 'Use if the student switched device or the tab crashed',
                  child: FilledButton(
                    onPressed: busy ? null : releaseSession,
                    style: FilledButton.styleFrom(
                      backgroundColor: _tint,
                      foregroundColor: ColorName.primary,
                      shape: shape,
                    ),
                    child: const Text('Let them reopen'),
                  ),
                ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: outline,
                child: const Text('Close'),
              ),
              if (terminated)
                FilledButton(
                  onPressed: busy ? null : reinstate,
                  style: FilledButton.styleFrom(shape: shape),
                  child: const Text('Reinstate result'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime at) => DateFormat('HH:mm:ss').format(at);

  static String _time(DateTime at) => DateFormat('HH:mm').format(at);
}

class _LogEntry {
  const _LogEntry(this.event, this.end);
  final IntegrityEventRecord event;

  /// AWAY_END của lần rời màn (null nếu chưa quay lại hoặc không phải AWAY_START).
  final IntegrityEventRecord? end;
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.background, required this.foreground});
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: foreground),
    ),
  );
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(this.label, {required this.onPressed, this.tinted = false});
  final String label;
  final VoidCallback? onPressed;
  final bool tinted;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: tinted ? const Color(0xFFEEF7FD) : Colors.white,
      foregroundColor: tinted ? ColorName.primary : const Color(0xFF1C1E21),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: const Size(0, 30),
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: tinted ? BorderSide.none : const BorderSide(color: Color(0xFFE4E6EB)),
      ),
    ),
    child: Text(label),
  );
}

class _Meter extends StatelessWidget {
  const _Meter({required this.count, required this.max, required this.color});
  final int count;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
              color: i <= count ? color : const Color(0xFFE4E6EB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

String _typeLabel(String type) => switch (type) {
  'AWAY_START' => 'Left the exam',
  'AWAY_END' => 'Returned to the exam',
  'RELOAD' => 'Reloaded the page',
  'NAVIGATION_BLOCKED' => 'Tried to navigate away',
  'BACK_BLOCKED' => 'Pressed back',
  'COPY' => 'Copied text',
  'PASTE' => 'Pasted text',
  'SESSION_CONFLICT' => 'Opened in another tab or device',
  'SESSION_TAKEOVER' => 'Continued on another device',
  'SESSION_RELEASED' => 'Allowed to reopen by teacher',
  'TEACHER_BANNED' => 'Suspended by teacher',
  'RESULT_REINSTATED' => 'Result reinstated',
  _ => type,
};
