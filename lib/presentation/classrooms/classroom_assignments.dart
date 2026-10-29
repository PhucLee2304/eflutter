import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/presentation/classrooms/proctoring_fields.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showAssignmentAuditSheet(BuildContext context, List<ExamAudit> audits) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Text(
                  'Assignment change history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: audits.isEmpty
                    ? const Center(child: Text('No changes recorded yet'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: audits.length,
                        separatorBuilder: (_, _) => const Divider(height: 28),
                        itemBuilder: (context, index) {
                          final audit = audits[index];
                          final time = audit.regradedAt ?? audit.createdAt;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                audit.reason.isEmpty ? 'Assignment updated' : audit.reason,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('MMM d, yyyy HH:mm').format(time)} · '
                                '${audit.actor?.name ?? audit.actorId}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (audit.scoreChanges.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ...audit.scoreChanges.map(
                                  (change) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Student ${change.studentId} · '
                                            'Attempt ${change.attemptId}',
                                          ),
                                        ),
                                        Text(
                                          '${change.beforeScore?.toStringAsFixed(2) ?? '-'}'
                                          ' → '
                                          '${change.afterScore?.toStringAsFixed(2) ?? '-'}',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );

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
    this.studentCount,
    required this.onReload,
    this.onLoadMore,
    required this.onCreate,
    required this.onOpen,
    required this.onGradebook,
    this.onClassGradebook,
    this.onAssignToClasses,
    this.onEditSchedule,
    this.onEditContent,
    this.onViewAudits,
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

  /// Sĩ số lớp (học sinh đã duyệt), mẫu số của thanh tiến độ nộp bài.
  final int? studentCount;
  final String? error;
  final String? loadMoreError;
  final bool hasMore;
  final VoidCallback onReload;
  final VoidCallback? onLoadMore;
  final VoidCallback onCreate;
  final ValueChanged<ClassroomAssignment> onOpen;
  final ValueChanged<ClassroomAssignment> onGradebook;

  /// Bảng điểm cả lớp (mọi assignment); chỉ giáo viên.
  final VoidCallback? onClassGradebook;
  final ValueChanged<ClassroomAssignment>? onAssignToClasses;
  final ValueChanged<ClassroomAssignment>? onEditSchedule;
  final ValueChanged<ClassroomAssignment>? onEditContent;
  final ValueChanged<ClassroomAssignment>? onViewAudits;
  final void Function(ClassroomAssignment assignment, bool active) onSetActive;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(padding: EdgeInsets.all(40), child: AppLoader());
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

    return _ClassworkList(view: this);
  }
}

/// Trạng thái thời gian của một assignment, dùng để lọc và chia nhóm.
enum _Phase { open, upcoming, closed }

_Phase _phaseOf(ClassroomAssignment a, DateTime now) {
  if (!a.active || now.isAfter(a.dueAt)) return _Phase.closed;
  if (now.isBefore(a.opensAt)) return _Phase.upcoming;
  return _Phase.open;
}

const _muted = Color(0xFF65676B);
const _faint = Color(0xFF8A8D91);
const _border = Color(0xFFE4E6EB);

class _ClassworkList extends StatefulWidget {
  const _ClassworkList({required this.view});
  final ClassroomAssignmentsView view;

  @override
  State<_ClassworkList> createState() => _ClassworkListState();
}

class _ClassworkListState extends State<_ClassworkList> {
  _Phase? filter;

  Widget _pill(String label, _Phase? value) {
    final selected = filter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: selected ? null : () => setState(() => filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : null,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? ColorName.primary : _muted,
          ),
        ),
      ),
    );
  }

  Widget _tile(ClassroomAssignment assignment) {
    final v = widget.view;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _AssignmentTile(
        assignment: assignment,
        isTeacher: v.isTeacher,
        classroomActive: v.classroomActive,
        studentCount: v.studentCount,
        onOpen: () => v.onOpen(assignment),
        onGradebook: () => v.onGradebook(assignment),
        onAssignToClasses: v.onAssignToClasses == null
            ? null
            : () => v.onAssignToClasses!(assignment),
        onEditSchedule: v.onEditSchedule == null ? null : () => v.onEditSchedule!(assignment),
        onEditContent: v.onEditContent == null ? null : () => v.onEditContent!(assignment),
        onViewAudits: v.onViewAudits == null ? null : () => v.onViewAudits!(assignment),
        onSetActive: (active) => v.onSetActive(assignment, active),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final now = DateTime.now();
    final groups = {for (final phase in _Phase.values) phase: <ClassroomAssignment>[]};
    for (final a in v.assignments) {
      groups[_phaseOf(a, now)]!.add(a);
    }
    const titles = {_Phase.open: 'Open now', _Phase.upcoming: 'Upcoming', _Phase.closed: 'Closed'};
    final shown = [
      for (final phase in _Phase.values)
        if (filter == null || filter == phase) phase,
    ];
    final empty = shown.every((phase) => groups[phase]!.isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pill('All', null),
                  _pill('Open', _Phase.open),
                  _pill('Upcoming', _Phase.upcoming),
                  _pill('Closed', _Phase.closed),
                ],
              ),
            ),
            if (v.isTeacher)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  if (v.onClassGradebook != null)
                    FilledButton.icon(
                      onPressed: v.onClassGradebook,
                      style: AppButtonStyles.secondary,
                      icon: const Icon(Icons.grid_view_outlined, size: 18),
                      label: const Text('Class gradebook'),
                    ),
                  if (v.classroomActive)
                    FilledButton.icon(
                      onPressed: v.onCreate,
                      style: AppButtonStyles.primary,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create assignment'),
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (empty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                v.assignments.isEmpty ? 'No assignments yet' : 'Nothing here',
                style: const TextStyle(color: _muted),
              ),
            ),
          ),
        for (final phase in shown)
          if (groups[phase]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
              child: Row(
                spacing: 8,
                children: [
                  Text(
                    titles[phase]!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${groups[phase]!.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _faint,
                    ),
                  ),
                ],
              ),
            ),
            ...groups[phase]!.map(_tile),
          ],
        if (v.loadingMore)
          const Padding(padding: EdgeInsets.all(20), child: AppLoader())
        else if (v.loadMoreError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: FilledButton.icon(
                onPressed: v.onLoadMore,
                style: AppButtonStyles.secondary,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry loading more'),
              ),
            ),
          )
        else if (v.hasMore)
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
    this.studentCount,
    required this.onOpen,
    required this.onGradebook,
    this.onAssignToClasses,
    this.onEditSchedule,
    this.onEditContent,
    this.onViewAudits,
    required this.onSetActive,
  });

  final ClassroomAssignment assignment;
  final bool isTeacher;
  final bool classroomActive;

  /// Sĩ số lớp (học sinh đã duyệt), mẫu số của thanh tiến độ nộp bài.
  final int? studentCount;
  final VoidCallback onOpen;
  final VoidCallback onGradebook;
  final VoidCallback? onAssignToClasses;
  final VoidCallback? onEditSchedule;
  final VoidCallback? onEditContent;
  final VoidCallback? onViewAudits;
  final ValueChanged<bool> onSetActive;

  static String _short(DateTime value) => DateFormat('MMM d, HH:mm').format(value.toLocal());

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
    ),
  );

  Widget _meta(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      Icon(icon, size: 15, color: _faint),
      Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
    ],
  );

  PopupMenuItem<VoidCallback> _menuItem(VoidCallback action, IconData icon, String label) =>
      PopupMenuItem(
        value: action,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppButtonStyles.tint,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: ColorName.primary),
            ),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final phase = _phaseOf(assignment, now);
    final hasOpened = !now.isBefore(assignment.opensAt);
    final hasEnded = now.isAfter(assignment.dueAt);
    final submission = assignment.submission;
    final hasAttempt = submission != null && submission.attemptId > 0;
    final hasResult =
        hasAttempt && (submission.status == 'SUBMITTED' || submission.status == 'LATE');
    final canOpen =
        isTeacher ||
        hasResult ||
        (classroomActive && assignment.active && (hasAttempt || (hasOpened && !hasEnded)));
    final actionLabel = switch (submission?.status) {
      'IN_PROGRESS' => 'Continue',
      'SUBMITTED' || 'LATE' when hasAttempt => 'View result',
      _ when !assignment.active => 'Paused',
      _ when !hasOpened => 'Not open yet',
      _ when hasEnded => 'Closed',
      _ => 'Start',
    };
    final dimmed = !assignment.active;

    // Học sinh: trạng thái bài làm của mình; giáo viên: trạng thái lịch của bài.
    final status = switch ((isTeacher, submission?.status)) {
      (false, 'SUBMITTED') when hasAttempt => _chip('Submitted', const Color(0xFFF0F2F5), _muted),
      (false, 'LATE') when hasAttempt => _chip(
        'Late',
        const Color(0xFFFFF4E5),
        const Color(0xFFB26A00),
      ),
      (false, 'IN_PROGRESS') => _chip('In progress', AppButtonStyles.tint, ColorName.primary),
      _ when dimmed => _chip('Paused', const Color(0xFFF0F2F5), _muted),
      _ => switch (phase) {
        _Phase.open => _chip('Open', const Color(0xFFE7F6EC), const Color(0xFF1E8E3E)),
        _Phase.upcoming => _chip('Scheduled', AppButtonStyles.tint, ColorName.primary),
        _Phase.closed => _chip('Closed', const Color(0xFFF0F2F5), _muted),
      },
    };

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              assignment.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: dimmed ? _muted : const Color(0xFF191919),
              ),
            ),
            status,
          ],
        ),
        if (assignment.description?.trim().isNotEmpty == true)
          Text(
            assignment.description!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _meta(
              Icons.calendar_today_outlined,
              isTeacher
                  ? '${hasOpened ? 'Opened' : 'Opens'} ${_short(assignment.opensAt)} · '
                        'Due ${_short(assignment.dueAt)}'
                  : 'Due ${_short(assignment.dueAt)}',
            ),
            _meta(Icons.timer_outlined, '${assignment.duration} min'),
            if (assignment.proctored)
              _meta(Icons.shield_outlined, 'Proctored · ${assignment.maxViolations} violations'),
          ],
        ),
      ],
    );

    final List<Widget> trailing;
    if (isTeacher) {
      final total = studentCount ?? assignment.submissions.length;
      final submitted = assignment.submissions
          .where((s) => s.status == 'SUBMITTED' || s.status == 'LATE')
          .length;
      trailing = [
        if (total > 0)
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 6,
              children: [
                Text(
                  '$submitted / $total',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (submitted / total).clamp(0, 1),
                    minHeight: 6,
                    color: ColorName.primary,
                    backgroundColor: const Color(0xFFEEF0F2),
                  ),
                ),
                const Text('submitted', style: TextStyle(fontSize: 11, color: _faint)),
              ],
            ),
          ),
        FilledButton.icon(
          onPressed: onGradebook,
          style: AppButtonStyles.secondary.copyWith(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          icon: const Icon(Icons.grid_view_outlined, size: 16),
          label: const Text('Gradebook'),
        ),
        Tooltip(
          message: assignment.active ? 'Active' : 'Paused',
          child: Switch(
            value: assignment.active,
            activeThumbColor: Colors.white,
            activeTrackColor: ColorName.primary,
            onChanged: classroomActive ? onSetActive : null,
          ),
        ),
        PopupMenuButton<VoidCallback>(
          tooltip: 'More',
          icon: const Icon(Icons.more_vert, size: 20, color: _muted),
          style: IconButton.styleFrom(
            fixedSize: const Size(36, 36),
            minimumSize: const Size(36, 36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shadowColor: const Color(0x33000000),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          menuPadding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _border),
          ),
          onSelected: (action) => action(),
          itemBuilder: (context) => [
            if (onEditContent != null)
              _menuItem(onEditContent!, Icons.edit_outlined, 'Edit assignment'),
            if (onEditSchedule != null)
              _menuItem(onEditSchedule!, Icons.schedule_outlined, 'Edit schedule'),
            if (onAssignToClasses != null)
              _menuItem(onAssignToClasses!, Icons.add_home_work_outlined, 'Assign to more classes'),
            if (onViewAudits != null)
              _menuItem(onViewAudits!, Icons.history_outlined, 'Change history'),
          ],
        ),
      ];
    } else {
      final score = submission?.score;
      trailing = [
        if (score != null && hasResult)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 2,
            children: [
              Text(
                '${score.toStringAsFixed(2)} / 10',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Text('score', style: TextStyle(fontSize: 11, color: _faint)),
            ],
          ),
        FilledButton(
          onPressed: canOpen ? onOpen : null,
          style: hasResult ? AppButtonStyles.secondary : AppButtonStyles.primary,
          child: Text(actionLabel),
        ),
      ];
    }

    final icon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: dimmed ? const Color(0xFFF0F2F5) : AppButtonStyles.tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.assignment_turned_in_outlined,
        size: 22,
        color: dimmed ? _faint : ColorName.primary,
      ),
    );

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isTeacher ? onGradebook : (canOpen ? onOpen : null),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16,
                      children: [
                        icon,
                        Expanded(child: info),
                      ],
                    ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: trailing,
                    ),
                  ],
                );
              }
              return Row(
                spacing: 16,
                children: [
                  icon,
                  Expanded(child: info),
                  ...trailing,
                ],
              );
            },
          ),
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
  bool proctored = false,
  int maxViolations = 2,
  String title = 'Edit schedule',
}) async {
  var selectedDuration = duration;
  var selectedOpensAt = opensAt;
  var selectedDueAt = dueAt;
  var selectedProctored = proctored;
  var selectedMaxViolations = maxViolations;
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
          return DateTime(date.year, date.month, date.day, time.hour, time.minute);
        }

        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: '$duration',
                    decoration: const InputDecoration(labelText: 'Time limit (minutes)'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => selectedDuration = int.tryParse(value) ?? 0,
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
                  ProctoringFields(
                    proctored: selectedProctored,
                    maxViolations: selectedMaxViolations,
                    onProctoredChanged: (value) => setDialogState(() => selectedProctored = value),
                    onMaxViolationsChanged: (value) => selectedMaxViolations = value,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
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
                    proctored: selectedProctored,
                    maxViolations: selectedMaxViolations,
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
    description = TextEditingController(text: widget.assignment.description ?? '');
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
                  onPressed: () => setState(() => questions.add(_QuestionDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add question'),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
                      options: question.options.map((option) => option.text.trim()).toList(),
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

/// Form tạo bài tập vẽ ngay trong tab Classwork (không cuộn riêng, nằm trong ListView của trang lớp).
class CreateAssignmentView extends StatefulWidget {
  const CreateAssignmentView({
    super.key,
    required this.classrooms,
    required this.currentClassroomId,
    required this.onBack,
    required this.onSubmit,
  });

  final List<Classroom> classrooms;
  final int currentClassroomId;
  final VoidCallback onBack;

  /// Gửi bài lên server; trả về true khi tạo thành công.
  final Future<bool> Function(CreateAssignmentInput input) onSubmit;

  @override
  State<CreateAssignmentView> createState() => _CreateAssignmentViewState();
}

class _CreateAssignmentViewState extends State<CreateAssignmentView> {
  static const _border = Color(0xFFE4E6EB);
  static const _muted = Color(0xFF65676B);
  static const _faint = Color(0xFF8A8D91);
  static const _selectedBorder = Color(0xFF9CCBE8);
  static const _selectedFill = Color(0xFFF3F9FD);

  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final selectedClassrooms = <int>{};
  final schedules = <int, _ScheduleDraft>{};
  final questions = <_QuestionDraft>[];
  final collapsed = <_QuestionDraft>{};
  int? expandedClassroom;
  bool saving = false;

  List<Classroom> get classrooms {
    final list = [...widget.classrooms];
    list.sort(
      (a, b) =>
          (b.id == widget.currentClassroomId ? 1 : 0) - (a.id == widget.currentClassroomId ? 1 : 0),
    );
    return list;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final opensAt = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 10));
    for (final classroom in widget.classrooms) {
      schedules[classroom.id] = _ScheduleDraft(
        duration: 60,
        opensAt: opensAt,
        dueAt: opensAt.add(const Duration(days: 1)),
      );
    }
    schedules.putIfAbsent(
      widget.currentClassroomId,
      () => _ScheduleDraft(
        duration: 60,
        opensAt: opensAt,
        dueAt: opensAt.add(const Duration(days: 1)),
      ),
    );
    selectedClassrooms.add(widget.currentClassroomId);
    expandedClassroom = widget.currentClassroomId;
    questions.add(_QuestionDraft());
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

  void showMessage(String message, {ToastType type = ToastType.error}) =>
      context.showToast(message, type: type);

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

  Future<void> submit() async {
    if (saving) return;
    if (!formKey.currentState!.validate()) {
      // Câu đang thu gọn có thể chứa ô lỗi; mở hết ra cho thấy.
      setState(collapsed.clear);
      showMessage('Please fill in the required fields');
      return;
    }
    if (selectedClassrooms.isEmpty) {
      showMessage('Select at least one classroom');
      return;
    }
    final chosen = {for (final id in selectedClassrooms) id: schedules[id]!};
    if (chosen.values.any((item) => !item.dueAt.isAfter(item.opensAt))) {
      showMessage('Due time must be after open time');
      return;
    }
    if (chosen.values.any(
      (item) => Duration(minutes: item.duration) > item.dueAt.difference(item.opensAt),
    )) {
      showMessage('Time limit must not exceed the assignment window');
      return;
    }
    setState(() => saving = true);
    final ok = await widget.onSubmit(
      CreateAssignmentInput(
        schedules: chosen.entries
            .map(
              (entry) => AssignmentScheduleInput(
                classroomId: entry.key,
                duration: entry.value.duration,
                opensAt: entry.value.opensAt,
                dueAt: entry.value.dueAt,
                proctored: entry.value.proctored,
                maxViolations: entry.value.maxViolations,
              ),
            )
            .toList(),
        title: title.text.trim(),
        description: description.text.trim(),
        questions: questions
            .map(
              (question) => CreateAssignmentQuestion(
                content: question.content.text.trim(),
                explanation: question.explanation.text.trim(),
                options: question.options.map((option) => option.text.trim()).toList(),
                correctOptionIndex: question.correctOptionIndex,
                excludedFromScore: question.excludedFromScore,
              ),
            )
            .toList(),
      ),
    );
    if (mounted && !ok) setState(() => saving = false);
  }

  static InputDecoration _decoration(String hint, {String? suffix}) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _faint, fontSize: 14),
      suffixText: suffix,
      filled: true,
      fillColor: const Color(0xFFF0F2F5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(Colors.transparent, 1),
      enabledBorder: border(Colors.transparent, 1),
      focusedBorder: border(ColorName.primary, 1.5),
      errorBorder: border(const Color(0xFFE53935), 1),
      focusedErrorBorder: border(const Color(0xFFE53935), 1.5),
    );
  }

  static Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
        ],
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3A3B3C)),
    ),
  );

  static Widget _card({required List<Widget> children, double spacing = 16}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing,
      children: children,
    ),
  );

  static Widget _cardHead(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 2,
    children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      Text(subtitle, style: const TextStyle(fontSize: 13, color: _muted)),
    ],
  );

  Widget _details() => _card(
    children: [
      _cardHead('Details', 'Students see the title and description before they start.'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Title', required: true),
          TextFormField(
            controller: title,
            enabled: !saving,
            decoration: _decoration('e.g. Practice Test 5 – Reading'),
            validator: _required,
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Description'),
          TextFormField(
            controller: description,
            enabled: !saving,
            minLines: 3,
            maxLines: 6,
            decoration: _decoration('What should students know before starting?'),
          ),
        ],
      ),
    ],
  );

  Widget _questionsHeader() => Row(
    spacing: 8,
    children: [
      const Text('Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppButtonStyles.tint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${questions.length}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ColorName.primary,
          ),
        ),
      ),
      const Spacer(),
      const Flexible(
        child: Text(
          'Select the circle next to the correct answer',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: _muted),
        ),
      ),
    ],
  );

  Widget _question(int index) {
    final draft = questions[index];
    final isCollapsed = collapsed.contains(draft);
    const iconStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      foregroundColor: WidgetStatePropertyAll(_faint),
    );
    final head = Row(
      spacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: ColorName.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Q${index + 1}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        Expanded(
          child: isCollapsed
              ? Text(
                  draft.content.text.trim().isEmpty ? 'Untitled question' : draft.content.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                )
              : const SizedBox.shrink(),
        ),
        if (!isCollapsed) ...[
          SizedBox(
            height: 20,
            child: FittedBox(
              child: Switch(
                value: draft.excludedFromScore,
                onChanged: saving
                    ? null
                    : (value) => setState(() => draft.excludedFromScore = value),
              ),
            ),
          ),
          const Text('Exclude from scoring', style: TextStyle(fontSize: 13, color: _muted)),
          Container(width: 1, height: 18, color: _border, margin: const EdgeInsets.only(left: 4)),
        ],
        IconButton(
          tooltip: 'Duplicate question',
          style: iconStyle,
          onPressed: saving
              ? null
              : () => setState(
                  () => questions.insert(
                    index + 1,
                    _QuestionDraft(
                      content: draft.content.text,
                      explanation: draft.explanation.text,
                      optionValues: draft.options.map((o) => o.text).toList(),
                      correctOptionIndex: draft.correctOptionIndex,
                      excludedFromScore: draft.excludedFromScore,
                    ),
                  ),
                ),
          icon: const Icon(Icons.copy_outlined, size: 18),
        ),
        IconButton(
          tooltip: 'Remove question',
          style: iconStyle,
          onPressed: questions.length > 1 && !saving
              ? () => setState(() {
                  questions.removeAt(index);
                  collapsed.remove(draft);
                  draft.dispose();
                })
              : null,
          icon: const Icon(Icons.delete_outline, size: 18),
        ),
        IconButton(
          tooltip: isCollapsed ? 'Expand' : 'Collapse',
          style: iconStyle,
          onPressed: () => setState(() {
            if (!collapsed.remove(draft)) collapsed.add(draft);
          }),
          icon: Icon(isCollapsed ? Icons.expand_more : Icons.expand_less, size: 20),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, isCollapsed ? 10 : 14, 12, isCollapsed ? 10 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            // Ẩn bằng Offstage để ô lỗi vẫn được validate khi thu gọn.
            Offstage(
              offstage: isCollapsed,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('Question', required: true),
                        TextFormField(
                          controller: draft.content,
                          enabled: !saving,
                          minLines: 2,
                          maxLines: null,
                          decoration: _decoration('Type the question'),
                          validator: _required,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        _label('Options', required: true),
                        for (var i = 0; i < draft.options.length; i++) _option(draft, i),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('Explanation (optional)'),
                        TextFormField(
                          controller: draft.explanation,
                          enabled: !saving,
                          maxLines: null,
                          decoration: _decoration('Why is this the right answer?'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(_QuestionDraft draft, int index) {
    const green = Color(0xFF34A853);
    final correct = draft.correctOptionIndex == index;
    final key = String.fromCharCode(65 + index);
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 12),
      decoration: BoxDecoration(
        color: correct ? const Color(0xFFEAF7EE) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: correct ? green : _border),
      ),
      child: Row(
        spacing: 8,
        children: [
          IconButton(
            tooltip: 'Mark option $key as correct',
            visualDensity: VisualDensity.compact,
            onPressed: saving ? null : () => setState(() => draft.correctOptionIndex = index),
            icon: Icon(
              correct ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: correct ? green : const Color(0xFFC9CCD1),
            ),
          ),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: correct ? green : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              key,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: correct ? Colors.white : _muted,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: draft.options[index],
              enabled: !saving,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Option $key',
                hintStyle: const TextStyle(color: _faint),
                // Theme app có viền/nền mặc định cho ô nhập; ô đáp án nằm trong khung nên bỏ hết.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              validator: _required,
            ),
          ),
          if (correct)
            const Text(
              'Correct',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E8E3E)),
            ),
        ],
      ),
    );
  }

  Widget _addQuestion() => InkWell(
    onTap: saving ? null : () => setState(() => questions.add(_QuestionDraft())),
    borderRadius: BorderRadius.circular(12),
    child: CustomPaint(
      painter: _DashedBorderPainter(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _selectedFill, borderRadius: BorderRadius.circular(12)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Icon(Icons.add, size: 18, color: ColorName.primary),
            Text(
              'Add question',
              style: TextStyle(fontWeight: FontWeight.w600, color: ColorName.primary),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _assignTo() => _card(
    spacing: 10,
    children: [
      _cardHead('Assign to', 'Tick a class to assign it. Click a class to set its schedule.'),
      for (final classroom in classrooms) _classRow(classroom),
    ],
  );

  Widget _classRow(Classroom classroom) {
    final selected = selectedClassrooms.contains(classroom.id);
    final expanded = expandedClassroom == classroom.id;
    final schedule = schedules[classroom.id]!;
    final summary = [
      classroom.code,
      if (classroom.id == widget.currentClassroomId) 'This class',
      if (selected && !expanded)
        '${DateFormat('MMM d').format(schedule.opensAt)} – '
            '${DateFormat('MMM d').format(schedule.dueAt)} · ${schedule.duration} min',
    ].join(' · ');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: selected ? _selectedFill : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _selectedBorder : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => expandedClassroom = expanded ? null : classroom.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 10, 6),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: saving
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              selectedClassrooms.add(classroom.id);
                            } else {
                              selectedClassrooms.remove(classroom.id);
                            }
                          }),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          classroom.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: _faint),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _border)),
              ),
              child: _schedule(schedule),
            ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label(label),
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: saving
            ? null
            : () async {
                final picked = await pickDateTime(value);
                if (picked != null) setState(() => onChanged(picked));
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            DateFormat('MMM d, HH:mm').format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    ],
  );

  Widget _schedule(_ScheduleDraft schedule) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Row(
        spacing: 10,
        children: [
          Expanded(child: _dateField('Opens', schedule.opensAt, (v) => schedule.opensAt = v)),
          Expanded(child: _dateField('Due', schedule.dueAt, (v) => schedule.dueAt = v)),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Time limit'),
          TextFormField(
            key: ObjectKey(schedule),
            initialValue: '${schedule.duration}',
            enabled: !saving,
            keyboardType: TextInputType.number,
            decoration: _decoration('60', suffix: 'minutes'),
            onChanged: (value) => setState(() => schedule.duration = int.tryParse(value) ?? 0),
            validator: (value) {
              final minutes = int.tryParse(value?.trim() ?? '');
              return minutes == null || minutes < 1 || minutes > 1440
                  ? 'Enter 1 to 1440 minutes'
                  : null;
            },
          ),
        ],
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      const Text(
                        'Proctored',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        schedule.proctored
                            ? 'Suspend after ${schedule.maxViolations} violations'
                            : 'Off',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: schedule.proctored,
                  onChanged: saving ? null : (v) => setState(() => schedule.proctored = v),
                ),
              ],
            ),
            if (schedule.proctored)
              TextFormField(
                key: ValueKey(('violations', schedule)),
                initialValue: '${schedule.maxViolations}',
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration: _decoration('2', suffix: 'violations allowed'),
                validator: ProctoringFields.validateMaxViolations,
                onChanged: (value) {
                  final parsed = int.tryParse(value.trim());
                  if (parsed != null && parsed >= 1) {
                    setState(() => schedule.maxViolations = parsed);
                  }
                },
              ),
          ],
        ),
      ),
    ],
  );

  Widget _note() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Icon(Icons.info_outline, size: 16, color: Color(0xFF8A6D00)),
        Expanded(
          child: Text(
            'Time limit must fit inside the open–due window. '
            'Students are notified when the assignment opens.',
            style: TextStyle(fontSize: 12, color: Color(0xFF8A6D00)),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _details(),
        const SizedBox(height: 20),
        _questionsHeader(),
        const SizedBox(height: 12),
        for (var i = 0; i < questions.length; i++)
          KeyedSubtree(key: ObjectKey(questions[i]), child: _question(i)),
        _addQuestion(),
      ],
    );
    final aside = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [_assignTo(), _note()],
    );
    return Form(
      key: formKey,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: saving ? null : widget.onBack,
                  style: TextButton.styleFrom(foregroundColor: ColorName.primary),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: saving ? null : submit,
                  style: AppButtonStyles.primary,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: const Text('Create assignment'),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 860
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 20,
                      children: [aside, main],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 24,
                      children: [
                        Expanded(child: main),
                        SizedBox(width: 340, child: aside),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9CCBE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScheduleDraft {
  _ScheduleDraft({required this.duration, required this.opensAt, required this.dueAt});
  int duration;
  DateTime opensAt;
  DateTime dueAt;
  bool proctored = false;
  int maxViolations = 2;
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
                onPressed: widget.canRemove && !widget.lockStructure ? widget.onRemove : null,
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
                  onPressed: () => setState(() => widget.draft.correctOptionIndex = optionIndex),
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
            decoration: const InputDecoration(labelText: 'Answer explanation (optional)'),
            maxLines: null,
          ),
          if (widget.showScoreExclusion)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude this question from scoring'),
              value: widget.draft.excludedFromScore,
              onChanged: (value) => setState(() => widget.draft.excludedFromScore = value ?? false),
            ),
        ],
      ),
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required' : null;

String _formatDateTime(DateTime value) => DateFormat('MMM d, yyyy • HH:mm').format(value);
