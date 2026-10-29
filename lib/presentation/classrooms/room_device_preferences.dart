import 'package:eflutter/presentation/classrooms/room_participants.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;
import 'package:shared_preferences/shared_preferences.dart';

/// Thiết bị người dùng đã chọn lần trước; chỉ lưu trên máy này, không gửi lên
/// backend.
class RoomDeviceChoice {
  const RoomDeviceChoice({this.microphoneId, this.cameraId, this.speakerId});

  final String? microphoneId;
  final String? cameraId;
  final String? speakerId;
}

enum RoomDeviceKind { microphone, camera, speaker }

class RoomDevicePreferences {
  RoomDevicePreferences(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const _keys = {
    RoomDeviceKind.microphone: 'room.microphoneDeviceId',
    RoomDeviceKind.camera: 'room.cameraDeviceId',
    RoomDeviceKind.speaker: 'room.speakerDeviceId',
  };

  /// Lỗi đọc bộ nhớ cục bộ không được chặn việc vào phòng.
  Future<RoomDeviceChoice> load() async {
    try {
      final [microphoneId, cameraId, speakerId] = await [
        for (final key in _keys.values) _prefs.getString(key),
      ].wait;
      return RoomDeviceChoice(microphoneId: microphoneId, cameraId: cameraId, speakerId: speakerId);
    } catch (_) {
      return const RoomDeviceChoice();
    }
  }

  Future<void> save(RoomDeviceKind kind, MediaDevice device) async {
    if (device.deviceId.isEmpty) return;
    try {
      await _prefs.setString(_keys[kind]!, device.deviceId);
    } catch (_) {}
  }
}

/// Chọn lại thiết bị đã lưu nếu vẫn còn trong danh sách, nếu không thì dùng
/// [resolveRoomDevice] với [fallback].
MediaDevice? preferredRoomDevice(
  String? savedId,
  List<MediaDevice> available, {
  MediaDevice? fallback,
}) {
  if (savedId != null && savedId.isNotEmpty) {
    for (final device in available) {
      if (device.deviceId == savedId) return device;
    }
  }
  return resolveRoomDevice(fallback, available);
}
