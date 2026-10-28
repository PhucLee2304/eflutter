import 'dart:async';
import 'dart:convert';

import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/data/data_sources/attempt_socket_connector.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Kết nối /ws/notifications: server chỉ gửi NOTIFICATION_CREATED khi có thông
/// báo mới, nên client không phải polling.
class NotificationSocketClient {
  NotificationSocketClient(this._localData, {required this.onConnected, required this.onCreated});

  final LocalDataBase _localData;

  /// Gọi mỗi lần kết nối (lại) thành công, để đồng bộ số bị lỡ khi mất kết nối.
  final void Function() onConnected;
  final void Function() onCreated;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  var _retryDelay = const Duration(seconds: 2);
  bool _active = false;

  Future<void> connect() async {
    _active = true;
    if (_channel != null) return;
    final token = await _localData.getAccessToken();
    if (!_active || token == null || token.isEmpty) return;

    final base = Uri.parse(AppConfig.baseUrl);
    final uri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/notifications/api/v1/ws/notifications',
      query: null,
      fragment: null,
    );
    final channel = connectAttemptSocket(uri, token);
    _channel = channel;
    _subscription = channel.stream.listen(
      _handleMessage,
      onError: (_) => _handleDisconnect(channel),
      onDone: () => _handleDisconnect(channel),
      cancelOnError: true,
    );
    try {
      await channel.ready;
      if (!_active || _channel != channel) return;
      _retryDelay = const Duration(seconds: 2);
      onConnected();
    } catch (_) {
      _handleDisconnect(channel);
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      if (data['type'] == 'NOTIFICATION_CREATED') onCreated();
    } catch (_) {
      // Bỏ qua message không đúng định dạng.
    }
  }

  void _handleDisconnect(WebSocketChannel channel) {
    if (_channel != channel) return;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (!_active || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(_retryDelay, () => unawaited(connect()));
    final next = _retryDelay * 2;
    _retryDelay = next > const Duration(seconds: 30) ? const Duration(seconds: 30) : next;
  }

  Future<void> close() async {
    _active = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final channel = _channel;
    _channel = null;
    await _subscription?.cancel();
    _subscription = null;
    await channel?.sink.close();
  }
}
