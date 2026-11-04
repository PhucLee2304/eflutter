import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/exams/self_study/self_study_stats.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const selfStudyBorder = Color(0xFFE3E8EF);
const selfStudyMuted = Color(0xFF5F6B7A);
const selfStudyTint = Color(0xFFEEF7FD);

/// Tiêu đề "Self-study", nút My history và hai thẻ chọn kỳ thi (TOEIC / THPT).
class SelfStudyHeader extends StatefulWidget {
  const SelfStudyHeader({super.key, required this.examType});

  final String examType;

  @override
  State<SelfStudyHeader> createState() => _SelfStudyHeaderState();
}

class _SelfStudyHeaderState extends State<SelfStudyHeader> {
  @override
  void initState() {
    super.initState();
    SelfStudyStatsStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    'Self-study',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: ColorName.labelPrimary,
                    ),
                  ),
                  Text(
                    'Practice past papers at your own pace and track your progress.',
                    style: TextStyle(fontSize: 15, color: selfStudyMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.histories.path),
              icon: const Icon(SolarIconsOutline.history, size: 18),
              label: const Text('My history'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorName.primary,
                backgroundColor: ColorName.white,
                side: const BorderSide(color: selfStudyBorder),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        ValueListenableBuilder(
          valueListenable: SelfStudyStatsStore.instance.stats,
          builder: (context, stats, _) {
            final cards = [
              for (final profile in _ExamChoice.all)
                _ExamChoiceCard(
                  profile: profile,
                  selected: profile.type == widget.examType,
                  stats: stats[profile.type],
                ),
            ];
            return LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 640
                  ? Column(spacing: 12, children: cards)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16,
                      children: [for (final card in cards) Expanded(child: card)],
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _ExamChoice {
  const _ExamChoice(this.type, this.subtitle, this.icon, this.path);

  final String type;
  final String subtitle;
  final IconData icon;
  final String path;

  static final all = [
    _ExamChoice(
      'TOEIC',
      'Listening & Reading · 990 pts',
      SolarIconsOutline.headphonesRound,
      AppRoutes.examToeic.path,
    ),
    _ExamChoice(
      'THPT',
      'National high school exam · English',
      SolarIconsOutline.squareAcademicCap,
      AppRoutes.examThpt.path,
    ),
  ];
}

class _ExamChoiceCard extends StatelessWidget {
  const _ExamChoiceCard({required this.profile, required this.selected, required this.stats});

  final _ExamChoice profile;
  final bool selected;
  final SelfStudyStats? stats;

  @override
  Widget build(BuildContext context) {
    final stats = this.stats;
    return Material(
      color: selected ? selfStudyTint : ColorName.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? ColorName.primary : selfStudyBorder,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: selected ? null : () => context.go(profile.path),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            spacing: 16,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected ? ColorName.primary : const Color(0xFFF1F3F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  profile.icon,
                  size: 24,
                  color: selected ? ColorName.white : selfStudyMuted,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      profile.type,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ColorName.labelPrimary,
                      ),
                    ),
                    Text(
                      profile.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: selfStudyMuted),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 4,
                        children: [
                          _Stat(value: '${stats?.attempts ?? 0}', label: 'attempts'),
                          _Stat(
                            value: stats?.bestScore == null
                                ? '–'
                                : formatSelfStudyScore(stats!.bestScore!),
                            label: 'best score',
                          ),
                          _Stat(
                            value: stats?.lastPracticeAt == null
                                ? '–'
                                : _relative(stats!.lastPracticeAt!),
                            label: 'last practice',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relative(DateTime at) {
    final diff = DateTime.now().difference(at.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 14) return '1 week ago';
    if (diff.inDays < 31) return '${diff.inDays ~/ 7} weeks ago';
    if (diff.inDays < 60) return '1 month ago';
    return '${diff.inDays ~/ 30} months ago';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600, color: ColorName.labelPrimary),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
      style: const TextStyle(fontSize: 13, color: selfStudyMuted),
    );
  }
}

String formatSelfStudyScore(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

/// Thanh số trang: ‹ 1 2 3 … 37 ›, rút gọn khi nhiều trang.
class PageNumberBar extends StatelessWidget {
  const PageNumberBar({
    super.key,
    required this.page,
    required this.pageCounts,
    required this.onSelect,
    this.enabled = true,
  });

  final int page;
  final int pageCounts;
  final ValueChanged<int> onSelect;
  final bool enabled;

  List<int?> _items() {
    if (pageCounts <= 7) return [for (var i = 1; i <= pageCounts; i++) i];
    final start = (page - 1).clamp(2, pageCounts - 3);
    final end = (page + 1).clamp(4, pageCounts - 1);
    return [
      1,
      if (start > 2) null,
      for (var i = start; i <= end; i++) i,
      if (end < pageCounts - 1) null,
      pageCounts,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (pageCounts <= 1) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        _PageButton(
          onTap: enabled && page > 1 ? () => onSelect(page - 1) : null,
          tooltip: 'Previous page',
          child: const Icon(SolarIconsOutline.altArrowLeft, size: 16),
        ),
        for (final item in _items())
          item == null
              ? const SizedBox(
                  width: 24,
                  height: 36,
                  child: Center(
                    child: Text('…', style: TextStyle(color: selfStudyMuted)),
                  ),
                )
              : _PageButton(
                  selected: item == page,
                  onTap: enabled && item != page ? () => onSelect(item) : null,
                  child: Text('$item'),
                ),
        _PageButton(
          onTap: enabled && page < pageCounts ? () => onSelect(page + 1) : null,
          tooltip: 'Next page',
          child: const Icon(SolarIconsOutline.altArrowRight, size: 16),
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.child, this.onTap, this.selected = false, this.tooltip});

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? ColorName.white : ColorName.labelPrimary;
    final button = Opacity(
      opacity: onTap == null && !selected ? 0.45 : 1,
      child: Material(
        color: selected ? ColorName.primary : ColorName.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: selected ? ColorName.primary : selfStudyBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: foreground),
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: foreground,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
