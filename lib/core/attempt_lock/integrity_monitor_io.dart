import 'package:eflutter/core/attempt_lock/integrity_away_tracker.dart';

/// Mobile/desktop: không theo dõi (ngoài phạm vi, mục 5).
class IntegrityMonitor {
  void start({
    required IntegrityAwayTracker tracker,
    required void Function(String type) onClipboard,
  }) {}

  void stop() {}
}
