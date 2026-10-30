import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/data_sources/gradebook_socket_client.dart';
import 'package:eflutter/data/models/attempt_integrity.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/classrooms/integrity_log_dialog.dart';
import 'package:eflutter/presentation/classrooms/integrity_violation_panel.dart';
import 'package:eflutter/presentation/classrooms/gradebook_widgets.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

part 'classroom_gradebook_integrity.dart';

class ClassroomGradebookScreen extends StatefulWidget {
  const ClassroomGradebookScreen({
    super.key,
    required this.classroomId,
    required this.assignmentId,
    this.repository,
    this.socket,
    this.onBack,
  });

  final int classroomId;
  final int assignmentId;

  /// Mở trong tab Classwork: Back quay về danh sách bài. Null thì quay về trang lớp.
  final VoidCallback? onBack;
  final ClassroomRepository? repository;
  final GradebookSocketGateway? socket;

  @override
  State<ClassroomGradebookScreen> createState() => _ClassroomGradebookScreenState();
}

class _ClassroomGradebookScreenState extends State<ClassroomGradebookScreen>
    with _GradebookIntegrity {
  @override
  late final ClassroomRepository repository;
  late final GradebookSocketGateway socket;
  StreamSubscription<GradebookSocketEvent>? eventSubscription;
  StreamSubscription<GradebookSocketStatus>? statusSubscription;
  Timer? refreshDebounce;
  @override
  ClassroomAssignment? assignment;
  AssignmentAnalytics? analytics;
  String? error;
  bool loading = true;
  GradebookSocketStatus socketStatus = GradebookSocketStatus.disconnected;

  @override
  void initState() {
    super.initState();
    repository = widget.repository ?? ClassroomRepository(getIt<Dio>());
    socket = widget.socket ?? GradebookSocketClient(getIt<LocalDataBase>());
    eventSubscription = socket.events.listen(handleSocketEvent);
    statusSubscription = socket.statuses.listen((status) {
      if (mounted) setState(() => socketStatus = status);
      // Nối lại: có thể đã lỡ push, tải lại cả vi phạm chờ xử lý.
      if (status == GradebookSocketStatus.connected && assignment != null) {
        load(showLoading: false);
      }
    });
    load();
    socket.connect().catchError((_) {});
  }

  void handleSocketEvent(GradebookSocketEvent event) {
    if (event.classroomId != widget.classroomId || event.assignmentId != widget.assignmentId) {
      return;
    }
    if (event.integrity case final update?) applyIntegrityUpdate(update);
    refreshDebounce?.cancel();
    refreshDebounce = Timer(const Duration(milliseconds: 250), () => load(showLoading: false));
  }

  @override
  Future<void> load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    final result = await repository.getGradebook(widget.classroomId, widget.assignmentId);
    final analyticsResult = await repository.getAssignmentAnalytics(
      widget.classroomId,
      widget.assignmentId,
    );
    if (!mounted) return;
    switch (result) {
      case Success(data: final value):
        setState(() {
          assignment = value;
          if (analyticsResult case Success(data: final value)) {
            analytics = value;
          }
          loading = false;
        });
        await loadPendingViolations();
      case Failure(message: final message):
        setState(() {
          error = message ?? 'Could not load the gradebook';
          loading = false;
        });
      case Cancelled():
        setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    refreshDebounce?.cancel();
    eventSubscription?.cancel();
    statusSubscription?.cancel();
    socket.close();
    super.dispose();
  }

  Future<void> resetAttempt(AssignmentSubmission submission) async {
    final student = submission.student;
    if (student == null || submission.attemptId == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset attempt?'),
        content: Text(
          '${student.name} will be able to start this assignment again. '
          'The current answers, score, and history will be removed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset attempt'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await repository.resetAssignmentAttempt(
      classroomId: widget.classroomId,
      assignmentId: widget.assignmentId,
      studentId: student.id,
    );
    if (!mounted) return;
    switch (result) {
      case Success():
        await load();
      case Failure(message: final message):
        context.showToast(message ?? 'Could not reset the attempt', type: ToastType.error);
      case Cancelled():
        break;
    }
  }

  Future<void> reconcile() async {
    final result = await repository.reconcileGradebook(
      classroomId: widget.classroomId,
      assignmentId: widget.assignmentId,
    );
    if (!mounted) return;
    switch (result) {
      case Success(data: final count):
        context.showToast('$count submission updates queued', type: ToastType.success);
        await Future<void>.delayed(const Duration(seconds: 2));
        await load();
      case Failure(message: final message):
        context.showToast(message ?? 'Could not reconcile gradebook', type: ToastType.error);
      case Cancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = socketStatus == GradebookSocketStatus.connected;
    final header = GbHeader(
      onBack: widget.onBack ?? () => context.go(classroomPath(widget.classroomId)),
      actions: [
        Tooltip(
          message: switch (socketStatus) {
            GradebookSocketStatus.connected => 'Live updates connected',
            GradebookSocketStatus.connecting => 'Connecting live updates',
            GradebookSocketStatus.disconnected => 'Live updates disconnected',
          },
          child: Row(
            spacing: 6,
            children: [
              Icon(Icons.circle, size: 8, color: live ? Gb.green : Gb.faint),
              Text(
                live ? 'Live' : 'Offline',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: live ? Gb.green : Gb.faint,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sync grades',
          onPressed: reconcile,
          style: IconButton.styleFrom(
            backgroundColor: AppButtonStyles.tint,
            foregroundColor: ColorName.primary,
          ),
          icon: const Icon(Icons.sync, size: 20),
        ),
      ],
    );
    final body = loading
        ? const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: AppLoader())
        : error != null
        ? GbError(message: error!, onRetry: load)
        : assignment == null
        ? const GbError(message: 'Assignment not found', onRetry: _noop)
        : GradebookView(
            assignment: assignment!,
            analytics: analytics,
            onResetAttempt: resetAttempt,
            integrityPanel: pendingViolations.isEmpty ? null : integrityPanel(),
            awayStudents: awayStudents,
            onOpenIntegrity: openIntegrityLog,
            scrollable: false,
          );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [header, body],
    );
    if (widget.onBack != null) {
      return Padding(padding: const EdgeInsets.only(top: 12, bottom: 32), child: content);
    }
    // Mở trực tiếp qua URL: tự cuộn, căn giữa như trang lớp.
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

void _noop() {}

enum GradebookSort { name, status, score }

class GradebookView extends StatefulWidget {
  const GradebookView({
    super.key,
    required this.assignment,
    this.analytics,
    this.onRefresh,
    this.onResetAttempt,
    this.integrityPanel,
    this.awayStudents = const {},
    this.onOpenIntegrity,
    this.scrollable = true,
  });

  final ClassroomAssignment assignment;
  final AssignmentAnalytics? analytics;
  final Future<void> Function()? onRefresh;
  final ValueChanged<AssignmentSubmission>? onResetAttempt;

  /// Giám sát: panel vi phạm chờ xử lý, học sinh đang rời màn, mở log.
  final Widget? integrityPanel;
  final Set<String> awayStudents;
  final ValueChanged<AssignmentSubmission>? onOpenIntegrity;

  /// false khi nằm trong một danh sách cuộn khác (tab Classwork).
  final bool scrollable;

  @override
  State<GradebookView> createState() => _GradebookViewState();
}

class _GradebookViewState extends State<GradebookView> {
  String query = '';
  String status = 'ALL';
  GradebookSort sort = GradebookSort.name;

  List<AssignmentSubmission> get visibleSubmissions {
    final normalizedQuery = query.trim().toLowerCase();
    final items = widget.assignment.submissions.where((submission) {
      final matchesStatus = status == 'ALL' || submission.status == status;
      final student = submission.student;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          (student?.name.toLowerCase().contains(normalizedQuery) ?? false) ||
          (student?.email.toLowerCase().contains(normalizedQuery) ?? false);
      return matchesStatus && matchesQuery;
    }).toList();

    items.sort((left, right) {
      switch (sort) {
        case GradebookSort.name:
          return (left.student?.name ?? '').toLowerCase().compareTo(
            (right.student?.name ?? '').toLowerCase(),
          );
        case GradebookSort.status:
          return left.status.compareTo(right.status);
        case GradebookSort.score:
          return (right.score ?? -1).compareTo(left.score ?? -1);
      }
    });
    return items;
  }

  Widget _summary() {
    final assignment = widget.assignment;
    final submissions = assignment.submissions;
    final submitted = submissions.where((item) => item.status == 'SUBMITTED').length;
    final late = submissions.where((item) => item.status == 'LATE').length;
    final inProgress = submissions.where((item) => item.status == 'IN_PROGRESS').length;
    final notStarted = submissions.where((item) => item.status == 'NOT_STARTED').length;
    final scores = submissions.map((item) => item.score).whereType<double>().toList();
    final analytics = widget.analytics;
    final average =
        analytics?.averageScore ??
        (scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length);
    final minimum =
        analytics?.minimumScore ?? (scores.isEmpty ? null : scores.reduce((a, b) => a < b ? a : b));
    final maximum =
        analytics?.maximumScore ?? (scores.isEmpty ? null : scores.reduce((a, b) => a > b ? a : b));
    final done = submitted + late;
    final rate = submissions.isEmpty ? 0.0 : done / submissions.length;
    final now = DateTime.now();
    final (label, background, foreground) = !assignment.active
        ? ('Paused', Gb.field, Gb.muted)
        : now.isBefore(assignment.opensAt)
        ? ('Upcoming', AppButtonStyles.tint, ColorName.primary)
        : now.isAfter(assignment.dueAt)
        ? ('Closed', Gb.field, Gb.muted)
        : ('Open', Gb.greenBg, Gb.green);
    final format = DateFormat('MMM d, HH:mm');
    final meta = [
      '${now.isBefore(assignment.opensAt) ? 'Opens' : 'Opened'} '
          '${format.format(assignment.opensAt)}',
      'Due ${format.format(assignment.dueAt)}',
      '${assignment.duration} min',
      if (assignment.proctored) 'Proctored · ${assignment.maxViolations} violations',
    ].join(' · ');
    return GbCard(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              assignment.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            GbPill(label, background: background, foreground: foreground),
          ],
        ),
        const SizedBox(height: 6),
        Text(meta, style: const TextStyle(fontSize: 13, color: Gb.muted)),
        const SizedBox(height: 16),
        GbStats(
          children: [
            GbStat(label: 'Students', value: '${submissions.length}'),
            GbStat(
              label: 'Submitted',
              value: '$done',
              sub: late > 0 ? 'incl. $late late' : null,
              color: Gb.green,
            ),
            GbStat(label: 'In progress', value: '$inProgress', color: ColorName.primary),
            GbStat(label: 'Not started', value: '$notStarted'),
            GbStat(
              label: 'Average',
              value: average == null ? '—' : average.toStringAsFixed(1),
              sub: minimum == null || maximum == null
                  ? null
                  : 'min ${minimum.toStringAsFixed(1)} · max ${maximum.toStringAsFixed(1)}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${(rate * 100).round()}% submitted',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Gb.muted),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: rate,
            minHeight: 8,
            backgroundColor: Gb.field,
            color: ColorName.primary,
          ),
        ),
      ],
    );
  }

  Widget _toolbar(bool compact) {
    Widget option(String value, String label) {
      final selected = status == value;
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => status = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? ColorName.primary : Gb.muted,
            ),
          ),
        ),
      );
    }

    final sortLabel = switch (sort) {
      GradebookSort.name => 'Name',
      GradebookSort.status => 'Status',
      GradebookSort.score => 'Score',
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GbSearchField(
            width: compact ? double.infinity : 200,
            onChanged: (value) => setState(() => query = value),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Gb.field, borderRadius: BorderRadius.circular(8)),
            child: Wrap(
              spacing: 2,
              children: [
                option('ALL', 'All'),
                option('NOT_STARTED', 'Not started'),
                option('IN_PROGRESS', 'In progress'),
                option('SUBMITTED', 'Submitted'),
                option('LATE', 'Late'),
              ],
            ),
          ),
          PopupMenuButton<GradebookSort>(
            tooltip: 'Sort gradebook',
            onSelected: (value) => setState(() => sort = value),
            position: PopupMenuPosition.under,
            offset: const Offset(0, 6),
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 6,
            shadowColor: Colors.black26,
            menuPadding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 180),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Gb.border),
            ),
            itemBuilder: (context) => [
              for (final (value, label, icon) in const [
                (GradebookSort.name, 'Name', Icons.sort_by_alpha),
                (GradebookSort.status, 'Status', Icons.flag_outlined),
                (GradebookSort.score, 'Score', Icons.leaderboard_outlined),
              ])
                PopupMenuItem(
                  value: value,
                  height: 38,
                  padding: EdgeInsets.zero,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: sort == value ? AppButtonStyles.tint : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      spacing: 10,
                      children: [
                        Icon(icon, size: 16, color: sort == value ? ColorName.primary : Gb.muted),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: sort == value ? FontWeight.w600 : FontWeight.w500,
                              color: sort == value ? ColorName.primary : Gb.text,
                            ),
                          ),
                        ),
                        if (sort == value)
                          const Icon(Icons.check, size: 16, color: ColorName.primary),
                      ],
                    ),
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Gb.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Text(
                    'Sort: $sortLabel',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const Icon(Icons.expand_more, size: 16, color: Gb.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _students(bool compact) {
    final visible = visibleSubmissions;
    final proctored = widget.assignment.proctored || visible.any((item) => item.proctored);
    Widget integrity(AssignmentSubmission submission) => IntegrityStatusCell(
      submission: submission,
      maxViolations: widget.assignment.maxViolations,
      away: widget.awayStudents.contains(submission.student?.id),
      onTap: widget.onOpenIntegrity == null || submission.attemptId == 0
          ? null
          : () => widget.onOpenIntegrity!(submission),
    );
    return GbCard(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _toolbar(compact),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('No matching students', style: TextStyle(color: Gb.muted)),
            ),
          )
        else if (compact)
          for (final submission in visible)
            _GradebookCompactRow(
              submission: submission,
              integrity: proctored ? integrity(submission) : null,
              onResetAttempt: widget.onResetAttempt,
            )
        else ...[
          _GradebookRow.header(proctored: proctored),
          for (final submission in visible)
            _GradebookRow(
              submission: submission,
              integrity: proctored ? integrity(submission) : null,
              onResetAttempt: widget.onResetAttempt,
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            'Showing ${visible.length} of ${widget.assignment.submissions.length} students',
            style: const TextStyle(fontSize: 12, color: Gb.faint),
          ),
        ),
      ],
    );
  }

  Widget? _hardest() {
    final questions = [...?widget.analytics?.questions.where((item) => item.answeredCount > 0)]
      ..sort((a, b) => b.wrongRate.compareTo(a.wrongRate));
    if (questions.isEmpty) return null;
    return GbCard(
      children: [
        const GbCardHead('Hardest questions', 'Highest wrong rate among submissions'),
        for (final question in questions.take(5)) ...[
          const SizedBox(height: 12),
          Row(
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppButtonStyles.tint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Q${question.order}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ColorName.primary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  question.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                '${question.wrongRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: question.wrongRate >= 50 ? Gb.red : Gb.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (question.wrongRate / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: Gb.field,
              color: question.wrongRate >= 50 ? const Color(0xFFF28B82) : ColorName.primary,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final aside = [?_hardest(), ?widget.integrityPanel];
        final students = _students(constraints.maxWidth < 700);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 20,
          children: [
            _summary(),
            if (wide && aside.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  Expanded(child: students),
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: aside,
                    ),
                  ),
                ],
              )
            else ...[
              ...aside,
              students,
            ],
          ],
        );
      },
    );
    if (!widget.scrollable) return content;
    final list = ListView(padding: const EdgeInsets.all(20), children: [content]);
    if (widget.onRefresh == null) return list;
    return RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
  }
}

class _GradebookRow extends StatelessWidget {
  const _GradebookRow({required this.submission, this.integrity, this.onResetAttempt})
    : proctored = integrity != null,
      isHeader = false;
  const _GradebookRow.header({required this.proctored})
    : submission = null,
      integrity = null,
      onResetAttempt = null,
      isHeader = true;

  final AssignmentSubmission? submission;
  final Widget? integrity;
  final ValueChanged<AssignmentSubmission>? onResetAttempt;
  final bool proctored;
  final bool isHeader;

  static const _head = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Gb.muted);

  @override
  Widget build(BuildContext context) {
    final item = submission;
    final student = item?.student;
    final canReset = item != null && item.attemptId > 0 && onResetAttempt != null;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isHeader ? 10 : 12),
      decoration: BoxDecoration(
        color: isHeader ? Gb.soft : Colors.white,
        border: const Border(bottom: BorderSide(color: Gb.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: isHeader
                ? const Text('STUDENT', style: _head)
                : Row(
                    spacing: 10,
                    children: [
                      GbAvatar(name: student?.name ?? '', url: student?.avatar),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              student?.name ?? 'Unavailable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              student?.email ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Gb.faint),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(
            width: 120,
            child: isHeader
                ? const Text('STATUS', style: _head)
                : Align(alignment: Alignment.centerLeft, child: GbPill.status(item!.status)),
          ),
          if (proctored)
            SizedBox(
              width: 140,
              child: isHeader ? const Text('VIOLATIONS', style: _head) : integrity,
            ),
          SizedBox(
            width: 80,
            child: isHeader
                ? const Text('SCORE', style: _head)
                : Text(
                    item!.score == null ? '—' : '${Gb.scoreText(item.score)}/10',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Gb.score(item.score),
                    ),
                  ),
          ),
          SizedBox(
            width: 40,
            child: isHeader
                ? null
                : IconButton(
                    tooltip: 'Reset attempt',
                    visualDensity: VisualDensity.compact,
                    onPressed: canReset ? () => onResetAttempt!(item) : null,
                    icon: const Icon(Icons.restart_alt, size: 18),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GradebookCompactRow extends StatelessWidget {
  const _GradebookCompactRow({required this.submission, this.integrity, this.onResetAttempt});
  final AssignmentSubmission submission;
  final Widget? integrity;
  final ValueChanged<AssignmentSubmission>? onResetAttempt;

  @override
  Widget build(BuildContext context) {
    final student = submission.student;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Gb.border)),
      ),
      child: Row(
        spacing: 10,
        children: [
          GbAvatar(name: student?.name ?? '', url: student?.avatar),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  student?.name ?? 'Unavailable',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(student?.email ?? '', style: const TextStyle(fontSize: 12, color: Gb.faint)),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [GbPill.status(submission.status), ?integrity],
                ),
              ],
            ),
          ),
          Text(
            submission.score == null ? '—' : '${Gb.scoreText(submission.score)}/10',
            style: TextStyle(fontWeight: FontWeight.w600, color: Gb.score(submission.score)),
          ),
          IconButton(
            tooltip: 'Reset attempt',
            onPressed: submission.attemptId > 0 && onResetAttempt != null
                ? () => onResetAttempt!(submission)
                : null,
            icon: const Icon(Icons.restart_alt, size: 18),
          ),
        ],
      ),
    );
  }
}
