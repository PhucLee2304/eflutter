import 'dart:async';

import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'hydrates answers, autosaves, and marks matching ACK as synced',
    () async {
      final remote = _FakeRemoteData();
      final socket = _FakeSocket();
      final cubit = AttemptSessionCubit(ExamRepository(remote), socket);

      await cubit.load(1, initialAttempt: _activeAttempt());
      await Future<void>.delayed(Duration.zero);
      cubit.selectAnswer(11, 102);

      expect(cubit.state.selectedOptions[11], 102);
      expect(socket.sent.single.optionId, 102);
      socket.ack(socket.sent.single.requestId);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.syncStatuses[11], AnswerSyncStatus.synced);

      await cubit.close();
    },
  );

  test('submit sends a complete local answer snapshot', () async {
    final remote = _FakeRemoteData();
    final socket = _FakeSocket();
    final cubit = AttemptSessionCubit(ExamRepository(remote), socket);
    await cubit.load(1, initialAttempt: _activeAttempt());
    await Future<void>.delayed(Duration.zero);
    cubit.selectAnswer(11, 102);
    await cubit.submit();

    expect(remote.submittedAnswers, hasLength(2));
    expect(remote.submittedAnswers.first.selectedOptionId, 102);
    expect(remote.submittedAnswers.last.selectedOptionId, isNull);
    expect(cubit.state.completedAttempt?.status, 'SUBMITTED');
    expect(socket.closed, isTrue);

    await cubit.close();
  });
}

ExamAttempt _activeAttempt() => ExamAttempt.fromJson({
  'id': 1,
  'examId': 2,
  'mode': 'PRACTICE',
  'status': 'ACTIVE',
  'startedAt': '2026-09-09T01:00:00Z',
  'totalQuestions': 2,
  'answeredCount': 1,
  'sections': [
    {
      'id': 3,
      'code': 'FULL',
      'title': 'Full',
      'order': 1,
      'groups': [],
      'questions': [
        {
          'id': 11,
          'content': 'Question one',
          'order': 1,
          'selectedOptionId': 101,
          'options': [
            {'id': 101, 'key': 'A', 'content': 'One', 'order': 1},
            {'id': 102, 'key': 'B', 'content': 'Two', 'order': 2},
          ],
        },
        {
          'id': 12,
          'content': 'Question two',
          'order': 2,
          'options': [
            {'id': 103, 'key': 'A', 'content': null, 'order': 1},
          ],
        },
      ],
    },
  ],
});

class _SentAnswer {
  const _SentAnswer(this.requestId, this.optionId);
  final String requestId;
  final int? optionId;
}

class _FakeSocket implements AttemptSocketGateway {
  final eventController = StreamController<AttemptSocketEvent>.broadcast();
  final statusController = StreamController<AttemptSocketStatus>.broadcast();
  final sent = <_SentAnswer>[];
  bool closed = false;

  @override
  Stream<AttemptSocketEvent> get events => eventController.stream;
  @override
  Stream<AttemptSocketStatus> get statuses => statusController.stream;

  @override
  Future<void> connect() async {
    statusController.add(AttemptSocketStatus.connected);
  }

  @override
  String sendAnswer({
    required int attemptId,
    required int questionId,
    required int? optionId,
  }) {
    final id = 'request-${sent.length + 1}';
    sent.add(_SentAnswer(id, optionId));
    return id;
  }

  void ack(String requestId) => eventController.add(
    AttemptSocketEvent(requestId: requestId, success: true),
  );

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await eventController.close();
    await statusController.close();
  }
}

class _FakeRemoteData implements RemoteDataBase {
  List<SubmitAttemptAnswer> submittedAnswers = [];

  @override
  Future<ExamAttempt> submitAttempt(
    int attemptId,
    List<SubmitAttemptAnswer> answers,
  ) async {
    submittedAnswers = answers;
    final json = _attemptJson('SUBMITTED');
    json['correctAnswers'] = 1;
    json['score'] = 5;
    return ExamAttempt.fromJson(json);
  }

  Map<String, dynamic> _attemptJson(String status) => {
    'id': 1,
    'examId': 2,
    'mode': 'PRACTICE',
    'status': status,
    'startedAt': '2026-09-09T01:00:00Z',
    'totalQuestions': 2,
    'answeredCount': 1,
    'sections': [],
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
