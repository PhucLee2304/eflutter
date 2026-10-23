import 'dart:math' as math;
import 'dart:ui' show Size;

enum RoomConnectionRecoveryAction { keepConnection, reconnect, exitRoom, retry }

int roomGridColumnCount(double width, {int? participantCount}) {
  final byWidth = width >= 1100
      ? 4
      : width >= 700
      ? 3
      : width >= 440
      ? 2
      : 1;
  if (participantCount == null) return byWidth;
  // Lưới gần vuông: 2 người -> 2 cột, 4 người -> 2x2, 5-9 người -> 3 cột.
  final balanced = math.max(1, math.sqrt(participantCount).ceil());
  return math.min(byWidth, balanced);
}

/// Kích thước đồng đều cho mọi ô sao cho cả lưới vừa vùng hiển thị; chỉ khi
/// ô nhỏ hơn [minWidth] thì lưới mới phải cuộn.
Size roomTileSize(
  Size area,
  int participantCount, {
  double spacing = 10,
  double aspectRatio = 16 / 10,
  double minWidth = 160,
}) {
  final count = math.max(1, participantCount);
  final columns = roomGridColumnCount(area.width, participantCount: count);
  final rows = (count / columns).ceil();
  final maxWidth = math.max(
    0.0,
    (area.width - spacing * (columns - 1)) / columns,
  );
  var width = maxWidth;
  final maxHeight = (area.height - spacing * (rows - 1)) / rows;
  if (width / aspectRatio > maxHeight) width = maxHeight * aspectRatio;
  width = math.min(maxWidth, math.max(width, minWidth));
  // Làm tròn xuống để Wrap không xuống dòng sớm vì sai số dấu phẩy động.
  width = width.floorToDouble();
  return Size(width, (width / aspectRatio).floorToDouble());
}

RoomConnectionRecoveryAction decideRoomConnectionRecovery({
  required bool mediaConnected,
  required bool roomRequestSucceeded,
  String? roomStatus,
}) {
  if (mediaConnected) return RoomConnectionRecoveryAction.keepConnection;
  if (!roomRequestSucceeded) return RoomConnectionRecoveryAction.retry;
  return roomStatus == 'LIVE'
      ? RoomConnectionRecoveryAction.reconnect
      : RoomConnectionRecoveryAction.exitRoom;
}
