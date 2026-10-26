import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Header chung của màn làm bài: tên đề, tiến độ, đồng hồ, bảng câu hỏi, hủy, nộp.
class AttemptHeader extends StatelessWidget {
  const AttemptHeader({
    super.key,
    required this.title,
    required this.state,
    required this.answeredCount,
    required this.totalQuestions,
    required this.onSubmit,
    required this.onCancel,
    this.onOpenPalette,
    this.subtitle,
  });

  final String title;
  final AttemptSessionState state;
  final int answeredCount;
  final int totalQuestions;
  final VoidCallback onSubmit;

  /// Null thì ẩn nút hủy (bài giao không hủy được, chỉ nộp).
  final VoidCallback? onCancel;
  final VoidCallback? onOpenPalette;

  /// Dòng phụ thêm, vd "Listening · Part 2".
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final busy = state.isSubmitting || state.isCancelling;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: ColorName.white,
        border: Border(bottom: BorderSide(color: ColorName.gray5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        ?subtitle,
                        '$answeredCount/$totalQuestions answered',
                        _socketLabel(state.socketStatus),
                      ].join('  |  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ColorName.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AttemptTimerBadge(remaining: state.remaining),
              const Spacer(),
              if (onOpenPalette != null) ...[
                IconButton.outlined(
                  tooltip: 'Question palette',
                  onPressed: onOpenPalette,
                  icon: const Icon(SolarIconsOutline.widget),
                ),
                const SizedBox(width: 8),
              ],
              if (onCancel != null) ...[
                IconButton.outlined(
                  tooltip: 'Cancel attempt',
                  onPressed: busy ? null : onCancel,
                  icon: state.isCancelling
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(SolarIconsOutline.closeCircle),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton.icon(
                onPressed: busy ? null : onSubmit,
                icon: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(SolarIconsOutline.checkCircle),
                label: const Text('Submit'),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColorName.gray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class AttemptSyncIcon extends StatelessWidget {
  const AttemptSyncIcon({super.key, required this.status});
  final AnswerSyncStatus status;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: switch (status) {
      AnswerSyncStatus.pending => 'Saving',
      AnswerSyncStatus.synced => 'Saved',
      AnswerSyncStatus.failed => 'Will retry',
      AnswerSyncStatus.rejected => 'Locked, not saved',
    },
    child: Icon(
      switch (status) {
        AnswerSyncStatus.pending => SolarIconsOutline.clockCircle,
        AnswerSyncStatus.synced => SolarIconsOutline.checkCircle,
        AnswerSyncStatus.failed => SolarIconsOutline.refreshCircle,
        AnswerSyncStatus.rejected => SolarIconsOutline.lock,
      },
      size: 20,
      color:
          status == AnswerSyncStatus.failed ||
              status == AnswerSyncStatus.rejected
          ? ColorName.orange
          : ColorName.labelSecondary,
    ),
  );
}

String _socketLabel(AttemptSocketStatus status) => switch (status) {
  AttemptSocketStatus.connected => 'Saved online',
  AttemptSocketStatus.connecting => 'Connecting',
  AttemptSocketStatus.disconnected => 'Offline, answers kept locally',
};
