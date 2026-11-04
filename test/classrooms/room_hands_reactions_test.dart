import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/presentation/classrooms/room_participant_widgets.dart';
import 'package:eflutter/presentation/classrooms/room_participants.dart';
import 'package:eflutter/presentation/classrooms/room_reactions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

RoomParticipantView person(
  String id, {
  bool host = false,
  DateTime? handRaisedAt,
}) => RoomParticipantView(
  identity: id,
  name: id,
  isHost: host,
  isLocal: false,
  microphoneOn: true,
  cameraOn: true,
  isSpeaking: false,
  connection: RoomParticipantConnection.good,
  handRaisedAt: handRaisedAt,
);

void main() {
  setUpAll(() {
    if (!getIt.isRegistered<Talker>()) {
      getIt.registerSingleton<Talker>(Talker());
    }
  });

  group('reaction packets', () {
    test('round-trips every allowed reaction without sender identity', () {
      for (final reaction in RoomReaction.values) {
        final packet = encodeRoomReaction(reaction);
        expect(packet.length, lessThanOrEqualTo(roomReactionMaxBytes));
        expect(decodeRoomReaction(packet), reaction);
        expect(
          (jsonDecode(utf8.decode(packet)) as Map).keys,
          isNot(contains('userId')),
        );
      }
    });

    test('rejects unknown, malformed and oversized packets', () {
      expect(decodeRoomReaction(utf8.encode('{"reaction":"bomb"}')), isNull);
      expect(decodeRoomReaction(utf8.encode('not json')), isNull);
      expect(decodeRoomReaction(utf8.encode('["clap"]')), isNull);
      expect(decodeRoomReaction(const []), isNull);
      final oversized = utf8.encode(
        jsonEncode({'reaction': 'clap', 'padding': 'x' * 80}),
      );
      expect(decodeRoomReaction(oversized), isNull);
    });
  });

  test('limits reactions per sender within a sliding window', () {
    final limiter = RoomReactionLimiter(
      maxEvents: 3,
      window: const Duration(seconds: 3),
    );
    final start = DateTime(2026, 1, 1, 10);

    expect(
      [
        for (var i = 0; i < 4; i++)
          limiter.allow('an', start.add(Duration(milliseconds: i * 100))),
      ],
      [true, true, true, false],
    );
    expect(limiter.allow('binh', start), isTrue, reason: 'limits are per key');
    expect(limiter.allow('an', start.add(const Duration(seconds: 3))), isTrue);
  });

  test('keeps only the newest visible reactions', () {
    var bubbles = <RoomReactionBubble>[];
    for (var i = 0; i < roomReactionMaxVisible + 3; i++) {
      bubbles = addRoomReactionBubble(
        bubbles,
        RoomReactionBubble(
          id: i,
          reaction: RoomReaction.clap,
          senderName: '$i',
        ),
      );
    }
    expect(bubbles, hasLength(roomReactionMaxVisible));
    expect(bubbles.first.id, 3);
    expect(bubbles.last.id, roomReactionMaxVisible + 2);
  });

  testWidgets('reaction overlay shows the sender and fades out', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoomReactionOverlay(
            bubbles: [
              RoomReactionBubble(
                id: 1,
                reaction: RoomReaction.clap,
                senderName: 'Binh',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('👏'), findsOneWidget);
    expect(find.text('Binh'), findsOneWidget);
    expect(find.bySemanticsLabel('Binh: Clap'), findsOneWidget);
    await tester.pump(roomReactionDisplayDuration);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Binh'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, lessThan(0.05));
  });

  testWidgets('teacher lowers one or all raised hands from the panel', (
    tester,
  ) async {
    final lowered = <String>[];
    var loweredAll = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 500,
            child: RoomParticipantPanel(
              participants: [
                person('teacher', host: true),
                person('An', handRaisedAt: DateTime(2026, 1, 1, 10, 1)),
                person('Binh', handRaisedAt: DateTime(2026, 1, 1, 10)),
                person('Chi'),
              ],
              onClose: () {},
              onLowerHand: lowered.add,
              onLowerAllHands: () => loweredAll = true,
            ),
          ),
        ),
      ),
    );

    final binhTop = tester.getTopLeft(find.text('Binh')).dy;
    final anTop = tester.getTopLeft(find.text('An')).dy;
    final chiTop = tester.getTopLeft(find.text('Chi')).dy;
    expect(binhTop, lessThan(anTop), reason: 'earliest hand first');
    expect(anTop, lessThan(chiTop));

    await tester.tap(find.byTooltip("Lower An's hand"));
    expect(lowered, ['An']);
    await tester.tap(find.text('Lower all'));
    expect(loweredAll, isTrue);
  });

  testWidgets('students see hand state without lowering actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: RoomParticipantPanel(
              participants: [person('An', handRaisedAt: DateTime(2026))],
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Hand raised'), findsOneWidget);
    expect(find.text('Lower all'), findsNothing);
    expect(find.byTooltip("Lower An's hand"), findsNothing);
  });

  testWidgets('tile marks a raised hand in text and semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 200,
          child: RoomParticipantTile(
            participant: person('An', handRaisedAt: DateTime(2026)),
          ),
        ),
      ),
    );

    expect(find.text('Hand raised'), findsOneWidget);
    expect(
      find.bySemanticsLabel('An, microphone on, camera on, hand raised'),
      findsOneWidget,
    );
  });

  test('hand endpoints send the raised flag and encode the student', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: options.method == 'PATCH'
                    ? {
                        'userId': 'an',
                        'microphoneAllowed': true,
                        'cameraAllowed': true,
                        'updatedAt': DateTime.utc(2026).toIso8601String(),
                        'handRaisedAt': DateTime.utc(2026).toIso8601String(),
                      }
                    : {
                        'userIds': ['an', 'binh'],
                      },
              ),
            );
          },
        ),
      );
    final repository = ClassroomRepository(dio);

    final raised = await repository.setHandRaised(5, 7, raised: true);
    final all = await repository.lowerHands(5, 7);
    await repository.lowerHands(5, 7, userId: 'student 1');

    const base = '/classrooms/api/v1/classrooms/5/rooms/7';
    expect(requests.map((r) => '${r.method} ${r.path}'), [
      'PATCH $base/hand',
      'DELETE $base/hands',
      'DELETE $base/hands/student%201',
    ]);
    expect(requests.first.data, {'raised': true});
    expect(raised.dataOrNull?.handRaisedAt, isNotNull);
    expect(all.dataOrNull, ['an', 'binh']);
  });
}
