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
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/classrooms/gradebook_widgets.dart';
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
  late DateTime selected = _today();
  List<CalendarEntry> entries = const [];
  List<CalendarEntry> upcoming = const [];
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

  /// Ngày đầu lưới (thứ Hai của tuần chứa ngày 1) và số tuần hiển thị.
  DateTime get gridStart => month.subtract(Duration(days: month.weekday - 1));
  int get weeks {
    final days = DateUtils.getDaysInMonth(month.year, month.month) + month.weekday - 1;
    return (days / 7).ceil();
  }

  Future<void> load() async {
    setState(() {
      loading = entries.isEmpty;
      error = null;
    });
    final now = DateTime.now();
    final results = await Future.wait([
      widget.repository.getCalendar(
        classroomId: widget.classroomId,
        from: gridStart,
        to: gridStart.add(Duration(days: weeks * 7)),
      ),
      widget.repository.getCalendar(
        classroomId: widget.classroomId,
        from: now,
        to: now.add(const Duration(days: 30)),
      ),
    ]);
    if (!mounted) return;
    switch (results[0]) {
      case Success(data: final value):
        setState(() {
          entries = value;
          if (results[1] case Success(data: final next)) {
            upcoming = next.where((entry) => entry.startsAt.isAfter(now)).take(5).toList();
          }
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
    final today = _today();
    selected = today.year == month.year && today.month == month.month ? today : month;
    await load();
  }

  Future<void> goToday() => jumpTo(_today());

  /// Chuyển tới tháng chứa [day] và chọn ngày đó.
  Future<void> jumpTo(DateTime day) async {
    final target = DateTime(day.year, day.month);
    setState(() => selected = day);
    if (target == month) return;
    month = target;
    await load();
  }

  Future<void> edit([CalendarEntry? schedule]) async {
    final input = await showScheduleEditor(context, schedule, day: selected);
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

  List<CalendarEntry> entriesOn(DateTime day) =>
      entries.where((entry) => DateUtils.isSameDay(entry.startsAt, day)).toList();

  @override
  Widget build(BuildContext context) {
    if (loading) return const AppLoader();
    if (error != null) return GbError(message: error!, onRetry: load);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final aside = [_dayDetail(), const SizedBox(height: 16), _upcoming()];
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _grid(compact: constraints.maxWidth < 600),
              const SizedBox(height: 16),
              ...aside,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _grid()),
            const SizedBox(width: 20),
            SizedBox(
              width: 300,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: aside),
            ),
          ],
        );
      },
    );
  }

  Widget _grid({bool compact = false}) {
    final today = _today();
    return GbCard(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            spacing: 10,
            children: [
              _iconButton(Icons.chevron_left, 'Previous month', () => changeMonth(-1)),
              _iconButton(Icons.chevron_right, 'Next month', () => changeMonth(1)),
              Text(
                DateFormat('MMMM yyyy').format(month),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Gb.text),
              ),
              OutlinedButton(
                onPressed: busy ? null : goToday,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Gb.text,
                  side: const BorderSide(color: Gb.border),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Today'),
              ),
              const Spacer(),
              if (widget.isTeacher && widget.classroomActive)
                FilledButton.icon(
                  onPressed: busy ? null : () => edit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(compact ? 'Add' : 'Add class schedule'),
                ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Gb.soft,
            border: Border.symmetric(horizontal: BorderSide(color: Gb.border)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              for (final day in const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'])
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Gb.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var week = 0; week < weeks; week++)
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++)
                Expanded(
                  child: _dayCell(
                    gridStart.add(Duration(days: week * 7 + weekday)),
                    today: today,
                    compact: compact,
                    lastRow: week == weeks - 1,
                    lastColumn: weekday == 6,
                  ),
                ),
            ],
          ),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Gb.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            spacing: 18,
            children: [_legend(Gb.red, 'Deadline'), _legend(_session, 'Class session')],
          ),
        ),
      ],
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onPressed) => SizedBox.square(
    dimension: 32,
    child: OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: Gb.muted,
        side: const BorderSide(color: Gb.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Tooltip(message: tooltip, child: Icon(icon, size: 18)),
    ),
  );

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      _dot(color, 8),
      Text(label, style: const TextStyle(fontSize: 12, color: Gb.muted)),
    ],
  );

  Widget _dot(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _dayCell(
    DateTime day, {
    required DateTime today,
    required bool compact,
    required bool lastRow,
    required bool lastColumn,
  }) {
    final inMonth = day.month == month.month;
    final isToday = DateUtils.isSameDay(day, today);
    final isSelected = DateUtils.isSameDay(day, selected);
    final events = entriesOn(day);
    const line = BorderSide(color: Color(0xFFEEF0F2));
    return InkWell(
      onTap: () => inMonth ? setState(() => selected = day) : jumpTo(day),
      child: Container(
        height: compact ? 64 : 112,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF5FAFE)
              : !inMonth
              ? const Color(0xFFFAFAFA)
              : Colors.white,
          border: isSelected
              ? Border.all(color: ColorName.primary, width: 2)
              : Border(
                  right: lastColumn ? BorderSide.none : line,
                  bottom: lastRow ? BorderSide.none : line,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? ColorName.primary : null,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isToday
                      ? Colors.white
                      : inMonth
                      ? Gb.text
                      : const Color(0xFFB0B5BD),
                ),
              ),
            ),
            if (compact)
              Wrap(
                spacing: 3,
                children: [for (final event in events.take(4)) _dot(_calendarColors(event).$1, 6)],
              )
            else ...[
              for (final event in events.take(2)) _chip(event),
              if (events.length > 2)
                Text(
                  '+${events.length - 2} more',
                  style: const TextStyle(fontSize: 11, color: Gb.muted),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(CalendarEntry event) {
    final (color, background) = _calendarColors(event);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(5)),
      child: Row(
        spacing: 5,
        children: [
          _dot(color, 6),
          Expanded(
            child: Text(
              '${DateFormat('HH:mm').format(event.startsAt)} ${_title(event)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayDetail() {
    final events = entriesOn(selected);
    return GbCard(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          DateFormat('EEEE, MMM d').format(selected),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Gb.text),
        ),
        const SizedBox(height: 14),
        if (events.isEmpty)
          const Text(
            'Nothing scheduled on this day.',
            style: TextStyle(fontSize: 12, color: Gb.faint),
          ),
        for (final event in events) _detailItem(event),
        if (widget.isTeacher && widget.classroomActive) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: busy || selected.isBefore(_today()) ? null : () => edit(),
              icon: const Icon(Icons.add, size: 18),
              label: Text('Add session on ${DateFormat('MMM d').format(selected)}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorName.primary,
                side: const BorderSide(color: ColorName.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _detailItem(CalendarEntry event) {
    final (color, _) = _calendarColors(event);
    final deadline = _isDeadline(event);
    final time = DateFormat('HH:mm').format(event.startsAt);
    final end = event.endsAt == null ? '' : ' – ${DateFormat('HH:mm').format(event.endsAt!)}';
    final assignmentId = event.relatedAssignmentId;
    final room = event.room;
    final editable = widget.isTeacher && widget.classroomActive && event.editable;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deadline ? 'DEADLINE · $time' : 'CLASS SESSION · $time$end',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
                        ),
                      ),
                      if (editable) ...[
                        // Buổi đã bắt đầu không đổi giờ được nữa, chỉ còn xoá.
                        if (event.startsAt.isAfter(DateTime.now()))
                          _smallAction(
                            Icons.edit_outlined,
                            'Edit class schedule',
                            () => edit(event),
                          ),
                        _smallAction(
                          Icons.delete_outline,
                          'Delete class schedule',
                          () => remove(event),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _title(event),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Gb.text,
                    ),
                  ),
                  if (event.description?.trim().isNotEmpty == true)
                    Text(
                      event.description!.trim(),
                      style: const TextStyle(fontSize: 12, color: Gb.muted),
                    ),
                  if (assignmentId != null)
                    InkWell(
                      onTap: () => widget.onOpenAssignment(assignmentId),
                      child: Text(
                        widget.isTeacher ? 'Open gradebook →' : 'Open assignment →',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: ColorName.primary,
                        ),
                      ),
                    ),
                  if (room != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: _roomActions(event, room),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallAction(IconData icon, String tooltip, VoidCallback onPressed) => IconButton(
    tooltip: tooltip,
    onPressed: busy ? null : onPressed,
    visualDensity: VisualDensity.compact,
    iconSize: 16,
    color: Gb.muted,
    icon: Icon(icon),
  );

  Widget _upcoming() => GbCard(
    padding: const EdgeInsets.all(18),
    children: [
      const Text(
        'Coming up',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Gb.text),
      ),
      const SizedBox(height: 12),
      if (upcoming.isEmpty)
        const Text('Nothing in the next 30 days.', style: TextStyle(fontSize: 12, color: Gb.faint)),
      for (final event in upcoming)
        InkWell(
          onTap: () => jumpTo(DateUtils.dateOnly(event.startsAt)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              spacing: 10,
              children: [
                _dot(_calendarColors(event).$1, 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        _title(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Gb.text,
                        ),
                      ),
                      Text(
                        _relativeDay(event.startsAt),
                        style: const TextStyle(fontSize: 12, color: Gb.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  String _relativeDay(DateTime value) {
    final days = DateUtils.dateOnly(value).difference(_today()).inDays;
    final day = switch (days) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => DateFormat('EEE, MMM d').format(value),
    };
    return '$day · ${DateFormat('HH:mm').format(value)}';
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

DateTime _today() => DateUtils.dateOnly(DateTime.now());

/// Bỏ tiền tố "Deadline:" vì màu và nhãn đã cho biết loại sự kiện.
String _title(CalendarEntry entry) => entry.title.replaceFirst(RegExp(r'^Deadline:\s*'), '');

bool _isDeadline(CalendarEntry entry) => entry.calendarType == 'ASSIGNMENT_DEADLINE';

/// Màu chữ và màu nền theo loại sự kiện (Figma 22:2).
(Color, Color) _calendarColors(CalendarEntry entry) =>
    _isDeadline(entry) ? (Gb.red, Gb.redBg) : (_session, _sessionBg);

const _session = Color(0xFF0369A1);
const _sessionBg = Color(0xFFE6F3FB);

/// Hộp thoại thêm/sửa buổi học (Figma 23:554): ngày lấy từ ô đang chọn, chỉ nhập tiêu đề, mô tả, giờ.
Future<ClassroomScheduleInput?> showScheduleEditor(
  BuildContext context,
  CalendarEntry? schedule, {
  DateTime? day,
}) async {
  final title = TextEditingController(text: schedule?.title ?? '');
  final description = TextEditingController(text: schedule?.description ?? '');
  final now = DateTime.now();
  var startsAt =
      schedule?.startsAt ??
      (day == null || !day.isAfter(DateUtils.dateOnly(now))
          ? now.add(const Duration(hours: 1))
          : DateTime(day.year, day.month, day.day, 19));
  startsAt = startsAt.subtract(Duration(minutes: startsAt.minute % 5));
  final endsAt = schedule?.endsAt ?? startsAt.add(const Duration(hours: 1));
  final date = DateUtils.dateOnly(startsAt);
  // Giờ gõ tự do dạng "HH:mm", chỉ kiểm tra khi bấm Save.
  final startText = TextEditingController(text: DateFormat('HH:mm').format(startsAt));
  final endText = TextEditingController(text: DateFormat('HH:mm').format(endsAt));
  String? error;

  DateTime? parse(String text) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
    if (match == null) return null;
    final hour = int.parse(match[1]!), minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return null;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  InputDecoration decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Gb.faint),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Gb.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ColorName.primary, width: 2),
    ),
  );

  Widget label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Gb.red),
            ),
        ],
      ),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Gb.muted),
    ),
  );

  final result = await showDialog<ClassroomScheduleInput>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Widget timeField(String name, TextEditingController controller) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label(name, required: true),
              TextField(
                controller: controller,
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                decoration: decoration('HH:mm'),
                onChanged: (_) {
                  if (error != null) setDialogState(() => error = null);
                },
              ),
            ],
          ),
        );

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      schedule == null ? 'Add class schedule' : 'Edit class schedule',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      DateFormat('EEE, MMM d, yyyy').format(startsAt),
                      style: const TextStyle(fontSize: 12, color: Gb.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20, color: Gb.faint),
              ),
            ],
          ),
          content: SizedBox(
            width: 512,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label('Title', required: true),
                  TextField(controller: title, decoration: decoration('e.g. Speaking practice')),
                  const SizedBox(height: 16),
                  label('Description'),
                  TextField(
                    controller: description,
                    minLines: 3,
                    maxLines: 4,
                    decoration: decoration('Room, topic, what to prepare…'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    spacing: 12,
                    children: [timeField('Starts', startText), timeField('Ends', endText)],
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!, style: const TextStyle(color: Gb.red, fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Gb.text,
                side: const BorderSide(color: Gb.border),
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final start = parse(startText.text);
                final end = parse(endText.text);
                final message = title.text.trim().isEmpty
                    ? 'Enter a title'
                    : start == null || end == null
                    ? 'Enter times as HH:mm, e.g. 21:30'
                    : start.isBefore(DateTime.now())
                    ? 'Start time cannot be in the past'
                    : !end.isAfter(start)
                    ? 'End time must be after start time'
                    : null;
                setDialogState(() => error = message);
                if (message != null) return;
                Navigator.pop(
                  context,
                  ClassroomScheduleInput(
                    title: title.text,
                    description: description.text,
                    startsAt: start!,
                    endsAt: end!,
                  ),
                );
              },
              child: const Text('Save schedule'),
            ),
          ],
        );
      },
    ),
  );
  title.dispose();
  description.dispose();
  startText.dispose();
  endText.dispose();
  return result;
}
