import 'dart:async';
import 'dart:convert';

import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/auth/auth_interceptor.dart';
import 'package:eflutter/data/data_sources/attempt_socket_connector.dart';
import 'package:eflutter/data/data_sources/attempt_socket_protocol.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

export 'package:eflutter/data/data_sources/attempt_socket_protocol.dart';

class AttemptSocketClient implements AttemptSocketGateway {
  AttemptSocketClient(this._auth);

  final AuthInterceptor _auth;
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
    final token = await _auth.freshAccessToken();
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
        onDone: () {
          // Bị khoá tài khoản: đã đăng xuất, đóng hẳn để AttemptSessionCubit không nối lại.
          if (_auth.handleSocketClosed(channel)) {
            unawaited(close());
            return;
          }
          _handleDisconnect();
        },
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
  String sendAnswer({required int attemptId, required int questionId, required int? optionId}) {
    return _send('ATTEMPT_ANSWER_UPDATED', {
      'attemptId': attemptId,
      'questionId': questionId,
      'optionId': optionId,
    });
  }

  @override
  String sendListeningAdvance({required int attemptId, required int page}) =>
      _send('ATTEMPT_LISTENING_ADVANCE', {'attemptId': attemptId, 'page': page});

  @override
  String sendSessionClaim({required int attemptId, String? sessionToken, bool takeover = false}) =>
      _send('ATTEMPT_SESSION_CLAIM', {
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
    channel.sink.add(jsonEncode({'type': type, 'requestId': requestId, 'payload': payload}));
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
