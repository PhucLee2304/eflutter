import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:uuid/uuid.dart';

enum AttemptIntegrityEventType {
  /// Điều hướng (sidebar, URL, back trình duyệt, deep link) bị chặn.
  navigationBlocked('NAVIGATION_BLOCKED'),

  /// Nút back (app bar, Android) bị chặn.
  backBlocked('BACK_BLOCKED'),

  /// Trạng thái vòng đời app đổi. Chỉ log local: rời màn đã có awayStart/awayEnd.
  lifecycleChanged(null),

  /// Khóa được khôi phục từ server sau khi mở lại app/tải lại trang.
  sessionRestored('RELOAD'),

  /// Bắt đầu một lần rời màn thi (`document.hidden || !hasFocus`).
  awayStart('AWAY_START'),

  /// Quay lại màn thi; [AttemptIntegrityEvent.startEventId] trỏ về awayStart.
  awayEnd('AWAY_END'),
  copy('COPY'),
  paste('PASTE');

  const AttemptIntegrityEventType(this.wire);

  /// Tên gửi lên server; null thì không gửi.
  final String? wire;
}

class AttemptIntegrityEvent {
  final AttemptIntegrityEventType type;
  final int attemptId;
  final String? detail;
  final DateTime at;

  /// Cố định qua mọi lần gửi lại để server chống đếm trùng (mục 1.5).
  final String eventId;
  final String? startEventId;
  final int? clientDurationMs;

  AttemptIntegrityEvent({
    required this.type,
    required this.attemptId,
    this.detail,
    DateTime? at,
    String? eventId,
    this.startEventId,
    this.clientDurationMs,
  }) : at = at ?? DateTime.now(),
       eventId = eventId ?? const Uuid().v4();
}

/// Gửi một event qua kết nối chủ phiên. [replayed]: event phát sinh khi chưa có
/// kết nối đó (offline, trước khi claim, kết nối cũ).
typedef AttemptIntegritySender =
    void Function(AttemptIntegrityEvent event, {required bool replayed});

/// Ghi nhận hành vi khi làm bài có giám sát (PLAN_ATTEMPT_INTEGRITY.md mục 1.10).
///
/// Event được xếp hàng theo attempt và chỉ rời hàng khi server ACK. Cubit làm bài
/// [bind] sender sau khi claim phiên thành công và [unbind] khi mất kết nối.
abstract interface class AttemptIntegrityReporter {
  void report(AttemptIntegrityEvent event);
  void bind(int attemptId, AttemptIntegritySender sender);
  void unbind(int attemptId);
  void acknowledge(int attemptId, String eventId);

  /// Bỏ hàng đợi: attempt bị reset, không còn, đã kết thúc.
  void clear(int attemptId);

  /// Attempt không giám sát: không xếp hàng event của nó nữa.
  void ignore(int attemptId);
}

@LazySingleton(as: AttemptIntegrityReporter)
class SocketAttemptIntegrityReporter implements AttemptIntegrityReporter {
  SocketAttemptIntegrityReporter([this._talker]);

  /// Giới hạn mỗi hàng đợi; quá thì bỏ event cũ nhất.
  static const maxQueued = 200;

  final Talker? _talker;

  /// Event chưa được ACK. Lúc [bind] mọi event còn lại đều là gửi bù.
  final _queues = <int, List<AttemptIntegrityEvent>>{};
  final _ignored = <int>{};
  int? _boundAttempt;
  AttemptIntegritySender? _sender;

  List<AttemptIntegrityEvent> pending(int attemptId) =>
      List.unmodifiable(_queues[attemptId] ?? const <AttemptIntegrityEvent>[]);

  @override
  void report(AttemptIntegrityEvent event) {
    final detail = event.detail == null ? '' : ' ${event.detail}';
    _talker?.info(
      '[ATTEMPT_LOCK] attempt=${event.attemptId} ${event.type.name}$detail',
    );
    if (event.type.wire == null || _ignored.contains(event.attemptId)) return;
    final bound = _boundAttempt == event.attemptId;
    final queue = _queues.putIfAbsent(event.attemptId, () => []);
    queue.add(event);
    if (queue.length > maxQueued) queue.removeAt(0);
    if (bound) _send(event, replayed: false);
  }

  @override
  void bind(int attemptId, AttemptIntegritySender sender) {
    _boundAttempt = attemptId;
    _sender = sender;
    _ignored.remove(attemptId);
    for (final event in List.of(_queues[attemptId] ?? const [])) {
      _send(event, replayed: true);
    }
  }

  @override
  void unbind(int attemptId) {
    if (_boundAttempt != attemptId) return;
    _boundAttempt = null;
    _sender = null;
  }

  @override
  void acknowledge(int attemptId, String eventId) =>
      _queues[attemptId]?.removeWhere((event) => event.eventId == eventId);

  @override
  void clear(int attemptId) {
    _queues.remove(attemptId);
    unbind(attemptId);
  }

  @override
  void ignore(int attemptId) {
    clear(attemptId);
    _ignored.add(attemptId);
  }

  void _send(AttemptIntegrityEvent event, {required bool replayed}) {
    try {
      _sender?.call(event, replayed: replayed);
    } catch (_) {
      // Còn trong hàng đợi, gửi lại ở lần bind sau.
    }
  }
}
