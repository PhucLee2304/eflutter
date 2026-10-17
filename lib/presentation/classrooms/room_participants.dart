import 'package:livekit_client/livekit_client.dart';

/// Metadata do backend gắn vào LiveKit token của giáo viên.
const roomHostMetadata = 'HOST';

/// Thao tác giáo viên làm trên một học sinh trong phòng.
enum RoomParticipantAction {
  mute,
  allowMicrophone,
  disableCamera,
  allowCamera,
  remove,
}

enum RoomParticipantConnection { good, weak, reconnecting }

/// Dữ liệu hiển thị của một participant, tách khỏi LiveKit để grid, panel và
/// test dùng chung.
class RoomParticipantView {
  const RoomParticipantView({
    required this.identity,
    required this.name,
    required this.isHost,
    required this.isLocal,
    required this.microphoneOn,
    required this.cameraOn,
    required this.isSpeaking,
    required this.connection,
    this.handRaisedAt,
    this.presenting = false,
    this.screenShareRequested = false,
    this.microphoneAllowed = true,
    this.cameraAllowed = true,
  });

  final String identity;
  final String name;
  final bool isHost;
  final bool isLocal;
  final bool microphoneOn;
  final bool cameraOn;
  final bool isSpeaking;
  final RoomParticipantConnection connection;
  final DateTime? handRaisedAt;
  final bool presenting;

  /// Chỉ giáo viên (và chính học sinh đó) thấy yêu cầu đang chờ duyệt.
  final bool screenShareRequested;

  /// Quyền do giáo viên cấp; khác với việc thiết bị đang bật hay tắt.
  final bool microphoneAllowed;
  final bool cameraAllowed;

  String get displayName => name.trim().isEmpty ? identity : name.trim();
}

RoomParticipantConnection roomParticipantConnection({
  required ConnectionQuality quality,
  required bool reconnecting,
}) {
  if (reconnecting || quality == ConnectionQuality.lost) {
    return RoomParticipantConnection.reconnecting;
  }
  if (quality == ConnectionQuality.poor) return RoomParticipantConnection.weak;
  return RoomParticipantConnection.good;
}

RoomParticipantView roomParticipantViewFrom(
  Participant participant, {
  required bool isLocal,
  required bool isHost,
  required bool roomReconnecting,
  DateTime? handRaisedAt,
  bool screenShareRequested = false,
  bool microphoneAllowed = true,
  bool cameraAllowed = true,
}) => RoomParticipantView(
  identity: participant.identity,
  name: participant.name,
  isHost: isHost,
  isLocal: isLocal,
  microphoneOn: participant.isMicrophoneEnabled(),
  cameraOn: participant.isCameraEnabled(),
  isSpeaking: participant.isSpeaking,
  connection: roomParticipantConnection(
    quality: participant.connectionQuality,
    reconnecting: isLocal && roomReconnecting,
  ),
  handRaisedAt: handRaisedAt,
  presenting: participant.isScreenShareEnabled(),
  screenShareRequested: screenShareRequested,
  microphoneAllowed: microphoneAllowed,
  cameraAllowed: cameraAllowed,
);

/// Giữ một dòng cho mỗi identity; phần tử đầu tiên được ưu tiên nên truyền
/// local participant trước để reconnect không tạo bản sao của chính mình.
List<T> dedupeRoomParticipants<T>(
  Iterable<T> participants,
  String Function(T participant) identityOf,
) {
  final seen = <String>{};
  return [
    for (final participant in participants)
      if (seen.add(identityOf(participant))) participant,
  ];
}

/// Giáo viên đứng đầu; với [byHand] học sinh giơ tay sớm hơn được ưu tiên, còn
/// lại sắp xếp theo tên. Grid tắt [byHand] để ô video không nhảy vị trí.
int compareRoomParticipants(
  RoomParticipantView a,
  RoomParticipantView b, {
  bool byHand = true,
}) {
  if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
  final aHand = a.handRaisedAt, bHand = b.handRaisedAt;
  if (byHand && (aHand != null || bHand != null)) {
    if (aHand == null) return 1;
    if (bHand == null) return -1;
    final byHand = aHand.compareTo(bHand);
    if (byHand != 0) return byHand;
  }
  final byName = a.displayName.toLowerCase().compareTo(
    b.displayName.toLowerCase(),
  );
  return byName != 0 ? byName : a.identity.compareTo(b.identity);
}

List<RoomParticipantView> filterRoomParticipants(
  Iterable<RoomParticipantView> participants,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return participants.toList();
  return participants
      .where((p) => p.displayName.toLowerCase().contains(normalized))
      .toList();
}

/// Trả về thiết bị đang chọn nếu vẫn còn cắm, nếu không thì thiết bị khả dụng
/// đầu tiên.
MediaDevice? resolveRoomDevice(
  MediaDevice? current,
  List<MediaDevice> available,
) {
  if (current != null) {
    for (final device in available) {
      if (device.deviceId == current.deviceId) return device;
    }
  }
  return available.isEmpty ? null : available.first;
}
