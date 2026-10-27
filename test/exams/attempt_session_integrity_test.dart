import 'dart:async';

import 'package:eflutter/core/attempt_lock/attempt_integrity_reporter.dart';
import 'package:eflutter/core/attempt_lock/integrity_away_tracker.dart';
import 'package:eflutter/core/attempt_lock/integrity_monitor.dart';
import 'package:eflutter/core/attempt_lock/integrity_session_store.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeSocket socket;
  late _FakeRemote remote;
  late SocketAttemptIntegrityReporter reporter;
  late _FakeMonitor monitor;
  late IntegritySessionStore store;
  late AttemptSessionCubit cubit;

  setUp(() {
    socket = _FakeSocket();
    remote = _FakeRemote();
    reporter = SocketAttemptIntegrityReporter();
    monitor = _FakeMonitor();
    store = IntegritySessionStore()..remove(1);
    cubit = AttemptSessionCubit(
      ExamRepository(remote),
      socket,
      reporter: reporter,
      monitor: monitor,
      sessionStore: store,
    );
  });

  tearDown(() => cubit.close());

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  Future<void> loadAndClaim() async {
    await cubit.load(1, initialAttempt: _attempt());
    await flush();
    socket.reply(
      socket.claims.last.requestId,
      payload: {
        'sessionToken': 'token-1',
        'sessionEpoch': 1,
        'state': {'violationCount': 0, 'maxViolations': 2, 'outcome': 'NONE'},
      },
    );
    await flush();
  }

  test(
    'bài giám sát claim khi nối socket; chưa owned thì không trả lời',
    () async {
      await cubit.load(1, initialAttempt: _attempt());
      await flush();

      expect(socket.claims.single.token, isNull);
      expect(cubit.state.sessionStatus, AttemptSessionStatus.claiming);
      cubit.selectAnswer(11, 101);
      expect(cubit.state.selectedOptions[11], isNull);

      socket.reply(
        socket.claims.single.requestId,
        payload: {'sessionToken': 'token-1', 'sessionEpoch': 1},
      );
      await flush();
      expect(cubit.state.sessionStatus, AttemptSessionStatus.owned);
      expect(store.read(1), 'token-1');
      expect(monitor.tracker, isNotNull);
      cubit.selectAnswer(11, 101);
      expect(socket.answers, hasLength(1));
    },
  );

  test(
    'claim lại sau reconnect dùng token đã lưu; event rời màn gửi kèm epoch',
    () async {
      await loadAndClaim();
      monitor.tracker!.update(focused: false);
      expect(socket.sentEvents.single.type, 'AWAY_START');
      expect(socket.sentEvents.single.epoch, 1);
      expect(socket.sentEvents.single.replayed, isFalse);

      socket.statusController.add(AttemptSocketStatus.disconnected);
      await flush();
      monitor.tracker!.update(focused: true);
      // Quay lại chỉ được chốt sau khoảng ổn định 1,5s.
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(socket.sentEvents, hasLength(1));

      await socket.connect();
      await flush();
      expect(socket.claims.last.token, 'token-1');
      socket.reply(
        socket.claims.last.requestId,
        payload: {'sessionToken': 'token-2', 'sessionEpoch': 1},
      );
      await flush();
      final types = socket.sentEvents.map((event) => event.type).toList();
      expect(types, ['AWAY_START', 'AWAY_START', 'AWAY_END']);
      expect(socket.sentEvents[1].eventId, socket.sentEvents[0].eventId);
      expect(
        socket.sentEvents.skip(1).every((event) => event.replayed),
        isTrue,
      );
      expect(socket.sentEvents[2].startEventId, socket.sentEvents[0].eventId);
    },
  );

  test('các lỗi claim chuyển trạng thái phiên', () async {
    await cubit.load(1, initialAttempt: _attempt());
    await flush();
    socket.reply(socket.claims.last.requestId, code: 'SESSION_IN_USE');
    await flush();
    expect(cubit.state.sessionStatus, AttemptSessionStatus.inUse);
    expect(cubit.state.sessionBlocked, isTrue);

    cubit.retrySessionClaim();
    socket.reply(
      socket.claims.last.requestId,
      code: 'SESSION_RECOVERING',
      details: {'retryAfterMs': 12000},
    );
    await flush();
    expect(cubit.state.sessionStatus, AttemptSessionStatus.recovering);
    expect(cubit.state.sessionRetryAfter, const Duration(seconds: 12));

    cubit.retrySessionClaim();
    socket.reply(
      socket.claims.last.requestId,
      code: 'SESSION_TAKEOVER_REQUIRED',
    );
    await flush();
    expect(cubit.state.sessionStatus, AttemptSessionStatus.takeoverRequired);

    cubit.takeoverSession();
    expect(socket.claims.last.takeover, isTrue);
  });

  test('ATTEMPT_VIOLATION cập nhật x/N và bật cảnh báo', () async {
    await loadAndClaim();
    socket.push('ATTEMPT_VIOLATION', {
      'attemptId': 1,
      'violationCount': 1,
      'maxViolations': 2,
    });
    await flush();

    expect(cubit.state.integrity?.violationCount, 1);
    expect(cubit.state.violationAlerts, 1);
  });

  test('ATTEMPT_VIOLATION_CLEARED giảm x/N, không bật cảnh báo', () async {
    await loadAndClaim();
    socket.push('ATTEMPT_VIOLATION', {
      'attemptId': 1,
      'violationCount': 1,
      'maxViolations': 2,
    });
    socket.push('ATTEMPT_VIOLATION_CLEARED', {
      'attemptId': 1,
      'violationCount': 0,
      'maxViolations': 2,
    });
    await flush();

    expect(cubit.state.integrity?.violationCount, 0);
    expect(cubit.state.violationAlerts, 1);
  });

  test('ATTEMPT_TERMINATED khóa bài, dừng giám sát và tải kết quả', () async {
    await loadAndClaim();
    reporter.report(
      AttemptIntegrityEvent(type: AttemptIntegrityEventType.copy, attemptId: 1),
    );
    socket.push('ATTEMPT_TERMINATED', {
      'attemptId': 1,
      'reason': 'MAX_VIOLATIONS',
    });
    await flush();
    await flush();

    expect(cubit.state.terminated, isTrue);
    expect(cubit.state.terminationReason, 'MAX_VIOLATIONS');
    expect(cubit.state.isLocked, isTrue);
    expect(monitor.stopped, isTrue);
    expect(reporter.pending(1), isEmpty);
    expect(cubit.state.completedAttempt?.isTerminated, isTrue);
  });

  test('ATTEMPT_SESSION_REVOKED chỉ áp khi epoch mới hơn', () async {
    await loadAndClaim();
    socket.push('ATTEMPT_SESSION_REVOKED', {'attemptId': 1, 'sessionEpoch': 1});
    await flush();
    expect(cubit.state.sessionStatus, AttemptSessionStatus.owned);

    socket.push('ATTEMPT_SESSION_REVOKED', {'attemptId': 1, 'sessionEpoch': 2});
    await flush();
    expect(cubit.state.sessionStatus, AttemptSessionStatus.revoked);
  });

  test('ATTEMPT_RESET xóa hàng đợi và token', () async {
    await loadAndClaim();
    socket.statusController.add(AttemptSocketStatus.disconnected);
    await flush();
    reporter.report(
      AttemptIntegrityEvent(
        type: AttemptIntegrityEventType.paste,
        attemptId: 1,
      ),
    );
    socket.push('ATTEMPT_RESET', {'attemptId': 1});
    await flush();

    expect(cubit.state.resetByTeacher, isTrue);
    expect(reporter.pending(1), isEmpty);
    expect(store.read(1), isNull);
  });

  test('bài không giám sát không claim', () async {
    await cubit.load(1, initialAttempt: _attempt(proctored: false));
    await flush();
    expect(socket.claims, isEmpty);
    expect(cubit.state.integrity, isNull);
    cubit.selectAnswer(11, 101);
    expect(socket.answers, hasLength(1));
  });
}

ExamAttempt _attempt({bool proctored = true}) => ExamAttempt.fromJson({
  'id': 1,
  'examId': 2,
  'mode': 'ASSIGNMENT',
  'status': 'ACTIVE',
  'totalQuestions': 1,
  'answeredCount': 0,
  'proctored': proctored,
  if (proctored) ...{
    'maxViolations': 2,
    'violationCount': 0,
    'integrityOutcome': 'NONE',
  },
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
          'content': 'Q',
          'order': 1,
          'options': [
            {'id': 101, 'key': 'A', 'content': 'A', 'order': 1},
          ],
        },
      ],
    },
  ],
});

class _Claim {
  const _Claim(this.requestId, this.token, this.takeover);
  final String requestId;
  final String? token;
  final bool takeover;
}

class _Event {
  const _Event(
    this.type,
    this.eventId,
    this.epoch,
    this.replayed,
    this.startEventId,
  );
  final String type;
  final String eventId;
  final int epoch;
  final bool replayed;
  final String? startEventId;
}

class _FakeSocket implements AttemptSocketGateway {
  final eventController = StreamController<AttemptSocketEvent>.broadcast();
  final statusController = StreamController<AttemptSocketStatus>.broadcast();
  final claims = <_Claim>[];
  final sentEvents = <_Event>[];
  final answers = <String>[];
  var _seq = 0;

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
    final id = 'answer-${++_seq}';
    answers.add(id);
    return id;
  }

  @override
  String sendSessionClaim({
    required int attemptId,
    String? sessionToken,
    bool takeover = false,
  }) {
    final id = 'claim-${++_seq}';
    claims.add(_Claim(id, sessionToken, takeover));
    return id;
  }

  @override
  String sendIntegrityEvent({
    required int attemptId,
    required int sessionEpoch,
    required String eventId,
    required String type,
    required DateTime at,
    bool replayed = false,
    String? startEventId,
    int? clientDurationMs,
    String? detail,
  }) {
    sentEvents.add(_Event(type, eventId, sessionEpoch, replayed, startEventId));
    return 'event-${++_seq}';
  }

  void reply(
    String requestId, {
    String? code,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? details,
  }) => eventController.add(
    AttemptSocketEvent(
      requestId: requestId,
      success: code == null,
      code: code,
      type: code == null ? 'ACK' : 'ERROR',
      payload: payload,
      details: details,
    ),
  );

  void push(String type, Map<String, dynamic> payload) => eventController.add(
    AttemptSocketEvent(
      requestId: '',
      success: true,
      type: type,
      attemptId: payload['attemptId'] as int,
      payload: payload,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> close() async {}
}

class _FakeMonitor implements IntegrityMonitor {
  IntegrityAwayTracker? tracker;
  bool stopped = false;

  @override
  void start({
    required IntegrityAwayTracker tracker,
    required void Function(String type) onClipboard,
  }) => this.tracker = tracker;

  @override
  void stop() => stopped = true;
}

class _FakeRemote implements RemoteDataBase {
  @override
  Future<ExamAttempt> getAttemptHistory(int attemptId) async =>
      ExamAttempt.fromJson({
        'id': 1,
        'examId': 2,
        'mode': 'ASSIGNMENT',
        'status': 'SUBMITTED',
        'proctored': true,
        'maxViolations': 2,
        'violationCount': 3,
        'integrityOutcome': 'TERMINATED',
        'terminationReason': 'MAX_VIOLATIONS',
        'score': 0,
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
