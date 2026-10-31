import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/classrooms/classroom_assignments.dart';
import 'package:eflutter/presentation/classrooms/assignment_review_view.dart';
import 'package:eflutter/presentation/classrooms/class_gradebook_screen.dart';
import 'package:eflutter/presentation/classrooms/classroom_gradebook_screen.dart';
import 'package:eflutter/presentation/classrooms/classwork_page.dart';
import 'package:eflutter/presentation/classrooms/student_progress_screen.dart';
import 'package:eflutter/presentation/classrooms/classroom_calendar.dart';
import 'package:eflutter/presentation/classrooms/classroom_people.dart';
import 'package:eflutter/presentation/classrooms/classroom_detail_header.dart';
import 'package:eflutter/presentation/posts/post_list.dart';
import 'package:eflutter/core/attempt_lock/integrity_consent.dart';
import 'package:eflutter/presentation/classrooms/integrity_consent_dialog.dart';
import 'package:eflutter/presentation/classrooms/assignment_start_dialog.dart';
import 'package:eflutter/presentation/classrooms/create_classroom_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ClassroomDetailScreen extends StatefulWidget {
  const ClassroomDetailScreen({
    super.key,
    required this.classroomId,
    this.postId,
    this.commentId,
    this.initialTab = 0,
    this.classwork = const ClassworkPage.list(),
  });
  final int classroomId;

  /// Mở chi tiết một bài viết của lớp ngay trong tab Announcements (`/classrooms/:id/posts/:postId`).
  final int? postId;
  final int? commentId;

  /// Tab mở sẵn theo URL (`/classwork`, `/calendar`, `/people`).
  final int initialTab;

  /// Màn con của tab Classwork theo URL (tạo/sửa bài, gradebook, tiến độ học sinh).
  final ClassworkPage classwork;
  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  late final ClassroomRepository repository = ClassroomRepository(getIt<Dio>());
  late final ExamRepository examRepository = ExamRepository(getIt<RemoteDataBase>());
  Classroom? classroom;
  List<ClassroomMember> requests = [];
  List<ClassroomAssignment> assignments = [];
  bool assignmentsLoading = true;
  bool assignmentsLoadingMore = false;
  String? assignmentsError;
  String? assignmentsLoadMoreError;
  int assignmentsPage = 0;
  int assignmentPageCounts = 1;
  bool loading = true;
  bool busy = false;

  /// Khác null khi đang mở form tạo bài trong tab Classwork (danh sách lớp có thể giao).
  List<Classroom>? creatingFor;

  /// Khác null khi đang mở màn sửa một bài trong tab Classwork.
  ({
    ClassroomAssignment assignment,
    EditableAssignment editable,
    List<Classroom> classrooms,
    List<ExamAudit> audits,
  })?
  editing;
  String? error;
  late int tab = widget.initialTab;

  // Bài mở sẵn từ URL; bỏ đi khi đổi tab để quay lại Announcements là danh sách.
  late int? initialPostId = widget.postId;

  // Đổi tab bằng URL; mọi URL của lớp dùng chung trang nên chỉ didUpdateWidget chạy.
  void selectTab(int value) {
    if (value == tab && widget.classwork.view == ClassworkView.list) return;
    context.go(classroomTabPath(widget.classroomId, value));
  }

  void goClasswork([String? path]) => context.go(path ?? classworkPath(widget.classroomId));

  @override
  void didUpdateWidget(covariant ClassroomDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab || oldWidget.postId != widget.postId) {
      setState(() {
        tab = widget.initialTab;
        initialPostId = widget.postId;
      });
    }
    if (oldWidget.classwork != widget.classwork) syncClasswork();
  }

  /// Nạp dữ liệu cho màn con đang mở theo URL; bỏ dữ liệu của màn đã rời.
  Future<void> syncClasswork() async {
    final page = widget.classwork;
    setState(() {
      if (page.view != ClassworkView.create) creatingFor = null;
      if (page.view != ClassworkView.edit || editing?.assignment.id != page.assignmentId) {
        editing = null;
      }
    });
    switch (page.view) {
      case ClassworkView.create when creatingFor == null:
        final classes = await loadTeacherClassrooms();
        if (!mounted || widget.classwork != page) return;
        if (classes == null) return goClasswork();
        setState(() => creatingFor = classes);
      case ClassworkView.edit when editing == null:
        await loadEditing(page.assignmentId!);
      default:
        break;
    }
  }

  StreamSubscription<AppState>? userSubscription;

  bool get isTeacher =>
      classroom?.teacher?.id == context.read<AppCubit>().state.user?.id.toString();

  @override
  void initState() {
    super.initState();
    userSubscription = context.read<AppCubit>().stream.listen((state) {
      if (classroom?.active == true && classroom?.teacher?.id == state.user?.id.toString()) {
        loadRequests();
      }
    });
    load();
    syncClasswork();
  }

  @override
  void dispose() {
    userSubscription?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await repository.get(widget.classroomId);
    if (!mounted) return;
    switch (result) {
      case Success(data: final item):
        setState(() {
          classroom = item;
          loading = false;
        });
        await loadAssignments();
        if (isTeacher && item.active) await loadRequests();
      case Failure(message: final message):
        setState(() {
          error = message;
          loading = false;
        });
      case Cancelled():
        setState(() => loading = false);
    }
  }

  Future<void> loadAssignments() async {
    setState(() {
      assignmentsLoading = true;
      assignmentsError = null;
      assignmentsLoadMoreError = null;
    });
    final result = await repository.getAssignments(widget.classroomId, page: 1);
    if (!mounted) return;
    switch (result) {
      case Success(data: final value):
        setState(() {
          assignments = value.items;
          assignmentsPage = 1;
          assignmentPageCounts = value.pageCounts;
          assignmentsLoading = false;
        });
      case Failure(message: final message):
        setState(() {
          assignmentsError = message ?? 'Could not load assignments';
          assignmentsLoading = false;
        });
      case Cancelled():
        setState(() => assignmentsLoading = false);
    }
  }

  Future<void> loadMoreAssignments() async {
    if (assignmentsLoading || assignmentsLoadingMore || assignmentsPage >= assignmentPageCounts) {
      return;
    }
    setState(() {
      assignmentsLoadingMore = true;
      assignmentsLoadMoreError = null;
    });
    final nextPage = assignmentsPage + 1;
    final result = await repository.getAssignments(widget.classroomId, page: nextPage);
    if (!mounted) return;
    switch (result) {
      case Success(data: final value):
        setState(() {
          assignments = [...assignments, ...value.items];
          assignmentsPage = nextPage;
          assignmentPageCounts = value.pageCounts;
          assignmentsLoadingMore = false;
        });
      case Failure(message: final message):
        setState(() {
          assignmentsLoadMoreError = message ?? 'Could not load more assignments';
          assignmentsLoadingMore = false;
        });
      case Cancelled():
        setState(() => assignmentsLoadingMore = false);
    }
  }

  bool onPageScroll(ScrollNotification notification) {
    if (tab == 1 && notification.metrics.extentAfter < 320 && !assignmentsLoadingMore) {
      unawaited(loadMoreAssignments());
    }
    return false;
  }

  /// Các lớp đang hoạt động mà người dùng là giáo viên; null khi tải lỗi (đã báo lỗi).
  Future<List<Classroom>?> loadTeacherClassrooms() async {
    final classes = <Classroom>[];
    final cubit = context.read<AppCubit>();
    var page = 1;
    var pageCounts = 1;
    do {
      final result = await repository.getMine(page: page);
      if (!mounted) return null;
      switch (result) {
        case Success(data: final value):
          pageCounts = value.pageCounts;
          classes.addAll(value.items.where((item) => item.active));
        case Failure(message: final message):
          showMessage(message ?? 'Could not load your classrooms');
          return null;
        case Cancelled():
          return null;
      }
      page++;
    } while (page <= pageCounts);
    // Mở thẳng bằng URL (reload) thì user có thể chưa nạp xong lúc gọi hàm này.
    final user =
        cubit.state.user ?? (await cubit.stream.firstWhere((state) => state.user != null)).user;
    if (!mounted) return null;
    final userID = user?.id.toString();
    return classes.where((item) => item.teacher?.id == userID).toList();
  }

  void createAssignment() => goClasswork(createAssignmentPath(widget.classroomId));

  // Gửi form tạo bài; thành công thì đóng form và tải lại danh sách Classwork.
  Future<bool> submitAssignment(CreateAssignmentInput input) async {
    final result = await repository.createAssignments(
      schedules: input.schedules,
      title: input.title,
      description: input.description,
      questions: input.questions,
    );
    if (!mounted) return false;
    switch (result) {
      case Success():
        goClasswork();
        await loadAssignments();
        return true;
      case Failure(message: final message):
        showMessage(message ?? 'Could not create the assignment');
        return false;
      case Cancelled():
        return false;
    }
  }

  void rememberReview(ClassroomAssignment assignment, int attemptId) =>
      assignmentReviewPaths[attemptId] = assignmentReviewPath(
        widget.classroomId,
        assignment.id,
        attemptId,
      );

  Future<void> openAssignment(ClassroomAssignment assignment) async {
    final submission = assignment.submission;
    if (submission?.attemptId != 0 && submission?.attemptId != null) {
      rememberReview(assignment, submission!.attemptId);
      final path = submission.status == 'IN_PROGRESS'
          ? attemptPracticePath(submission.attemptId)
          : assignmentReviewPath(widget.classroomId, assignment.id, submission.attemptId);
      context.go(path);
      return;
    }

    // Xem đủ tiêu đề, mô tả và luật làm bài rồi mới tạo attempt.
    if (!await showAssignmentStartDialog(context, assignment) || !mounted) return;
    // Bài có giám sát: phải đồng ý quy chế trước khi tạo attempt (mục 1.7).
    if (assignment.proctored &&
        !await showIntegrityConsentDialog(context, maxViolations: assignment.maxViolations)) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    final result = await examRepository.createExamAttempt(
      assignment.examId,
      CreateExamAttemptRequest(
        contextType: 'CLASSROOM_ASSIGNMENT',
        contextId: assignment.id,
        integrityConsentVersion: assignment.proctored ? integrityConsentVersion : null,
      ),
    );
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success(data: final attempt):
        rememberReview(assignment, attempt.id);
        context.go(attemptPracticePath(attempt.id), extra: attempt);
      case Failure(code: 409, message: final message):
        final activeResult = await examRepository.getAttempts(
          status: 'ACTIVE',
          page: 1,
          pageSize: 20,
        );
        if (!mounted) return;
        switch (activeResult) {
          case Success(data: final page):
            final matching = page.attempts
                .where((attempt) => attempt.examId == assignment.examId)
                .firstOrNull;
            final activeAttempt = matching ?? page.attempts.firstOrNull;
            if (activeAttempt != null) {
              if (activeAttempt.examId == assignment.examId) {
                rememberReview(assignment, activeAttempt.id);
              }
              context.go(attemptPracticePath(activeAttempt.id), extra: activeAttempt);
              return;
            }
          case Failure():
          case Cancelled():
            break;
        }
        showMessage(message ?? 'Could not resume the active attempt');
      case Failure(message: final message):
        showMessage(message ?? 'Could not start the assignment');
      case Cancelled():
        break;
    }
  }

  Future<void> openAssignmentById(int assignmentId) async {
    // Giáo viên mở bảng điểm của bài, học sinh mới bắt đầu/xem bài làm.
    if (isTeacher) {
      context.go(
        classroomGradebookPath(
          widget.classroomId,
          assignmentId,
          backTo: classroomTabPath(widget.classroomId, 2),
        ),
      );
      return;
    }
    final cached = assignments.where((item) => item.id == assignmentId);
    if (cached.isNotEmpty) {
      await openAssignment(cached.first);
      return;
    }
    setState(() => busy = true);
    final result = await repository.getAssignment(widget.classroomId, assignmentId);
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success(data: final assignment):
        await openAssignment(assignment);
      case Failure(message: final message):
        showMessage(message ?? 'Could not open the assignment');
      case Cancelled():
        break;
    }
  }

  Future<void> setAssignmentActive(ClassroomAssignment assignment, bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pause assignment?'),
          content: const Text(
            'Students will not be able to start. Attempts currently in progress '
            'will be submitted and graded using their saved answers.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pause and submit'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => busy = true);
    final result = await repository.setAssignmentActive(widget.classroomId, assignment.id, active);
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await loadAssignments();
      case Failure(message: final message):
        showMessage(message ?? 'Could not update the assignment');
      case Cancelled():
        break;
    }
  }

  void editAssignmentContent(ClassroomAssignment assignment) =>
      goClasswork(editAssignmentPath(widget.classroomId, assignment.id));

  Future<void> loadEditing(int assignmentId) async {
    final page = widget.classwork;
    setState(() => busy = true);
    final (assignmentResult, editableResult, auditsResult, classes) = await (
      repository.getAssignment(widget.classroomId, assignmentId),
      repository.getEditableAssignment(widget.classroomId, assignmentId),
      repository.getAssignmentAudits(classroomId: widget.classroomId, assignmentId: assignmentId),
      loadTeacherClassrooms(),
    ).wait;
    if (!mounted) return;
    setState(() => busy = false);
    if (widget.classwork != page) return;
    final assignment = assignmentResult.dataOrNull;
    final editable = editableResult.dataOrNull;
    if (assignment == null || editable == null) {
      final failure = editableResult is Failure ? editableResult : assignmentResult;
      if (failure case Failure(message: final message)) {
        showMessage(message ?? 'Could not load the assignment');
      }
      return goClasswork();
    }
    setState(
      () => editing = (
        assignment: assignment,
        editable: editable,
        classrooms: classes ?? const [],
        audits: auditsResult.dataOrNull ?? const [],
      ),
    );
  }

  /// Lưu màn sửa: gửi cả form như lúc tạo (schedules gồm lớp hiện tại và lớp mới tích),
  /// backend tự so và chỉ ghi phần thay đổi. Cần xác nhận thì hỏi một lần rồi gửi lại.
  Future<bool> saveAssignmentContent(CreateAssignmentInput input) async {
    final session = editing!;
    Future<Result<ClassroomAssignment>> save({bool confirm = false, String reason = ''}) =>
        repository.updateAssignment(
          classroomId: widget.classroomId,
          assignmentId: session.assignment.id,
          title: input.title,
          description: input.description,
          questions: input.questions,
          schedules: input.schedules,
          confirm: confirm,
          reason: reason,
        );

    var result = await save();
    if (!mounted) return false;
    if (result case Failure(code: 409)) {
      final reason = await _confirmUpdate(session.editable);
      if (reason == null || !mounted) return false;
      result = await save(confirm: true, reason: reason);
      if (!mounted) return false;
    }
    switch (result) {
      case Success():
        goClasswork();
        showMessage('Assignment updated', type: ToastType.success);
        await loadAssignments();
        return true;
      case Failure(message: final message):
        showMessage(message ?? 'Could not update the assignment');
        return false;
      case Cancelled():
        return false;
    }
  }

  /// Một hộp xác nhận cho mọi thay đổi ảnh hưởng tới bài đang làm. Trả lý do (có thể rỗng;
  /// backend báo lỗi nếu sửa câu hỏi mà thiếu lý do), hoặc null khi huỷ.
  Future<String?> _confirmUpdate(EditableAssignment editable) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Students have already started'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              '${editable.activeAttempts} in progress, ${editable.submittedAttempts} submitted.',
            ),
            Text(
              'Changing questions pauses every class using this exam '
              '(${editable.affectedAssignments.map((item) => item.classroomName).join(', ')}), '
              'submits attempts in progress and re-grades submissions. '
              'A shorter schedule may end active attempts sooner.',
            ),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for correction',
                helperText: 'Required when you changed questions',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppButtonStyles.secondary,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppButtonStyles.primary,
            child: const Text('Confirm and save'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    return confirmed == true ? reason : null;
  }

  void openGradebook(ClassroomAssignment assignment) =>
      goClasswork(classroomGradebookPath(widget.classroomId, assignment.id));

  Future<void> loadRequests() async {
    final result = await repository.joinRequests(widget.classroomId);
    if (!mounted) return;
    switch (result) {
      case Success(data: final items):
        setState(() => requests = items);
      case Failure(message: final message):
        showMessage(message ?? 'Could not load join requests');
      case Cancelled():
        break;
    }
  }

  Future<void> edit() async {
    final saved = await showEditClassroomDialog(context, classroom!);
    if (saved != null && mounted) await load();
  }

  Future<void> archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive classroom?'),
        content: const Text('The classroom will no longer accept join requests.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    final result = await repository.archive(widget.classroomId);
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await load();
      case Failure(message: final message):
        showMessage(message ?? 'Could not archive the classroom');
      case Cancelled():
        break;
    }
  }

  Future<void> review(ClassroomMember member, bool approve) async {
    final userId = member.user?.id;
    if (userId == null) return;
    setState(() => busy = true);
    final result = await repository.review(widget.classroomId, userId, approve);
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await load();
      case Failure(message: final message):
        showMessage(message ?? 'Could not process the request');
      case Cancelled():
        break;
    }
  }

  /// Duyệt lần lượt mọi yêu cầu đang chờ rồi tải lại một lần.
  Future<void> approveAll() async {
    setState(() => busy = true);
    var failed = 0;
    for (final member in [...requests]) {
      final userId = member.user?.id;
      if (userId == null) continue;
      final result = await repository.review(widget.classroomId, userId, true);
      if (result is! Success) failed++;
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (failed > 0) showMessage('Could not approve $failed request(s)');
    await load();
  }

  Future<void> remove(ClassroomMember member) async {
    final userId = member.user?.id;
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text(member.user?.name ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    final result = await repository.remove(widget.classroomId, userId);
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await load();
      case Failure(message: final message):
        showMessage(message ?? 'Could not remove the student');
      case Cancelled():
        break;
    }
  }

  void showMessage(String text, {ToastType type = ToastType.error}) =>
      context.showToast(text, type: type);

  @override
  Widget build(BuildContext context) {
    context.watch<AppCubit>();
    final item = classroom;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: ClassroomTopBar(onBack: () => context.go('/classrooms')),
      body: loading
          ? const AppLoader()
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  TextButton(onPressed: load, child: const Text('Retry')),
                ],
              ),
            )
          : item == null
          ? const Center(child: Text('Classroom not found'))
          : Column(
              children: [
                if (busy) const LinearProgressIndicator(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: load,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: onPageScroll,
                      child: ListView(
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1128),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ClassroomBanner(
                                      classroom: item,
                                      canManage: isTeacher && item.active,
                                      busy: busy,
                                      onEdit: edit,
                                      onArchive: archive,
                                    ),
                                    ClassroomTabs(selected: tab, onSelected: selectTab),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1128),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: switch (tab) {
                                  0 => ClassroomPostsView(
                                    classroomId: widget.classroomId,
                                    isTeacher: isTeacher,
                                    active: item.active,
                                    classroomName: item.name,
                                    postId: initialPostId,
                                    commentId: widget.commentId,
                                    aside: ClassroomStreamAside(
                                      classroom: item,
                                      assignments: assignments,
                                      onOpenAssignment: openAssignment,
                                      onViewAll: () => selectTab(1),
                                    ),
                                  ),
                                  1
                                      when widget.classwork.view == ClassworkView.review &&
                                          widget.classwork.attemptId != null =>
                                    AssignmentReviewView(
                                      key: ValueKey(('review', widget.classwork.attemptId)),
                                      attemptId: widget.classwork.attemptId!,
                                      title: assignments
                                          .where((a) => a.id == widget.classwork.assignmentId)
                                          .firstOrNull
                                          ?.title,
                                      onBack: goClasswork,
                                    ),
                                  1 when widget.classwork.view == ClassworkView.gradebook =>
                                    ClassroomGradebookScreen(
                                      key: ValueKey(('gradebook', widget.classwork.assignmentId)),
                                      classroomId: widget.classroomId,
                                      assignmentId: widget.classwork.assignmentId!,
                                      onBack: () => goClasswork(widget.classwork.backTo),
                                    ),
                                  1 when widget.classwork.view == ClassworkView.classGradebook =>
                                    ClassGradebookScreen(
                                      classroomId: widget.classroomId,
                                      classroom: item,
                                      onBack: goClasswork,
                                      onOpenAssignment: (id) => goClasswork(
                                        classroomGradebookPath(
                                          widget.classroomId,
                                          id,
                                          backTo: classGradebookPath(widget.classroomId),
                                        ),
                                      ),
                                    ),
                                  1 when widget.classwork.view == ClassworkView.student =>
                                    StudentProgressScreen(
                                      key: ValueKey(('student', widget.classwork.studentId)),
                                      classroomId: widget.classroomId,
                                      studentId: widget.classwork.studentId!,
                                      onBack: () =>
                                          goClasswork(classGradebookPath(widget.classroomId)),
                                      onOpenAssignment: (id) => goClasswork(
                                        classroomGradebookPath(
                                          widget.classroomId,
                                          id,
                                          backTo: studentProgressPath(
                                            widget.classroomId,
                                            widget.classwork.studentId!,
                                          ),
                                        ),
                                      ),
                                    ),
                                  1 when widget.classwork.view == ClassworkView.edit =>
                                    editing == null
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 48),
                                            child: AppLoader(),
                                          )
                                        : CreateAssignmentView(
                                            key: ValueKey(('edit', editing!.assignment.id)),
                                            currentClassroomId: widget.classroomId,
                                            editing: editing!.editable,
                                            assignment: editing!.assignment,
                                            classrooms: editing!.classrooms,
                                            audits: editing!.audits,
                                            onBack: goClasswork,
                                            onSubmit: saveAssignmentContent,
                                          ),
                                  1 when widget.classwork.view == ClassworkView.create =>
                                    creatingFor == null
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 48),
                                            child: AppLoader(),
                                          )
                                        : CreateAssignmentView(
                                            classrooms: creatingFor!,
                                            currentClassroomId: widget.classroomId,
                                            onBack: goClasswork,
                                            onSubmit: submitAssignment,
                                          ),
                                  1 => ClassroomAssignmentsView(
                                    assignments: assignments,
                                    loading: assignmentsLoading,
                                    loadingMore: assignmentsLoadingMore,
                                    error: assignmentsError,
                                    loadMoreError: assignmentsLoadMoreError,
                                    hasMore: assignmentsPage < assignmentPageCounts,
                                    isTeacher: isTeacher,
                                    classroomActive: item.active,
                                    studentCount: item.countApprovedMembers ?? item.members.length,
                                    onReload: loadAssignments,
                                    onLoadMore: loadMoreAssignments,
                                    onCreate: createAssignment,
                                    onOpen: openAssignment,
                                    onGradebook: openGradebook,
                                    onClassGradebook: () =>
                                        goClasswork(classGradebookPath(widget.classroomId)),
                                    onEditContent: editAssignmentContent,
                                    onSetActive: setAssignmentActive,
                                  ),
                                  2 => ClassroomCalendarView(
                                    repository: repository,
                                    classroomId: widget.classroomId,
                                    isTeacher: isTeacher,
                                    classroomActive: item.active,
                                    onOpenAssignment: openAssignmentById,
                                  ),
                                  _ => ClassroomPeopleView(
                                    members: item.members,
                                    requests: requests,
                                    canManage: isTeacher && item.active,
                                    busy: busy,
                                    onRemove: remove,
                                    onReview: review,
                                    onApproveAll: approveAll,
                                  ),
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
