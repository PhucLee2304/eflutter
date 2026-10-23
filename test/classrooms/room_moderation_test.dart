import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/presentation/classrooms/room_participant_widgets.dart';
import 'package:eflutter/presentation/classrooms/room_participants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

RoomParticipantView person(
  String id, {
  bool host = false,
  bool local = false,
  bool microphoneAllowed = true,
  bool cameraAllowed = true,
}) => RoomParticipantView(
  identity: id,
  name: id,
  isHost: host,
  isLocal: local,
  microphoneOn: microphoneAllowed,
  cameraOn: cameraAllowed,
  isSpeaking: false,
  connection: RoomParticipantConnection.good,
  microphoneAllowed: microphoneAllowed,
  cameraAllowed: cameraAllowed,
);

void main() {
  setUpAll(() {
    if (!getIt.isRegistered<Talker>()) {
      getIt.registerSingleton<Talker>(Talker());
    }
  });

  Future<void> pumpPanel(
    WidgetTester tester,
    List<RoomParticipantView> people, {
    void Function(String, RoomParticipantAction)? onModerate,
    VoidCallback? onMuteAll,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 600,
          child: RoomParticipantPanel(
            participants: people,
            onClose: () {},
            onModerate: onModerate,
            onMuteAll: onMuteAll,
          ),
        ),
      ),
    ),
  );

  testWidgets('teacher moderates a student from the row menu', (tester) async {
    final actions = <String>[];
    await pumpPanel(tester, [
      person('Co Lan', host: true, local: true),
      person('An'),
    ], onModerate: (id, action) => actions.add('$id:${action.name}'));

    expect(find.byTooltip('More actions for Co Lan'), findsNothing);
    await tester.tap(find.byTooltip('More actions for An'));
    await tester.pumpAndSettle();
    expect(find.text('Mute microphone'), findsOneWidget);
    expect(find.text('Turn off camera'), findsOneWidget);
    expect(find.text('Remove from session'), findsOneWidget);

    await tester.tap(find.text('Mute microphone'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More actions for An'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from session'));
    await tester.pumpAndSettle();
    expect(actions, ['An:mute', 'An:remove']);
  });

  testWidgets('muted students offer allow actions and show why', (
    tester,
  ) async {
    final actions = <RoomParticipantAction>[];
    await pumpPanel(tester, [
      person('An', microphoneAllowed: false, cameraAllowed: false),
    ], onModerate: (_, action) => actions.add(action));

    expect(
      find.text('Student · Muted by teacher · Camera off by teacher'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('More actions for An'));
    await tester.pumpAndSettle();
    expect(find.text('Mute microphone'), findsNothing);
    await tester.tap(find.text('Allow microphone'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More actions for An'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow camera'));
    await tester.pumpAndSettle();
    expect(actions, [
      RoomParticipantAction.allowMicrophone,
      RoomParticipantAction.allowCamera,
    ]);
  });

  testWidgets('mute all is offered only while a student can still talk', (
    tester,
  ) async {
    var mutedAll = false;
    await pumpPanel(
      tester,
      [person('Co Lan', host: true, local: true), person('An')],
      onModerate: (_, _) {},
      onMuteAll: () => mutedAll = true,
    );
    await tester.tap(find.text('Mute all'));
    expect(mutedAll, isTrue);

    await pumpPanel(
      tester,
      [
        person('Co Lan', host: true, local: true),
        person('An', microphoneAllowed: false),
      ],
      onModerate: (_, _) {},
      onMuteAll: () {},
    );
    expect(find.text('Mute all'), findsNothing);
  });

  testWidgets('students never see moderation controls', (tester) async {
    await pumpPanel(tester, [person('An'), person('Binh', local: true)]);

    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('Mute all'), findsNothing);
  });

  test('moderation endpoints target the student and send the reason', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: options.path.endsWith('/mute-all')
                    ? {
                        'userIds': ['an'],
                      }
                    : {
                        'userId': 'student 1',
                        'microphoneAllowed': false,
                        'cameraAllowed': true,
                        'updatedAt': DateTime.utc(2026).toIso8601String(),
                      },
              ),
            );
          },
        ),
      );
    final repository = ClassroomRepository(dio);

    for (final action in RoomDeviceModeration.values) {
      await repository.moderateParticipantDevice(5, 7, 'student 1', action);
    }
    final all = await repository.muteAllParticipants(5, 7);
    await repository.removeParticipant(5, 7, 'student 1', reason: '  Noisy  ');
    await repository.removeParticipant(5, 7, 'student 1', reason: '   ');

    const base = '/classrooms/api/v1/classrooms/5/rooms/7/participants';
    expect(requests.map((r) => '${r.method} ${r.path}'), [
      'POST $base/student%201/mute',
      'POST $base/student%201/allow-microphone',
      'POST $base/student%201/disable-camera',
      'POST $base/student%201/allow-camera',
      'POST $base/mute-all',
      'POST $base/student%201/remove',
      'POST $base/student%201/remove',
    ]);
    expect(requests[5].data, {'reason': 'Noisy'});
    expect(requests[6].data, isNull);
    expect(all.dataOrNull, ['an']);
  });
}
