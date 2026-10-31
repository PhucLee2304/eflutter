import 'package:eflutter/core/attempt_lock/attempt_lock_notifier.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/exams/attempt/integrity_overlays.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:eflutter/presentation/exams/exam_history_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Phần chung của mọi màn làm bài (L1): chặn rời màn khi đang làm, khóa/mở khóa
/// AttemptLockNotifier, báo lỗi socket và chuyển sang lịch sử khi đã nộp/hủy.
/// Bài có giám sát: cảnh báo vi phạm và che màn khi phiên ở nơi khác, bị đình chỉ
/// hoặc bị reset (PLAN_ATTEMPT_INTEGRITY.md I3).
class AttemptSessionScope extends StatelessWidget {
  const AttemptSessionScope({super.key, required this.cubit, required this.child});

  final AttemptSessionCubit cubit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lock = getIt<AttemptLockNotifier>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack(context, lock);
      },
      child: MultiBlocListener(
        listeners: [
          // Chuyển trang đúng một lần khi bài vừa nộp xong; server tự nộp thì báo lý do trước.
          BlocListener<AttemptSessionCubit, AttemptSessionState>(
            bloc: cubit,
            listenWhen: (previous, current) =>
                previous.completedAttempt == null && current.completedAttempt != null,
            listener: (context, state) async {
              notifyExamHistoryChanged();
              lock.unlock();
              // Bị đình chỉ: ở lại màn đình chỉ, học sinh tự bấm xem kết quả.
              if (state.terminated) return;
              if (state.submitReason case final reason?) {
                await _showSubmittedNotice(context, reason);
                if (!context.mounted) return;
              }
              _openResult(context, state);
            },
          ),
        ],
        child: BlocListener<AttemptSessionCubit, AttemptSessionState>(
          bloc: cubit,
          listener: (context, state) {
            final attempt = state.attempt;
            if (state.resetByTeacher) {
              lock.unlock();
            } else if (attempt != null &&
                attempt.status.toUpperCase() == 'ACTIVE' &&
                state.completedAttempt == null) {
              lock.lock(attempt.id);
            }
            if (state.failure != null) context.handleFailure(state.failure);
            if (state.socketMessage != null) {
              context.showToast(state.socketMessage!, type: ToastType.error);
            }
          },
          child: BlocConsumer<AttemptSessionCubit, AttemptSessionState>(
            bloc: cubit,
            listenWhen: (previous, current) =>
                current.violationAlerts > previous.violationAlerts && !current.terminated,
            listener: (context, state) {
              final integrity = state.integrity;
              if (integrity != null) showViolationWarning(context, integrity);
            },
            buildWhen: (previous, current) =>
                IntegrityOverlay.covers(previous) != IntegrityOverlay.covers(current) ||
                (IntegrityOverlay.covers(current) &&
                    (previous.sessionStatus != current.sessionStatus ||
                        previous.completedAttempt != current.completedAttempt ||
                        previous.sessionRetryAfter != current.sessionRetryAfter)),
            builder: (context, state) => Stack(
              children: [
                child,
                if (IntegrityOverlay.covers(state))
                  Positioned.fill(
                    child: IntegrityOverlay(
                      state: state,
                      cubit: cubit,
                      onViewResult: () => _openResult(context, state),
                      onLeave: () => leaveAttempt(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hộp báo vì sao bài bị nộp; chỉ chuyển trang sau khi học sinh bấm "Got it".
  static Future<void> _showSubmittedNotice(BuildContext context, String reason) {
    final (title, message) = switch (reason) {
      'EXAM_UPDATED' => (
        'Your teacher updated this assignment',
        'Your attempt was submitted with the answers you had saved, so it is graded '
            'against one version of the questions.',
      ),
      'ASSIGNMENT_PAUSED' => (
        'This assignment was closed',
        'Your teacher paused the assignment. Your attempt was submitted with the answers '
            'you had saved.',
      ),
      'REMOVED_FROM_CLASS' => (
        'You were removed from the class',
        'Your attempt was submitted with the answers you had saved.',
      ),
      _ => ('Your attempt was submitted', 'It was submitted with the answers you had saved.'),
    };
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(SolarIconsOutline.infoCircle, size: 36, color: ColorName.primary),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it, view result'),
            ),
          ],
        ),
      ),
    );
  }

  static void _openResult(BuildContext context, AttemptSessionState state) {
    final completed = state.completedAttempt;
    if (completed == null) return;
    // Bài giao mở từ lớp thì xem lại trong tab Classwork của lớp đó.
    final review = assignmentReviewPaths[completed.id];
    if (review != null) {
      context.go(review);
      return;
    }
    context.go(attemptHistoryDetailPath(completed.id), extra: completed);
  }

  /// Đang làm bài thì không có lối rời màn: chỉ nộp hoặc hủy bài.
  static void _handleBack(BuildContext context, AttemptLockNotifier lock) {
    if (lock.isLocked) {
      lock.reportBackBlocked();
      context.showToast(
        'You are taking an exam. Submit or cancel it to leave.',
        type: ToastType.warning,
      );
      return;
    }
    leaveAttempt(context);
  }
}

void leaveAttempt(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.histories.path);
  }
}

Future<bool> confirmAttemptAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Back')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: ColorName.red) : null,
            onPressed: () => context.pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<void> confirmSubmitAttempt(
  BuildContext context,
  AttemptSessionCubit cubit, {
  String message = 'Your current answers will be graded and cannot be changed.',
}) async {
  final accepted = await confirmAttemptAction(
    context,
    title: 'Submit attempt?',
    message: message,
    action: 'Submit',
  );
  if (accepted) await cubit.submit();
}

Future<void> confirmCancelAttempt(BuildContext context, AttemptSessionCubit cubit) async {
  final accepted = await confirmAttemptAction(
    context,
    title: 'Cancel attempt?',
    message: 'The attempt will be saved as cancelled without a score.',
    action: 'Cancel attempt',
    destructive: true,
  );
  if (accepted) await cubit.cancel();
}

/// Không tải được attempt (đã nộp, hết hạn, không tồn tại).
class MissingAttempt extends StatelessWidget {
  const MissingAttempt({super.key});

  /// Đồng bộ lại khóa với server trước khi rời màn.
  Future<void> _back(BuildContext context) async {
    await getIt<AttemptLockNotifier>().refresh();
    if (context.mounted) leaveAttempt(context);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Attempt not found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _back(context),
          icon: const Icon(SolarIconsOutline.altArrowLeft),
          label: const Text('Back'),
        ),
      ],
    ),
  );
}
