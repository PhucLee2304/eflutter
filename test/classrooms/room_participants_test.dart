import 'package:eflutter/presentation/classrooms/room_device_settings.dart';
import 'package:eflutter/presentation/classrooms/room_participant_widgets.dart';
import 'package:eflutter/presentation/classrooms/room_participants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    show ConnectionQuality, MediaDevice;

RoomParticipantView participant(
  String identity, {
  String? name,
  bool host = false,
  bool local = false,
  bool microphoneOn = true,
  bool cameraOn = true,
  RoomParticipantConnection connection = RoomParticipantConnection.good,
  DateTime? handRaisedAt,
}) => RoomParticipantView(
  identity: identity,
  name: name ?? identity,
  isHost: host,
  isLocal: local,
  microphoneOn: microphoneOn,
  cameraOn: cameraOn,
  isSpeaking: false,
  connection: connection,
  handRaisedAt: handRaisedAt,
);

void main() {
  group('participant ordering', () {
    test('puts the teacher first, raised hands next, then names', () {
      final sorted = [
        participant('s-zed', name: 'Zed'),
        participant('s-anna', name: 'anna'),
        participant(
          's-late',
          name: 'Late',
          handRaisedAt: DateTime(2026, 1, 1, 10, 5),
        ),
        participant('t', name: 'Teacher', host: true),
        participant(
          's-early',
          name: 'Early',
          handRaisedAt: DateTime(2026, 1, 1, 10),
        ),
      ]..sort(compareRoomParticipants);

      expect(sorted.map((p) => p.identity), [
        't',
        's-early',
        's-late',
        's-anna',
        's-zed',
      ]);
    });

    test('keeps grid order stable when hands are raised', () {
      final sorted = [
        participant('b', name: 'B', handRaisedAt: DateTime(2026)),
        participant('a', name: 'A'),
      ]..sort((a, b) => compareRoomParticipants(a, b, byHand: false));

      expect(sorted.map((p) => p.identity), ['a', 'b']);
    });

    test('keeps one row per identity, preferring the first entry', () {
      final deduped = dedupeRoomParticipants([
        participant('me', name: 'Local copy', local: true),
        participant('other'),
        participant('me', name: 'Stale remote copy'),
      ], (p) => p.identity);

      expect(deduped.map((p) => p.name), ['Local copy', 'other']);
    });

    test('searches by display name, ignoring case and spaces', () {
      final people = [
        participant('1', name: 'Nguyen Van An'),
        participant('2', name: 'Tran Thi Binh'),
        participant('fallback-id', name: '  '),
      ];

      expect(filterRoomParticipants(people, '  van ').map((p) => p.identity), [
        '1',
      ]);
      expect(
        filterRoomParticipants(people, 'FALLBACK').single.identity,
        'fallback-id',
      );
      expect(filterRoomParticipants(people, ''), hasLength(3));
    });
  });

  test('maps LiveKit connection quality to a visible status', () {
    expect(
      roomParticipantConnection(
        quality: ConnectionQuality.excellent,
        reconnecting: false,
      ),
      RoomParticipantConnection.good,
    );
    expect(
      roomParticipantConnection(
        quality: ConnectionQuality.poor,
        reconnecting: false,
      ),
      RoomParticipantConnection.weak,
    );
    expect(
      roomParticipantConnection(
        quality: ConnectionQuality.lost,
        reconnecting: false,
      ),
      RoomParticipantConnection.reconnecting,
    );
    expect(
      roomParticipantConnection(
        quality: ConnectionQuality.good,
        reconnecting: true,
      ),
      RoomParticipantConnection.reconnecting,
    );
  });

  test('falls back to the first device when the selected one is unplugged', () {
    const usb = MediaDevice('usb', 'USB mic', 'audioinput', null);
    const builtIn = MediaDevice('built-in', 'Built-in mic', 'audioinput', null);

    expect(resolveRoomDevice(usb, const [builtIn, usb])?.deviceId, 'usb');
    expect(resolveRoomDevice(usb, const [builtIn])?.deviceId, 'built-in');
    expect(resolveRoomDevice(null, const [builtIn])?.deviceId, 'built-in');
    expect(resolveRoomDevice(usb, const []), isNull);
  });

  group('participant panel', () {
    Future<void> pumpPanel(
      WidgetTester tester,
      List<RoomParticipantView> people,
    ) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 600,
            child: RoomParticipantPanel(participants: people, onClose: () {}),
          ),
        ),
      ),
    );

    testWidgets('groups the teacher and lists students with their status', (
      tester,
    ) async {
      await pumpPanel(tester, [
        participant(
          's1',
          name: 'Binh',
          microphoneOn: false,
          connection: RoomParticipantConnection.weak,
        ),
        participant('t', name: 'Co Lan', host: true),
        participant(
          'me',
          name: 'An',
          local: true,
          cameraOn: false,
          handRaisedAt: DateTime(2026),
        ),
      ]);

      expect(find.text('People (3)'), findsOneWidget);
      // Tiêu đề nhóm và vai trò ở dòng giáo viên.
      expect(find.text('Teacher'), findsNWidgets(2));
      expect(find.text('Students (2)'), findsOneWidget);
      expect(find.text('An (You)'), findsOneWidget);
      expect(find.text('Student · Weak connection'), findsOneWidget);
      expect(find.byTooltip('Hand raised'), findsOneWidget);
      expect(find.byTooltip('Microphone off'), findsOneWidget);
      expect(find.byTooltip('Camera off'), findsOneWidget);

      final anTop = tester.getTopLeft(find.text('An (You)')).dy;
      final binhTop = tester.getTopLeft(find.text('Binh')).dy;
      expect(anTop, lessThan(binhTop), reason: 'raised hand is listed first');
    });

    testWidgets('filters by name and shows an empty state', (tester) async {
      await pumpPanel(tester, [
        participant('t', name: 'Co Lan', host: true),
        participant('s1', name: 'Binh'),
      ]);

      await tester.enterText(find.byType(TextField), 'bin');
      await tester.pump();
      expect(find.text('Binh'), findsOneWidget);
      expect(find.text('Co Lan'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pump();
      expect(find.text('No participants found'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('Co Lan'), findsOneWidget);
    });
  });

  testWidgets(
    'tile shows mic, role and reconnecting state without relying on color',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 200,
            child: RoomParticipantTile(
              participant: participant(
                't',
                name: 'Co Lan',
                host: true,
                microphoneOn: false,
                cameraOn: false,
                connection: RoomParticipantConnection.reconnecting,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_off), findsOneWidget);
      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('Reconnecting'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Co Lan, teacher, microphone off, camera off, Reconnecting',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'device dialog follows device changes and explains missing speakers',
    (tester) async {
      const first = MediaDevice('mic-1', 'Headset', 'audioinput', null);
      const second = MediaDevice('mic-2', 'Laptop mic', 'audioinput', null);
      final options = ValueNotifier(
        const RoomDeviceOptions(
          microphones: [first, second],
          cameras: [],
          speakers: [],
          microphone: first,
        ),
      );
      addTearDown(options.dispose);
      MediaDevice? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: RoomDeviceSettingsDialog(
            options: options,
            onMicrophoneChanged: (device) async => selected = device,
            onCameraChanged: (_) async {},
            onSpeakerChanged: (_) async {},
          ),
        ),
      );

      expect(find.text('Headset'), findsOneWidget);
      expect(find.text('No camera found'), findsOneWidget);
      expect(
        find.textContaining('Speaker selection is not supported'),
        findsOneWidget,
      );

      await tester.tap(find.text('Headset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Laptop mic').last);
      await tester.pumpAndSettle();
      expect(selected?.deviceId, 'mic-2');

      // Headset bị rút: màn hình phòng cập nhật options, dialog phải theo kịp.
      options.value = const RoomDeviceOptions(
        microphones: [second],
        cameras: [],
        speakers: [],
        microphone: second,
      );
      await tester.pump();
      expect(find.text('Headset'), findsNothing);
      expect(find.text('Laptop mic'), findsOneWidget);
    },
  );
}
