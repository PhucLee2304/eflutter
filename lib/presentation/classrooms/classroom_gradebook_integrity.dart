part of 'classroom_gradebook_screen.dart';

/// Phần giám sát của gradebook (PLAN_ATTEMPT_INTEGRITY.md I4): vi phạm chờ xử lý,
/// "đang rời màn thi" từ push ATTEMPT_INTEGRITY_UPDATED, và các thao tác giáo viên.
mixin _GradebookIntegrity on State<ClassroomGradebookScreen> {
  ClassroomRepository get repository;
  ClassroomAssignment? get assignment;
  Future<void> load({bool showLoading = true});

  List<IntegrityEventRecord> pendingViolations = const [];

  /// Học sinh đang rời màn thi → lúc bắt đầu rời (để ô Violations đếm giờ).
  final awaySince = <String, DateTime>{};
  final busyEvents = <String>{};

  /// Tải lại vi phạm chờ xử lý: khi mở màn, khi socket nối lại, khi có push.
  Future<void> loadPendingViolations() async {
    if (assignment?.proctored != true) return;
    final result = await repository.getIntegrityEvents(
      classroomId: widget.classroomId,
      assignmentId: widget.assignmentId,
      pending: true,
    );
    if (!mounted) return;
    if (result case Success(data: final page)) {
      setState(() => pendingViolations = page.items);
    }
  }

  void applyIntegrityUpdate(IntegrityUpdate update) {
    final away = update.away && update.status == 'ACTIVE';
    if (away == awaySince.containsKey(update.studentId)) return;
    setState(() {
      if (away) {
        awaySince[update.studentId] = DateTime.now();
      } else {
        awaySince.remove(update.studentId);
      }
    });
  }

  String _studentName(String studentId) =>
      assignment?.submissions
          .where((item) => item.student?.id == studentId)
          .firstOrNull
          ?.student
          ?.name ??
      'Student';

  AssignmentSubmission? _submissionOf(String studentId) =>
      assignment?.submissions.where((item) => item.student?.id == studentId).firstOrNull;

  /// Vi phạm chờ xử lý của học sinh còn đang làm bài: chỉ những vi phạm này lên panel T2.
  /// Bài đã nộp xử lý từ ô Proctoring của bảng (mở log).
  List<IntegrityEventRecord> get activePendingViolations => [
    for (final event in pendingViolations)
      if (_submissionOf(event.studentId)?.status == 'IN_PROGRESS') event,
  ];

  /// Review các vi phạm của một học sinh theo thứ tự; dừng ở lỗi đầu tiên.
  Future<void> reviewViolations(List<IntegrityEventRecord> events, String action) async {
    if (events.isEmpty) return;
    final studentId = events.first.studentId;
    final before = _submissionOf(studentId)?.violationCount ?? 0;
    final ids = events.map((event) => event.eventId).toList();
    setState(() => busyEvents.addAll(ids));
    Result<void>? result;
    for (final event in events) {
      result = await repository.reviewIntegrityEvent(
        classroomId: widget.classroomId,
        assignmentId: widget.assignmentId,
        eventId: event.eventId,
        action: action,
      );
      if (result is! Success) break;
    }
    if (!mounted) return;
    setState(() => busyEvents.removeAll(ids));
    if (result case Failure(message: final message)) {
      context.showToast(message ?? 'Could not review the violation', type: ToastType.error);
      await load(showLoading: false);
      return;
    }
    final name = _studentName(studentId);
    if (action == IntegrityReviewAction.allowContinue) {
      final after = (before - events.length).clamp(0, before);
      context.showToast(
        'Not counted. $name is back to $after ${after == 1 ? 'violation' : 'violations'}.',
        type: ToastType.success,
      );
    } else {
      context.showToast('Kept. $name still has $before violations.', type: ToastType.success);
    }
    await load(showLoading: false);
  }

  Future<void> openIntegrityLog(AssignmentSubmission submission) => showIntegrityLogDialog(
    context,
    repository: repository,
    classroomId: widget.classroomId,
    assignmentId: widget.assignmentId,
    submission: submission,
    maxViolations: assignment?.maxViolations ?? 0,
    onChanged: () => load(showLoading: false),
  );

  /// Null khi không còn học sinh đang làm bài cần quyết định (panel ẩn).
  Widget? integrityPanel() {
    final current = assignment;
    final events = activePendingViolations;
    if (current == null || !current.proctored || events.isEmpty) return null;
    return IntegrityViolationPanel(
      events: events,
      submissions: current.submissions,
      maxViolations: current.maxViolations,
      busyEventIds: busyEvents,
      onDontCount: (events) => reviewViolations(events, IntegrityReviewAction.allowContinue),
      onKeep: (events) => reviewViolations(events, IntegrityReviewAction.keep),
      onOpenLog: openIntegrityLog,
    );
  }
}
