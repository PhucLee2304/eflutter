import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/presentation/classrooms/classroom_assignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final assignment = ClassroomAssignment(
    id: 1,
    classroomId: 2,
    title: 'Midterm assignment',
    examId: 3,
    duration: 45,
    opensAt: DateTime.now().subtract(const Duration(hours: 1)),
    dueAt: DateTime.now().add(const Duration(hours: 1)),
    active: true,
    submission: const AssignmentSubmission(
      id: 0,
      assignmentId: 1,
      attemptId: 0,
      status: 'NOT_STARTED',
    ),
  );

  testWidgets('student can start an open assignment on a narrow screen', (tester) async {
    var opened = false;
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomAssignmentsView(
            assignments: [assignment],
            loading: false,
            isTeacher: false,
            classroomActive: true,
            onReload: () {},
            onCreate: () {},
            onOpen: (_) => opened = true,
            onGradebook: (_) {},
            onSetActive: (_, _) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    expect(opened, isTrue);
  });

  testWidgets('teacher sees create and gradebook actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomAssignmentsView(
            assignments: [assignment],
            loading: false,
            isTeacher: true,
            classroomActive: true,
            onReload: () {},
            onCreate: () {},
            onOpen: (_) {},
            onGradebook: (_) {},
            onSetActive: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('Create assignment'), findsOneWidget);
    expect(find.text('Gradebook'), findsOneWidget);
  });

  testWidgets('shows a retry action when loading the next page fails', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClassroomAssignmentsView(
              assignments: [assignment],
              loading: false,
              loadMoreError: 'Could not load more assignments',
              hasMore: true,
              isTeacher: false,
              classroomActive: true,
              onReload: () {},
              onLoadMore: () => retried = true,
              onCreate: () {},
              onOpen: (_) {},
              onGradebook: (_) {},
              onSetActive: (_, _) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Retry loading more'));
    expect(retried, isTrue);
  });

  group('create assignment view', () {
    final classroom = Classroom(id: 2, code: 'CLASS002', name: 'Class 2', active: true);

    Future<void> fillForm(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Practice Test 5 – Reading'),
        'Assignment',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Type the question'), '2 + 2 = ?');
      for (final option in ['A', 'B', 'C', 'D']) {
        await tester.enterText(find.widgetWithText(TextFormField, 'Option $option'), option);
      }
    }

    Future<void> pump(
      WidgetTester tester,
      Future<bool> Function(CreateAssignmentInput) onSubmit,
    ) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                CreateAssignmentView(
                  classrooms: [classroom],
                  currentClassroomId: classroom.id,
                  onBack: () {},
                  onSubmit: onSubmit,
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('submits the current classroom by default', (tester) async {
      CreateAssignmentInput? submitted;
      await pump(tester, (input) async {
        submitted = input;
        return true;
      });
      await fillForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create assignment'));
      await tester.pump();

      expect(submitted?.title, 'Assignment');
      expect(submitted?.schedules.single.classroomId, classroom.id);
      expect(submitted?.questions.single.options, ['A', 'B', 'C', 'D']);
    });

    testWidgets('rejects submitting without a selected classroom', (tester) async {
      var called = false;
      await pump(tester, (_) async => called = true);
      await fillForm(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Create assignment'));
      await tester.pump();

      expect(called, isFalse);
      expect(find.text('Select at least one classroom'), findsOneWidget);
    });
  });

  testWidgets('missing submission does not enable an unopened assignment', (tester) async {
    final unopened = ClassroomAssignment(
      id: 4,
      classroomId: 2,
      title: 'Future assignment',
      examId: 5,
      duration: 30,
      opensAt: DateTime.now().add(const Duration(hours: 1)),
      dueAt: DateTime.now().add(const Duration(hours: 2)),
      active: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomAssignmentsView(
            assignments: [unopened],
            loading: false,
            isTeacher: false,
            classroomActive: true,
            onReload: () {},
            onCreate: () {},
            onOpen: (_) {},
            onGradebook: (_) {},
            onSetActive: (_, _) {},
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Not open yet'));
    expect(button.onPressed, isNull);
  });

  testWidgets('submitted result remains available while assignment is paused', (tester) async {
    var opened = false;
    final paused = ClassroomAssignment(
      id: 6,
      classroomId: 2,
      title: 'Paused assignment',
      examId: 7,
      duration: 30,
      opensAt: DateTime.now().subtract(const Duration(hours: 2)),
      dueAt: DateTime.now().subtract(const Duration(hours: 1)),
      active: false,
      submission: const AssignmentSubmission(
        id: 8,
        assignmentId: 6,
        attemptId: 9,
        status: 'SUBMITTED',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassroomAssignmentsView(
            assignments: [paused],
            loading: false,
            isTeacher: false,
            classroomActive: true,
            onReload: () {},
            onCreate: () {},
            onOpen: (_) => opened = true,
            onGradebook: (_) {},
            onSetActive: (_, _) {},
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'View result'));
    expect(opened, isTrue);
  });
}
