import 'dart:async';
import 'dart:convert';

import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/data/data_sources/attempt_socket_connector.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum AttemptSocketStatus { disconnected, connecting, connected }

class AttemptSocketEvent {
  final String requestId;
  final bool success;
  final String? code;
  final String? message;
  final String? type;
  final int? attemptId;

  /// Payload của ACK (vd `ListeningState` cho ATTEMPT_LISTENING_ADVANCE).
  final Map<String, dynamic>? payload;

  /// Dữ liệu kèm lỗi (vd `retryAfterMs` của SESSION_RECOVERING).
  final Map<String, dynamic>? details;

  const AttemptSocketEvent({
    required this.requestId,
    required this.success,
    this.code,
    this.message,
    this.type,
    this.attemptId,
    this.payload,
    this.details,
  });
}

/// Mã lỗi WS của luồng TOEIC_STRICT (PLAN_TOEIC_ATTEMPT.md mục 1.5).
abstract final class AttemptSocketCode {
  static const questionLocked = 'QUESTION_LOCKED';
  static const pageLocked = 'PAGE_LOCKED';
  static const listeningPageMismatch = 'LISTENING_PAGE_MISMATCH';
  static const listeningAdvanceTooEarly = 'LISTENING_ADVANCE_TOO_EARLY';
  static const attemptExpired = 'ATTEMPT_EXPIRED';
  static const attemptNotActive = 'ATTEMPT_NOT_ACTIVE';
  static const attemptNotFound = 'ATTEMPT_NOT_FOUND';

  // Giám sát (PLAN_ATTEMPT_INTEGRITY.md mục 1.9).
  static const attemptNotProctored = 'ATTEMPT_NOT_PROCTORED';
  static const sessionInUse = 'SESSION_IN_USE';
  static const sessionRecovering = 'SESSION_RECOVERING';
  static const sessionTakeoverRequired = 'SESSION_TAKEOVER_REQUIRED';
  static const integrityEventInvalid = 'INTEGRITY_EVENT_INVALID';
}

/// Push server gửi tới học sinh, payload luôn có `attemptId`.
abstract final class AttemptSocketPush {
  static const submitting = 'ATTEMPT_SUBMITTING';
  static const submitted = 'ATTEMPT_SUBMITTED';
  static const violation = 'ATTEMPT_VIOLATION';

  /// Giáo viên cho tiếp tục làm bài: vi phạm được xóa, số vi phạm giảm.
  static const violationCleared = 'ATTEMPT_VIOLATION_CLEARED';
  static const terminated = 'ATTEMPT_TERMINATED';
  static const sessionRevoked = 'ATTEMPT_SESSION_REVOKED';
  static const reset = 'ATTEMPT_RESET';

  static const all = {
    submitting,
    submitted,
    violation,
    terminated,
    sessionRevoked,
    reset,
  };
}

abstract interface class AttemptSocketGateway {
  Stream<AttemptSocketEvent> get events;
  Stream<AttemptSocketStatus> get statuses;
  Future<void> connect();
  String sendAnswer({
    required int attemptId,
    required int questionId,
    required int? optionId,
  });
  String sendListeningAdvance({required int attemptId, required int page});
  String sendSessionClaim({
    required int attemptId,
    String? sessionToken,
    bool takeover = false,
  });
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
  });
  Future<void> close();
}

class AttemptSocketClient implements AttemptSocketGateway {
  AttemptSocketClient(this._localData);

  final LocalDataBase _localData;
  final _events = StreamController<AttemptSocketEvent>.broadcast();
  final _statuses = StreamController<AttemptSocketStatus>.broadcast();
  final _uuid = const Uuid();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  @override
  Stream<AttemptSocketEvent> get events => _events.stream;
  @override
  Stream<AttemptSocketStatus> get statuses => _statuses.stream;

  @override
  Future<void> connect() async {
    if (_channel != null || _closed) return;
    _statuses.add(AttemptSocketStatus.connecting);
    final token = await _localData.getAccessToken();
    if (token == null || token.isEmpty) {
      _statuses.add(AttemptSocketStatus.disconnected);
      throw StateError('Authentication token is missing.');
    }

    final uri = _socketUri();
    final channel = connectAttemptSocket(uri, token);
    _channel = channel;
    try {
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
      await channel.ready;
      if (!_closed) _statuses.add(AttemptSocketStatus.connected);
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      _channel = null;
      if (!_closed) _statuses.add(AttemptSocketStatus.disconnected);
      rethrow;
    }
  }

  @override
  String sendAnswer({
    required int attemptId,
    required int questionId,
    required int? optionId,
  }) {
    return _send('ATTEMPT_ANSWER_UPDATED', {
      'attemptId': attemptId,
      'questionId': questionId,
      'optionId': optionId,
    });
  }

  @override
  String sendListeningAdvance({required int attemptId, required int page}) =>
      _send('ATTEMPT_LISTENING_ADVANCE', {
        'attemptId': attemptId,
        'page': page,
      });

  @override
  String sendSessionClaim({
    required int attemptId,
    String? sessionToken,
    bool takeover = false,
  }) => _send('ATTEMPT_SESSION_CLAIM', {
    'attemptId': attemptId,
    'sessionToken': ?sessionToken,
    if (takeover) 'takeover': true,
  });

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
  }) => _send('ATTEMPT_INTEGRITY_EVENT', {
    'attemptId': attemptId,
    'sessionEpoch': sessionEpoch,
    'eventId': eventId,
    'type': type,
    'at': at.toUtc().toIso8601String(),
    if (replayed) 'replayed': true,
    'startEventId': ?startEventId,
    'clientDurationMs': ?clientDurationMs,
    'detail': ?detail,
  });

  String _send(String type, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) throw StateError('Socket is not connected.');
    final requestId = _uuid.v4();
    channel.sink.add(
      jsonEncode({'type': type, 'requestId': requestId, 'payload': payload}),
    );
    return requestId;
  }

  void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (AttemptSocketPush.all.contains(type)) {
        final payload = data['payload'] as Map<String, dynamic>?;
        _events.add(
          AttemptSocketEvent(
            requestId: '',
            success: true,
            type: type,
            attemptId: (payload?['attemptId'] as num?)?.toInt(),
            payload: payload,
          ),
        );
        return;
      }
      if (type != 'ACK' && type != 'ERROR') return;
      _events.add(
        AttemptSocketEvent(
          requestId: data['requestId'] as String? ?? '',
          success: type == 'ACK',
          code: data['code'] as String?,
          message: data['message'] as String?,
          type: type,
          payload: data['payload'] is Map<String, dynamic>
              ? data['payload'] as Map<String, dynamic>
              : null,
          details: data['details'] is Map<String, dynamic>
              ? data['details'] as Map<String, dynamic>
              : null,
        ),
      );
    } catch (_) {
      // Ignore malformed server messages; they do not belong to a request.
    }
  }

  void _handleDisconnect() {
    _channel = null;
    // AttemptSessionCubit owns reconnect timing and resends every answer whose
    // latest request has not been acknowledged.
    if (!_closed) _statuses.add(AttemptSocketStatus.disconnected);
  }

  Uri _socketUri() {
    final base = Uri.parse(AppConfig.baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/exams/api/v1/ws/exams',
      query: null,
      fragment: null,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    await _events.close();
    await _statuses.close();
  }
}
