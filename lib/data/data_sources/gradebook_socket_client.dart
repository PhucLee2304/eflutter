import 'dart:async';
import 'dart:convert';

import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/data/data_sources/attempt_socket_connector.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum GradebookSocketStatus { disconnected, connecting, connected }

class GradebookSocketEvent {
  const GradebookSocketEvent({
    required this.classroomId,
    required this.assignmentId,
  });

  final int classroomId;
  final int assignmentId;
}

abstract interface class GradebookSocketGateway {
  Stream<GradebookSocketEvent> get events;
  Stream<GradebookSocketStatus> get statuses;
  Future<void> connect();
  Future<void> close();
}

class GradebookSocketClient implements GradebookSocketGateway {
  GradebookSocketClient(this._localData);

  final LocalDataBase _localData;
  final _events = StreamController<GradebookSocketEvent>.broadcast();
  final _statuses = StreamController<GradebookSocketStatus>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _closed = false;

  @override
  Stream<GradebookSocketEvent> get events => _events.stream;

  @override
  Stream<GradebookSocketStatus> get statuses => _statuses.stream;

  @override
  Future<void> connect() async {
    if (_channel != null || _closed) return;
    _statuses.add(GradebookSocketStatus.connecting);
    final token = await _localData.getAccessToken();
    if (token == null || token.isEmpty) {
      _statuses.add(GradebookSocketStatus.disconnected);
      throw StateError('Authentication token is missing.');
    }

    final base = Uri.parse(AppConfig.baseUrl);
    final uri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/classrooms/api/v1/ws/classrooms',
      query: null,
      fragment: null,
    );
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
      if (!_closed) _statuses.add(GradebookSocketStatus.connected);
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      _channel = null;
      if (!_closed) _statuses.add(GradebookSocketStatus.disconnected);
      _scheduleReconnect();
      rethrow;
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      if (data['type'] != 'GRADEBOOK_UPDATED') return;
      final payload = data['payload'] as Map<String, dynamic>;
      _events.add(
        GradebookSocketEvent(
          classroomId: (payload['classroomId'] as num).toInt(),
          assignmentId: (payload['assignmentId'] as num).toInt(),
        ),
      );
    } catch (_) {
      // Ignore messages that do not match the gradebook event contract.
    }
  }

  void _handleDisconnect() {
    _channel = null;
    if (!_closed) {
      _statuses.add(GradebookSocketStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      connect().catchError((_) {});
    });
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    await _events.close();
    await _statuses.close();
  }
}
