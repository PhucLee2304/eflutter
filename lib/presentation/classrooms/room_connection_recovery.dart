enum RoomConnectionRecoveryAction { keepConnection, reconnect, exitRoom, retry }

int roomGridColumnCount(double width) {
  if (width >= 1100) return 4;
  if (width >= 700) return 3;
  if (width >= 440) return 2;
  return 1;
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
