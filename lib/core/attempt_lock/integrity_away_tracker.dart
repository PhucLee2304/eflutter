import 'dart:async';

/// Một lần rời màn thi đã kết thúc.
class AwayEpisode {
  const AwayEpisode({required this.startedAt, required this.endedAt});
  final DateTime startedAt;
  final DateTime endedAt;
  Duration get duration => endedAt.difference(startedAt);
}

/// State machine "rời màn" (PLAN_ATTEMPT_INTEGRITY.md mục 1.3): rời màn là
/// `hidden || !focused`. Một lần Alt+Tab sinh cả blur lẫn visibilitychange nhưng
/// chỉ là một episode: chỉ báo khi trạng thái gộp đổi.
///
/// Quay lại chỉ được chốt sau [settle]: nếu lại rời màn trước đó (focus giả nhấp
/// nháy khi đang ở app khác) thì vẫn là cùng episode. Thời điểm kết thúc là lúc
/// bắt đầu khoảng quay lại ổn định.
class IntegrityAwayTracker {
  IntegrityAwayTracker({
    required this.onStart,
    required this.onEnd,
    this.settle = Duration.zero,
  });

  final void Function(DateTime at) onStart;
  final void Function(AwayEpisode episode) onEnd;
  final Duration settle;

  bool _hidden = false;
  bool _focused = true;
  DateTime? _awaySince;
  DateTime? _returnedAt;
  Timer? _settleTimer;

  bool get isAway => _awaySince != null;

  void update({bool? hidden, bool? focused, DateTime? at}) {
    _hidden = hidden ?? _hidden;
    _focused = focused ?? _focused;
    final now = at ?? DateTime.now();
    final away = _hidden || !_focused;
    if (away) {
      // Quay lại chưa ổn định: tiếp tục episode cũ.
      _settleTimer?.cancel();
      _returnedAt = null;
      if (_awaySince == null) {
        _awaySince = now;
        onStart(now);
      }
      return;
    }
    if (_awaySince == null || _returnedAt != null) return;
    _returnedAt = now;
    if (settle == Duration.zero) {
      _finish();
    } else {
      _settleTimer = Timer(settle, _finish);
    }
  }

  void _finish() {
    final since = _awaySince;
    final returnedAt = _returnedAt;
    if (since == null || returnedAt == null) return;
    _awaySince = null;
    _returnedAt = null;
    onEnd(AwayEpisode(startedAt: since, endedAt: returnedAt));
  }

  void dispose() => _settleTimer?.cancel();
}
