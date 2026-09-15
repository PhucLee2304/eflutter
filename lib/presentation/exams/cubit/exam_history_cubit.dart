import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ExamHistoryStatus {
  submitted('SUBMITTED', 'Submitted'),
  active('ACTIVE', 'Active'),
  cancelled('CANCELLED', 'Cancelled');

  const ExamHistoryStatus(this.value, this.label);

  final String value;
  final String label;
}

class ExamHistoryState {
  final ExamHistoryStatus status;
  final List<ExamAttempt> attempts;
  final int page;
  final int pageCounts;
  final bool isLoading;
  final Failure? failure;

  const ExamHistoryState({
    this.status = ExamHistoryStatus.submitted,
    this.attempts = const [],
    this.page = 1,
    this.pageCounts = 1,
    this.isLoading = false,
    this.failure,
  });

  bool get canGoPrevious => page > 1;

  bool get canGoNext => page < pageCounts;

  ExamHistoryState copyWith({
    ExamHistoryStatus? status,
    List<ExamAttempt>? attempts,
    int? page,
    int? pageCounts,
    bool? isLoading,
    Object? failure = _failureSentinel,
  }) {
    return ExamHistoryState(
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      page: page ?? this.page,
      pageCounts: pageCounts ?? this.pageCounts,
      isLoading: isLoading ?? this.isLoading,
      failure: identical(failure, _failureSentinel)
          ? this.failure
          : failure as Failure?,
    );
  }
}

const _failureSentinel = Object();

class ExamHistoryCubit extends Cubit<ExamHistoryState> {
  ExamHistoryCubit(this._examRepository, {this.pageSize = 20})
    : super(const ExamHistoryState());

  final ExamRepository _examRepository;
  final int pageSize;

  Future<void> load({int page = 1, ExamHistoryStatus? status}) async {
    final nextStatus = status ?? state.status;
    emit(
      state.copyWith(
        status: nextStatus,
        isLoading: true,
        failure: null,
        attempts: page == 1 && status != null ? const [] : null,
      ),
    );

    final result = await _examRepository.getAttempts(
      status: nextStatus.value,
      page: page,
      pageSize: pageSize,
    );

    switch (result) {
      case Success(data: final data):
        emit(
          state.copyWith(
            attempts: data.attempts,
            page: data.page,
            pageCounts: data.pageCounts,
            isLoading: false,
          ),
        );
      case Failure():
        emit(state.copyWith(isLoading: false, failure: result));
        emit(state.copyWith(failure: null));
      case Cancelled():
        emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> selectStatus(ExamHistoryStatus status) async {
    if (status == state.status && state.attempts.isNotEmpty) return;
    await load(page: 1, status: status);
  }

  Future<void> refresh() => load(page: state.page);

  Future<void> nextPage() async {
    if (!state.canGoNext || state.isLoading) return;
    await load(page: state.page + 1);
  }

  Future<void> previousPage() async {
    if (!state.canGoPrevious || state.isLoading) return;
    await load(page: state.page - 1);
  }
}
