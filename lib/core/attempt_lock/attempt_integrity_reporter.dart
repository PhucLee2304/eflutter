import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';

enum AttemptIntegrityEventType {
  /// Điều hướng (sidebar, URL, back trình duyệt, deep link) bị chặn.
  navigationBlocked,

  /// Nút back (app bar, Android) bị chặn.
  backBlocked,

  /// Trạng thái vòng đời app đổi: rời tab, mất focus, app vào nền.
  lifecycleChanged,

  /// Khóa được khôi phục từ server sau khi mở lại app/tải lại trang.
  sessionRestored,
}

class AttemptIntegrityEvent {
  final AttemptIntegrityEventType type;
  final int attemptId;
  final String? detail;
  final DateTime at;

  AttemptIntegrityEvent({
    required this.type,
    required this.attemptId,
    this.detail,
    DateTime? at,
  }) : at = at ?? DateTime.now();
}

/// Điểm móc cho cơ chế chống gian lận sau này (gửi về server, cảnh báo,
/// tự nộp bài…). Hiện tại chỉ ghi log.
abstract interface class AttemptIntegrityReporter {
  void report(AttemptIntegrityEvent event);
}

@LazySingleton(as: AttemptIntegrityReporter)
class LogAttemptIntegrityReporter implements AttemptIntegrityReporter {
  final Talker _talker;

  LogAttemptIntegrityReporter(this._talker);

  @override
  void report(AttemptIntegrityEvent event) {
    final detail = event.detail == null ? '' : ' ${event.detail}';
    _talker.info(
      '[ATTEMPT_LOCK] attempt=${event.attemptId} ${event.type.name}$detail',
    );
  }
}
