import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

abstract final class NotificationBrowser {
  /// Tắt hoặc rời trang.
  static StreamSubscription<void> onPageHide(void Function() callback) =>
      web.EventStreamProviders.pageHideEvent.forTarget(web.window).listen((_) => callback());

  /// Trang được khôi phục từ back/forward cache.
  static StreamSubscription<void> onPageRestored(void Function() callback) =>
      web.EventStreamProviders.pageShowEvent.forTarget(web.window).listen((event) {
        if ((event as web.PageTransitionEvent).persisted) callback();
      });

  static bool get permissionGranted => web.Notification.permission == 'granted';

  static bool get pageHidden => web.document.visibilityState == 'hidden';

  /// Hiện thông báo hệ thống; bấm vào thì focus tab, đóng thông báo rồi gọi [onClick].
  static void show({
    required String title,
    required String body,
    required String tag,
    required void Function() onClick,
  }) {
    final notification = web.Notification(
      title,
      web.NotificationOptions(body: body, tag: tag, icon: 'icons/Icon-192.png'),
    );
    notification.onclick = (web.Event _) {
      web.window.focus();
      notification.close();
      onClick();
    }.toJS;
  }
}
