import 'dart:async';

import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_questions.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AnswerSyncStatus { pending, synced, failed }

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
  });

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
  );
}

const _sentinel = Object();

class AttemptSessionCubit extends Cubit<AttemptSessionState> {
  AttemptSessionCubit(this._repository, this._socket)
    : super(const AttemptSessionState()) {
    _eventSubscription = _socket.events.listen(_handleSocketEvent);
    _statusSubscription = _socket.statuses.listen(_handleSocketStatus);
  }

  final ExamRepository _repository;
  final AttemptSocketGateway _socket;
  final Map<String, int> _questionByRequest = {};
  final Map<int, String> _latestRequest = {};
  StreamSubscription<AttemptSocketEvent>? _eventSubscription;
  StreamSubscription<AttemptSocketStatus>? _statusSubscription;
  Timer? _countdownTimer;
  Timer? _reconnectTimer;
  bool _closing = false;

  Future<void> load(int attemptId, {ExamAttempt? initialAttempt}) async {
    emit(state.copyWith(isLoading: initialAttempt == null, failure: null));
    final attempt =
        initialAttempt != null && initialAttempt.questions.isNotEmpty
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

  void selectAnswer(int questionId, int? optionId) {
    if (state.isLocked || state.isSubmitting || state.isCancelling) return;
    final answers = Map<int, int?>.from(state.selectedOptions)
      ..[questionId] = optionId;
    final statuses = Map<int, AnswerSyncStatus>.from(state.syncStatuses)
      ..[questionId] = AnswerSyncStatus.pending;
    emit(state.copyWith(selectedOptions: answers, syncStatuses: statuses));
    _sendLatest(questionId);
  }

  Future<void> submit() async {
    final attempt = state.attempt;
    if (attempt == null || state.isSubmitting || state.isCancelling) return;
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
    if (state.socketStatus != AttemptSocketStatus.connected) {
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
    final questionId = _questionByRequest.remove(event.requestId);
    if (questionId == null || _latestRequest[questionId] != event.requestId) {
      return;
    }
    final statuses = Map<int, AnswerSyncStatus>.from(state.syncStatuses)
      ..[questionId] = event.success
          ? AnswerSyncStatus.synced
          : AnswerSyncStatus.failed;
    final terminal =
        event.code == 'ATTEMPT_EXPIRED' || event.code == 'ATTEMPT_NOT_ACTIVE';
    emit(
      state.copyWith(
        syncStatuses: statuses,
        isLocked: terminal ? true : state.isLocked,
        socketMessage: event.success ? null : event.message ?? event.code,
      ),
    );
    if (event.code == 'ATTEMPT_EXPIRED') unawaited(submit());
  }

  void _handleSocketStatus(AttemptSocketStatus status) {
    emit(state.copyWith(socketStatus: status));
    if (status == AttemptSocketStatus.connected) {
      _reconnectTimer?.cancel();
      for (final entry in state.syncStatuses.entries) {
        if (entry.value != AnswerSyncStatus.synced) _sendLatest(entry.key);
      }
    } else if (status == AttemptSocketStatus.disconnected) {
      _scheduleReconnect();
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
        emit(state.copyWith(remaining: Duration.zero, isLocked: true));
        unawaited(submit());
      } else {
        emit(state.copyWith(remaining: remaining));
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
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
  Future<void> close() async {
    _closing = true;
    _countdownTimer?.cancel();
    _reconnectTimer?.cancel();
    await _eventSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _socket.close();
    return super.close();
  }
}
