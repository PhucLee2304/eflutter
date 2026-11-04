import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;

typedef RoomDeviceChanged = Future<void> Function(MediaDevice device);

/// Danh sách thiết bị và lựa chọn hiện tại; màn hình phòng giữ bản gốc, dialog
/// đọc lại qua [current] để cập nhật khi thiết bị bị cắm/rút trong lúc mở.
class RoomDeviceOptions {
  const RoomDeviceOptions({
    required this.microphones,
    required this.cameras,
    required this.speakers,
    this.microphone,
    this.camera,
    this.speaker,
  });

  final List<MediaDevice> microphones;
  final List<MediaDevice> cameras;
  final List<MediaDevice> speakers;
  final MediaDevice? microphone;
  final MediaDevice? camera;
  final MediaDevice? speaker;
}

class RoomDeviceSettingsDialog extends StatelessWidget {
  const RoomDeviceSettingsDialog({
    super.key,
    required this.options,
    required this.onMicrophoneChanged,
    required this.onCameraChanged,
    required this.onSpeakerChanged,
  });

  final ValueListenable<RoomDeviceOptions> options;
  final RoomDeviceChanged onMicrophoneChanged;
  final RoomDeviceChanged onCameraChanged;
  final RoomDeviceChanged onSpeakerChanged;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Audio and video'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      child: ValueListenableBuilder(
        valueListenable: options,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DevicePicker(
              label: 'Microphone',
              icon: Icons.mic_outlined,
              devices: value.microphones,
              selected: value.microphone,
              onChanged: onMicrophoneChanged,
            ),
            const SizedBox(height: 16),
            _DevicePicker(
              label: 'Camera',
              icon: Icons.videocam_outlined,
              devices: value.cameras,
              selected: value.camera,
              onChanged: onCameraChanged,
            ),
            const SizedBox(height: 16),
            _DevicePicker(
              label: 'Speaker',
              icon: Icons.volume_up_outlined,
              devices: value.speakers,
              selected: value.speaker,
              onChanged: onSpeakerChanged,
              emptyText:
                  'Speaker selection is not supported here. Audio plays on the system default device.',
            ),
          ],
        ),
      ),
    ),
    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
  );
}

class _DevicePicker extends StatelessWidget {
  const _DevicePicker({
    required this.label,
    required this.icon,
    required this.devices,
    required this.selected,
    required this.onChanged,
    this.emptyText,
  });

  final String label;
  final IconData icon;
  final List<MediaDevice> devices;
  final MediaDevice? selected;
  final RoomDeviceChanged onChanged;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Text(emptyText ?? 'No ${label.toLowerCase()} found'),
      );
    }
    final value = devices.where((device) => device.deviceId == selected?.deviceId).firstOrNull;
    return DropdownButtonFormField<MediaDevice>(
      // Key theo lựa chọn để field nhận giá trị mới khi thiết bị bị rút.
      key: ValueKey('${label}_${value?.deviceId}'),
      initialValue: value,
      isExpanded: true,
      items: [
        for (final (index, device) in devices.indexed)
          DropdownMenuItem(
            value: device,
            child: Text(
              device.label.isEmpty ? '$label ${index + 1}' : device.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (device) {
        if (device != null) onChanged(device);
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
