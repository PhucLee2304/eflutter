import 'package:eflutter/presentation/classrooms/room_connection_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses responsive room grid breakpoints', () {
    expect(roomGridColumnCount(390), 1);
    expect(roomGridColumnCount(440), 2);
    expect(roomGridColumnCount(700), 3);
    expect(roomGridColumnCount(1100), 4);
    expect(roomGridColumnCount(1440), 4);
  });

  test('keeps a connection that LiveKit already recovered', () {
    expect(
      decideRoomConnectionRecovery(
        mediaConnected: true,
        roomRequestSucceeded: true,
        roomStatus: 'LIVE',
      ),
      RoomConnectionRecoveryAction.keepConnection,
    );
  });

  test('requests a new token when the room remains live', () {
    expect(
      decideRoomConnectionRecovery(
        mediaConnected: false,
        roomRequestSucceeded: true,
        roomStatus: 'LIVE',
      ),
      RoomConnectionRecoveryAction.reconnect,
    );
  });

  test('exits when the room is scheduled or ended', () {
    for (final status in ['SCHEDULED', 'ENDED']) {
      expect(
        decideRoomConnectionRecovery(
          mediaConnected: false,
          roomRequestSucceeded: true,
          roomStatus: status,
        ),
        RoomConnectionRecoveryAction.exitRoom,
      );
    }
  });

  test('retries while room status cannot be loaded', () {
    expect(
      decideRoomConnectionRecovery(
        mediaConnected: false,
        roomRequestSucceeded: false,
      ),
      RoomConnectionRecoveryAction.retry,
    );
  });
}
