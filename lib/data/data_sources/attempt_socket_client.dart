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

  const AttemptSocketEvent({
    required this.requestId,
    required this.success,
    this.code,
    this.message,
  });
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
    final channel = _channel;
    if (channel == null) throw StateError('Socket is not connected.');
    final requestId = _uuid.v4();
    channel.sink.add(
      jsonEncode({
        'type': 'ATTEMPT_ANSWER_UPDATED',
        'requestId': requestId,
        'payload': {
          'attemptId': attemptId,
          'questionId': questionId,
          'optionId': optionId,
        },
      }),
    );
    return requestId;
  }

  void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type != 'ACK' && type != 'ERROR') return;
      _events.add(
        AttemptSocketEvent(
          requestId: data['requestId'] as String? ?? '',
          success: type == 'ACK',
          code: data['code'] as String?,
          message: data['message'] as String?,
        ),
      );
    } catch (_) {
      // Ignore malformed server messages; they do not belong to a request.
    }
  }

  void _handleDisconnect() {
    _channel = null;
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
