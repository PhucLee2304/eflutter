import 'package:eflutter/presentation/classrooms/room_device_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;

void main() {
  const builtIn = MediaDevice('built-in', 'Built-in mic', 'audioinput', null);
  const usb = MediaDevice('usb', 'USB mic', 'audioinput', null);

  test('selects the saved device when it is still available', () {
    expect(preferredRoomDevice('usb', const [builtIn, usb]), usb);
  });

  test('falls back to the first device when the saved one is gone', () {
    expect(preferredRoomDevice('headset', const [builtIn, usb]), builtIn);
    expect(preferredRoomDevice(null, const [builtIn, usb]), builtIn);
    expect(preferredRoomDevice('', const [builtIn, usb]), builtIn);
  });

  test('falls back to the given device through resolveRoomDevice', () {
    expect(
      preferredRoomDevice('headset', const [builtIn, usb], fallback: usb),
      usb,
    );
    const unplugged = MediaDevice('old', 'Old mic', 'audioinput', null);
    expect(
      preferredRoomDevice(null, const [builtIn, usb], fallback: unplugged),
      builtIn,
    );
  });

  test('returns null when there is no device', () {
    expect(preferredRoomDevice('usb', const []), isNull);
  });
}
