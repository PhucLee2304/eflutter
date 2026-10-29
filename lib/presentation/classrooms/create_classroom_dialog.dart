import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/helpers/file_picker/file_picker_helper.dart';
import 'package:eflutter/core/utils/helpers/file_picker/local_picked_file.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/data/repositories/user_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:flutter/material.dart';

/// Popup tạo lớp (ảnh tùy chọn, tên, mô tả); trả về lớp vừa tạo hoặc null khi hủy.
Future<Classroom?> showCreateClassroomDialog(BuildContext context) => showDialog<Classroom>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const _CreateClassroomDialog(),
);

class _CreateClassroomDialog extends StatefulWidget {
  const _CreateClassroomDialog();

  @override
  State<_CreateClassroomDialog> createState() => _CreateClassroomDialogState();
}

class _CreateClassroomDialogState extends State<_CreateClassroomDialog> {
  static const _fill = Color(0xFFF0F2F5);
  static const _muted = Color(0xFF65676B);

  final name = TextEditingController();
  final description = TextEditingController();
  final nameFocus = FocusNode();
  LocalPickedFile? photo;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    nameFocus.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    final file = await pickImageFile();
    if (file != null && mounted) setState(() => photo = file);
  }

  // Tên file an toàn và không trùng trong thư mục avatars, giống luồng avatar ở profile.
  String _uploadName(String original) {
    final dot = original.lastIndexOf('.');
    final ext = dot > -1 ? original.substring(dot) : '';
    final base = (dot > -1 ? original.substring(0, dot) : original)
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${DateTime.now().millisecondsSinceEpoch}-${base.isEmpty ? 'classroom' : base}$ext';
  }

  Future<String?> _uploadPhoto(LocalPickedFile file) async {
    final users = getIt<UserRepository>();
    final fileName = _uploadName(file.name);
    final presign = await users.getPresignedUploadUrl(
      fileName: fileName,
      contentType: file.contentType,
      folder: 'avatars',
    );
    if (presign case Success(data: final url)) {
      final upload = await users.uploadBinaryToUrl(
        url: url,
        bytes: file.bytes,
        contentType: file.contentType,
      );
      if (upload is Success) return fileName;
    }
    return null;
  }

  Future<void> submit() async {
    if (name.text.trim().isEmpty || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    String? avatar;
    if (photo case final file?) {
      avatar = await _uploadPhoto(file);
      if (avatar == null) {
        if (!mounted) return;
        setState(() {
          saving = false;
          error = 'Could not upload the photo';
        });
        return;
      }
    }
    final text = description.text.trim();
    final result = await ClassroomRepository(
      getIt<Dio>(),
    ).create(name.text, description: text.isEmpty ? null : text, avatar: avatar);
    if (!mounted) return;
    switch (result) {
      case Success(data: final classroom):
        Navigator.pop(context, classroom);
      case Failure(message: final message):
        setState(() {
          saving = false;
          error = message ?? 'Could not create the classroom';
        });
      case Cancelled():
        setState(() => saving = false);
    }
  }

  InputDecoration _decoration(String hint) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8A8D91)),
      filled: true,
      fillColor: _fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(_fill, 1),
      enabledBorder: border(_fill, 1),
      focusedBorder: border(ColorName.primary, 1.5),
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
        ],
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3A3B3C)),
    ),
  );

  Widget _photoRow() {
    final file = photo;
    return Row(
      children: [
        InkWell(
          onTap: saving ? null : pickPhoto,
          customBorder: const CircleBorder(),
          child: CustomPaint(
            painter: file == null ? _DashedCirclePainter() : null,
            child: CircleAvatar(
              radius: 36,
              backgroundColor: _fill,
              backgroundImage: file == null ? null : MemoryImage(file.bytes),
              child: file == null
                  ? const Icon(Icons.add_photo_alternate_outlined, size: 28, color: _muted)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Classroom photo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Optional · JPG or PNG',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A8D91)),
            ),
            const SizedBox(height: 6),
            Row(
              spacing: 8,
              children: [
                _smallButton(file == null ? 'Upload' : 'Change', saving ? null : pickPhoto),
                if (file != null)
                  _smallButton('Remove', saving ? null : () => setState(() => photo = null)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _smallButton(String label, VoidCallback? onPressed) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppButtonStyles.tint,
      foregroundColor: ColorName.primary,
      minimumSize: const Size(0, 30),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 520,
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
                      'Create classroom',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: saving ? null : () => Navigator.pop(context),
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _photoRow(),
                    const SizedBox(height: 18),
                    _label('Classroom name', required: true),
                    TextField(
                      controller: name,
                      focusNode: nameFocus,
                      autofocus: true,
                      enabled: !saving,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration('e.g. Advanced Mathematics 12A'),
                    ),
                    const SizedBox(height: 18),
                    _label('Description'),
                    TextField(
                      controller: description,
                      enabled: !saving,
                      keyboardType: TextInputType.multiline,
                      // Không giới hạn nội dung; ô cao 3–6 dòng rồi cuộn bên trong.
                      minLines: 3,
                      maxLines: 6,
                      decoration: _decoration('What will students learn in this class?'),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        spacing: 8,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: _muted),
                          Expanded(
                            child: Text(
                              'A join code is generated automatically. '
                              'Share it with your students.',
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(fontSize: 13, color: Color(0xFFE53935))),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    style: button.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(AppButtonStyles.tint),
                      foregroundColor: const WidgetStatePropertyAll(ColorName.primary),
                    ),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: name.text.trim().isEmpty || saving ? null : submit,
                    style: button.merge(
                      FilledButton.styleFrom(
                        backgroundColor: ColorName.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create'),
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

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9CCD1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Offset.zero & size;
    const dashes = 28;
    const sweep = 2 * 3.141592653589793 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(0.5), i * sweep, sweep / 2, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
