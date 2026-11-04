import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';

/// Màu icon của hộp xác nhận: đỏ khi mất dữ liệu / đình chỉ, cam khi đảo lại được,
/// xanh khi thao tác thường.
abstract final class ConfirmActionColors {
  static const red = Color(0xFFD93025);
  static const redBg = Color(0xFFFDECEA);
  static const orange = Color(0xFFB06000);
  static const orangeBg = Color(0xFFFEF3E2);
  static const blue = Color(0xFF0483CA);
  static const blueBg = Color(0xFFEEF7FD);
}

/// Hộp xác nhận chung (Figma T4): icon tròn, tiêu đề, mô tả, ô ghi chú tùy chọn.
/// Trả null khi hủy; chuỗi (rỗng nếu không có ô) khi xác nhận. [required]: nút bị khóa
/// tới khi ô có chữ. [danger]: nút xác nhận màu đỏ (mặc định khi icon đỏ).
Future<String?> showConfirmAction(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required Color tint,
  required String title,
  required String message,
  required String action,
  String? field,
  bool required = false,
  String hint = 'Add a note for the record',
  int? maxLength,
  bool? danger,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ConfirmDialog(
    icon: icon,
    color: color,
    tint: tint,
    title: title,
    message: message,
    action: action,
    field: field,
    required: required,
    hint: hint,
    maxLength: maxLength,
    danger: danger ?? color == ConfirmActionColors.red,
  ),
);

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.message,
    required this.action,
    required this.field,
    required this.required,
    required this.hint,
    required this.maxLength,
    required this.danger,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String message;
  final String action;
  final String? field;
  final bool required;
  final String hint;
  final int? maxLength;
  final bool danger;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = controller.text.trim();
    final enabled = !widget.required || text.isNotEmpty;
    final danger = widget.danger;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: widget.tint, shape: BoxShape.circle),
                child: Icon(widget.icon, size: 22, color: widget.color),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _text),
              ),
              const SizedBox(height: 6),
              Text(widget.message, style: const TextStyle(fontSize: 13, color: _muted)),
              if (widget.field != null) ...[
                const SizedBox(height: 16),
                Text(
                  widget.required ? '${widget.field} *' : widget.field!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _text),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: widget.maxLength,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    counterText: '',
                    hintStyle: const TextStyle(fontSize: 13, color: _faint),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF0F2F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _text,
                      side: const BorderSide(color: Color(0xFFE4E6EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: enabled ? () => Navigator.pop(context, text) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: danger ? ConfirmActionColors.red : ColorName.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(widget.action),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _text = Color(0xFF1C1E21);
  static const _muted = Color(0xFF65676B);
  static const _faint = Color(0xFF8A8D91);
}
