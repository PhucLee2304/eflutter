import 'package:eflutter/data/models/attempt_integrity.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/presentation/classrooms/classroom_gradebook_screen.dart';
import 'package:eflutter/presentation/classrooms/integrity_violation_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AssignmentSubmission _submission(
  String id, {
  int violations = 0,
  int pending = 0,
  String? outcome = 'NONE',
}) => AssignmentSubmission(
  id: id.hashCode,
  assignmentId: 1,
  attemptId: 10,
  status: 'IN_PROGRESS',
  student: ClassroomUser(id: id, name: 'Name $id', email: '$id@x.io'),
  proctored: true,
  violationCount: violations,
  pendingViolations: pending,
  integrityOutcome: outcome,
);

ClassroomAssignment _assignment(List<AssignmentSubmission> submissions) =>
    ClassroomAssignment(
      id: 1,
      classroomId: 2,
      title: 'Proctored quiz',
      examId: 3,
      duration: 30,
      opensAt: DateTime(2026, 10, 27, 8),
      dueAt: DateTime(2026, 10, 27, 10),
      active: true,
      proctored: true,
      maxViolations: 2,
      submissions: submissions,
    );

void main() {
  test('schedule input gửi proctored và maxViolations', () {
    final json = AssignmentScheduleInput(
      classroomId: 1,
      duration: 30,
      opensAt: DateTime.utc(2026),
      dueAt: DateTime.utc(2026, 2),
      proctored: true,
      maxViolations: 3,
    ).toJson();
    expect(json['proctored'], isTrue);
    expect(json['maxViolations'], 3);

    final plain = AssignmentScheduleInput(
      classroomId: 1,
      duration: 30,
      opensAt: DateTime.utc(2026),
      dueAt: DateTime.utc(2026, 2),
    ).toJson();
    expect(plain['proctored'], isFalse);
    expect(plain.containsKey('maxViolations'), isFalse);
  });

  test('parse push ATTEMPT_INTEGRITY_UPDATED', () {
    final update = IntegrityUpdate.fromJson({
      'classroomId': 2,
      'assignmentId': 1,
      'studentId': 's1',
      'attemptId': 10,
      'violationCount': 1,
      'maxViolations': 2,
      'status': 'ACTIVE',
      'outcome': 'NONE',
      'away': true,
      'event': {
        'eventId': 'e1',
        'type': 'AWAY_END',
        'level': 'VIOLATION',
        'violationNo': 1,
        'serverDurationMs': 5200,
        'at': '2026-10-27T01:00:00Z',
      },
    });
    expect(update.away, isTrue);
    expect(update.event?.isPending, isTrue);
    expect(update.event?.studentId, 's1');
  });

  testWidgets('bảng điểm có cột vi phạm, chấm chờ xử lý và Away', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AssignmentSubmission? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradebookView(
            assignment: _assignment([
              _submission('s1', violations: 1, pending: 1),
              _submission('s2', violations: 3, outcome: 'TERMINATED'),
            ]),
            awayStudents: const {'s1'},
            onOpenIntegrity: (submission) => opened = submission,
          ),
        ),
      ),
    );

    expect(find.text('VIOLATIONS'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Away'), findsOneWidget);
    expect(find.text('Suspended'), findsOneWidget);
    await tester.tap(find.text('1/2'));
    expect(opened?.student?.id, 's1');
  });

  testWidgets('panel vi phạm gọi Cấm và Cho tiếp tục', (tester) async {
    final banned = <String>[];
    final allowed = <String>[];
    final event = IntegrityEventRecord(
      eventId: 'e1',
      attemptId: 10,
      studentId: 's1',
      type: 'AWAY_END',
      level: IntegrityLevel.violation,
      violationNo: 1,
      serverDurationMs: 4000,
      receivedAt: DateTime(2026, 10, 27, 8),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntegrityViolationPanel(
              events: [event],
              submissions: [_submission('s1', violations: 1, pending: 1)],
              maxViolations: 2,
              onBan: (event) => banned.add(event.eventId),
              onAllowContinue: (events) =>
                  allowed.addAll(events.map((event) => event.eventId)),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Pending violations (1)'), findsOneWidget);
    expect(find.text('Removes it: 1 → 0/2'), findsOneWidget);
    await tester.tap(find.text('Allow to continue'));
    await tester.tap(find.text('Ban'));
    expect(allowed, ['e1']);
    expect(banned, ['e1']);
  });

  testWidgets('gộp nhiều vi phạm của một học sinh thành một thẻ', (
    tester,
  ) async {
    final allowed = <String>[];
    IntegrityEventRecord violation(String id, int no, int minute) =>
        IntegrityEventRecord(
          eventId: id,
          attemptId: 10,
          studentId: 's1',
          type: 'AWAY_END',
          level: IntegrityLevel.violation,
          violationNo: no,
          receivedAt: DateTime(2026, 10, 27, 8, minute),
        );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntegrityViolationPanel(
              events: [violation('e1', 1, 1), violation('e2', 2, 5)],
              submissions: [_submission('s1', violations: 2, pending: 2)],
              maxViolations: 2,
              onBan: (_) {},
              onAllowContinue: (events) =>
                  allowed.addAll(events.map((event) => event.eventId)),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Pending violations (1)'), findsOneWidget);
    expect(find.textContaining('Violation 2/2'), findsOneWidget);
    expect(find.text('2 unreviewed'), findsOneWidget);
    await tester.tap(find.text('Allow to continue'));
    expect(allowed, ['e2', 'e1']);
  });
}
