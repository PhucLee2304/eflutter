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
  final _activityEvents = StreamController<RoomActivitySocketEvent>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final _seenEventIds = <String>{};
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _closed = false;
  bool _hasConnected = false;

  Stream<ClassroomRoom> get events => _events.stream;
  Stream<RoomActivitySocketEvent> get activityEvents => _activityEvents.stream;

  /// Phát mỗi khi socket nối lại sau khi đã từng kết nối; event phát ra trong
  /// lúc mất kết nối không được replay nên client cần tải lại activity.
  Stream<void> get reconnected => _reconnected.stream;

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
      if (_closed || _channel != channel) return;
      if (_hasConnected) _reconnected.add(null);
      _hasConnected = true;
    } catch (_) {
      _disconnected();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final eventId = data['eventId'] as String?;
      if (eventId != null && eventId.isNotEmpty) {
        if (!_seenEventIds.add(eventId)) return;
        if (_seenEventIds.length > 256) {
          _seenEventIds.remove(_seenEventIds.first);
        }
      }
      final type = data['type'] as String? ?? '';
      if (type == 'ROOM_STARTED' || type == 'ROOM_ENDED') {
        _events.add(
          ClassroomRoom.fromJson(data['payload'] as Map<String, dynamic>),
        );
      }
      final roomId = (data['roomId'] as num?)?.toInt();
      if (eventId != null &&
          roomId != null &&
          _roomActivityTypes.contains(type)) {
        final payload = data['payload'];
        _activityEvents.add(
          RoomActivitySocketEvent(
            eventId: eventId,
            type: type,
            roomId: roomId,
            createdAt: DateTime.parse(data['createdAt'] as String).toLocal(),
            userId: payload is Map<String, dynamic>
                ? payload['userId'] as String?
                : null,
          ),
        );
      }
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
    await _activityEvents.close();
    await _reconnected.close();
  }
}

const _roomActivityTypes = {
  'PARTICIPANT_PERMISSIONS_UPDATED',
  'HAND_RAISED',
  'HAND_LOWERED',
  'SCREEN_SHARE_REQUESTED',
  'SCREEN_SHARE_APPROVED',
  'SCREEN_SHARE_REJECTED',
  'SCREEN_SHARE_STOPPED',
  'PARTICIPANT_REMOVED',
  'PARTICIPANT_MICROPHONE_ALLOWED',
};

class RoomActivitySocketEvent {
  const RoomActivitySocketEvent({
    required this.eventId,
    required this.type,
    required this.roomId,
    required this.createdAt,
    this.userId,
  });

  final String eventId;
  final String type;
  final int roomId;
  final DateTime createdAt;

  /// Participant bị tác động bởi event (ví dụ người bị dừng chia sẻ màn hình).
  final String? userId;
}
