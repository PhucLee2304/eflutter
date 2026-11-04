import 'dart:async';

import 'package:web/web.dart';

/// Web: hỏi xác nhận khi đóng tab hoặc tải lại trang lúc đang làm bài.
class LeaveGuard {
  StreamSubscription<BeforeUnloadEvent>? _subscription;

  void enable() {
    _subscription ??= EventStreamProviders.beforeUnloadEvent
        .forTarget(window)
        .listen((event) {
          event.preventDefault();
          event.returnValue = '';
        });
  }

  void disable() {
    _subscription?.cancel();
    _subscription = null;
  }
}
