import 'package:eflutter/core/attempt_lock/attempt_lock_notifier.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:eflutter/presentation/exams/exam_history_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Phần chung của mọi màn làm bài (L1): chặn rời màn khi đang làm, khóa/mở khóa
/// AttemptLockNotifier, báo lỗi socket và chuyển sang lịch sử khi đã nộp/hủy.
class AttemptSessionScope extends StatelessWidget {
  const AttemptSessionScope({
    super.key,
    required this.cubit,
    required this.child,
  });

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
      child: BlocListener<AttemptSessionCubit, AttemptSessionState>(
        bloc: cubit,
        listener: (context, state) {
          final attempt = state.attempt;
          if (attempt != null &&
              attempt.status.toUpperCase() == 'ACTIVE' &&
              state.completedAttempt == null) {
            lock.lock(attempt.id);
          }
          if (state.failure != null) context.handleFailure(state.failure);
          if (state.socketMessage != null) {
            context.showToast(state.socketMessage!, type: ToastType.error);
          }
          final completed = state.completedAttempt;
          if (completed != null) {
            notifyExamHistoryChanged();
            lock.unlock();
            context.go(
              attemptHistoryDetailPath(completed.id),
              extra: completed,
            );
          }
        },
        child: child,
      ),
    );
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
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: ColorName.red)
                : null,
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

Future<void> confirmCancelAttempt(
  BuildContext context,
  AttemptSessionCubit cubit,
) async {
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
