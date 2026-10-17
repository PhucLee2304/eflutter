import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/presentation/classrooms/room_participant_widgets.dart';
import 'package:eflutter/presentation/classrooms/room_participants.dart';
import 'package:eflutter/presentation/classrooms/room_screen_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

RoomParticipantState state(
  String userId, {
  DateTime? requestedAt,
  DateTime? approvedAt,
  DateTime? removedAt,
}) => RoomParticipantState(
  userId: userId,
  microphoneAllowed: true,
  cameraAllowed: true,
  updatedAt: DateTime(2026),
  screenShareRequestedAt: requestedAt,
  screenShareApprovedAt: approvedAt,
  removedAt: removedAt,
);

void main() {
  setUpAll(() {
    if (!getIt.isRegistered<Talker>()) {
      getIt.registerSingleton<Talker>(Talker());
    }
  });

  group('screen share control', () {
    final requested = DateTime(2026, 1, 1, 10);

    test('teachers present directly and students ask first', () {
      RoomScreenShareControl control({
        bool supported = true,
        bool isHost = false,
        bool sharing = false,
        RoomParticipantState? own,
      }) => roomScreenShareControl(
        supported: supported,
        isHost: isHost,
        sharing: sharing,
        ownState: own,
      );

      expect(control(isHost: true), RoomScreenShareControl.start);
      expect(control(), RoomScreenShareControl.request);
      expect(
        control(own: state('s', requestedAt: requested)),
        RoomScreenShareControl.waiting,
      );
      expect(
        control(
          own: state('s', requestedAt: requested, approvedAt: requested),
        ),
        RoomScreenShareControl.start,
      );
      expect(control(sharing: true), RoomScreenShareControl.stop);
      expect(
        control(supported: false, isHost: true),
        RoomScreenShareControl.unavailable,
      );
    });

    test('lists only pending requests, oldest first', () {
      final activity = RoomActivity(
        roomId: 7,
        classroomId: 5,
        status: 'LIVE',
        isHost: true,
        updatedAt: DateTime(2026),
        participants: [
          state('late', requestedAt: requested.add(const Duration(minutes: 2))),
          state('approved', requestedAt: requested, approvedAt: requested),
          state('none'),
          state('removed', requestedAt: requested, removedAt: requested),
          state('early', requestedAt: requested),
        ],
      );

      expect(pendingScreenShareRequests(activity).map((s) => s.userId), [
        'early',
        'late',
      ]);
      expect(pendingScreenShareRequests(null), isEmpty);
    });

    test('prefers the teacher when two shares overlap during replacement', () {
      expect(
        pickRoomPresenter(['student', 'teacher'], (id) => id == 'teacher'),
        'teacher',
      );
      expect(
        pickRoomPresenter(['student-1', 'student-2'], (_) => false),
        'student-1',
      );
      expect(pickRoomPresenter(<String>[], (_) => false), isNull);
    });
  });

  testWidgets('own presentation shows a placeholder instead of a mirror', (
    tester,
  ) async {
    var stopped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 640,
          height: 360,
          child: RoomScreenShareStage(
            presenterName: 'An',
            isLocal: true,
            onStop: () => stopped = true,
          ),
        ),
      ),
    );

    expect(find.text('You are presenting'), findsOneWidget);
    expect(
      find.text('Everyone in the class can see your screen.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Stop presenting'));
    expect(stopped, isTrue);
  });

  testWidgets('viewers see who presents and only teachers can stop it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 640,
          height: 360,
          child: RoomScreenShareStage(presenterName: 'Binh', isLocal: false),
        ),
      ),
    );

    expect(find.text('Binh is presenting'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('teacher reviews requests and cannot double submit', (
    tester,
  ) async {
    final reviews = <String>[];
    Future<void> pump(Set<String> reviewing) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomScreenShareRequests(
            requests: [state('s1', requestedAt: DateTime(2026))],
            nameOf: (id) => id == 's1' ? 'Binh' : 'A student',
            reviewing: reviewing,
            onReview: (id, approve) => reviews.add('$id:$approve'),
          ),
        ),
      ),
    );

    await pump(const {});
    expect(find.text('Binh wants to present'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.tap(find.text('Decline'));
    expect(reviews, ['s1:true', 's1:false']);

    await pump(const {'s1'});
    await tester.tap(find.text('Allow'));
    expect(reviews, hasLength(2));
  });

  testWidgets('participant panel marks presenters and pending requests', (
    tester,
  ) async {
    RoomParticipantView view(
      String id, {
      bool presenting = false,
      bool requested = false,
    }) => RoomParticipantView(
      identity: id,
      name: id,
      isHost: false,
      isLocal: false,
      microphoneOn: true,
      cameraOn: true,
      isSpeaking: false,
      connection: RoomParticipantConnection.good,
      presenting: presenting,
      screenShareRequested: requested,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 500,
            child: RoomParticipantPanel(
              participants: [
                view('Binh', presenting: true),
                view('Chi', requested: true),
              ],
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Student · Presenting'), findsOneWidget);
    expect(find.text('Student · Wants to present'), findsOneWidget);
    expect(find.byTooltip('Presenting'), findsOneWidget);
  });

  test(
    'screen share endpoints use the room path and encode the user',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode:
                      options.path.endsWith('/start') ||
                          options.path.endsWith('/stop')
                      ? 204
                      : 200,
                  data:
                      options.path.endsWith('/start') ||
                          options.path.endsWith('/stop')
                      ? null
                      : {
                          'userId': 'student 1',
                          'microphoneAllowed': true,
                          'cameraAllowed': true,
                          'updatedAt': DateTime.utc(2026).toIso8601String(),
                          'screenShareRequestedAt': DateTime.utc(
                            2026,
                          ).toIso8601String(),
                        },
                ),
              );
            },
          ),
        );
      final repository = ClassroomRepository(dio);

      final requested = await repository.requestScreenShare(5, 7);
      await repository.reviewScreenShare(5, 7, 'student 1', approve: true);
      await repository.reviewScreenShare(5, 7, 'student 1', approve: false);
      final started = await repository.startScreenShare(5, 7);
      await repository.stopScreenShare(5, 7, 'student 1');

      const base = '/classrooms/api/v1/classrooms/5/rooms/7/screen-share';
      expect(requests.map((r) => '${r.method} ${r.path}'), [
        'POST $base/request',
        'POST $base/student%201/approve',
        'POST $base/student%201/reject',
        'POST $base/start',
        'POST $base/student%201/stop',
      ]);
      expect(requested.dataOrNull?.screenShareRequestedAt, isNotNull);
      expect(started, isA<Success<void>>());
    },
  );
}
