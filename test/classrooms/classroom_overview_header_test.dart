import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/presentation/classrooms/classroom_detail_header.dart';
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

  Widget banner(Classroom item) => ClassroomBanner(
    classroom: item,
    canManage: true,
    busy: false,
    onEdit: () {},
    onArchive: () {},
  );

  for (final width in [390.0, 1280.0]) {
    testWidgets('shows classroom banner at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: banner(classroom))));
      expect(find.text('Class 1'), findsOneWidget);
      expect(find.text('3JZSP2FS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('copies class code', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: banner(classroom))));
    await tester.tap(find.byTooltip('Copy class code'));
    await tester.pump();
    expect(copied, '3JZSP2FS');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
  });

  testWidgets('classroom tabs report the tapped tab', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClassroomTabs(selected: 0, onSelected: (value) => selected = value)),
      ),
    );
    for (final label in ClassroomTabs.labels) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('People'));
    expect(selected, 3);
  });

  testWidgets('long description is capped with See more', (tester) async {
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
            children: [
              ClassroomStreamAside(
                classroom: longClassroom,
                assignments: const [],
                onOpenAssignment: (_) {},
                onViewAll: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text(longDescription.trim()));
    expect(text.maxLines, 6);
    await tester.tap(find.text('See more'));
    await tester.pump();
    expect(tester.widget<Text>(find.text(longDescription.trim())).maxLines, isNull);
    expect(find.text('See less'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
