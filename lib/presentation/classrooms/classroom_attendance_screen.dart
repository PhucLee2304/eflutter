import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/classrooms/classroom_detail_header.dart';
import 'package:eflutter/presentation/classrooms/gradebook_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Vào sau mốc này kể từ lúc phòng bắt đầu thì tính là trễ.
const _lateAfter = Duration(minutes: 10);

enum _Status { present, late, absent }

/// Một học sinh trong bảng: các lượt vào/ra đã sắp theo giờ vào.
class _Row {
  _Row(this.user, this.sessions);
  final ClassroomUser? user;
  final List<RoomAttendanceSession> sessions;

  DateTime? get joined => sessions.firstOrNull?.joinedAt;
  DateTime? lastLeft(DateTime fallback) => sessions.isEmpty
      ? null
      : sessions.map((s) => s.leftAt ?? fallback).reduce((a, b) => a.isAfter(b) ? a : b);
  Duration total(DateTime fallback) =>
      sessions.fold(Duration.zero, (sum, s) => sum + (s.leftAt ?? fallback).difference(s.joinedAt));
}

/// Điểm danh một buổi học (Figma 30:139): nằm trong tab Calendar, chỉ liệt kê học sinh.
/// Present/Late/Absent tính ở client từ các lượt vào/ra và danh sách học sinh của lớp.
class RoomAttendanceScreen extends StatefulWidget {
  const RoomAttendanceScreen({super.key, required this.classroomId, required this.roomId});
  final int classroomId;
  final int roomId;

  @override
  State<RoomAttendanceScreen> createState() => _RoomAttendanceScreenState();
}

class _RoomAttendanceScreenState extends State<RoomAttendanceScreen> {
  late final ClassroomRepository repository = ClassroomRepository(getIt<Dio>());
  Classroom? classroom;
  ClassroomRoom? room;
  String? sessionTitle;
  List<RoomAttendanceSession>? sessions;
  String? error;
  String query = '';
  _Status? filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      repository.getRoom(widget.classroomId, widget.roomId),
      repository.get(widget.classroomId),
      repository.getRoomAttendance(widget.classroomId, widget.roomId),
    ]);
    if (!mounted) return;
    if (results[2] case Failure(message: final message)) {
      setState(() => error = message ?? 'Could not load attendance');
      return;
    }
    setState(() {
      error = null;
      if (results[0] case Success(data: final ClassroomRoom value)) room = value;
      if (results[1] case Success(data: final Classroom value)) classroom = value;
      if (results[2] case Success(data: final List<RoomAttendanceSession> value)) sessions = value;
    });
    final current = room;
    if (current == null || sessionTitle != null) return;
    final calendar = await repository.getCalendar(
      classroomId: widget.classroomId,
      from: current.startsAt.subtract(const Duration(minutes: 1)),
      to: current.endsAt.add(const Duration(minutes: 1)),
    );
    if (!mounted) return;
    if (calendar case Success(data: final entries)) {
      setState(
        () => sessionTitle = entries
            .where((entry) => entry.room?.id == widget.roomId)
            .firstOrNull
            ?.title,
      );
    }
  }

  void _back() => context.go(classroomTabPath(widget.classroomId, 2));

  DateTime get _now => DateTime.now();

  /// Học sinh của lớp (kể cả người chưa vào) cộng người có lượt vào nhưng đã rời lớp.
  List<_Row> get _rows {
    final byUser = <String, List<RoomAttendanceSession>>{};
    final users = <String, ClassroomUser?>{};
    for (final session in sessions ?? const <RoomAttendanceSession>[]) {
      if (session.role == 'HOST') continue;
      final key = session.user?.id ?? 'unknown-${session.id}';
      byUser.putIfAbsent(key, () => []).add(session);
      users[key] = session.user;
    }
    // Học sinh chỉ thấy lượt của mình nên không suy ra vắng mặt từ danh sách lớp.
    if (room?.isHost == true) {
      for (final member in classroom?.members ?? const <ClassroomMember>[]) {
        final user = member.user;
        if (user == null || user.id == classroom?.teacher?.id) continue;
        users.putIfAbsent(user.id, () => user);
      }
    }
    return [
      for (final MapEntry(:key, :value) in users.entries)
        _Row(value, [...?byUser[key]]..sort((a, b) => a.joinedAt.compareTo(b.joinedAt))),
    ]..sort(
      (a, b) => (a.user?.name ?? '').toLowerCase().compareTo((b.user?.name ?? '').toLowerCase()),
    );
  }

  _Status _status(_Row row) {
    final joined = row.joined;
    if (joined == null) return _Status.absent;
    final start = room?.startedAt ?? room?.startsAt;
    if (start != null && joined.isAfter(start.add(_lateAfter))) return _Status.late;
    return _Status.present;
  }

  @override
  Widget build(BuildContext context) {
    final item = classroom;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: ClassroomTopBar(onBack: _back),
      body: ListView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1128),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item != null) ...[
                      ClassroomBanner(
                        classroom: item,
                        canManage: false,
                        busy: false,
                        onEdit: () {},
                        onArchive: () {},
                      ),
                      ClassroomTabs(
                        selected: 2,
                        onSelected: (tab) => context.go(classroomTabPath(widget.classroomId, tab)),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _header(),
                    const SizedBox(height: 20),
                    if (error != null)
                      GbError(message: error!, onRetry: _load)
                    else if (sessions == null)
                      const Padding(padding: EdgeInsets.all(48), child: AppLoader())
                    else
                      ..._content(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final info = room;
    final time = info == null
        ? ''
        : ' · ${DateFormat('EEE, MMM d · HH:mm').format(info.startsAt)} – ${DateFormat('HH:mm').format(info.endsAt)}';
    final (label, foreground, background) = switch (info?.status) {
      'LIVE' => ('Live', Gb.green, Gb.greenBg),
      'ENDED' => ('Ended', const Color(0xFF475467), const Color(0xFFF2F4F7)),
      _ => ('Not started', Gb.orange, Gb.orangeBg),
    };
    return Row(
      spacing: 12,
      children: [
        SizedBox.square(
          dimension: 32,
          child: OutlinedButton(
            onPressed: _back,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: Gb.text,
              side: const BorderSide(color: Gb.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Tooltip(
              message: 'Back to calendar',
              child: Icon(Icons.arrow_back, size: 18),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                'Attendance${sessionTitle == null ? '' : ' · $sessionTitle'}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Gb.text),
              ),
              Text('Class session$time', style: const TextStyle(fontSize: 12, color: Gb.muted)),
            ],
          ),
        ),
        if (info != null) GbPill(label, background: background, foreground: foreground),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Gb.text,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Gb.border),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  List<Widget> _content() {
    final rows = _rows;
    final statuses = {for (final row in rows) row: _status(row)};
    int count(_Status status) => statuses.values.where((s) => s == status).length;
    final attended = rows.length - count(_Status.absent);
    final value = query.trim().toLowerCase();
    final visible = rows.where((row) {
      if (filter != null && statuses[row] != filter) return false;
      if (value.isEmpty) return true;
      final user = row.user;
      return user != null &&
          (user.name.toLowerCase().contains(value) || user.email.toLowerCase().contains(value));
    }).toList();
    final info = room;
    final started = info?.startedAt;
    final length = started == null ? null : (info?.endedAt ?? _now).difference(started);
    return [
      if (info?.isHost == true) ...[
        GbStats(
          children: [
            GbStat(label: 'Attended', value: '$attended / ${rows.length}'),
            GbStat(label: 'Late', value: '${count(_Status.late)}'),
            GbStat(
              label: 'Absent',
              value: '${count(_Status.absent)}',
              color: count(_Status.absent) > 0 ? Gb.red : null,
            ),
            GbStat(label: 'Session length', value: length == null ? '—' : _duration(length)),
          ],
        ),
        const SizedBox(height: 20),
      ],
      GbCard(
        padding: EdgeInsets.zero,
        children: [
          _toolbar(rows.length, count),
          _tableHead(),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                rows.isEmpty ? 'No students in this class yet' : 'No students match',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Gb.muted),
              ),
            ),
          for (final (index, row) in visible.indexed)
            _row(index, row, statuses[row]!, last: index == visible.length - 1),
        ],
      ),
    ];
  }

  Widget _toolbar(int total, int Function(_Status) count) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const GbCardHead(
          'Students',
          'Joined is the first join, Left the last leave; the bar shows each stay',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  _filterOption(null, 'All $total'),
                  _filterOption(_Status.present, 'Present ${count(_Status.present)}'),
                  _filterOption(_Status.late, 'Late ${count(_Status.late)}'),
                  _filterOption(_Status.absent, 'Absent ${count(_Status.absent)}'),
                ],
              ),
            ),
            GbSearchField(
              width: 220,
              hint: 'Search student',
              onChanged: (value) => setState(() => query = value),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _filterOption(_Status? value, String label) {
    final selected = filter == value;
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => filter = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Gb.text : Gb.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableHead() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: const BoxDecoration(
      color: Gb.soft,
      border: Border.symmetric(horizontal: BorderSide(color: Gb.border)),
    ),
    child: const Row(
      children: [
        SizedBox(width: 36, child: _HeadText('#')),
        Expanded(child: _HeadText('STUDENT')),
        SizedBox(width: 80, child: _HeadText('JOINED')),
        SizedBox(width: 80, child: _HeadText('LEFT')),
        SizedBox(width: 220, child: _HeadText('TIME IN CLASS')),
        SizedBox(width: 84, child: _HeadText('STATUS')),
      ],
    ),
  );

  Widget _row(int index, _Row row, _Status status, {required bool last}) {
    final now = _now;
    final absent = status == _Status.absent;
    final joined = row.joined;
    final left = row.lastLeft(now);
    final stillHere = row.sessions.any((s) => s.leftAt == null) && room?.status == 'LIVE';
    final (label, foreground, background) = switch (status) {
      _Status.present => ('Present', Gb.green, Gb.greenBg),
      _Status.late => ('Late', Gb.orange, Gb.orangeBg),
      _Status.absent => ('Absent', Gb.red, Gb.redBg),
    };
    String time(DateTime? value) => value == null ? '—' : DateFormat('HH:mm').format(value);
    const cellStyle = TextStyle(fontSize: 12, color: Gb.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Gb.field)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 12,
                color: Gb.faint,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Row(
              spacing: 10,
              children: [
                GbAvatar(name: row.user?.name ?? '?', url: row.user?.avatar),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.user?.name ?? 'User no longer available',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: absent ? Gb.muted : Gb.text,
                        ),
                      ),
                      Text(
                        row.user?.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Gb.faint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 80, child: Text(time(joined), style: cellStyle)),
          SizedBox(width: 80, child: Text(stillHere ? 'In class' : time(left), style: cellStyle)),
          SizedBox(
            width: 220,
            child: absent
                ? const Text('—', style: cellStyle)
                : Row(
                    spacing: 10,
                    children: [
                      _timeline(row, now),
                      Text(
                        _duration(row.total(now)),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Gb.text,
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(
            width: 84,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GbPill(label, background: background, foreground: foreground),
            ),
          ),
        ],
      ),
    );
  }

  /// Thanh thời gian: mỗi đoạn xanh là một lượt có mặt trong khoảng phòng mở; rê chuột xem giờ.
  Widget _timeline(_Row row, DateTime now) {
    final info = room;
    final start = info?.startedAt ?? row.joined!;
    final end = info?.endedAt ?? now;
    final span = end.difference(start).inSeconds;
    final tooltip = row.sessions
        .map(
          (s) =>
              '${DateFormat('HH:mm').format(s.joinedAt)}–${s.leftAt == null ? 'now' : DateFormat('HH:mm').format(s.leftAt!)}',
        )
        .join(', ');
    const width = 130.0;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: width,
        height: 6,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF0F3),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Stack(
          children: [
            for (final session in row.sessions)
              if (span > 0)
                Positioned(
                  left: width * _fraction(session.joinedAt, start, span),
                  width:
                      (width *
                              (_fraction(session.leftAt ?? now, start, span) -
                                  _fraction(session.joinedAt, start, span)))
                          .clamp(3.0, width),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: ColorName.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

double _fraction(DateTime value, DateTime start, int span) =>
    (value.difference(start).inSeconds / span).clamp(0.0, 1.0);

String _duration(Duration value) {
  final minutes = value.inMinutes;
  if (minutes < 60) return '${minutes}m';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

class _HeadText extends StatelessWidget {
  const _HeadText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Gb.muted),
  );
}
