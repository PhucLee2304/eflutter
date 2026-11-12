import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';

/// Nút tròn 32px dùng ở thanh điều khiển của lesson (câu trước/sau, Repeat, Auto-scroll).
class LessonIconButton extends StatelessWidget {
  const LessonIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// null: nút bấm thường; true/false: nút bật/tắt (bật thì viền và nền xanh nhạt).
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final isOn = selected == true;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(32),
        minimumSize: const Size.square(32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: isOn
            ? ColorName.primary
            : selected == false
            ? ColorName.labelSecondary
            : ColorName.labelPrimary,
        backgroundColor: isOn ? ColorName.primary.withValues(alpha: 0.1) : null,
        side: BorderSide(color: isOn ? ColorName.primary : ColorName.gray5),
      ),
    );
  }
}
