import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_detail.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExamDetailState {
  final ExamDetail? exam;
  final ExamAttempt? startedAttempt;
  final bool isLoading;
  final bool isStarting;
  final bool attemptStarted;
  final Failure? failure;

  const ExamDetailState({
    this.exam,
    this.startedAttempt,
    this.isLoading = false,
    this.isStarting = false,
    this.attemptStarted = false,
    this.failure,
  });

  ExamDetailState copyWith({
    Object? exam = _examSentinel,
    Object? startedAttempt = _attemptSentinel,
    bool? isLoading,
    bool? isStarting,
    bool? attemptStarted,
    Object? failure = _failureSentinel,
  }) {
    return ExamDetailState(
      exam: identical(exam, _examSentinel) ? this.exam : exam as ExamDetail?,
      startedAttempt: identical(startedAttempt, _attemptSentinel)
          ? this.startedAttempt
          : startedAttempt as ExamAttempt?,
      isLoading: isLoading ?? this.isLoading,
      isStarting: isStarting ?? this.isStarting,
      attemptStarted: attemptStarted ?? this.attemptStarted,
      failure: identical(failure, _failureSentinel)
          ? this.failure
          : failure as Failure?,
    );
  }
}

const _examSentinel = Object();
const _attemptSentinel = Object();
const _failureSentinel = Object();

class ExamDetailCubit extends Cubit<ExamDetailState> {
  final ExamRepository _examRepository;

  ExamDetailCubit(this._examRepository) : super(const ExamDetailState());

  Future<void> load(int examId) async {
    emit(state.copyWith(isLoading: true, failure: null, attemptStarted: false));
    final result = await _examRepository.getExamById(examId).withLoading();

    switch (result) {
      case Success(data: final exam):
        emit(state.copyWith(exam: exam, isLoading: false));
      case Failure():
        emit(state.copyWith(isLoading: false, failure: result));
        emit(state.copyWith(failure: null));
      case Cancelled():
        emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> createAttempt(
    int examId,
    CreateExamAttemptRequest request,
  ) async {
    emit(
      state.copyWith(
        isStarting: true,
        failure: null,
        attemptStarted: false,
        startedAttempt: null,
      ),
    );
    final result = await _examRepository
        .createExamAttempt(examId, request)
        .withLoading();

    switch (result) {
      case Success(data: final attempt):
        emit(
          state.copyWith(
            startedAttempt: attempt,
            isStarting: false,
            attemptStarted: true,
          ),
        );
        emit(state.copyWith(attemptStarted: false));
      case Failure():
        if (result.code == 409) {
          final activeResult = await _examRepository.getAttempts(
            status: 'ACTIVE',
            page: 1,
            pageSize: 1,
          );
          if (activeResult case Success(
            data: final page,
          ) when page.attempts.isNotEmpty) {
            emit(
              state.copyWith(
                startedAttempt: page.attempts.first,
                isStarting: false,
                attemptStarted: true,
              ),
            );
            emit(state.copyWith(attemptStarted: false));
            return;
          }
        }
        emit(state.copyWith(isStarting: false, failure: result));
        emit(state.copyWith(failure: null));
      case Cancelled():
        emit(state.copyWith(isStarting: false));
    }
  }
}
