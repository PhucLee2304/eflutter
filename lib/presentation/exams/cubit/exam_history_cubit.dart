import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Loại đề tự luyện được liệt kê trong lịch sử.
const selfStudyExamTypes = ['TOEIC', 'THPT'];

class ExamHistoryState {
  /// null = cả TOEIC và THPT.
  final String? examType;
  final String search;
  final List<ExamAttempt> attempts;
  final int page;
  final int pageCounts;
  final bool isLoading;
  final Failure? failure;

  const ExamHistoryState({
    this.examType,
    this.search = '',
    this.attempts = const [],
    this.page = 1,
    this.pageCounts = 1,
    this.isLoading = false,
    this.failure,
  });

  ExamHistoryState copyWith({
    Object? examType = _sentinel,
    String? search,
    List<ExamAttempt>? attempts,
    int? page,
    int? pageCounts,
    bool? isLoading,
    Object? failure = _sentinel,
  }) {
    return ExamHistoryState(
      examType: identical(examType, _sentinel) ? this.examType : examType as String?,
      search: search ?? this.search,
      attempts: attempts ?? this.attempts,
      page: page ?? this.page,
      pageCounts: pageCounts ?? this.pageCounts,
      isLoading: isLoading ?? this.isLoading,
      failure: identical(failure, _sentinel) ? this.failure : failure as Failure?,
    );
  }
}

const _sentinel = Object();

/// Lịch sử tự luyện: chỉ attempt đã nộp của đề TOEIC/THPT, không gồm bài giao trong lớp.
class ExamHistoryCubit extends Cubit<ExamHistoryState> {
  ExamHistoryCubit(this._examRepository, {this.pageSize = 10}) : super(const ExamHistoryState());

  final ExamRepository _examRepository;
  final int pageSize;
  int _request = 0;

  Future<void> load({int page = 1}) async {
    final request = ++_request;
    emit(state.copyWith(isLoading: true, failure: null));

    final result = await _examRepository.getAttempts(
      status: 'SUBMITTED',
      page: page,
      pageSize: pageSize,
      excludeMode: 'ASSIGNMENT',
      examTypes: state.examType == null ? selfStudyExamTypes : [state.examType!],
      search: state.search,
    );
    if (request != _request || isClosed) return;

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

  Future<void> setExamType(String? type) async {
    if (type == state.examType) return;
    emit(state.copyWith(examType: type));
    await load();
  }

  Future<void> setSearch(String search) async {
    final value = search.trim();
    if (value == state.search) return;
    emit(state.copyWith(search: value));
    await load();
  }

  Future<void> goToPage(int page) => load(page: page);

  Future<void> refresh() => load(page: state.page);
}
