import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/data/models/exam_summary.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExamListState {
  final List<ExamSummary> exams;
  final int page;
  final int pageCounts;
  final List<int> years;
  final String search;
  final int? year;
  final bool isLoading;
  final Failure? failure;

  const ExamListState({
    this.exams = const [],
    this.page = 1,
    this.pageCounts = 1,
    this.years = const [],
    this.search = '',
    this.year,
    this.isLoading = false,
    this.failure,
  });

  bool get isFiltered => search.isNotEmpty || year != null;

  bool get canGoPrevious => page > 1;

  bool get canGoNext => page < pageCounts;

  ExamListState copyWith({
    List<ExamSummary>? exams,
    int? page,
    int? pageCounts,
    List<int>? years,
    String? search,
    Object? year = _failureSentinel,
    bool? isLoading,
    Object? failure = _failureSentinel,
  }) {
    return ExamListState(
      exams: exams ?? this.exams,
      page: page ?? this.page,
      pageCounts: pageCounts ?? this.pageCounts,
      years: years ?? this.years,
      search: search ?? this.search,
      year: identical(year, _failureSentinel) ? this.year : year as int?,
      isLoading: isLoading ?? this.isLoading,
      failure: identical(failure, _failureSentinel) ? this.failure : failure as Failure?,
    );
  }
}

const _failureSentinel = Object();

class ExamListCubit extends Cubit<ExamListState> {
  final ExamRepository _examRepository;
  final String examType;
  final int pageSize;

  ExamListCubit(this._examRepository, {required this.examType, this.pageSize = 9})
    : super(const ExamListState());

  Future<void> load({int page = 1}) async {
    emit(state.copyWith(isLoading: true, failure: null));
    final result = await _examRepository
        .getExams(
          type: examType,
          page: page,
          pageSize: pageSize,
          search: state.search,
          year: state.year,
        )
        .withLoading();

    switch (result) {
      case Success(data: final data):
        emit(
          state.copyWith(
            exams: data.exams,
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

  /// Năm có đề của loại này, cho bộ lọc năm.
  Future<void> loadYears() async {
    final result = await _examRepository.getExamYears(examType);
    if (result case Success(data: final years)) emit(state.copyWith(years: years));
  }

  Future<void> refresh() => load(page: state.page);

  Future<void> goToPage(int page) async {
    if (state.isLoading || page == state.page) return;
    await load(page: page);
  }

  Future<void> setSearch(String search) async {
    final value = search.trim();
    if (value == state.search) return;
    emit(state.copyWith(search: value));
    await load();
  }

  Future<void> setYear(int? year) async {
    if (year == state.year) return;
    emit(state.copyWith(year: year));
    await load();
  }

  Future<void> nextPage() async {
    if (!state.canGoNext || state.isLoading) return;
    await load(page: state.page + 1);
  }

  Future<void> previousPage() async {
    if (!state.canGoPrevious || state.isLoading) return;
    await load(page: state.page - 1);
  }
}
