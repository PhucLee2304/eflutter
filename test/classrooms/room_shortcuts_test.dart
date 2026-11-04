import 'package:eflutter/presentation/classrooms/room_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

RoomShortcut? shortcut(
  LogicalKeyboardKey key, {
  PhysicalKeyboardKey? physical,
  bool control = false,
  bool meta = false,
  bool alt = false,
  bool shift = false,
  bool apple = false,
}) => roomShortcutFor(
  logicalKey: key,
  physicalKey: physical ?? PhysicalKeyboardKey.keyQ,
  control: control,
  meta: meta,
  alt: alt,
  shift: shift,
  apple: apple,
);

RoomShortcutDecision decide(
  RoomShortcut shortcut, {
  bool roomActive = true,
  bool editingText = false,
  bool isHost = false,
  bool microphoneOn = false,
  bool microphoneAllowed = true,
  bool cameraOn = false,
  bool cameraAllowed = true,
}) => roomShortcutDecision(
  shortcut,
  roomActive: roomActive,
  editingText: editingText,
  isHost: isHost,
  microphoneOn: microphoneOn,
  microphoneAllowed: microphoneAllowed,
  cameraOn: cameraOn,
  cameraAllowed: cameraAllowed,
);

void main() {
  group('roomShortcutFor', () {
    test('maps Ctrl+D, Ctrl+E and Ctrl+Alt+H off Apple platforms', () {
      expect(
        shortcut(LogicalKeyboardKey.keyD, control: true),
        RoomShortcut.toggleMicrophone,
      );
      expect(
        shortcut(LogicalKeyboardKey.keyE, control: true),
        RoomShortcut.toggleCamera,
      );
      expect(
        shortcut(LogicalKeyboardKey.keyH, control: true, alt: true),
        RoomShortcut.toggleHand,
      );
    });

    test('uses Cmd on Apple platforms and ignores Ctrl there', () {
      expect(
        shortcut(LogicalKeyboardKey.keyD, meta: true, apple: true),
        RoomShortcut.toggleMicrophone,
      );
      expect(
        shortcut(LogicalKeyboardKey.keyD, control: true, apple: true),
        isNull,
      );
      expect(shortcut(LogicalKeyboardKey.keyD, meta: true), isNull);
    });

    test('rejects extra or missing modifiers', () {
      expect(shortcut(LogicalKeyboardKey.keyD), isNull);
      expect(
        shortcut(LogicalKeyboardKey.keyD, control: true, shift: true),
        isNull,
      );
      expect(
        shortcut(LogicalKeyboardKey.keyD, control: true, alt: true),
        isNull,
      );
      expect(shortcut(LogicalKeyboardKey.keyH, control: true), isNull);
      expect(
        shortcut(LogicalKeyboardKey.keyD, control: true, meta: true),
        isNull,
      );
    });

    test(
      'falls back to the physical key when Option changes the character',
      () {
        expect(
          shortcut(
            const LogicalKeyboardKey(0x02d9), // "˙" from Option+H on macOS.
            physical: PhysicalKeyboardKey.keyH,
            meta: true,
            alt: true,
            apple: true,
          ),
          RoomShortcut.toggleHand,
        );
      },
    );

    test('prefers the typed character over the physical position', () {
      expect(
        shortcut(
          LogicalKeyboardKey.keyE,
          physical: PhysicalKeyboardKey.keyD,
          control: true,
        ),
        RoomShortcut.toggleCamera,
      );
    });
  });

  group('roomShortcutDecision', () {
    test('ignores shortcuts while typing or outside an active room', () {
      for (final value in RoomShortcut.values) {
        expect(decide(value, editingText: true), RoomShortcutDecision.ignore);
        expect(decide(value, roomActive: false), RoomShortcutDecision.ignore);
      }
    });

    test('does not turn on a device the teacher locked', () {
      expect(
        decide(RoomShortcut.toggleMicrophone, microphoneAllowed: false),
        RoomShortcutDecision.locked,
      );
      expect(
        decide(RoomShortcut.toggleCamera, cameraAllowed: false),
        RoomShortcutDecision.locked,
      );
    });

    test('still turns off a locked device that is on', () {
      expect(
        decide(
          RoomShortcut.toggleMicrophone,
          microphoneOn: true,
          microphoneAllowed: false,
        ),
        RoomShortcutDecision.run,
      );
      expect(
        decide(RoomShortcut.toggleCamera, cameraOn: true, cameraAllowed: false),
        RoomShortcutDecision.run,
      );
    });

    test('raising a hand is only for students', () {
      expect(decide(RoomShortcut.toggleHand), RoomShortcutDecision.run);
      expect(
        decide(RoomShortcut.toggleHand, isHost: true),
        RoomShortcutDecision.ignore,
      );
      expect(
        decide(RoomShortcut.toggleMicrophone, isHost: true),
        RoomShortcutDecision.run,
      );
    });
  });

  test('labels shortcuts for each platform', () {
    expect(
      roomShortcutLabel(RoomShortcut.toggleMicrophone, apple: false),
      'Ctrl+D',
    );
    expect(roomShortcutLabel(RoomShortcut.toggleCamera, apple: true), 'Cmd+E');
    expect(
      roomShortcutLabel(RoomShortcut.toggleHand, apple: false),
      'Ctrl+Alt+H',
    );
    expect(
      roomShortcutLabel(RoomShortcut.toggleHand, apple: true),
      'Cmd+Option+H',
    );
  });

  testWidgets('detects focus inside a text field', (tester) async {
    final buttonFocus = FocusNode();
    final fieldFocus = FocusNode();
    addTearDown(buttonFocus.dispose);
    addTearDown(fieldFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextButton(
                focusNode: buttonFocus,
                onPressed: () {},
                child: const Text('Button'),
              ),
              TextField(focusNode: fieldFocus),
            ],
          ),
        ),
      ),
    );

    buttonFocus.requestFocus();
    await tester.pump();
    expect(roomTextInputFocused(), isFalse);

    fieldFocus.requestFocus();
    await tester.pump();
    expect(roomTextInputFocused(), isTrue);
  });
}
