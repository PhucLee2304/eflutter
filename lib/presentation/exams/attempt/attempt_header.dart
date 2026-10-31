import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/attempt/integrity_overlays.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Header chung của màn làm bài: tên đề, tiến độ, đồng hồ, bảng câu hỏi, hủy, nộp.
class AttemptHeader extends StatelessWidget {
  const AttemptHeader({
    super.key,
    this.title,
    required this.state,
    required this.answeredCount,
    required this.totalQuestions,
    required this.onSubmit,
    required this.onCancel,
    this.onOpenPalette,
    this.subtitle,
    this.showSubmit = true,
  });

  /// Null thì bỏ khối tên + tiến độ bên trái (màn đã có thẻ đầu bài và cột tiến độ).
  final String? title;
  final AttemptSessionState state;
  final int answeredCount;
  final int totalQuestions;
  final VoidCallback onSubmit;

  /// Null thì ẩn nút hủy (bài giao không hủy được, chỉ nộp).
  final VoidCallback? onCancel;
  final VoidCallback? onOpenPalette;

  /// Dòng phụ thêm, vd "Listening · Part 2".
  final String? subtitle;

  /// Tắt khi màn đã có nút nộp riêng (cột tiến độ của màn làm bài dạng cuộn).
  final bool showSubmit;

  static final _paletteStyle = FilledButton.styleFrom(
    backgroundColor: const Color(0xFFEEF7FD),
    foregroundColor: ColorName.primary,
    minimumSize: const Size(36, 36),
    fixedSize: const Size.fromHeight(36),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );

  @override
  Widget build(BuildContext context) {
    final busy = state.isSubmitting || state.isCancelling;
    final actions = [
      _SavePill(status: state.socketStatus),
      if (state.integrity case final integrity?) IntegrityBadge(integrity: integrity),
      // Nút mở bảng câu hỏi kèm tiến độ (màn hẹp không có cột tiến độ).
      if (onOpenPalette != null)
        FilledButton.icon(
          onPressed: onOpenPalette,
          style: _paletteStyle.copyWith(
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          ),
          icon: const Icon(SolarIconsOutline.widget, size: 18),
          label: Text(
            '$answeredCount/$totalQuestions',
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ),
      if (onCancel != null)
        IconButton.outlined(
          tooltip: 'Cancel attempt',
          onPressed: busy ? null : onCancel,
          icon: state.isCancelling
              ? const SizedBox.square(dimension: 18, child: AppLoader())
              : const Icon(SolarIconsOutline.closeCircle, size: 20),
        ),
      if (showSubmit)
        FilledButton.icon(
          onPressed: busy ? null : onSubmit,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: state.isSubmitting
              ? const SizedBox.square(dimension: 18, child: AppLoader())
              : const Icon(SolarIconsOutline.checkCircle, size: 18),
          label: const Text('Submit'),
        ),
    ];
    final name = title;
    final Widget titleBlock = name == null
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              Text(
                [?subtitle, '$answeredCount/$totalQuestions answered'].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: ColorName.labelSecondary),
              ),
            ],
          );
    // Thanh trên (Figma 30:676): tên bài trái, đồng hồ giữa, trạng thái lưu + nộp bên phải.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: ColorName.white,
        border: Border(bottom: BorderSide(color: ColorName.gray5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                if (name != null) titleBlock,
                Row(
                  children: [
                    AttemptTimerBadge(remaining: state.remaining),
                    const Spacer(),
                    Flexible(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actions,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: titleBlock),
              AttemptTimerBadge(remaining: state.remaining),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: 10,
                  children: actions,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Trạng thái tự lưu đáp án lên server.
class _SavePill extends StatelessWidget {
  const _SavePill({required this.status});
  final AttemptSocketStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      AttemptSocketStatus.connected => ('Saved', const Color(0xFF475467), const Color(0xFFF2F4F7)),
      AttemptSocketStatus.connecting => (
        'Connecting…',
        const Color(0xFF475467),
        const Color(0xFFF2F4F7),
      ),
      AttemptSocketStatus.disconnected => (
        'Offline · kept on this device',
        const Color(0xFFB26A00),
        const Color(0xFFFFF4E5),
      ),
    };
    return Tooltip(
      message: 'Answers are saved automatically while you work.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: foreground),
        ),
      ),
    );
  }
}

class AttemptTimerBadge extends StatelessWidget {
  const AttemptTimerBadge({super.key, required this.remaining});
  final Duration? remaining;
  @override
  Widget build(BuildContext context) {
    final value = remaining == null
        ? 'No limit'
        : '${remaining!.inHours.toString().padLeft(2, '0')}:${(remaining!.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining!.inSeconds % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: ColorName.gray6, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          const Icon(SolarIconsOutline.clockCircle, size: 16, color: ColorName.labelSecondary),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (remaining != null)
            const Text('left', style: TextStyle(fontSize: 12, color: ColorName.labelSecondary)),
        ],
      ),
    );
  }
}
