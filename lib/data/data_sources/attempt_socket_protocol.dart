// Kiểu dữ liệu và hằng của WebSocket /ws/exams, tách khỏi AttemptSocketClient để code và
// test dùng giao thức không kéo theo AuthInterceptor/DI (và package:web).

enum AttemptSocketStatus { disconnected, connecting, connected }

class AttemptSocketEvent {
  final String requestId;
  final bool success;
  final String? code;
  final String? message;
  final String? type;
  final int? attemptId;

  /// Payload của ACK (vd `ListeningState` cho ATTEMPT_LISTENING_ADVANCE).
  final Map<String, dynamic>? payload;

  /// Dữ liệu kèm lỗi (vd `retryAfterMs` của SESSION_RECOVERING).
  final Map<String, dynamic>? details;

  const AttemptSocketEvent({
    required this.requestId,
    required this.success,
    this.code,
    this.message,
    this.type,
    this.attemptId,
    this.payload,
    this.details,
  });
}

/// Mã lỗi WS của luồng TOEIC_STRICT (PLAN_TOEIC_ATTEMPT.md mục 1.5).
abstract final class AttemptSocketCode {
  static const questionLocked = 'QUESTION_LOCKED';
  static const pageLocked = 'PAGE_LOCKED';
  static const listeningPageMismatch = 'LISTENING_PAGE_MISMATCH';
  static const listeningAdvanceTooEarly = 'LISTENING_ADVANCE_TOO_EARLY';
  static const attemptExpired = 'ATTEMPT_EXPIRED';
  static const attemptNotActive = 'ATTEMPT_NOT_ACTIVE';
  static const attemptNotFound = 'ATTEMPT_NOT_FOUND';

  // Giám sát (PLAN_ATTEMPT_INTEGRITY.md mục 1.9).
  static const attemptNotProctored = 'ATTEMPT_NOT_PROCTORED';
  static const sessionInUse = 'SESSION_IN_USE';
  static const sessionRecovering = 'SESSION_RECOVERING';
  static const sessionTakeoverRequired = 'SESSION_TAKEOVER_REQUIRED';
  static const integrityEventInvalid = 'INTEGRITY_EVENT_INVALID';
}

/// Push server gửi tới học sinh, payload luôn có `attemptId`.
abstract final class AttemptSocketPush {
  static const submitted = 'ATTEMPT_SUBMITTED';
  static const violation = 'ATTEMPT_VIOLATION';

  /// Giáo viên cho tiếp tục làm bài: vi phạm được xóa, số vi phạm giảm.
  static const violationCleared = 'ATTEMPT_VIOLATION_CLEARED';
  static const terminated = 'ATTEMPT_TERMINATED';
  static const sessionRevoked = 'ATTEMPT_SESSION_REVOKED';
  static const reset = 'ATTEMPT_RESET';

  static const all = {submitted, violation, terminated, sessionRevoked, reset};
}

abstract interface class AttemptSocketGateway {
  Stream<AttemptSocketEvent> get events;
  Stream<AttemptSocketStatus> get statuses;
  Future<void> connect();
  String sendAnswer({required int attemptId, required int questionId, required int? optionId});
  String sendListeningAdvance({required int attemptId, required int page});
  String sendSessionClaim({required int attemptId, String? sessionToken, bool takeover = false});
  String sendIntegrityEvent({
    required int attemptId,
    required int sessionEpoch,
    required String eventId,
    required String type,
    required DateTime at,
    bool replayed = false,
    String? startEventId,
    int? clientDurationMs,
    String? detail,
  });
  Future<void> close();
}
