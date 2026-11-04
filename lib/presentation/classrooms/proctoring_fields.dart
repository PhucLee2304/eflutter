import 'package:flutter/material.dart';

/// Ô "Proctored" và số lần vi phạm được phép (PLAN_ATTEMPT_INTEGRITY.md I4), dùng
/// trong form tạo bài, giao đề có sẵn và sửa lịch.
class ProctoringFields extends StatelessWidget {
  const ProctoringFields({
    super.key,
    required this.proctored,
    required this.maxViolations,
    required this.onProctoredChanged,
    required this.onMaxViolationsChanged,
  });

  final bool proctored;
  final int maxViolations;
  final ValueChanged<bool> onProctoredChanged;
  final ValueChanged<int> onMaxViolationsChanged;

  static String? validateMaxViolations(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < 1 ? 'Enter a number of at least 1' : null;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: proctored,
        onChanged: (value) => onProctoredChanged(value ?? false),
        secondary: const Icon(Icons.shield_outlined),
        title: const Text('Proctored'),
        subtitle: const Text('Record when students leave the exam tab; you see it live'),
      ),
      if (proctored)
        TextFormField(
          initialValue: '$maxViolations',
          decoration: const InputDecoration(
            labelText: 'Allowed violations',
            helperText:
                'Going over this number automatically suspends the attempt '
                'with a score of 0',
            helperMaxLines: 2,
          ),
          keyboardType: TextInputType.number,
          validator: validateMaxViolations,
          onChanged: (value) {
            final parsed = int.tryParse(value.trim());
            if (parsed != null && parsed >= 1) onMaxViolationsChanged(parsed);
          },
        ),
    ],
  );
}
