import 'package:eflutter/data/models/classroom.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses room state and enforces the teacher start window', () {
    final startsAt = DateTime.utc(2026, 10, 12, 10);
    final room = ClassroomRoom.fromJson({
      'id': 7,
      'classroomId': 2,
      'scheduleId': 9,
      'status': 'SCHEDULED',
      'startsAt': startsAt.toIso8601String(),
      'endsAt': startsAt.add(const Duration(hours: 1)).toIso8601String(),
      'isHost': true,
    });

    expect(room.isHost, isTrue);
    expect(
      room.canStartAt(startsAt.subtract(const Duration(minutes: 31))),
      isFalse,
    );
    expect(
      room.canStartAt(startsAt.subtract(const Duration(minutes: 30))),
      isTrue,
    );
    expect(room.canStartAt(startsAt.add(const Duration(minutes: 59))), isTrue);
    expect(room.canStartAt(startsAt.add(const Duration(hours: 1))), isFalse);
  });

  test('parses room connection and attendance sessions', () {
    final joinedAt = DateTime.utc(2026, 10, 12, 10, 5);
    final connection = RoomConnection.fromJson({
      'url': 'ws://localhost:7880',
      'token': 'token',
      'room': {
        'id': 7,
        'classroomId': 2,
        'scheduleId': 9,
        'status': 'LIVE',
        'startsAt': joinedAt.toIso8601String(),
        'endsAt': joinedAt.add(const Duration(hours: 1)).toIso8601String(),
        'isHost': false,
      },
    });
    final session = RoomAttendanceSession.fromJson({
      'id': 1,
      'role': 'PARTICIPANT',
      'joinedAt': joinedAt.toIso8601String(),
      'user': {
        'id': '3',
        'name': 'Student',
        'email': 'student@example.com',
        'avatar': '',
      },
    });

    expect(connection.room.status, 'LIVE');
    expect(connection.token, 'token');
    expect(session.user?.name, 'Student');
    expect(session.leftAt, isNull);
  });
}
