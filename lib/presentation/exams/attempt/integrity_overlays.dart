import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Badge "Proctored · x/N" ở header màn làm bài; đỏ khi đã dùng hết số lần.
class IntegrityBadge extends StatelessWidget {
  const IntegrityBadge({super.key, required this.integrity});

  final AttemptIntegrityState integrity;

  @override
  Widget build(BuildContext context) {
    final atLimit =
        integrity.maxViolations > 0 &&
        integrity.violationCount >= integrity.maxViolations;
    final color = atLimit
        ? ColorName.red
        : integrity.violationCount > 0
        ? ColorName.orange
        : ColorName.primary;
    return Tooltip(
      message:
          'Leaving the exam screen is recorded. Going over '
          '${integrity.maxViolations} violations suspends the attempt.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(SolarIconsOutline.shieldCheck, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              'Proctored · ${integrity.violationCount}/${integrity.maxViolations}',
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showViolationWarning(
  BuildContext context,
  AttemptIntegrityState integrity,
) => showDialog<void>(
  context: context,
  builder: (context) {
    final remaining = integrity.maxViolations - integrity.violationCount;
    return AlertDialog(
      icon: const Icon(
        SolarIconsOutline.dangerTriangle,
        color: ColorName.red,
        size: 36,
      ),
      title: Text(
        'Violation ${integrity.violationCount}/${integrity.maxViolations}',
      ),
      content: Text(
        'You left the exam screen. Your teacher has been notified. '
        '${remaining > 0 ? 'You have $remaining more allowed.' : 'One more violation will suspend the attempt with a score of 0.'}',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to the exam'),
        ),
      ],
    );
  },
);

/// Màn che phần làm bài khi kết nối này không được làm bài: phiên ở nơi khác,
/// bị đình chỉ, bị reset. Null thì không che.
class IntegrityOverlay extends StatelessWidget {
  const IntegrityOverlay({
    super.key,
    required this.state,
    required this.cubit,
    required this.onViewResult,
    required this.onLeave,
  });

  final AttemptSessionState state;
  final AttemptSessionCubit cubit;
  final VoidCallback onViewResult;
  final VoidCallback onLeave;

  static bool covers(AttemptSessionState state) =>
      state.terminated || state.resetByTeacher || state.sessionBlocked;

  @override
  Widget build(BuildContext context) {
    if (state.terminated) {
      final completed = state.completedAttempt != null;
      return _Panel(
        icon: SolarIconsOutline.forbiddenCircle,
        color: ColorName.red,
        title: 'Attempt suspended',
        message: state.terminationReason == 'TEACHER_BANNED'
            ? 'Your teacher suspended this attempt. It has been submitted with a '
                  'score of 0. Contact your teacher if this is a mistake.'
            : 'You went over the allowed number of violations. The attempt has '
                  'been submitted with a score of 0. Contact your teacher if this '
                  'is a mistake.',
        actions: [
          FilledButton(
            onPressed: completed ? onViewResult : null,
            child: Text(completed ? 'View result' : 'Saving the attempt…'),
          ),
        ],
      );
    }
    if (state.resetByTeacher) {
      return _Panel(
        icon: SolarIconsOutline.restart,
        color: ColorName.orange,
        title: 'Attempt reset',
        message:
            'Your teacher reset this attempt. Open the assignment again to '
            'start over.',
        actions: [FilledButton(onPressed: onLeave, child: const Text('Leave'))],
      );
    }
    return switch (state.sessionStatus) {
      AttemptSessionStatus.claiming => const _Panel(
        icon: SolarIconsOutline.shieldCheck,
        color: ColorName.primary,
        title: 'Connecting to the proctored session…',
        message: 'Please wait a moment.',
        actions: [CircularProgressIndicator()],
      ),
      AttemptSessionStatus.inUse => _Panel(
        icon: SolarIconsOutline.monitor,
        color: ColorName.orange,
        title: 'Attempt is open elsewhere',
        message:
            'This attempt is open in another tab or device. Close it there, '
            'then try again.',
        actions: [
          FilledButton(
            onPressed: cubit.retrySessionClaim,
            child: const Text('Try again'),
          ),
        ],
      ),
      AttemptSessionStatus.recovering => _Panel(
        icon: SolarIconsOutline.clockCircle,
        color: ColorName.orange,
        title: 'Waiting for the previous session…',
        message:
            'The previous session disconnected recently. It can continue for '
            'about ${(state.sessionRetryAfter ?? Duration.zero).inSeconds + 1} '
            'more seconds before this device can take over.',
        actions: const [CircularProgressIndicator()],
      ),
      AttemptSessionStatus.takeoverRequired => _Panel(
        icon: SolarIconsOutline.smartphone,
        color: ColorName.primary,
        title: 'Continue on this device?',
        message:
            'The attempt was last open somewhere else. Continuing here closes it '
            'there. Your teacher will see this change.',
        actions: [
          FilledButton(
            onPressed: cubit.takeoverSession,
            child: const Text('Continue here'),
          ),
        ],
      ),
      AttemptSessionStatus.revoked => _Panel(
        icon: SolarIconsOutline.monitor,
        color: ColorName.orange,
        title: 'Attempt continued in another session',
        message: 'This attempt is now open in another tab or device.',
        actions: [
          FilledButton(
            onPressed: cubit.retrySessionClaim,
            child: const Text('Try again'),
          ),
        ],
      ),
      AttemptSessionStatus.none ||
      AttemptSessionStatus.owned => const SizedBox.shrink(),
    };
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  // Màn che nằm trên Scaffold trong Stack nên cần Material riêng cho chữ và nút.
  Widget build(BuildContext context) => Material(
    color: ColorName.white,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ColorName.labelSecondary),
              ),
              const SizedBox(height: 20),
              Wrap(spacing: 8, children: actions),
            ],
          ),
        ),
      ),
    ),
  );
}
