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
  const factory DictionarySearchState.success(SearchResponse response) = _Success;
  const factory DictionarySearchState.error(String message) = _Error;
}

@injectable
class DictionarySearchCubit extends Cubit<DictionarySearchState> {
  final DictionaryRepository _repository;

  DictionarySearchCubit(this._repository) : super(const DictionarySearchState.initial());

  Future<void> search(String query, {int page = 1, int pageSize = 20}) async {
    if (query.isEmpty) {
      emit(const DictionarySearchState.initial());
      return;
    }
    emit(const DictionarySearchState.loading());
    final result = await _repository.searchWords(query, page, pageSize);
    switch (result) {
      case Success(data: final data):
        emit(DictionarySearchState.success(data));
      case Failure(message: final message):
        emit(DictionarySearchState.error(message ?? 'An error occurred'));
      case Cancelled():
        break;
    }
  }
}
