import 'dart:async';

/// Ngoài web: không có sự kiện trang hay Notification hệ thống.
abstract final class NotificationBrowser {
  static StreamSubscription<void> onPageHide(void Function() callback) =>
      const Stream<void>.empty().listen(null);

  static StreamSubscription<void> onPageRestored(void Function() callback) =>
      const Stream<void>.empty().listen(null);

  static bool get permissionGranted => false;

  static bool get pageHidden => false;

  static void show({
    required String title,
    required String body,
    required String tag,
    required void Function() onClick,
  }) {}
}
