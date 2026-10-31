part of 'attempt_session_cubit.dart';

/// [rejected]: server từ chối vĩnh viễn (QUESTION_LOCKED), không gửi lại.
enum AnswerSyncStatus { pending, synced, failed, rejected }

class AttemptSessionState {
  final ExamAttempt? attempt;
  final Map<int, int?> selectedOptions;
  final Map<int, AnswerSyncStatus> syncStatuses;
  final AttemptSocketStatus socketStatus;
  final Duration? remaining;
  final bool isLoading;
  final bool isSubmitting;
  final bool isCancelling;
  final bool isLocked;
  final ExamAttempt? completedAttempt;
  final Failure? failure;
  final String? socketMessage;

  // Giám sát (PLAN_ATTEMPT_INTEGRITY.md): null khi bài không giám sát.
  final AttemptIntegrityState? integrity;
  final AttemptSessionStatus sessionStatus;
  final Duration? sessionRetryAfter;

  /// Tăng mỗi lần nhận ATTEMPT_VIOLATION để màn làm bài hiện cảnh báo.
  final int violationAlerts;
  final bool terminated;
  final String? terminationReason;

  /// Giáo viên reset bài (hoặc attempt không còn) trong lúc đang làm.
  final bool resetByTeacher;

  /// Lý do server tự nộp bài (EXAM_UPDATED, ASSIGNMENT_PAUSED, REMOVED_FROM_CLASS);
  /// có giá trị thì báo cho học sinh trước khi chuyển sang trang kết quả.
  final String? submitReason;

  const AttemptSessionState({
    this.attempt,
    this.selectedOptions = const {},
    this.syncStatuses = const {},
    this.socketStatus = AttemptSocketStatus.disconnected,
    this.remaining,
    this.isLoading = false,
    this.isSubmitting = false,
    this.isCancelling = false,
    this.isLocked = false,
    this.completedAttempt,
    this.failure,
    this.socketMessage,
    this.integrity,
    this.sessionStatus = AttemptSessionStatus.none,
    this.sessionRetryAfter,
    this.violationAlerts = 0,
    this.terminated = false,
    this.terminationReason,
    this.resetByTeacher = false,
    this.submitReason,
  });

  /// Bài có giám sát mà kết nối này chưa (hoặc không còn) là chủ phiên.
  bool get sessionBlocked =>
      integrity != null &&
      sessionStatus != AttemptSessionStatus.none &&
      sessionStatus != AttemptSessionStatus.owned;

  int get answeredCount =>
      selectedOptions.values.where((v) => v != null).length;

  AttemptSessionState copyWith({
    Object? attempt = _sentinel,
    Map<int, int?>? selectedOptions,
    Map<int, AnswerSyncStatus>? syncStatuses,
    AttemptSocketStatus? socketStatus,
    Object? remaining = _sentinel,
    bool? isLoading,
    bool? isSubmitting,
    bool? isCancelling,
    bool? isLocked,
    Object? completedAttempt = _sentinel,
    Object? failure = _sentinel,
    Object? socketMessage = _sentinel,
    Object? integrity = _sentinel,
    AttemptSessionStatus? sessionStatus,
    Object? sessionRetryAfter = _sentinel,
    int? violationAlerts,
    bool? terminated,
    Object? terminationReason = _sentinel,
    bool? resetByTeacher,
    String? submitReason,
  }) => AttemptSessionState(
    attempt: identical(attempt, _sentinel)
        ? this.attempt
        : attempt as ExamAttempt?,
    selectedOptions: selectedOptions ?? this.selectedOptions,
    syncStatuses: syncStatuses ?? this.syncStatuses,
    socketStatus: socketStatus ?? this.socketStatus,
    remaining: identical(remaining, _sentinel)
        ? this.remaining
        : remaining as Duration?,
    isLoading: isLoading ?? this.isLoading,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isCancelling: isCancelling ?? this.isCancelling,
    isLocked: isLocked ?? this.isLocked,
    completedAttempt: identical(completedAttempt, _sentinel)
        ? this.completedAttempt
        : completedAttempt as ExamAttempt?,
    failure: identical(failure, _sentinel) ? this.failure : failure as Failure?,
    socketMessage: identical(socketMessage, _sentinel)
        ? this.socketMessage
        : socketMessage as String?,
    integrity: identical(integrity, _sentinel)
        ? this.integrity
        : integrity as AttemptIntegrityState?,
    sessionStatus: sessionStatus ?? this.sessionStatus,
    sessionRetryAfter: identical(sessionRetryAfter, _sentinel)
        ? this.sessionRetryAfter
        : sessionRetryAfter as Duration?,
    violationAlerts: violationAlerts ?? this.violationAlerts,
    terminated: terminated ?? this.terminated,
    terminationReason: identical(terminationReason, _sentinel)
        ? this.terminationReason
        : terminationReason as String?,
    resetByTeacher: resetByTeacher ?? this.resetByTeacher,
    submitReason: submitReason ?? this.submitReason,
  );
}

const _sentinel = Object();
