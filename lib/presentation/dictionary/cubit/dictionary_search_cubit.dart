import 'package:eflutter/data/models/dictionary/search_response.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/repositories/dictionary_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'dictionary_search_cubit.freezed.dart';

@freezed
class DictionarySearchState with _$DictionarySearchState {
  const factory DictionarySearchState.initial() = _Initial;
  const factory DictionarySearchState.loading() = _Loading;

  /// [response] gom mọi trang đã tải (`data` nối dồn, `page` là trang cuối đã tải).
  const factory DictionarySearchState.success(
    SearchResponse response, {
    required String query,
    @Default(false) bool isLoadingMore,
  }) = _Success;
  const factory DictionarySearchState.error(String message) = _Error;
}

@injectable
class DictionarySearchCubit extends Cubit<DictionarySearchState> {
  static const _pageSize = 20;

  final DictionaryRepository _repository;

  DictionarySearchCubit(this._repository) : super(const DictionarySearchState.initial());

  Future<void> search(String query) async {
    if (query.isEmpty) {
      emit(const DictionarySearchState.initial());
      return;
    }
    emit(const DictionarySearchState.loading());
    final result = await _repository.getWords(query, pageSize: _pageSize);
    switch (result) {
      case Success(data: final data):
        emit(DictionarySearchState.success(data, query: query));
      case Failure(message: final message):
        emit(DictionarySearchState.error(message ?? 'An error occurred'));
      case Cancelled():
        break;
    }
  }

  /// Tải trang tiếp theo của lần tìm hiện tại và nối vào danh sách.
  Future<void> loadMore() async {
    final current = state;
    if (current is! _Success || current.isLoadingMore) return;
    if (current.response.page >= current.response.pageCounts) return;

    emit(current.copyWith(isLoadingMore: true));

    final result = await _repository.getWords(
      current.query,
      page: current.response.page + 1,
      pageSize: _pageSize,
    );

    // Người dùng đã tìm từ khác trong lúc chờ: bỏ kết quả cũ.
    final latest = state;
    if (latest is! _Success || latest.query != current.query) return;

    switch (result) {
      case Success(data: final data):
        emit(latest.copyWith(
          response: data.copyWith(data: [...latest.response.data, ...data.data]),
          isLoadingMore: false,
        ));
      case Failure():
      case Cancelled():
        // Giữ danh sách đang có; cuộn lại sẽ thử tải tiếp.
        emit(latest.copyWith(isLoadingMore: false));
    }
  }
}
