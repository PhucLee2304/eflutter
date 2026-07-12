import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/data/models/exam_detail.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExamDetailState {
  final ExamDetail? exam;
  final bool isLoading;
  final Failure? failure;

  const ExamDetailState({this.exam, this.isLoading = false, this.failure});

  ExamDetailState copyWith({
    Object? exam = _examSentinel,
    bool? isLoading,
    Object? failure = _failureSentinel,
  }) {
    return ExamDetailState(
      exam: identical(exam, _examSentinel) ? this.exam : exam as ExamDetail?,
      isLoading: isLoading ?? this.isLoading,
      failure: identical(failure, _failureSentinel)
          ? this.failure
          : failure as Failure?,
    );
  }
}

const _examSentinel = Object();
const _failureSentinel = Object();

class ExamDetailCubit extends Cubit<ExamDetailState> {
  final ExamRepository _examRepository;

  ExamDetailCubit(this._examRepository) : super(const ExamDetailState());

  Future<void> load(int examId) async {
    emit(state.copyWith(isLoading: true, failure: null));
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
}
