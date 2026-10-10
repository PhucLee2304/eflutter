import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/data_sources/gradebook_socket_client.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ClassroomGradebookScreen extends StatefulWidget {
  const ClassroomGradebookScreen({
    super.key,
    required this.classroomId,
    required this.assignmentId,
    this.repository,
    this.socket,
  });

  final int classroomId;
  final int assignmentId;
  final ClassroomRepository? repository;
  final GradebookSocketGateway? socket;

  @override
  State<ClassroomGradebookScreen> createState() =>
      _ClassroomGradebookScreenState();
}

class _ClassroomGradebookScreenState extends State<ClassroomGradebookScreen> {
  late final ClassroomRepository repository;
  late final GradebookSocketGateway socket;
  StreamSubscription<GradebookSocketEvent>? eventSubscription;
  StreamSubscription<GradebookSocketStatus>? statusSubscription;
  Timer? refreshDebounce;
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
    });
    load();
    socket.connect().catchError((_) {});
  }

  void handleSocketEvent(GradebookSocketEvent event) {
    if (event.classroomId != widget.classroomId ||
        event.assignmentId != widget.assignmentId) {
      return;
    }
    refreshDebounce?.cancel();
    refreshDebounce = Timer(
      const Duration(milliseconds: 250),
      () => load(showLoading: false),
    );
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    final result = await repository.getGradebook(
      widget.classroomId,
      widget.assignmentId,
    );
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? 'Could not reset the attempt')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count submission updates queued')),
        );
        await Future<void>.delayed(const Duration(seconds: 2));
        await load();
      case Failure(message: final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? 'Could not reconcile gradebook')),
        );
      case Cancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Gradebook'),
      actions: [
        IconButton(
          tooltip: switch (socketStatus) {
            GradebookSocketStatus.connected => 'Live updates connected',
            GradebookSocketStatus.connecting => 'Connecting live updates',
            GradebookSocketStatus.disconnected => 'Live updates disconnected',
          },
          onPressed: null,
          icon: Icon(
            socketStatus == GradebookSocketStatus.connected
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
          ),
        ),
        IconButton(
          tooltip: 'Retry grade sync',
          onPressed: reconcile,
          icon: const Icon(Icons.sync),
        ),
      ],
      leading: IconButton(
        tooltip: 'Back to classroom',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go(classroomPath(widget.classroomId)),
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
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
        : assignment == null
        ? const Center(child: Text('Assignment not found'))
        : GradebookView(
            assignment: assignment!,
            analytics: analytics,
            onRefresh: load,
            onResetAttempt: resetAttempt,
          ),
  );
}

enum GradebookSort { name, status, score }

class GradebookView extends StatefulWidget {
  const GradebookView({
    super.key,
    required this.assignment,
    this.analytics,
    this.onRefresh,
    this.onResetAttempt,
  });

  final ClassroomAssignment assignment;
  final AssignmentAnalytics? analytics;
  final Future<void> Function()? onRefresh;
  final ValueChanged<AssignmentSubmission>? onResetAttempt;

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

  @override
  Widget build(BuildContext context) {
    final submissions = widget.assignment.submissions;
    final submitted = submissions
        .where((item) => item.status == 'SUBMITTED')
        .length;
    final inProgress = submissions
        .where((item) => item.status == 'IN_PROGRESS')
        .length;
    final notStarted = submissions
        .where((item) => item.status == 'NOT_STARTED')
        .length;
    final late = submissions.where((item) => item.status == 'LATE').length;
    final scores = submissions
        .where((item) => item.score != null)
        .map((item) => item.score!)
        .toList();
    final average = scores.isEmpty
        ? null
        : scores.reduce((left, right) => left + right) / scores.length;
    final visible = visibleSubmissions;

    final content = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.assignment.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Due ${DateFormat('MMM d, yyyy • HH:mm').format(widget.assignment.dueAt)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _Metric(label: 'Students', value: '${submissions.length}'),
                    _Metric(label: 'Not started', value: '$notStarted'),
                    _Metric(label: 'In progress', value: '$inProgress'),
                    _Metric(label: 'Submitted', value: '$submitted'),
                    _Metric(label: 'Late', value: '$late'),
                    _Metric(
                      label: 'Average',
                      value: average == null
                          ? '—'
                          : '${average.toStringAsFixed(2)}/10',
                    ),
                    if (widget.analytics != null) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Average: ${widget.analytics!.averageScore?.toStringAsFixed(2) ?? '-'}',
                          ),
                          Text(
                            'Minimum: ${widget.analytics!.minimumScore?.toStringAsFixed(2) ?? '-'}',
                          ),
                          Text(
                            'Maximum: ${widget.analytics!.maximumScore?.toStringAsFixed(2) ?? '-'}',
                          ),
                          Text(
                            'Completion: ${widget.analytics!.completionRate.toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                      if (widget.analytics!.questions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Questions with the highest wrong rate',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        ...([...widget.analytics!.questions]..sort(
                              (a, b) => b.wrongRate.compareTo(a.wrongRate),
                            ))
                            .take(5)
                            .map(
                              (question) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${question.order}. ${question.content}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  '${question.wrongRate.toStringAsFixed(1)}%',
                                ),
                              ),
                            ),
                      ],
                    ],
                  ],
                ),
                const Divider(height: 32),
                _GradebookToolbar(
                  status: status,
                  sort: sort,
                  onQueryChanged: (value) => setState(() => query = value),
                  onStatusChanged: (value) => setState(() => status = value),
                  onSortChanged: (value) => setState(() => sort = value),
                ),
                const SizedBox(height: 16),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No matching students')),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 700
                        ? _GradebookList(
                            submissions: visible,
                            onResetAttempt: widget.onResetAttempt,
                          )
                        : _GradebookTable(
                            submissions: visible,
                            onResetAttempt: widget.onResetAttempt,
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    if (widget.onRefresh == null) return content;
    return RefreshIndicator(onRefresh: widget.onRefresh!, child: content);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _GradebookToolbar extends StatelessWidget {
  const _GradebookToolbar({
    required this.status,
    required this.sort,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
  });

  final String status;
  final GradebookSort sort;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<GradebookSort> onSortChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 280,
        child: TextField(
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Search students',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      DropdownButton<String>(
        value: status,
        onChanged: (value) {
          if (value != null) onStatusChanged(value);
        },
        items: const [
          DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
          DropdownMenuItem(value: 'NOT_STARTED', child: Text('Not started')),
          DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In progress')),
          DropdownMenuItem(value: 'SUBMITTED', child: Text('Submitted')),
          DropdownMenuItem(value: 'LATE', child: Text('Late')),
        ],
      ),
      PopupMenuButton<GradebookSort>(
        tooltip: 'Sort gradebook',
        initialValue: sort,
        onSelected: onSortChanged,
        itemBuilder: (context) => const [
          PopupMenuItem(value: GradebookSort.name, child: Text('Sort by name')),
          PopupMenuItem(
            value: GradebookSort.status,
            child: Text('Sort by status'),
          ),
          PopupMenuItem(
            value: GradebookSort.score,
            child: Text('Sort by score'),
          ),
        ],
        icon: const Icon(Icons.sort),
      ),
    ],
  );
}

class _GradebookTable extends StatelessWidget {
  const _GradebookTable({required this.submissions, this.onResetAttempt});
  final List<AssignmentSubmission> submissions;
  final ValueChanged<AssignmentSubmission>? onResetAttempt;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: const [
        DataColumn(label: Text('Student')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Score'), numeric: true),
        DataColumn(label: Text('Sync')),
        DataColumn(label: Text('Actions')),
      ],
      rows: submissions
          .map(
            (submission) => DataRow(
              cells: [
                DataCell(Text(submission.student?.name ?? 'Unavailable')),
                DataCell(Text(submission.student?.email ?? '')),
                DataCell(Text(_statusLabel(submission.status))),
                DataCell(Text(_scoreLabel(submission.score))),
                DataCell(Text(_statusLabel(submission.syncStatus))),
                DataCell(
                  IconButton(
                    tooltip: 'Reset attempt',
                    onPressed:
                        submission.attemptId > 0 && onResetAttempt != null
                        ? () => onResetAttempt!(submission)
                        : null,
                    icon: const Icon(Icons.restart_alt),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    ),
  );
}

class _GradebookList extends StatelessWidget {
  const _GradebookList({required this.submissions, this.onResetAttempt});
  final List<AssignmentSubmission> submissions;
  final ValueChanged<AssignmentSubmission>? onResetAttempt;

  @override
  Widget build(BuildContext context) => Column(
    children: submissions
        .map(
          (submission) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(submission.student?.name ?? 'Unavailable'),
            subtitle: Text(
              '${submission.student?.email ?? ''}\n${_statusLabel(submission.status)}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_scoreLabel(submission.score)),
                IconButton(
                  tooltip: 'Reset attempt',
                  onPressed: submission.attemptId > 0 && onResetAttempt != null
                      ? () => onResetAttempt!(submission)
                      : null,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

String _statusLabel(String status) {
  final words = status
      .trim()
      .split('_')
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '-';
  return words
      .map((word) => '${word[0]}${word.substring(1).toLowerCase()}')
      .join(' ');
}

String _scoreLabel(double? score) =>
    score == null ? '—' : '${score.toStringAsFixed(2)}/10';
