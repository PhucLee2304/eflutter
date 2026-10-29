part of 'classroom_gradebook_screen.dart';

/// Phần giám sát của gradebook (PLAN_ATTEMPT_INTEGRITY.md I4): vi phạm chờ xử lý,
/// "đang rời màn thi" từ push ATTEMPT_INTEGRITY_UPDATED, và các thao tác giáo viên.
mixin _GradebookIntegrity on State<ClassroomGradebookScreen> {
  ClassroomRepository get repository;
  ClassroomAssignment? get assignment;
  Future<void> load({bool showLoading = true});

  List<IntegrityEventRecord> pendingViolations = const [];
  final awayStudents = <String>{};
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
    if (away == awayStudents.contains(update.studentId)) return;
    setState(() {
      if (away) {
        awayStudents.add(update.studentId);
      } else {
        awayStudents.remove(update.studentId);
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

  /// Review các vi phạm của một học sinh theo thứ tự; dừng ở lỗi đầu tiên.
  Future<void> reviewViolations(List<IntegrityEventRecord> events, String action) async {
    if (events.isEmpty) return;
    if (action == IntegrityReviewAction.ban &&
        await confirmBanAttempt(context, _studentName(events.first.studentId)) == null) {
      return;
    }
    if (!mounted) return;
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

  Widget integrityPanel() {
    final current = assignment;
    if (current == null || !current.proctored) return const SizedBox.shrink();
    return IntegrityViolationPanel(
      events: pendingViolations,
      submissions: current.submissions,
      maxViolations: current.maxViolations,
      busyEventIds: busyEvents,
      onBan: (event) => reviewViolations([event], IntegrityReviewAction.ban),
      onAllowContinue: (events) => reviewViolations(events, IntegrityReviewAction.allowContinue),
    );
  }
}
