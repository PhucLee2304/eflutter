import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/presentation/classrooms/classroom_gradebook_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final submissions = List.generate(
    50,
    (index) => AssignmentSubmission(
      id: index + 1,
      assignmentId: 1,
      attemptId: index.isEven ? index + 10 : 0,
      status: switch (index % 4) {
        0 => 'SUBMITTED',
        1 => 'IN_PROGRESS',
        2 => 'NOT_STARTED',
        _ => 'LATE',
      },
      student: ClassroomUser(
        id: 'student-$index',
        name: 'Student ${index + 1}',
        email: 'student${index + 1}@example.com',
      ),
      score: index % 4 == 0 ? 8.5 : null,
    ),
  );
  final assignment = ClassroomAssignment(
    id: 1,
    classroomId: 2,
    title: 'First Assignment',
    examId: 3,
    duration: 45,
    opensAt: DateTime(2026, 10, 5, 8),
    dueAt: DateTime(2026, 10, 6, 8),
    active: true,
    submissions: submissions,
  );

  Future<void> pumpGradebook(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GradebookView(assignment: assignment)),
      ),
    );
  }

  testWidgets('renders fifty students as a table on desktop', (tester) async {
    await pumpGradebook(tester, const Size(1200, 900));

    expect(find.text('Students'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a compact list and searches students on mobile', (
    tester,
  ) async {
    await pumpGradebook(tester, const Size(390, 800));

    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Student 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'student50@example.com');
    await tester.pump();

    expect(find.text('Student 50'), findsOneWidget);
    expect(find.text('Student 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an empty submission status without throwing', (
    tester,
  ) async {
    final emptyStatusAssignment = ClassroomAssignment(
      id: 2,
      classroomId: 2,
      title: 'Assignment with incomplete data',
      examId: 3,
      duration: 45,
      opensAt: DateTime(2026, 10, 5, 8),
      dueAt: DateTime(2026, 10, 6, 8),
      active: true,
      submissions: const [
        AssignmentSubmission(
          id: 1,
          assignmentId: 2,
          attemptId: 0,
          status: '',
          student: ClassroomUser(
            id: 'student',
            name: 'Student',
            email: 'student@example.com',
          ),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GradebookView(assignment: emptyStatusAssignment)),
      ),
    );

    expect(find.textContaining('student@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
