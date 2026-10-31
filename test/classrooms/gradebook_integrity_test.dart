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

ClassroomAssignment _assignment(List<AssignmentSubmission> submissions) => ClassroomAssignment(
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

  testWidgets('bảng điểm có cột Proctoring, đang rời màn và đình chỉ', (tester) async {
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
            awaySince: {'s1': DateTime.now()},
            onOpenIntegrity: (submission) => opened = submission,
          ),
        ),
      ),
    );

    expect(find.text('PROCTORING · 2 ALLOWED'), findsOneWidget);
    expect(find.text('● Left the exam · 0:00'), findsOneWidget);
    expect(find.text('Suspended · score 0'), findsOneWidget);
    await tester.tap(find.text('● Left the exam · 0:00'));
    expect(opened?.student?.id, 's1');
  });

  testWidgets('ô Proctoring mô tả số lần bằng chữ và nút Review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradebookView(
            assignment: _assignment([
              _submission('s1'),
              _submission('s2', violations: 1, pending: 1),
              _submission('s3', violations: 2),
              _submission('s4', violations: 3, outcome: 'REINSTATED'),
            ]),
          ),
        ),
      ),
    );

    expect(find.text('No violations'), findsOneWidget);
    expect(find.text('1 violation'), findsOneWidget);
    expect(find.text('Review 1 new'), findsOneWidget);
    expect(find.text('Limit reached'), findsOneWidget);
    expect(find.text('Reinstated'), findsOneWidget);
  });

  testWidgets('panel gọi Don\'t count it, Keep it và Open log', (tester) async {
    final kept = <String>[];
    final allowed = <String>[];
    AssignmentSubmission? opened;
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
              onDontCount: (events) => allowed.addAll(events.map((event) => event.eventId)),
              onKeep: (events) => kept.addAll(events.map((event) => event.eventId)),
              onOpenLog: (submission) => opened = submission,
            ),
          ),
        ),
      ),
    );

    expect(find.text('1 student needs a decision now'), findsOneWidget);
    expect(find.text('1 violation'), findsOneWidget);
    expect(find.text('Ban'), findsNothing);
    await tester.tap(find.text("Don't count it"));
    await tester.tap(find.text('Keep it'));
    await tester.tap(find.text('Open log'));
    expect(allowed, ['e1']);
    expect(kept, ['e1']);
    expect(opened?.student?.id, 's1');
  });

  testWidgets('gộp nhiều vi phạm của một học sinh thành một dòng', (tester) async {
    final allowed = <String>[];
    IntegrityEventRecord violation(String id, int no, int minute) => IntegrityEventRecord(
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
              onDontCount: (events) => allowed.addAll(events.map((event) => event.eventId)),
              onKeep: (_) {},
              onOpenLog: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('1 student needs a decision now'), findsOneWidget);
    expect(find.text('Limit reached'), findsOneWidget);
    expect(find.textContaining('2 new'), findsOneWidget);
    await tester.tap(find.text("Don't count it"));
    expect(allowed, ['e2', 'e1']);
  });
}
