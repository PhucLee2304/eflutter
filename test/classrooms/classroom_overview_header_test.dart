import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/presentation/classrooms/classroom_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final classroom = Classroom.fromJson({
    'id': 1,
    'code': '3JZSP2FS',
    'name': 'Class 1',
    'description': 'A short class description',
    'active': true,
    'teacher': {'id': '12', 'name': 'Teacher', 'email': 'teacher@example.com'},
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('shows classroom overview at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClassroomOverviewHeader(classroom: classroom)),
        ),
      );
      expect(find.text('Class 1'), findsOneWidget);
      expect(find.text('3JZSP2FS'), findsOneWidget);
      expect(find.text('A short class description'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('copies class code', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClassroomOverviewHeader(classroom: classroom)),
      ),
    );
    await tester.tap(find.byTooltip('Copy class code'));
    await tester.pump();
    expect(copied, '3JZSP2FS');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
  });

  testWidgets('centers classroom tabs in the page area', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: TabsBar(selected: 0, onSelected: (_) {})),
        ),
      ),
    );
    expect(
      tester.getCenter(find.byType(SegmentedButton<int>)).dx,
      closeTo(600, 1),
    );
  });

  testWidgets(
    'shows a long description without truncation in a scrollable page',
    (tester) async {
      tester.view.physicalSize = const Size(390, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final longDescription = 'Long description line. ' * 200;
      final longClassroom = Classroom.fromJson({
        'id': 1,
        'code': 'ABC12345',
        'name': 'Class',
        'active': true,
        'description': longDescription,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [ClassroomOverviewHeader(classroom: longClassroom)],
            ),
          ),
        ),
      );
      expect(find.text(longDescription.trim()), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
