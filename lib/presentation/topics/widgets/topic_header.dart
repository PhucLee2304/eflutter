import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class TopicBreadcrumb extends StatelessWidget {
  const TopicBreadcrumb({required this.items, super.key});

  /// Mục cuối là trang hiện tại nên không có onTap.
  final List<(String, VoidCallback?)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (index, (label, onTap)) in items.indexed) ...[
            if (index > 0)
              const Icon(
                SolarIconsOutline.altArrowRight,
                size: 14,
                color: ColorName.gray1,
              ),
            if (onTap == null)
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ColorName.labelPrimary,
                ),
              )
            else
              InkWell(
                onTap: onTap,
                child: Text(
                  label,
                  style: const TextStyle(color: ColorName.primary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class TopicHeader extends StatelessWidget {
  const TopicHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.chips = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  /// Nhãn xám bên phải, vd. "29 parts", "Vocab level: B1".
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        spacing: 12,
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: 'Back',
              style: IconButton.styleFrom(
                side: const BorderSide(color: ColorName.gray5),
              ),
              icon: const Icon(SolarIconsOutline.arrowLeft, size: 18),
            ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorName.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: ColorName.primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ColorName.labelPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: ColorName.labelSecondary),
                ),
              ],
            ),
          ),
          for (final chip in chips)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ColorName.gray6,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                chip,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ColorName.labelSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
