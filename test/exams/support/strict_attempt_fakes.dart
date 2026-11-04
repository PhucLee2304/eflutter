import 'dart:async';

import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/data/models/attempt_page.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:dio/dio.dart';

/// Attempt TOEIC_STRICT 3 trang: 0 = Part 1 (câu 1), 1 = Part 2 (câu 2), 2 = Part 5 (câu 3).
ExamAttempt strictAttempt() => ExamAttempt.fromJson({
  'id': 1,
  'examId': 2,
  'mode': 'TEST',
  'status': 'ACTIVE',
  'flow': 'TOEIC_STRICT',
  'stage': 'LISTENING',
  'totalQuestions': 3,
  'answeredCount': 0,
});

Map<String, dynamic> navigatorJson({
  String stage = 'LISTENING',
  int? current = 0,
}) => {
  'flow': 'TOEIC_STRICT',
  'stage': stage,
  'currentPage': ?current,
  'serverTime': '2026-10-26T01:00:00Z',
  'totalQuestions': 3,
  'answeredCount': 1,
  'pages': [
    {
      'index': 0,
      'section': 'LISTENING',
      'part': 'PART_1',
      'questions': [
        {'id': 11, 'number': 1, 'answered': true, 'locked': false},
      ],
    },
    {
      'index': 1,
      'section': 'LISTENING',
      'part': 'PART_2',
      'questions': [
        {'id': 12, 'number': 7, 'answered': false, 'locked': true},
      ],
    },
    {
      'index': 2,
      'section': 'READING',
      'part': 'PART_5',
      'questions': [
        {'id': 13, 'number': 101, 'answered': false, 'locked': true},
      ],
    },
  ],
};

Map<String, dynamic> pageJson(
  int index, {
  int elapsedMs = 0,
  int audioMs = 4000,
}) => {
  'index': index,
  'section': index < 2 ? 'LISTENING' : 'READING',
  'group': {
    'title': '',
    'instruction': '',
    'audioUrl': index < 2 ? 'https://cdn/a$index.mp3' : null,
    'audioDurationMs': index < 2 ? audioMs : null,
  },
  'questions': [
    {
      'id': 11 + index,
      'number': index + 1,
      'content': '',
      'selectedOptionId': index == 0 ? 101 : null,
      'options': [
        {'id': 101 + index * 10, 'key': 'A', 'content': null},
      ],
    },
  ],
  if (index < 2)
    'listening': {
      'elapsedMs': elapsedMs,
      'gapMs': 5000,
      'minAdvanceAt': '2026-10-26T01:00:02Z',
    },
};

class FakeStrictRemote implements RemoteDataBase {
  Map<String, dynamic> navigator = navigatorJson();
  final pages = <int, Map<String, dynamic>>{
    for (var i = 0; i < 3; i++) i: pageJson(i),
  };
  final lockedPages = <int>{};
  int navigatorCalls = 0;
  final pageCalls = <int>[];

  @override
  Future<AttemptNavigator> getAttemptNavigator(int attemptId) async {
    navigatorCalls++;
    return AttemptNavigator.fromJson(navigator);
  }

  @override
  Future<AttemptPage> getAttemptPage(int attemptId, int index) async {
    pageCalls.add(index);
    if (lockedPages.contains(index)) {
      final options = RequestOptions(path: '/pages/$index');
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 409),
        type: DioExceptionType.badResponse,
      );
    }
    return AttemptPage.fromJson(pages[index]!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SentAdvance {
  const SentAdvance(this.requestId, this.page);
  final String requestId;
  final int page;
}

class FakeStrictSocket implements AttemptSocketGateway {
  final eventController = StreamController<AttemptSocketEvent>.broadcast();
  final statusController = StreamController<AttemptSocketStatus>.broadcast();
  final answers = <String>[];
  final advances = <SentAdvance>[];
  bool connected = true;

  @override
  Stream<AttemptSocketEvent> get events => eventController.stream;
  @override
  Stream<AttemptSocketStatus> get statuses => statusController.stream;

  @override
  Future<void> connect() async =>
      statusController.add(AttemptSocketStatus.connected);

  @override
  String sendAnswer({
    required int attemptId,
    required int questionId,
    required int? optionId,
  }) {
    final id = 'answer-${answers.length + 1}';
    answers.add(id);
    return id;
  }

  @override
  String sendListeningAdvance({required int attemptId, required int page}) {
    if (!connected) throw StateError('Socket is not connected.');
    final id = 'advance-${advances.length + 1}';
    advances.add(SentAdvance(id, page));
    return id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void reply(String requestId, {String? code, Map<String, dynamic>? payload}) =>
      eventController.add(
        AttemptSocketEvent(
          requestId: requestId,
          success: code == null,
          code: code,
          type: code == null ? 'ACK' : 'ERROR',
          payload: payload,
        ),
      );

  @override
  Future<void> close() async {}
}
