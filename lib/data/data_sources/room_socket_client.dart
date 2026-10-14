import 'dart:async';
import 'dart:convert';

import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/data/data_sources/attempt_socket_connector.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RoomSocketClient {
  RoomSocketClient(this._localData);
  final LocalDataBase _localData;
  final _events = StreamController<ClassroomRoom>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _closed = false;

  Stream<ClassroomRoom> get events => _events.stream;

  Future<void> connect() async {
    if (_channel != null || _closed) return;
    final token = await _localData.getAccessToken();
    if (token == null || token.isEmpty) return;
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
        onError: (_) => _disconnected(),
        onDone: _disconnected,
        cancelOnError: true,
      );
      await channel.ready;
    } catch (_) {
      _disconnected();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      if (data['type'] != 'ROOM_STARTED' && data['type'] != 'ROOM_ENDED') {
        return;
      }
      _events.add(
        ClassroomRoom.fromJson(data['payload'] as Map<String, dynamic>),
      );
    } catch (_) {
      // Other classroom events use the same socket and are ignored here.
    }
  }

  void _disconnected() {
    _channel = null;
    if (_closed || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 2), connect);
  }

  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _events.close();
  }
}
