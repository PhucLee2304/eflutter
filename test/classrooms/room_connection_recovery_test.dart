import 'package:eflutter/presentation/classrooms/room_connection_recovery.dart';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses responsive room grid breakpoints', () {
    expect(roomGridColumnCount(390), 1);
    expect(roomGridColumnCount(440), 2);
    expect(roomGridColumnCount(700), 3);
    expect(roomGridColumnCount(1100), 4);
    expect(roomGridColumnCount(1440), 4);
  });

  test('balances grid columns by participant count', () {
    expect(roomGridColumnCount(1440, participantCount: 1), 1);
    expect(roomGridColumnCount(1440, participantCount: 2), 2);
    expect(roomGridColumnCount(1440, participantCount: 4), 2);
    expect(roomGridColumnCount(1440, participantCount: 5), 3);
    expect(roomGridColumnCount(1440, participantCount: 30), 4);
    expect(roomGridColumnCount(390, participantCount: 6), 1);
  });

  test('sizes uniform tiles to fit the visible area', () {
    const spacing = 10.0;
    for (final (area, count) in [
      (const Size(1200, 700), 1),
      (const Size(1200, 700), 4),
      (const Size(1200, 700), 9),
      (const Size(800, 400), 6),
    ]) {
      final tile = roomTileSize(area, count, spacing: spacing);
      final columns = roomGridColumnCount(area.width, participantCount: count);
      final rows = (count / columns).ceil();
      expect(
        tile.width * columns + spacing * (columns - 1),
        lessThanOrEqualTo(area.width),
      );
      expect(
        tile.height * rows + spacing * (rows - 1),
        lessThanOrEqualTo(area.height),
      );
      expect(tile.width / tile.height, closeTo(16 / 10, 0.02));
    }
  });

  test('keeps a readable minimum tile width and scrolls instead', () {
    final tile = roomTileSize(const Size(1200, 300), 40);
    expect(tile.width, 160);
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
