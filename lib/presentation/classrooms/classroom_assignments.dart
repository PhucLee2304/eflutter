import 'package:eflutter/data/models/classroom.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateAssignmentInput {
  const CreateAssignmentInput({
    required this.schedules,
    required this.title,
    required this.description,
    required this.questions,
  });

  final List<AssignmentScheduleInput> schedules;
  final String title;
  final String description;
  final List<CreateAssignmentQuestion> questions;
}

class ClassroomAssignmentsView extends StatelessWidget {
  const ClassroomAssignmentsView({
    super.key,
    required this.assignments,
    required this.loading,
    this.loadingMore = false,
    required this.isTeacher,
    required this.classroomActive,
    required this.onReload,
    this.onLoadMore,
    required this.onCreate,
    required this.onOpen,
    required this.onGradebook,
    this.onAssignToClasses,
    this.onEditSchedule,
    this.onEditContent,
    required this.onSetActive,
    this.error,
    this.loadMoreError,
    this.hasMore = false,
  });

  final List<ClassroomAssignment> assignments;
  final bool loading;
  final bool loadingMore;
  final bool isTeacher;
  final bool classroomActive;
  final String? error;
  final String? loadMoreError;
  final bool hasMore;
  final VoidCallback onReload;
  final VoidCallback? onLoadMore;
  final VoidCallback onCreate;
  final ValueChanged<ClassroomAssignment> onOpen;
  final ValueChanged<ClassroomAssignment> onGradebook;
  final ValueChanged<ClassroomAssignment>? onAssignToClasses;
  final ValueChanged<ClassroomAssignment>? onEditSchedule;
  final ValueChanged<ClassroomAssignment>? onEditContent;
  final void Function(ClassroomAssignment assignment, bool active) onSetActive;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!),
            TextButton(onPressed: onReload, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isTeacher && classroomActive)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create assignment'),
            ),
          ),
        if (isTeacher && classroomActive) const SizedBox(height: 16),
        if (assignments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No assignments yet')),
          )
        else
          ...assignments.map(
            (assignment) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AssignmentTile(
                assignment: assignment,
                isTeacher: isTeacher,
                classroomActive: classroomActive,
                onOpen: () => onOpen(assignment),
                onGradebook: () => onGradebook(assignment),
                onAssignToClasses: onAssignToClasses == null
                    ? null
                    : () => onAssignToClasses!(assignment),
                onEditSchedule: onEditSchedule == null
                    ? null
                    : () => onEditSchedule!(assignment),
                onEditContent: onEditContent == null
                    ? null
                    : () => onEditContent!(assignment),
                onSetActive: (active) => onSetActive(assignment, active),
              ),
            ),
          ),
        if (loadingMore)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (loadMoreError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: TextButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry loading more'),
              ),
            ),
          )
        else if (hasMore)
          const SizedBox(height: 24),
      ],
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.isTeacher,
    required this.classroomActive,
    required this.onOpen,
    required this.onGradebook,
    this.onAssignToClasses,
    this.onEditSchedule,
    this.onEditContent,
    required this.onSetActive,
  });

  final ClassroomAssignment assignment;
  final bool isTeacher;
  final bool classroomActive;
  final VoidCallback onOpen;
  final VoidCallback onGradebook;
  final VoidCallback? onAssignToClasses;
  final VoidCallback? onEditSchedule;
  final VoidCallback? onEditContent;
  final ValueChanged<bool> onSetActive;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hasOpened = !now.isBefore(assignment.opensAt);
    final hasEnded = now.isAfter(assignment.dueAt);
    final submission = assignment.submission;
    final hasAttempt = submission != null && submission.attemptId > 0;
    final hasResult =
        hasAttempt &&
        (submission.status == 'SUBMITTED' || submission.status == 'LATE');
    final canOpen =
        isTeacher ||
        hasResult ||
        (classroomActive &&
            assignment.active &&
            (hasAttempt || (hasOpened && !hasEnded)));
    final actionLabel = switch (submission?.status) {
      'IN_PROGRESS' => 'Continue',
      'SUBMITTED' || 'LATE' when hasAttempt => 'View result',
      _ when !assignment.active => 'Paused',
      _ when !hasOpened => 'Not open yet',
      _ when hasEnded => 'Closed',
      _ => 'Start',
    };

    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.assignment_outlined),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assignment.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (assignment.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(assignment.description!),
              ],
              const SizedBox(height: 10),
              Text(
                'Opens ${_formatDateTime(assignment.opensAt)} | '
                'Due ${_formatDateTime(assignment.dueAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Time limit: ${assignment.duration} minutes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!isTeacher && submission?.score != null) ...[
                const SizedBox(height: 4),
                Text('Score: ${submission!.score!.toStringAsFixed(2)}/10'),
              ],
            ],
          ),
        ),
      ],
    );
    final action = isTeacher
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: assignment.active,
                onChanged: classroomActive ? onSetActive : null,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onEditContent,
                tooltip: 'Edit assignment',
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onEditSchedule,
                tooltip: 'Edit schedule',
                icon: const Icon(Icons.schedule_outlined),
              ),
              IconButton(
                onPressed: onAssignToClasses,
                tooltip: 'Assign to more classes',
                icon: const Icon(Icons.add_home_work_outlined),
              ),
              OutlinedButton.icon(
                onPressed: onGradebook,
                icon: const Icon(Icons.grading_outlined),
                label: const Text('Gradebook'),
              ),
            ],
          )
        : FilledButton(
            onPressed: canOpen ? onOpen : null,
            child: Text(actionLabel),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<AssignmentScheduleInput?> showAssignmentScheduleDialog(
  BuildContext context, {
  required int classroomId,
  required int duration,
  required DateTime opensAt,
  required DateTime dueAt,
  String title = 'Edit schedule',
}) async {
  var selectedDuration = duration;
  var selectedOpensAt = opensAt;
  var selectedDueAt = dueAt;
  final formKey = GlobalKey<FormState>();

  return showDialog<AssignmentScheduleInput>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<DateTime?> pick(DateTime initial) async {
          final date = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime.now().subtract(const Duration(days: 3650)),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (date == null || !context.mounted) return null;
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(initial),
          );
          if (time == null) return null;
          return DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        }

        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: '$duration',
                  decoration: const InputDecoration(
                    labelText: 'Time limit (minutes)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      selectedDuration = int.tryParse(value) ?? 0,
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    return parsed == null || parsed < 1 || parsed > 1440
                        ? 'Enter a value from 1 to 1440'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('Opens'),
                  subtitle: Text(_formatDateTime(selectedOpensAt)),
                  onTap: () async {
                    final value = await pick(selectedOpensAt);
                    if (value != null) {
                      setDialogState(() => selectedOpensAt = value);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Due'),
                  subtitle: Text(_formatDateTime(selectedDueAt)),
                  onTap: () async {
                    final value = await pick(selectedDueAt);
                    if (value != null) {
                      setDialogState(() => selectedDueAt = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (!selectedDueAt.isAfter(selectedOpensAt) ||
                    Duration(minutes: selectedDuration) >
                        selectedDueAt.difference(selectedOpensAt)) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  AssignmentScheduleInput(
                    classroomId: classroomId,
                    duration: selectedDuration,
                    opensAt: selectedOpensAt,
                    dueAt: selectedDueAt,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}

Future<CreateAssignmentInput?> showCreateAssignmentDialog(
  BuildContext context, {
  required List<Classroom> classrooms,
  required int currentClassroomId,
}) {
  return Navigator.of(context).push<CreateAssignmentInput>(
    MaterialPageRoute(
      builder: (context) => _CreateAssignmentDialog(
        classrooms: classrooms,
        currentClassroomId: currentClassroomId,
      ),
    ),
  );
}

Future<CreateAssignmentInput?> showEditAssignmentDialog(
  BuildContext context,
  EditableAssignment assignment,
) => showDialog<CreateAssignmentInput>(
  context: context,
  builder: (context) => _EditAssignmentDialog(assignment: assignment),
);

class _EditAssignmentDialog extends StatefulWidget {
  const _EditAssignmentDialog({required this.assignment});
  final EditableAssignment assignment;

  @override
  State<_EditAssignmentDialog> createState() => _EditAssignmentDialogState();
}

class _EditAssignmentDialogState extends State<_EditAssignmentDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController description;
  late final List<_QuestionDraft> questions;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.assignment.title);
    description = TextEditingController(
      text: widget.assignment.description ?? '',
    );
    questions = widget.assignment.questions
        .map(
          (question) => _QuestionDraft(
            content: question.content,
            explanation: question.explanation ?? '',
            optionValues: question.options,
            correctOptionIndex: question.correctOptionIndex,
            excludedFromScore: question.excludedFromScore,
            id: question.id,
            optionIds: question.optionIds,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    for (final question in questions) {
      question.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit assignment'),
    content: SizedBox(
      width: 680,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: title,
                enabled: !widget.assignment.hasAttempts,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: _required,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: description,
                enabled: !widget.assignment.hasAttempts,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: null,
              ),
              const SizedBox(height: 16),
              ...List.generate(
                questions.length,
                (index) => _QuestionEditor(
                  key: ObjectKey(questions[index]),
                  index: index,
                  draft: questions[index],
                  canRemove: questions.length > 1,
                  lockStructure: widget.assignment.hasAttempts,
                  showScoreExclusion: true,
                  onRemove: () => setState(() {
                    final removed = questions.removeAt(index);
                    removed.dispose();
                  }),
                ),
              ),
              if (!widget.assignment.hasAttempts)
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => questions.add(_QuestionDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add question'),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            CreateAssignmentInput(
              schedules: const [],
              title: title.text.trim(),
              description: description.text.trim(),
              questions: questions
                  .map(
                    (question) => CreateAssignmentQuestion(
                      content: question.content.text.trim(),
                      explanation: question.explanation.text.trim(),
                      options: question.options
                          .map((option) => option.text.trim())
                          .toList(),
                      correctOptionIndex: question.correctOptionIndex,
                      excludedFromScore: question.excludedFromScore,
                      id: question.id,
                      optionIds: question.optionIds,
                    ),
                  )
                  .toList(),
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _CreateAssignmentDialog extends StatefulWidget {
  const _CreateAssignmentDialog({
    required this.classrooms,
    required this.currentClassroomId,
  });

  final List<Classroom> classrooms;
  final int currentClassroomId;

  @override
  State<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends State<_CreateAssignmentDialog> {
  final formKey = GlobalKey<FormState>();
  final selectedClassrooms = <int>{};
  final schedules = <int, _ScheduleDraft>{};
  String title = '';
  String description = '';
  int duration = 60;
  final questions = <_QuestionDraft>[];
  late DateTime opensAt;
  late DateTime dueAt;

  @override
  void initState() {
    super.initState();
    selectedClassrooms.add(widget.currentClassroomId);
    opensAt = DateTime.now().add(const Duration(minutes: 10));
    dueAt = DateTime.now().add(const Duration(days: 1));
    schedules[widget.currentClassroomId] = _ScheduleDraft(
      duration: duration,
      opensAt: opensAt,
      dueAt: dueAt,
    );
    questions.add(_QuestionDraft());
  }

  @override
  void dispose() {
    for (final question in questions) {
      question.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create assignment')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Title'),
                    onChanged: (value) => title = value,
                    validator: _required,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description'),
                    onChanged: (value) => description = value,
                    maxLines: null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Questions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => questions.add(_QuestionDraft())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add question'),
                      ),
                    ],
                  ),
                  ...List.generate(
                    questions.length,
                    (index) => _QuestionEditor(
                      key: ObjectKey(questions[index]),
                      index: index,
                      draft: questions[index],
                      canRemove: questions.length > 1,
                      onRemove: () => setState(() {
                        final removed = questions.removeAt(index);
                        removed.dispose();
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Assign to',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ...widget.classrooms.map(
                    (classroom) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selectedClassrooms.contains(classroom.id),
                      title: Text(classroom.name),
                      subtitle: Text(classroom.code),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          selectedClassrooms.add(classroom.id);
                          schedules[classroom.id] = _ScheduleDraft(
                            duration: duration,
                            opensAt: opensAt,
                            dueAt: dueAt,
                          );
                        } else {
                          selectedClassrooms.remove(classroom.id);
                          schedules.remove(classroom.id);
                        }
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.classrooms
                      .where((item) => selectedClassrooms.contains(item.id))
                      .map((classroom) {
                        final schedule = schedules[classroom.id]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    classroom.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  TextFormField(
                                    initialValue: '${schedule.duration}',
                                    decoration: const InputDecoration(
                                      labelText: 'Time limit (minutes)',
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) => schedule.duration =
                                        int.tryParse(value) ?? 0,
                                    validator: (value) {
                                      final minutes = int.tryParse(
                                        value?.trim() ?? '',
                                      );
                                      return minutes == null ||
                                              minutes < 1 ||
                                              minutes > 1440
                                          ? 'Enter a value from 1 to 1440 minutes'
                                          : null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final value = await pickDateTime(
                                            schedule.opensAt,
                                          );
                                          if (value != null) {
                                            setState(
                                              () => schedule.opensAt = value,
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.play_circle_outline,
                                        ),
                                        label: Text(
                                          'Opens ${_formatDateTime(schedule.opensAt)}',
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final value = await pickDateTime(
                                            schedule.dueAt,
                                          );
                                          if (value != null) {
                                            setState(
                                              () => schedule.dueAt = value,
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.event_outlined),
                                        label: Text(
                                          'Due ${_formatDateTime(schedule.dueAt)}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (selectedClassrooms.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Select at least one classroom'),
                    ),
                  );
                  return;
                }
                if (schedules.values.any(
                  (item) => !item.dueAt.isAfter(item.opensAt),
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Due time must be after open time'),
                    ),
                  );
                  return;
                }
                if (schedules.values.any(
                  (item) =>
                      Duration(minutes: item.duration) >
                      item.dueAt.difference(item.opensAt),
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Time limit must not exceed the assignment window',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  CreateAssignmentInput(
                    schedules: schedules.entries
                        .map(
                          (entry) => AssignmentScheduleInput(
                            classroomId: entry.key,
                            duration: entry.value.duration,
                            opensAt: entry.value.opensAt,
                            dueAt: entry.value.dueAt,
                          ),
                        )
                        .toList(),
                    title: title,
                    description: description,
                    questions: questions
                        .map(
                          (question) => CreateAssignmentQuestion(
                            content: question.content.text.trim(),
                            explanation: question.explanation.text.trim(),
                            options: question.options
                                .map((option) => option.text.trim())
                                .toList(),
                            correctOptionIndex: question.correctOptionIndex,
                          ),
                        )
                        .toList(),
                  ),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScheduleDraft {
  _ScheduleDraft({
    required this.duration,
    required this.opensAt,
    required this.dueAt,
  });
  int duration;
  DateTime opensAt;
  DateTime dueAt;
}

class _QuestionDraft {
  _QuestionDraft({
    String content = '',
    String explanation = '',
    List<String> optionValues = const [],
    this.correctOptionIndex = 0,
    this.excludedFromScore = false,
    this.id = 0,
    this.optionIds = const [],
  }) {
    this.content.text = content;
    this.explanation.text = explanation;
    for (var i = 0; i < options.length && i < optionValues.length; i++) {
      options[i].text = optionValues[i];
    }
  }
  final content = TextEditingController();
  final explanation = TextEditingController();
  final options = List.generate(4, (_) => TextEditingController());
  int correctOptionIndex;
  bool excludedFromScore;
  final int id;
  final List<int> optionIds;

  void dispose() {
    content.dispose();
    explanation.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({
    super.key,
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
    this.showScoreExclusion = false,
    this.lockStructure = false,
  });

  final int index;
  final _QuestionDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;
  final bool showScoreExclusion;
  final bool lockStructure;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${widget.index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: widget.canRemove && !widget.lockStructure
                    ? widget.onRemove
                    : null,
                tooltip: 'Remove question',
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextFormField(
            controller: widget.draft.content,
            enabled: !widget.lockStructure,
            decoration: const InputDecoration(labelText: 'Question content'),
            maxLines: null,
            validator: _required,
          ),
          const SizedBox(height: 8),
          ...List.generate(4, (optionIndex) {
            final key = String.fromCharCode(65 + optionIndex);
            return Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => widget.draft.correctOptionIndex = optionIndex,
                  ),
                  tooltip: 'Mark option $key as correct',
                  icon: Icon(
                    widget.draft.correctOptionIndex == optionIndex
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: widget.draft.options[optionIndex],
                    enabled: !widget.lockStructure,
                    decoration: InputDecoration(labelText: 'Option $key'),
                    validator: _required,
                  ),
                ),
              ],
            );
          }),
          TextFormField(
            controller: widget.draft.explanation,
            enabled: !widget.lockStructure,
            decoration: const InputDecoration(
              labelText: 'Answer explanation (optional)',
            ),
            maxLines: null,
          ),
          if (widget.showScoreExclusion)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude this question from scoring'),
              value: widget.draft.excludedFromScore,
              onChanged: (value) => setState(
                () => widget.draft.excludedFromScore = value ?? false,
              ),
            ),
        ],
      ),
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required' : null;

String _formatDateTime(DateTime value) =>
    DateFormat('MMM d, yyyy • HH:mm').format(value);
