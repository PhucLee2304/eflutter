import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Popup nhập mã lớp; trả về mã đủ [codeLength] ký tự hoặc null khi hủy.
Future<String?> showJoinClassroomDialog(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _JoinClassroomDialog());

// Khớp với alphabet/codeLength sinh mã lớp ở backend (learning/internal/service/classroom.go).
const codeLength = 8;
final _codeChars = RegExp('[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]');

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.toUpperCase().split('').where(_codeChars.hasMatch).join();
    final clipped = text.length > codeLength ? text.substring(0, codeLength) : text;
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }
}

class _JoinClassroomDialog extends StatefulWidget {
  const _JoinClassroomDialog();

  @override
  State<_JoinClassroomDialog> createState() => _JoinClassroomDialogState();
}

class _JoinClassroomDialogState extends State<_JoinClassroomDialog> {
  final controller = TextEditingController();
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    controller.addListener(() => setState(() {}));
    focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  bool get complete => controller.text.length == codeLength;

  void submit() {
    if (complete) Navigator.pop(context, controller.text);
  }

  Widget _slot(int index) {
    final text = controller.text;
    final filled = index < text.length;
    final active = focus.hasFocus && index == text.length;
    return SizedBox(
      width: 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: Center(
              child: filled
                  ? Text(
                      text[index],
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                    )
                  : active
                  ? Container(width: 2, height: 28, color: ColorName.primary)
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: active ? 2.5 : 2,
            decoration: BoxDecoration(
              color: filled || active ? ColorName.primary : const Color(0xFFC9CCD1),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const SizedBox(width: 36),
                  const Expanded(
                    child: Text(
                      'Join a classroom',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: AppButtonStyles.tint,
                      foregroundColor: ColorName.primary,
                      fixedSize: const Size(36, 36),
                      minimumSize: const Size(36, 36),
                    ),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE4E6EB)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
              child: Column(
                children: [
                  const Text(
                    'Ask your teacher for the class code, then enter it here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF65676B)),
                  ),
                  const SizedBox(height: 20),
                  Stack(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 12,
                        children: [for (var i = 0; i < codeLength; i++) _slot(i)],
                      ),
                      // Ô nhập thật nằm trong suốt phủ lên các ô gạch chân để nhận bàn phím/dán.
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: controller,
                            focusNode: focus,
                            autofocus: true,
                            showCursor: false,
                            enableInteractiveSelection: false,
                            textCapitalization: TextCapitalization.characters,
                            keyboardType: TextInputType.visiblePassword,
                            inputFormatters: [_UpperCaseFormatter()],
                            onSubmitted: (_) => submit(),
                            decoration: const InputDecoration.collapsed(hintText: ''),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '$codeLength characters · letters and numbers',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8A8D91)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: button.merge(
                      FilledButton.styleFrom(
                        backgroundColor: AppButtonStyles.tint,
                        foregroundColor: ColorName.primary,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: complete ? submit : null,
                    style: button.merge(
                      FilledButton.styleFrom(
                        backgroundColor: ColorName.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
