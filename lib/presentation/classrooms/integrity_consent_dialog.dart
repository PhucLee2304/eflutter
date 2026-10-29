import 'package:eflutter/core/attempt_lock/integrity_consent.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Hộp đồng ý quy chế giám sát (PLAN_ATTEMPT_INTEGRITY.md mục 1.7). Trả true khi
/// học sinh tích ô và bấm Bắt đầu.
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(SolarIconsOutline.shieldCheck, color: ColorName.primary, size: 36),
    title: const Text('Proctored assignment'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final rule in integrityConsentRules(widget.maxViolations))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(rule)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _accepted,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              title: const Text('I have read and agree to the proctoring rules'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Back')),
      FilledButton(
        onPressed: _accepted ? () => Navigator.of(context).pop(true) : null,
        child: const Text('Start'),
      ),
    ],
  );
}
