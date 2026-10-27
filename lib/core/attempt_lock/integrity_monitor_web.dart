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
class IntegrityMonitor {
  static const pollInterval = Duration(milliseconds: 500);

  final _subscriptions = <StreamSubscription<Event>>[];
  Timer? _poll;

  void start({
    required IntegrityAwayTracker tracker,
    required void Function(String type) onClipboard,
  }) {
    if (_subscriptions.isNotEmpty) return;
    void sync() =>
        tracker.update(hidden: document.hidden, focused: document.hasFocus());
    sync();
    _subscriptions.addAll([
      const EventStreamProvider<Event>(
        'visibilitychange',
      ).forTarget(document).listen((_) => sync()),
      EventStreamProviders.blurEvent
          .forTarget(window)
          .listen((_) => tracker.update(focused: false)),
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
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
