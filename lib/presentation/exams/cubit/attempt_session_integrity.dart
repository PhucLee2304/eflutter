part of 'attempt_session_cubit.dart';

/// Phiên làm bài có giám sát (PLAN_ATTEMPT_INTEGRITY.md mục 1.4).
///
/// - [claiming]: đang xin quyền chủ phiên;
/// - [owned]: kết nối này là chủ phiên, được trả lời;
/// - [inUse]: bài đang mở ở tab/thiết bị khác;
/// - [recovering]: phiên cũ vừa ngắt, chờ [AttemptSessionState.sessionRetryAfter];
/// - [takeoverRequired]: phải xác nhận tiếp tục trên thiết bị này;
/// - [revoked]: phiên khác đã chiếm quyền.
enum AttemptSessionStatus {
  none,
  claiming,
  owned,
  inUse,
  recovering,
  takeoverRequired,
  revoked,
}

class AttemptIntegrityState {
  const AttemptIntegrityState({
    required this.violationCount,
    required this.maxViolations,
    required this.outcome,
  });

  final int violationCount;
  final int maxViolations;
  final String outcome;

  factory AttemptIntegrityState.fromAttempt(ExamAttempt attempt) =>
      AttemptIntegrityState(
        violationCount: attempt.violationCount ?? 0,
        maxViolations: attempt.maxViolations ?? 0,
        outcome: attempt.integrityOutcome ?? IntegrityOutcome.none,
      );

  /// `state` trong ACK claim/event của server.
  factory AttemptIntegrityState.fromJson(Map<String, dynamic> json) =>
      AttemptIntegrityState(
        violationCount: (json['violationCount'] as num?)?.toInt() ?? 0,
        maxViolations: (json['maxViolations'] as num?)?.toInt() ?? 0,
        outcome: json['outcome'] as String? ?? IntegrityOutcome.none,
      );

  AttemptIntegrityState copyWith({int? violationCount, int? maxViolations}) =>
      AttemptIntegrityState(
        violationCount: violationCount ?? this.violationCount,
        maxViolations: maxViolations ?? this.maxViolations,
        outcome: outcome,
      );
}

/// Quay lại màn thi phải giữ ổn định chừng này mới kết thúc episode (focus giả).
const _awaySettle = Duration(milliseconds: 1500);

mixin _AttemptIntegrity on Cubit<AttemptSessionState> {
  AttemptSocketGateway get _socket;
  AttemptIntegrityReporter get _reporter;
  IntegrityMonitor get _monitor;
  IntegritySessionStore get _sessionStore;
  bool get _closing;
  void _waitForBackendSubmission();
  void _resendPendingAnswers();

  final _claimRequests = <String>{};
  final _eventByRequest = <String, String>{};
  int? _sessionEpoch;
  Timer? _claimRetryTimer;
  IntegrityAwayTracker? _awayTracker;
  String? _awayStartEventId;

  bool get _isProctoredActive {
    final attempt = state.attempt;
    return attempt != null &&
        attempt.proctored &&
        attempt.status.toUpperCase() == 'ACTIVE' &&
        !state.terminated;
  }

  void _initIntegrity(ExamAttempt attempt) {
    if (!attempt.proctored) {
      _reporter.ignore(attempt.id);
      return;
    }
    final active = attempt.status.toUpperCase() == 'ACTIVE';
    emit(
      state.copyWith(
        integrity: AttemptIntegrityState.fromAttempt(attempt),
        sessionStatus: active
            ? AttemptSessionStatus.claiming
            : AttemptSessionStatus.none,
      ),
    );
  }

  /// "Thử lại" ở màn bài đang mở nơi khác / bị thu hồi.
  void retrySessionClaim() => _claimSession();

  /// Học sinh xác nhận tiếp tục bài trên thiết bị này (SESSION_TAKEOVER_REQUIRED).
  void takeoverSession() => _claimSession(takeover: true);

  void _claimSession({bool takeover = false}) {
    final attempt = state.attempt;
    if (_closing || attempt == null || !_isProctoredActive) return;
    _claimRetryTimer?.cancel();
    emit(
      state.copyWith(
        sessionStatus: AttemptSessionStatus.claiming,
        sessionRetryAfter: null,
      ),
    );
    if (state.socketStatus != AttemptSocketStatus.connected) return;
    try {
      _claimRequests.add(
        _socket.sendSessionClaim(
          attemptId: attempt.id,
          sessionToken: _sessionStore.read(attempt.id),
          takeover: takeover,
        ),
      );
    } catch (_) {
      // Socket vừa ngắt: claim lại khi nối lại.
    }
  }

  void _onIntegrityDisconnected() {
    final attempt = state.attempt;
    if (attempt != null) _reporter.unbind(attempt.id);
  }

  /// Trả true nếu [event] thuộc luồng giám sát.
  bool _handleIntegrityEvent(AttemptSocketEvent event) {
    if (_claimRequests.remove(event.requestId)) {
      _onClaimResult(event);
      return true;
    }
    final eventId = _eventByRequest.remove(event.requestId);
    if (eventId != null) {
      _onEventResult(event, eventId);
      return true;
    }
    final attempt = state.attempt;
    if (attempt == null || event.attemptId != attempt.id) return false;
    final payload = event.payload ?? const <String, dynamic>{};
    switch (event.type) {
      case AttemptSocketPush.violation:
        final count = (payload['violationCount'] as num?)?.toInt();
        final max = (payload['maxViolations'] as num?)?.toInt();
        // Vượt ngưỡng thì ATTEMPT_TERMINATED theo ngay sau: không cảnh báo nữa.
        final exceeded = count != null && max != null && count > max;
        emit(
          state.copyWith(
            integrity: state.integrity?.copyWith(
              violationCount: count,
              maxViolations: max,
            ),
            violationAlerts: state.violationAlerts + (exceeded ? 0 : 1),
          ),
        );
      case AttemptSocketPush.violationCleared:
        emit(
          state.copyWith(
            integrity: state.integrity?.copyWith(
              violationCount: (payload['violationCount'] as num?)?.toInt(),
              maxViolations: (payload['maxViolations'] as num?)?.toInt(),
            ),
          ),
        );
      case AttemptSocketPush.terminated:
        _stopIntegrity(attempt.id);
        emit(
          state.copyWith(
            terminated: true,
            terminationReason: payload['reason'] as String?,
            isLocked: true,
            failure: null,
          ),
        );
        _waitForBackendSubmission();
      case AttemptSocketPush.sessionRevoked:
        final epoch = (payload['sessionEpoch'] as num?)?.toInt() ?? 0;
        // Push gửi tới mọi kết nối của học sinh, kể cả phiên vừa claim.
        if (state.sessionStatus != AttemptSessionStatus.owned ||
            epoch <= (_sessionEpoch ?? 0)) {
          return true;
        }
        _reporter.unbind(attempt.id);
        emit(state.copyWith(sessionStatus: AttemptSessionStatus.revoked));
      case AttemptSocketPush.reset:
        _stopIntegrity(attempt.id);
        _sessionStore.remove(attempt.id);
        emit(state.copyWith(resetByTeacher: true, isLocked: true));
      default:
        return false;
    }
    return true;
  }

  void _onClaimResult(AttemptSocketEvent event) {
    final attempt = state.attempt;
    if (attempt == null || !_isProctoredActive) return;
    if (event.success) {
      final payload = event.payload ?? const <String, dynamic>{};
      final token = payload['sessionToken'] as String?;
      if (token != null) _sessionStore.write(attempt.id, token);
      _sessionEpoch = (payload['sessionEpoch'] as num?)?.toInt();
      final integrity = payload['state'];
      emit(
        state.copyWith(
          sessionStatus: AttemptSessionStatus.owned,
          integrity: integrity is Map<String, dynamic>
              ? AttemptIntegrityState.fromJson(integrity)
              : state.integrity,
        ),
      );
      _reporter.bind(attempt.id, _sendIntegrityEvent);
      _startMonitor(attempt.id);
      _resendPendingAnswers();
      return;
    }
    switch (event.code) {
      case AttemptSocketCode.attemptNotProctored:
        _reporter.ignore(attempt.id);
        emit(
          state.copyWith(
            integrity: null,
            sessionStatus: AttemptSessionStatus.none,
          ),
        );
        _resendPendingAnswers();
      case AttemptSocketCode.sessionInUse:
        emit(state.copyWith(sessionStatus: AttemptSessionStatus.inUse));
      case AttemptSocketCode.sessionRecovering:
        final retryAfter = Duration(
          milliseconds: (event.details?['retryAfterMs'] as num?)?.toInt() ?? 0,
        );
        emit(
          state.copyWith(
            sessionStatus: AttemptSessionStatus.recovering,
            sessionRetryAfter: retryAfter,
          ),
        );
        _claimRetryTimer = Timer(
          retryAfter + const Duration(milliseconds: 500),
          _claimSession,
        );
      case AttemptSocketCode.sessionTakeoverRequired:
        emit(
          state.copyWith(sessionStatus: AttemptSessionStatus.takeoverRequired),
        );
      case AttemptSocketCode.attemptNotActive ||
          AttemptSocketCode.attemptExpired:
        _stopIntegrity(attempt.id);
        emit(state.copyWith(isLocked: true));
        _waitForBackendSubmission();
      case AttemptSocketCode.attemptNotFound:
        _stopIntegrity(attempt.id);
        emit(state.copyWith(isLocked: true, resetByTeacher: true));
      default:
        _claimRetryTimer = Timer(const Duration(seconds: 2), _claimSession);
    }
  }

  void _sendIntegrityEvent(
    AttemptIntegrityEvent event, {
    required bool replayed,
  }) {
    final requestId = _socket.sendIntegrityEvent(
      attemptId: event.attemptId,
      sessionEpoch: _sessionEpoch ?? 0,
      eventId: event.eventId,
      type: event.type.wire!,
      at: event.at,
      replayed: replayed,
      startEventId: event.startEventId,
      clientDurationMs: event.clientDurationMs,
      detail: event.detail,
    );
    _eventByRequest[requestId] = event.eventId;
  }

  void _onEventResult(AttemptSocketEvent event, String eventId) {
    final attempt = state.attempt;
    if (attempt == null) return;
    if (event.success) {
      _reporter.acknowledge(attempt.id, eventId);
      final integrity = event.payload?['state'];
      if (integrity is Map<String, dynamic> && state.integrity != null) {
        emit(
          state.copyWith(integrity: AttemptIntegrityState.fromJson(integrity)),
        );
      }
      return;
    }
    switch (event.code) {
      case AttemptSocketCode.integrityEventInvalid:
        _reporter.acknowledge(attempt.id, eventId);
      case AttemptSocketCode.attemptNotFound ||
          AttemptSocketCode.attemptNotActive ||
          AttemptSocketCode.attemptExpired:
        _reporter.clear(attempt.id);
      default:
        // Giữ trong hàng đợi, gửi bù ở lần claim sau.
        break;
    }
  }

  void _startMonitor(int attemptId) {
    if (_awayTracker != null) return;
    final tracker = IntegrityAwayTracker(
      settle: _awaySettle,
      onStart: (at) {
        final event = AttemptIntegrityEvent(
          type: AttemptIntegrityEventType.awayStart,
          attemptId: attemptId,
          at: at,
        );
        _awayStartEventId = event.eventId;
        _reporter.report(event);
      },
      onEnd: (episode) {
        final startEventId = _awayStartEventId;
        _awayStartEventId = null;
        if (startEventId == null) return;
        _reporter.report(
          AttemptIntegrityEvent(
            type: AttemptIntegrityEventType.awayEnd,
            attemptId: attemptId,
            at: episode.endedAt,
            startEventId: startEventId,
            clientDurationMs: episode.duration.inMilliseconds,
          ),
        );
      },
    );
    _awayTracker = tracker;
    _monitor.start(
      tracker: tracker,
      onClipboard: (type) => _reporter.report(
        AttemptIntegrityEvent(
          type: type == 'copy'
              ? AttemptIntegrityEventType.copy
              : AttemptIntegrityEventType.paste,
          attemptId: attemptId,
        ),
      ),
    );
  }

  /// Dừng giám sát: bài đã kết thúc, bị đình chỉ hoặc reset.
  void _stopIntegrity(int attemptId) {
    _monitor.stop();
    _awayTracker?.dispose();
    _awayTracker = null;
    _awayStartEventId = null;
    _claimRetryTimer?.cancel();
    _reporter.clear(attemptId);
  }
}
