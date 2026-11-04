import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Popup thông tin bài giao: tiêu đề, mô tả đầy đủ (cuộn được) và luật làm bài.
/// Chưa làm thì nút chính là "Start attempt"; đã nộp ([submitted]) thì là "View result".
/// Trả về true khi học sinh bấm nút chính.
Future<bool> showAssignmentStartDialog(
  BuildContext context,
  ClassroomAssignment assignment, {
  bool submitted = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _AssignmentStartDialog(assignment: assignment, submitted: submitted),
    ) ??
    false;

class _AssignmentStartDialog extends StatelessWidget {
  const _AssignmentStartDialog({required this.assignment, required this.submitted});
  final ClassroomAssignment assignment;
  final bool submitted;

  static const _muted = Color(0xFF646A73);
  static const _border = Color(0xFFE5E6EB);

  @override
  Widget build(BuildContext context) {
    final description = assignment.description?.trim() ?? '';
    final rules = [
      (Icons.calendar_today_outlined, 'Due ${DateFormat('MMM d, HH:mm').format(assignment.dueAt)}'),
      (Icons.timer_outlined, '${assignment.duration} minutes once you start'),
      if (!submitted) (Icons.save_outlined, 'Answers are saved automatically'),
      if (assignment.proctored)
        (
          Icons.shield_outlined,
          'Proctored · ${assignment.maxViolations} warnings submit the attempt',
        ),
    ];
    final button = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      assignment.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context, false),
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
            const Divider(height: 1, color: _border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 18,
                  children: [
                    if (description.isNotEmpty)
                      SelectableText(
                        description,
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF1F2329)),
                      ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 10,
                        children: [
                          for (final (icon, text) in rules)
                            Row(
                              spacing: 10,
                              children: [
                                Icon(icon, size: 16, color: _muted),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: const TextStyle(fontSize: 13, color: _muted),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
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
                    onPressed: () => Navigator.pop(context, false),
                    style: button.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(AppButtonStyles.tint),
                      foregroundColor: const WidgetStatePropertyAll(ColorName.primary),
                    ),
                    child: Text(submitted ? 'Close' : 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: button.merge(
                      FilledButton.styleFrom(
                        backgroundColor: ColorName.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    child: Text(submitted ? 'View result' : 'Start attempt'),
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
