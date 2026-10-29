import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'dart:async';

import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/data_sources/room_socket_client.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';

class ClassroomCalendarView extends StatefulWidget {
  const ClassroomCalendarView({
    super.key,
    required this.repository,
    required this.classroomId,
    required this.isTeacher,
    required this.classroomActive,
    required this.onOpenAssignment,
  });

  final ClassroomRepository repository;
  final int classroomId;
  final bool isTeacher;
  final bool classroomActive;
  final ValueChanged<int> onOpenAssignment;

  @override
  State<ClassroomCalendarView> createState() => _ClassroomCalendarViewState();
}

class _ClassroomCalendarViewState extends State<ClassroomCalendarView> {
  late final RoomSocketClient roomSocket = RoomSocketClient(getIt<LocalDataBase>());
  StreamSubscription<ClassroomRoom>? roomSubscription;
  Timer? clockTimer;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<CalendarEntry> entries = const [];
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    roomSubscription = roomSocket.events.listen((room) {
      if (room.classroomId == widget.classroomId) unawaited(load());
    });
    roomSocket.connect();
    clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    load();
  }

  @override
  void dispose() {
    roomSubscription?.cancel();
    roomSocket.close();
    clockTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await widget.repository.getCalendar(
      classroomId: widget.classroomId,
      from: month,
      to: DateTime(month.year, month.month + 1),
    );
    if (!mounted) return;
    switch (result) {
      case Success(data: final value):
        setState(() {
          entries = value;
          loading = false;
        });
      case Failure(message: final message):
        setState(() {
          error = message ?? 'Could not load the calendar';
          loading = false;
        });
      case Cancelled():
        setState(() => loading = false);
    }
  }

  Future<void> changeMonth(int offset) async {
    month = DateTime(month.year, month.month + offset);
    await load();
  }

  Future<void> edit([CalendarEntry? schedule]) async {
    final input = await showScheduleEditor(context, schedule);
    if (input == null || !mounted) return;
    setState(() => busy = true);
    final result = schedule == null
        ? await widget.repository.createSchedule(classroomId: widget.classroomId, input: input)
        : await widget.repository.updateSchedule(
            classroomId: widget.classroomId,
            scheduleId: schedule.id,
            input: input,
          );
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await load();
      case Failure(message: final message):
        _message(message ?? 'Could not save the class schedule');
      case Cancelled():
        break;
    }
  }

  Future<void> remove(CalendarEntry schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete class schedule?'),
        content: Text(schedule.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    final result = await widget.repository.deleteSchedule(
      classroomId: widget.classroomId,
      scheduleId: schedule.id,
    );
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await load();
      case Failure(message: final message):
        _message(message ?? 'Could not delete the class schedule');
      case Cancelled():
        break;
    }
  }

  Future<void> startRoom(CalendarEntry entry) async {
    final room = entry.room;
    if (room == null) return;
    setState(() => busy = true);
    final result = await widget.repository.startRoom(widget.classroomId, room.id);
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await load();
        if (mounted) {
          context.push(classroomRoomPath(widget.classroomId, room.id));
        }
      case Failure(message: final message):
        _message(message ?? 'Could not start the room');
      case Cancelled():
        break;
    }
  }

  void _message(String value, {ToastType type = ToastType.error}) =>
      context.showToast(value, type: type);

  @override
  Widget build(BuildContext context) {
    if (loading) return const AppLoader();
    if (error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: load,
          icon: const Icon(Icons.refresh),
          label: Text(error!),
        ),
      );
    }
    final grouped = <DateTime, List<CalendarEntry>>{};
    for (final entry in entries) {
      final day = DateTime(entry.startsAt.year, entry.startsAt.month, entry.startsAt.day);
      grouped.putIfAbsent(day, () => []).add(entry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: busy ? null : () => changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: busy ? null : () => changeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
            if (widget.isTeacher && widget.classroomActive) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: busy ? null : () => edit(),
                icon: const Icon(Icons.add),
                label: const Text('Add class schedule'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: Text('No class schedules or deadlines this month')),
          )
        else
          ...grouped.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d').format(entry.key),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  ...entry.value.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_calendarIcon(entry.calendarType)),
                      title: Text(entry.title),
                      subtitle: Text(_calendarDetails(entry)),
                      onTap: entry.relatedAssignmentId != null
                          ? () => widget.onOpenAssignment(entry.relatedAssignmentId!)
                          : null,
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          if (widget.isTeacher && widget.classroomActive && entry.editable) ...[
                            IconButton(
                              tooltip: 'Edit class schedule',
                              onPressed: busy ? null : () => edit(entry),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete class schedule',
                              onPressed: busy ? null : () => remove(entry),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                          if (entry.room case final room?) ..._roomActions(entry, room),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _roomActions(CalendarEntry entry, ClassroomRoom room) {
    if (room.status == 'LIVE') {
      return [
        _attendanceAction(room),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => context.push(classroomRoomPath(widget.classroomId, room.id)),
          icon: const Icon(Icons.video_call_outlined),
          label: const Text('Join'),
        ),
      ];
    }
    if (room.status == 'ENDED') {
      return [
        const Padding(padding: EdgeInsets.all(12), child: Text('Ended')),
        _attendanceAction(room),
      ];
    }
    if (widget.isTeacher && widget.classroomActive) {
      final now = DateTime.now();
      if (now.isBefore(room.startsAt.subtract(const Duration(minutes: 30)))) {
        return [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Starts ${DateFormat('MMM d, HH:mm').format(room.startsAt)}'),
          ),
        ];
      }
      if (!room.canStartAt(now)) {
        return [const Padding(padding: EdgeInsets.all(12), child: Text('Start window ended'))];
      }
      return [
        FilledButton.icon(
          onPressed: busy ? null : () => startRoom(entry),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
        ),
      ];
    }
    return [
      const Padding(padding: EdgeInsets.all(12), child: Text('Waiting for the teacher to start')),
    ];
  }

  Widget _attendanceAction(ClassroomRoom room) => IconButton(
    tooltip: widget.isTeacher ? 'Attendance' : 'My attendance',
    onPressed: () => context.push(roomAttendancePath(widget.classroomId, room.id)),
    icon: const Icon(Icons.fact_check_outlined),
  );
}

IconData _calendarIcon(String type) => switch (type) {
  'CLASS_SCHEDULE' => Icons.school_outlined,
  'ASSIGNMENT_DEADLINE' => Icons.assignment_late_outlined,
  _ => Icons.event_outlined,
};

String _calendarDetails(CalendarEntry entry) {
  final values = <String>[DateFormat('HH:mm').format(entry.startsAt)];
  if (entry.endsAt != null) {
    values[0] += ' - ${DateFormat('HH:mm').format(entry.endsAt!)}';
  }
  if (entry.description?.trim().isNotEmpty == true) {
    values.add(entry.description!.trim());
  }
  return values.join(' · ');
}

Future<ClassroomScheduleInput?> showScheduleEditor(
  BuildContext context,
  CalendarEntry? schedule,
) async {
  final title = TextEditingController(text: schedule?.title ?? '');
  final description = TextEditingController(text: schedule?.description ?? '');
  var startsAt = schedule?.startsAt ?? DateTime.now().add(const Duration(hours: 1));
  var endsAt = schedule?.endsAt ?? startsAt.add(const Duration(hours: 1));

  Future<DateTime?> pickDateTime(BuildContext dialogContext, DateTime initial) async {
    final date = await showDatePicker(
      context: dialogContext,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !dialogContext.mounted) return null;
    final time = await showTimePicker(
      context: dialogContext,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  final result = await showDialog<ClassroomScheduleInput>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(schedule == null ? 'Add class schedule' : 'Edit class schedule'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts'),
                  subtitle: Text(DateFormat('MMM d, yyyy HH:mm').format(startsAt)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final value = await pickDateTime(dialogContext, startsAt);
                    if (value != null) setDialogState(() => startsAt = value);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ends'),
                  subtitle: Text(DateFormat('MMM d, yyyy HH:mm').format(endsAt)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final value = await pickDateTime(dialogContext, endsAt);
                    if (value != null) setDialogState(() => endsAt = value);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty || !endsAt.isAfter(startsAt)) {
                return;
              }
              Navigator.pop(
                context,
                ClassroomScheduleInput(
                  title: title.text,
                  description: description.text,
                  startsAt: startsAt,
                  endsAt: endsAt,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  description.dispose();
  return result;
}
