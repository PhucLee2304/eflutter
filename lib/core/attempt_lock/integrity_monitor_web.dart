import 'dart:async';

import 'package:eflutter/core/attempt_lock/integrity_away_tracker.dart';
import 'package:web/web.dart';

/// Web: rời tab (`visibilitychange`), mất focus và copy/paste. Copy/paste chỉ ghi
/// nhận, không chặn (mục 1.3).
///
/// Sự kiện `focus` của window không đáng tin: khi trình duyệt đang ở sau app khác,
/// Flutter web vẫn tự `focus()` lại ô nhập ẩn và Chrome bắn `focus` giả, cắt một lần
/// rời màn dài thành nhiều mảnh dưới ngưỡng. Vì vậy trạng thái focus luôn lấy từ
/// `document.hasFocus()`, và được dò lại định kỳ.
///
/// Tải lại / đóng trang không phải rời màn (reload chỉ được ghi bằng RELOAD). Thứ tự
/// `beforeunload` / `blur` / `visibilitychange` khác nhau giữa trình duyệt, nên mỗi lần
/// rời màn chỉ được chốt sau [awayConfirm]: trang đang bị huỷ sẽ chết trước đó và
/// không gửi gì. Sau `beforeunload` thì chờ [unloadGrace] (hộp "Leave site?"); hộp
/// mở lâu hơn thế thì cả khoảng đó là một lần rời màn. Rời màn sau khoảng chờ thì
/// episode được tính từ lúc bắt đầu rời.
class IntegrityMonitor {
  static const pollInterval = Duration(milliseconds: 250);
  static const awayConfirm = Duration(milliseconds: 600);
  static const unloadGrace = Duration(seconds: 3);

  final _subscriptions = <StreamSubscription<Event>>[];
  Timer? _poll;
  DateTime? _unloadAt;

  /// Lúc bắt đầu rời màn chưa chốt.
  DateTime? _awayAt;

  void start({
    required IntegrityAwayTracker tracker,
    required void Function(String type) onClipboard,
  }) {
    if (_subscriptions.isNotEmpty) return;
    void sync({bool blurred = false}) {
      final hidden = document.hidden;
      final focused = !blurred && document.hasFocus();
      final now = DateTime.now();
      if (!hidden && focused) {
        // Hộp "Leave site?" chặn JS: đồng hồ không chạy nên chuyển tab lúc hộp đang
        // mở không bị phát hiện. Ở lại hộp quá [unloadGrace] thì cả khoảng đó là
        // một lần rời màn.
        final unloadAt = _unloadAt;
        if (!tracker.isAway &&
            unloadAt != null &&
            now.difference(unloadAt) > unloadGrace) {
          tracker.update(focused: false, at: unloadAt);
        }
        _awayAt = null;
        _unloadAt = null;
        tracker.update(hidden: false, focused: true, at: now);
        return;
      }
      // Đang trong episode: báo ngay để quay lại chưa ổn định vẫn là cùng episode.
      if (tracker.isAway) {
        tracker.update(hidden: hidden, focused: focused);
        return;
      }
      final since = _awayAt ??= now;
      final unloadAt = _unloadAt;
      final wait = unloadAt != null && now.difference(unloadAt) < unloadGrace
          ? unloadGrace
          : awayConfirm;
      if (now.difference(since) < wait) return;
      _awayAt = null;
      _unloadAt = null;
      tracker.update(hidden: hidden, focused: focused, at: since);
    }

    sync();
    _subscriptions.addAll([
      EventStreamProviders.beforeUnloadEvent
          .forTarget(window)
          .listen((_) => _unloadAt ??= DateTime.now()),
      const EventStreamProvider<Event>(
        'visibilitychange',
      ).forTarget(document).listen((_) => sync()),
      EventStreamProviders.blurEvent
          .forTarget(window)
          .listen((_) => sync(blurred: true)),
      EventStreamProviders.focusEvent.forTarget(window).listen((_) => sync()),
      EventStreamProviders.copyEvent
          .forTarget(document)
          .listen((_) => onClipboard('copy')),
      EventStreamProviders.pasteEvent
          .forTarget(document)
          .listen((_) => onClipboard('paste')),
    ]);
    _poll = Timer.periodic(pollInterval, (_) => sync());
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
    _unloadAt = null;
    _awayAt = null;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
