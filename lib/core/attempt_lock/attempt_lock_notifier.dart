import 'package:eflutter/core/attempt_lock/attempt_integrity_reporter.dart';
import 'package:eflutter/core/attempt_lock/leave_guard.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

/// Khóa người dùng trong màn làm bài khi có attempt ACTIVE.
///
/// Nguồn sự thật là server (mỗi user tối đa một attempt ACTIVE), nên khóa
/// được khôi phục sau khi tải lại trang, mở tab mới hoặc đăng nhập máy khác.
/// Lối ra duy nhất là nộp hoặc hủy bài trong màn làm bài.
@lazySingleton
class AttemptLockNotifier extends ChangeNotifier {
  final ExamRepository _repository;
  final AttemptIntegrityReporter _reporter;
  final LeaveGuard _leaveGuard;

  AttemptLockNotifier(
    RemoteDataBase remoteData,
    this._reporter,
    this._leaveGuard,
  ) : _repository = ExamRepository(remoteData);

  int? _attemptId;
  AppLifecycleListener? _lifecycleListener;

  int? get attemptId => _attemptId;
  bool get isLocked => _attemptId != null;
  String? get lockedPath =>
      _attemptId == null ? null : attemptPracticePath(_attemptId!);

  /// Đồng bộ khóa với attempt ACTIVE trên server. Lỗi mạng giữ nguyên trạng thái.
  Future<void> refresh() async {
    final result = await _repository.getAttempts(
      status: 'ACTIVE',
      page: 1,
      pageSize: 1,
    );
    if (result case Success(data: final page)) {
      final active = page.attempts.firstOrNull;
      if (active == null) {
        unlock();
      } else if (active.id != _attemptId) {
        lock(active.id);
        _report(AttemptIntegrityEventType.sessionRestored);
      }
    }
  }

  void lock(int attemptId) {
    if (_attemptId == attemptId) return;
    _attemptId = attemptId;
    _leaveGuard.enable();
    _lifecycleListener ??= AppLifecycleListener(
      onStateChange: (state) => _report(
        AttemptIntegrityEventType.lifecycleChanged,
        detail: state.name,
      ),
    );
    notifyListeners();
  }

  void unlock() {
    if (_attemptId == null) return;
    _attemptId = null;
    _leaveGuard.disable();
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    notifyListeners();
  }

  /// Dùng trong redirect của router: trả đường dẫn màn làm bài nếu [path]
  /// nằm ngoài màn đó, ngược lại trả null.
  String? redirectFor(String path) {
    final locked = lockedPath;
    if (locked == null || path == locked) return null;
    if (kDebugMode && path == AppRoutes.log.path) return null;
    _report(AttemptIntegrityEventType.navigationBlocked, detail: path);
    return locked;
  }

  void reportBackBlocked() => _report(AttemptIntegrityEventType.backBlocked);

  void _report(AttemptIntegrityEventType type, {String? detail}) {
    final attemptId = _attemptId;
    if (attemptId == null) return;
    _reporter.report(
      AttemptIntegrityEvent(type: type, attemptId: attemptId, detail: detail),
    );
  }

  @override
  void dispose() {
    _leaveGuard.disable();
    _lifecycleListener?.dispose();
    super.dispose();
  }
}
