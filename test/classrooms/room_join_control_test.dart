import 'package:eflutter/presentation/classrooms/room_join_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in {
    'SCHEDULED': 'Waiting for the teacher to start',
    'ENDED': 'Class has ended',
  }.entries) {
    testWidgets('${entry.key} disables joining', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoomJoinControl(
              status: entry.key,
              connecting: false,
              onJoin: () {},
            ),
          ),
        ),
      );

      expect(find.text(entry.value), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });
  }

  testWidgets('LIVE enables joining', (tester) async {
    var joined = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomJoinControl(
            status: 'LIVE',
            connecting: false,
            onJoin: () => joined = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Join classroom'));
    expect(joined, isTrue);
  });

  testWidgets('shows LiveKit unavailable and disables while connecting', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomJoinControl(
            status: 'LIVE',
            connecting: true,
            error: 'LiveKit is temporarily unavailable',
            onJoin: () {},
          ),
        ),
      ),
    );

    expect(find.text('LiveKit is temporarily unavailable'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
