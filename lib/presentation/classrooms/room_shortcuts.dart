import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Phím tắt trong phòng học; giữ phần nhận diện phím và quyết định thuần để
/// test không cần dựng màn hình phòng.
enum RoomShortcut { toggleMicrophone, toggleCamera, toggleHand }

enum RoomShortcutDecision {
  /// Thực hiện thao tác.
  run,

  /// Giáo viên đã khóa thiết bị đang tắt: nuốt phím và báo lý do, không bật.
  locked,

  /// Không áp dụng (đang nhập liệu, có dialog, chưa vào phòng, giáo viên giơ
  /// tay): để phím đi tiếp như bình thường.
  ignore,
}

const _letters = {
  RoomShortcut.toggleMicrophone: (LogicalKeyboardKey.keyD, PhysicalKeyboardKey.keyD),
  RoomShortcut.toggleCamera: (LogicalKeyboardKey.keyE, PhysicalKeyboardKey.keyE),
  RoomShortcut.toggleHand: (LogicalKeyboardKey.keyH, PhysicalKeyboardKey.keyH),
};

/// Ctrl/Cmd+D: mic, Ctrl/Cmd+E: camera, Ctrl/Cmd+Alt+H: giơ/hạ tay. Trên
/// macOS/iOS phím chính là Cmd, nơi khác là Ctrl; không nhận Shift hoặc phím
/// bổ trợ còn lại để tránh nuốt tổ hợp khác của trình duyệt.
RoomShortcut? roomShortcutFor({
  required LogicalKeyboardKey logicalKey,
  required PhysicalKeyboardKey physicalKey,
  required bool control,
  required bool meta,
  required bool alt,
  required bool shift,
  required bool apple,
}) {
  final primary = apple ? meta : control;
  final other = apple ? control : meta;
  if (!primary || other || shift) return null;
  RoomShortcut? match(bool Function(LogicalKeyboardKey, PhysicalKeyboardKey) test) {
    for (final entry in _letters.entries) {
      final wantsAlt = entry.key == RoomShortcut.toggleHand;
      if (alt == wantsAlt && test(entry.value.$1, entry.value.$2)) {
        return entry.key;
      }
    }
    return null;
  }

  // Ưu tiên ký tự theo bố cục bàn phím; Option trên macOS đổi ký tự (Option+H
  // ra "˙") nên dự phòng bằng vị trí phím vật lý.
  return match((logical, _) => logical == logicalKey) ??
      match((_, physical) => physical == physicalKey);
}

RoomShortcutDecision roomShortcutDecision(
  RoomShortcut shortcut, {
  required bool roomActive,
  required bool editingText,
  required bool isHost,
  required bool microphoneOn,
  required bool microphoneAllowed,
  required bool cameraOn,
  required bool cameraAllowed,
}) {
  if (!roomActive || editingText) return RoomShortcutDecision.ignore;
  return switch (shortcut) {
    // Bị khóa chỉ chặn bật; đang bật thì vẫn cho tắt.
    RoomShortcut.toggleMicrophone =>
      !microphoneOn && !microphoneAllowed ? RoomShortcutDecision.locked : RoomShortcutDecision.run,
    RoomShortcut.toggleCamera =>
      !cameraOn && !cameraAllowed ? RoomShortcutDecision.locked : RoomShortcutDecision.run,
    RoomShortcut.toggleHand => isHost ? RoomShortcutDecision.ignore : RoomShortcutDecision.run,
  };
}

String roomShortcutLabel(RoomShortcut shortcut, {required bool apple}) {
  final primary = apple ? 'Cmd' : 'Ctrl';
  return switch (shortcut) {
    RoomShortcut.toggleMicrophone => '$primary+D',
    RoomShortcut.toggleCamera => '$primary+E',
    RoomShortcut.toggleHand => '$primary+${apple ? 'Option' : 'Alt'}+H',
  };
}

/// Focus nằm trong một ô nhập liệu (TextField, ô tìm kiếm, ô lý do remove):
/// phím tắt phải nhường cho việc gõ chữ.
bool roomTextInputFocused() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() !=
    null;
