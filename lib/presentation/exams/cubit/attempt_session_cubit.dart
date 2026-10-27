import 'dart:async';

import 'package:eflutter/core/attempt_lock/attempt_integrity_reporter.dart';
import 'package:eflutter/core/attempt_lock/integrity_away_tracker.dart';
import 'package:eflutter/core/attempt_lock/integrity_monitor.dart';
import 'package:eflutter/core/attempt_lock/integrity_session_store.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_questions.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'attempt_session_integrity.dart';
part 'attempt_session_state.dart';

class AttemptSessionCubit extends Cubit<AttemptSessionState>
    with _AttemptIntegrity {
  AttemptSessionCubit(
    this._repository,
    this._socket, {
    AttemptIntegrityReporter? reporter,
    IntegrityMonitor? monitor,
    IntegritySessionStore? sessionStore,
  }) : _reporter = reporter ?? SocketAttemptIntegrityReporter(),
       _monitor = monitor ?? IntegrityMonitor(),
       _sessionStore = sessionStore ?? IntegritySessionStore(),
       super(const AttemptSessionState()) {
    _eventSubscription = _socket.events.listen(_handleSocketEvent);
    _statusSubscription = _socket.statuses.listen(_handleSocketStatus);
  }

  final ExamRepository _repository;
  @override
  final AttemptSocketGateway _socket;
  @override
  final AttemptIntegrityReporter _reporter;
  @override
  final IntegrityMonitor _monitor;
  @override
  final IntegritySessionStore _sessionStore;
  final Map<String, int> _questionByRequest = {};
  final Map<int, String> _latestRequest = {};
  StreamSubscription<AttemptSocketEvent>? _eventSubscription;
  StreamSubscription<AttemptSocketStatus>? _statusSubscription;
  Timer? _countdownTimer;
  Timer? _reconnectTimer;
  Timer? _completionPollTimer;
  @override
  bool _closing = false;

  Future<void> load(int attemptId, {ExamAttempt? initialAttempt}) async {
    emit(state.copyWith(isLoading: initialAttempt == null, failure: null));
    // Flow TOEIC_STRICT không có `GET /questions` (409): đáp án nạp dần theo trang
    // qua mergeAnswers.
    final attempt =
        initialAttempt != null &&
            (initialAttempt.questions.isNotEmpty || initialAttempt.isStrict)
        ? initialAttempt
        : (await _repository.getAttemptQuestions(attemptId)).dataOrNull;
    if (attempt == null) {
      emit(
        state.copyWith(
          isLoading: false,
          failure: const Failure(message: 'Unable to load this attempt.'),
        ),
      );
      return;
    }
    _hydrate(attempt);
    _initIntegrity(attempt);
    if (attempt.status.toUpperCase() == 'ACTIVE') {
      _startCountdown(attempt.expiresAt);
      await _connect();
    }
  }

  void _hydrate(ExamAttempt attempt) {
    final answers = <int, int?>{};
    for (final question in _allQuestions(attempt)) {
      answers[question.id] = question.selectedOptionId;
    }
    emit(
      state.copyWith(
        attempt: attempt,
        selectedOptions: answers,
        isLoading: false,
        isLocked: attempt.status.toUpperCase() != 'ACTIVE',
      ),
    );
  }

  /// Nạp đáp án đã lưu của một trang (flow strict). Câu đã có trong state giữ giá trị
  /// local vì có thể vừa chọn mà chưa kịp đồng bộ.
  void mergeAnswers(Map<int, int?> answers) {
    final missing = answers.entries.where(
      (e) => !state.selectedOptions.containsKey(e.key),
    );
    if (missing.isEmpty) return;
    emit(
      state.copyWith(
        selectedOptions: {
          ...state.selectedOptions,
          ...Map.fromEntries(missing),
        },
      ),
    );
  }

  void selectAnswer(int questionId, int? optionId) {
    if (state.isLocked ||
        state.isSubmitting ||
        state.isCancelling ||
        state.sessionBlocked) {
      return;
    }
    final answers = Map<int, int?>.from(state.selectedOptions)
      ..[questionId] = optionId;
    final statuses = Map<int, AnswerSyncStatus>.from(state.syncStatuses)
      ..[questionId] = AnswerSyncStatus.pending;
    emit(state.copyWith(selectedOptions: answers, syncStatuses: statuses));
    _sendLatest(questionId);
  }

  Future<void> submit() async {
    final attempt = state.attempt;
    if (attempt == null ||
        state.isSubmitting ||
        state.isCancelling ||
        state.sessionBlocked) {
      return;
    }
    emit(state.copyWith(isSubmitting: true, isLocked: true, failure: null));
    final answers = state.selectedOptions.entries
        .map(
          (e) =>
              SubmitAttemptAnswer(questionId: e.key, selectedOptionId: e.value),
        )
        .toList();
    final result = await _repository.submitAttempt(attempt.id, answers);
    switch (result) {
      case Success(data: final completed):
        _countdownTimer?.cancel();
        await _socket.close();
        emit(
          state.copyWith(
            attempt: completed,
            completedAttempt: completed,
            isSubmitting: false,
          ),
        );
      case Failure():
        if (result.code == 409) {
          final history = await _repository.getAttemptHistory(attempt.id);
          if (history case Success(data: final completed)) {
            await _socket.close();
            emit(
              state.copyWith(
                attempt: completed,
                completedAttempt: completed,
                isSubmitting: false,
              ),
            );
            return;
          }
        }
        emit(
          state.copyWith(
            isSubmitting: false,
            isLocked: state.remaining == Duration.zero,
            failure: result,
          ),
        );
      case Cancelled():
        emit(state.copyWith(isSubmitting: false, isLocked: false));
    }
  }

  Future<void> cancel() async {
    final attempt = state.attempt;
    if (attempt == null || state.isSubmitting || state.isCancelling) return;
    emit(state.copyWith(isCancelling: true, isLocked: true, failure: null));
    final result = await _repository.cancelAttempt(attempt.id);
    switch (result) {
      case Success(data: final completed):
        _countdownTimer?.cancel();
        await _socket.close();
        emit(
          state.copyWith(
            attempt: completed,
            completedAttempt: completed,
            isCancelling: false,
          ),
        );
      case Failure():
        emit(
          state.copyWith(isCancelling: false, isLocked: false, failure: result),
        );
      case Cancelled():
        emit(state.copyWith(isCancelling: false, isLocked: false));
    }
  }

  Future<void> _connect() async {
    if (_closing) return;
    try {
      await _socket.connect();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _sendLatest(int questionId) {
    if (state.socketStatus != AttemptSocketStatus.connected ||
        state.sessionStatus == AttemptSessionStatus.claiming) {
      _markSyncFailed(questionId);
      _scheduleReconnect();
      return;
    }
    try {
      final requestId = _socket.sendAnswer(
        attemptId: state.attempt!.id,
        questionId: questionId,
        optionId: state.selectedOptions[questionId],
      );
      _questionByRequest[requestId] = questionId;
      _latestRequest[questionId] = requestId;
    } catch (_) {
      _markSyncFailed(questionId);
      _scheduleReconnect();
    }
  }

  void _markSyncFailed(int questionId) {
    final statuses = Map<int, AnswerSyncStatus>.from(state.syncStatuses)
      ..[questionId] = AnswerSyncStatus.failed;
    emit(state.copyWith(syncStatuses: statuses));
  }

  void _handleSocketEvent(AttemptSocketEvent event) {
    if (_handleIntegrityEvent(event)) return;
    if (event.type == 'ATTEMPT_SUBMITTING' &&
        event.attemptId == state.attempt?.id) {
      _countdownTimer?.cancel();
      emit(state.copyWith(isLocked: true, isSubmitting: true, failure: null));
      _waitForBackendSubmission();
      return;
    }
    if (event.type == 'ATTEMPT_SUBMITTED' &&
        event.attemptId == state.attempt?.id) {
      emit(state.copyWith(isLocked: true, isSubmitting: true, failure: null));
      _waitForBackendSubmission();
      return;
    }
    final questionId = _questionByRequest.remove(event.requestId);
    if (questionId == null || _latestRequest[questionId] != event.requestId) {
      return;
    }
    final statuses = Map<int, AnswerSyncStatus>.from(state.syncStatuses)
      ..[questionId] = event.success
          ? AnswerSyncStatus.synced
          : event.code == AttemptSocketCode.questionLocked
          ? AnswerSyncStatus.rejected
          : AnswerSyncStatus.failed;
    final terminal =
        event.code == AttemptSocketCode.attemptExpired ||
        event.code == AttemptSocketCode.attemptNotActive;
    emit(
      state.copyWith(
        syncStatuses: statuses,
        isLocked: terminal ? true : state.isLocked,
        socketMessage: event.success ? null : event.message ?? event.code,
      ),
    );
    if (event.code == AttemptSocketCode.attemptExpired) {
      _waitForBackendSubmission();
    }
  }

  void _handleSocketStatus(AttemptSocketStatus status) {
    emit(state.copyWith(socketStatus: status));
    if (status == AttemptSocketStatus.connected) {
      _reconnectTimer?.cancel();
      // Bài giám sát: đáp án gửi lại sau khi claim phiên thành công.
      if (_isProctoredActive) {
        _claimSession();
      } else {
        _resendPendingAnswers();
      }
    } else if (status == AttemptSocketStatus.disconnected) {
      _onIntegrityDisconnected();
      _scheduleReconnect();
    }
  }

  @override
  void _resendPendingAnswers() {
    for (final entry in state.syncStatuses.entries) {
      if (entry.value == AnswerSyncStatus.pending ||
          entry.value == AnswerSyncStatus.failed) {
        _sendLatest(entry.key);
      }
    }
  }

  void _scheduleReconnect() {
    if (_closing || state.isLocked || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 2), _connect);
  }

  void _startCountdown(DateTime? expiresAt) {
    if (expiresAt == null) {
      emit(state.copyWith(remaining: null));
      return;
    }
    void tick() {
      final remaining = expiresAt.toLocal().difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _countdownTimer?.cancel();
        emit(
          state.copyWith(
            remaining: Duration.zero,
            isLocked: true,
            isSubmitting: true,
            failure: null,
          ),
        );
        _waitForBackendSubmission();
      } else {
        emit(state.copyWith(remaining: remaining));
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  @override
  void _waitForBackendSubmission() {
    if (_closing || _completionPollTimer?.isActive == true) return;
    final startedAt = DateTime.now();

    Future<void> poll() async {
      final attempt = state.attempt;
      if (_closing || attempt == null || state.completedAttempt != null) return;
      final result = await _repository.getAttemptHistory(attempt.id);
      if (result case Success(data: final completed)) {
        await _socket.close();
        emit(
          state.copyWith(
            attempt: completed,
            completedAttempt: completed,
            isSubmitting: false,
            isLocked: true,
          ),
        );
        return;
      }
      if (DateTime.now().difference(startedAt) >= const Duration(minutes: 2)) {
        emit(
          state.copyWith(
            isSubmitting: false,
            failure: const Failure(
              message:
                  'Submission is still processing. Please reload the result.',
            ),
          ),
        );
        return;
      }
      _completionPollTimer = Timer(const Duration(seconds: 2), poll);
    }

    unawaited(poll());
  }

  static Iterable<ExamQuestion> _allQuestions(ExamAttempt attempt) sync* {
    for (final section in attempt.questions) {
      yield* section.questions;
      for (final group in section.groups) {
        yield* group.questions;
      }
    }
  }

  @override
  void onChange(Change<AttemptSessionState> change) {
    super.onChange(change);
    final completed = change.nextState.completedAttempt;
    if (completed != null && change.currentState.completedAttempt == null) {
      _stopIntegrity(completed.id);
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    final attempt = state.attempt;
    if (attempt != null) {
      _monitor.stop();
      _claimRetryTimer?.cancel();
      _reporter.unbind(attempt.id);
    }
    _countdownTimer?.cancel();
    _reconnectTimer?.cancel();
    _completionPollTimer?.cancel();
    await _eventSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _socket.close();
    return super.close();
  }
}
