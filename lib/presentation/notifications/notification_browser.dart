// API trình duyệt cho thông báo (sự kiện trang, Notification hệ thống). Bản io là stub
// để code dùng chung (và test chạy trên VM) không kéo theo package:web.
export 'notification_browser_io.dart' if (dart.library.js_interop) 'notification_browser_web.dart';
