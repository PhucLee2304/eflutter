import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Màu theo số vi phạm: xám khi chưa có, cam khi còn lượt, đỏ khi hết lượt.
(Color, Color) _violationColors(AttemptIntegrityState integrity) {
  final count = integrity.violationCount;
  final max = integrity.maxViolations;
  if (max > 0 && count >= max) {
    return (const Color(0xFFD93025), const Color(0xFFFDECEA));
  }
  if (count > 0) return (const Color(0xFFB26A00), const Color(0xFFFFF4E5));
  return (const Color(0xFF65676B), const Color(0xFFF0F2F5));
}

/// Badge giám sát ở header màn làm bài (Figma S2): khiên + thanh vạch + chữ, cùng cách
/// nói với giáo viên (T1).
class IntegrityBadge extends StatelessWidget {
  const IntegrityBadge({super.key, required this.integrity});

  final AttemptIntegrityState integrity;

  @override
  Widget build(BuildContext context) => Tooltip(
    richMessage: TextSpan(
      children: [
        const TextSpan(
          text: 'Proctored exam\n',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        TextSpan(
          text:
              'Leaving the exam tab counts as a violation.\n'
              'Going over ${integrity.maxViolations} suspends the attempt with a score of 0.',
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1E21),
      borderRadius: BorderRadius.circular(8),
    ),
    child: _ViolationPill(integrity: integrity),
  );
}

/// Viên "khiên + vạch + chữ"; vạch chỉ vẽ khi được phép tối đa 5 lần.
class _ViolationPill extends StatelessWidget {
  const _ViolationPill({required this.integrity});

  final AttemptIntegrityState integrity;

  @override
  Widget build(BuildContext context) {
    final count = integrity.violationCount;
    final max = integrity.maxViolations;
    final (color, background) = _violationColors(integrity);
    final label = max > 0 && count >= max
        ? 'Limit reached'
        : count == 0
        ? 'No violations'
        : '$count of $max ${max == 1 ? 'violation' : 'violations'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Icon(SolarIconsOutline.shieldCheck, size: 16, color: color),
          if (max > 0 && max <= 5)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [
                for (var i = 0; i < max; i++)
                  Container(
                    width: 14,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < count ? color : const Color(0xFFE4E6EB),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Cảnh báo sau mỗi lần rời màn (Figma S3): cùng viên badge với header để học sinh
/// thấy ngay mình còn bao nhiêu lượt.
Future<void> showViolationWarning(BuildContext context, AttemptIntegrityState integrity) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final remaining = integrity.maxViolations - integrity.violationCount;
        final (color, background) = _violationColors(integrity);
        final message = remaining > 0
            ? 'Your teacher has been notified. You can leave $remaining more '
                  '${remaining == 1 ? 'time' : 'times'}; after that the attempt is '
                  'suspended with a score of 0.'
            : 'Your teacher has been notified. You have used all allowed violations. '
                  'Leaving again will suspend the attempt with a score of 0.';
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                    child: Icon(Icons.exit_to_app, size: 22, color: color),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You left the exam',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1E21),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF65676B))),
                  const SizedBox(height: 14),
                  _ViolationPill(integrity: integrity),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Back to the exam'),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  static const _red = (Color(0xFFD93025), Color(0xFFFDECEA));
  static const _orange = (Color(0xFFB26A00), Color(0xFFFFF4E5));
  static const _blue = (ColorName.primary, Color(0xFFEEF7FD));

  static const _waiting = Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      Text('Please wait…', style: TextStyle(fontSize: 13, color: Color(0xFF65676B))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (state.terminated) {
      final completed = state.completedAttempt != null;
      final byTeacher = state.terminationReason == 'TEACHER_BANNED';
      final max = state.integrity?.maxViolations;
      return _Panel(
        icon: Icons.block,
        colors: _red,
        title: byTeacher ? 'Your teacher suspended this attempt' : 'Attempt suspended',
        message: !completed
            ? 'Saving your answers before showing the result.'
            : byTeacher
            ? 'It was submitted with a score of 0. Contact your teacher if this '
                  'is a mistake.'
            : 'You went over ${max == null ? 'the allowed number of' : '$max'} '
                  'violations. The attempt was submitted with a score of 0. '
                  'Contact your teacher if this is a mistake.',
        actions: [
          completed
              ? FilledButton(onPressed: onViewResult, child: const Text('View result'))
              : const FilledButton(onPressed: null, child: Text('Saving the attempt…')),
        ],
      );
    }
    if (state.resetByTeacher) {
      return _Panel(
        icon: Icons.refresh,
        colors: _orange,
        title: 'Attempt reset',
        message:
            'Your teacher reset this attempt. Open the assignment again to '
            'start over.',
        actions: [FilledButton(onPressed: onLeave, child: const Text('Back to classwork'))],
      );
    }
    return switch (state.sessionStatus) {
      AttemptSessionStatus.claiming => const _Panel(
        icon: SolarIconsOutline.shieldCheck,
        colors: _blue,
        title: 'Connecting to the proctored session',
        message: 'This only takes a moment.',
        actions: [_waiting],
      ),
      AttemptSessionStatus.inUse => _Panel(
        icon: Icons.desktop_windows_outlined,
        colors: _orange,
        title: 'Open in another tab or device',
        message: 'Close it there, then try again here.',
        actions: [FilledButton(onPressed: cubit.retrySessionClaim, child: const Text('Try again'))],
      ),
      AttemptSessionStatus.recovering => _Panel(
        icon: Icons.schedule,
        colors: _orange,
        title: 'Waiting for the previous session',
        message:
            'It disconnected recently. This device can take over in '
            '${(state.sessionRetryAfter ?? Duration.zero).inSeconds + 1}s.',
        actions: const [_waiting],
      ),
      AttemptSessionStatus.takeoverRequired => _Panel(
        icon: Icons.swap_horiz,
        colors: _blue,
        title: 'Continue on this device?',
        message:
            'The attempt was last open somewhere else. Continuing here closes it '
            'there. Your teacher will see this.',
        actions: [
          FilledButton(
            onPressed: onLeave,
            style: FilledButton.styleFrom(
              backgroundColor: _blue.$2,
              foregroundColor: ColorName.primary,
            ),
            child: const Text('Not now'),
          ),
          FilledButton(onPressed: cubit.takeoverSession, child: const Text('Continue here')),
        ],
      ),
      AttemptSessionStatus.revoked => _Panel(
        icon: Icons.desktop_windows_outlined,
        colors: _orange,
        title: 'Continued in another session',
        message: 'This attempt is now open in another tab or device.',
        actions: [
          FilledButton(onPressed: cubit.retrySessionClaim, child: const Text('Take it back')),
        ],
      ),
      AttemptSessionStatus.none || AttemptSessionStatus.owned => const SizedBox.shrink(),
    };
  }
}

/// Thẻ chung của màn che (Figma S4): icon trên nền nhạt, tiêu đề, mô tả, hành động.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.colors,
    required this.title,
    required this.message,
    required this.actions,
  });

  final IconData icon;

  /// (màu chính, màu nền nhạt).
  final (Color, Color) colors;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  // Màn che nằm trên Scaffold trong Stack nên cần Material riêng cho chữ và nút.
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF7F8FA),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: ColorName.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E6EB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: colors.$2, shape: BoxShape.circle),
                  child: Icon(icon, size: 24, color: colors.$1),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1E21),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF65676B)),
                ),
                const SizedBox(height: 20),
                Wrap(spacing: 8, alignment: WrapAlignment.center, children: actions),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
