import 'package:eflutter/core/attempt_lock/integrity_consent.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Hộp đồng ý quy chế giám sát (Figma S1). Trả true khi học sinh tích ô và bấm
/// Start attempt.
Future<bool> showIntegrityConsentDialog(BuildContext context, {required int maxViolations}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _IntegrityConsentDialog(maxViolations: maxViolations),
    ) ??
    false;

class _IntegrityConsentDialog extends StatefulWidget {
  const _IntegrityConsentDialog({required this.maxViolations});

  final int maxViolations;

  @override
  State<_IntegrityConsentDialog> createState() => _IntegrityConsentDialogState();
}

class _IntegrityConsentDialogState extends State<_IntegrityConsentDialog> {
  bool _accepted = false;

  static const _text = Color(0xFF1C1E21);
  static const _muted = Color(0xFF65676B);
  static const _tint = Color(0xFFEEF7FD);
  static const _soft = Color(0xFFF7F8FA);
  static const _red = Color(0xFFD93025);

  static IconData _icon(IntegrityRuleKind kind) => switch (kind) {
    IntegrityRuleKind.leaveTab => Icons.exit_to_app,
    IntegrityRuleKind.limit => Icons.block,
    IntegrityRuleKind.recorded => Icons.visibility_outlined,
    IntegrityRuleKind.teacher => Icons.person_outline,
    IntegrityRuleKind.privacy => Icons.lock_outline,
  };

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 12,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: _tint, shape: BoxShape.circle),
                    child: const Icon(
                      SolarIconsOutline.shieldCheck,
                      color: ColorName.primary,
                      size: 24,
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          'Proctored assignment',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _text),
                        ),
                        Text(
                          'Read the rules before you start',
                          style: TextStyle(fontSize: 13, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: IconButton.styleFrom(
                      backgroundColor: _tint,
                      foregroundColor: ColorName.primary,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  spacing: 10,
                  children: [
                    for (final (kind, rule) in integrityConsentRules(widget.maxViolations))
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 10,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              _icon(kind),
                              size: 16,
                              color: kind == IntegrityRuleKind.limit ? _red : ColorName.primary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              rule,
                              style: const TextStyle(fontSize: 13, height: 1.4, color: _muted),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _accepted = !_accepted),
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    Checkbox(
                      value: _accepted,
                      onChanged: (value) => setState(() => _accepted = value ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'I have read and agree to the proctoring rules',
                        style: TextStyle(fontSize: 13, color: _text),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: _tint,
                      foregroundColor: ColorName.primary,
                      shape: shape,
                    ),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _accepted ? () => Navigator.of(context).pop(true) : null,
                    style: FilledButton.styleFrom(shape: shape),
                    child: const Text('Start attempt'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
