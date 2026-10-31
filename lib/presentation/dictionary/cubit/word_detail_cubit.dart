import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/repositories/dictionary_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'word_detail_cubit.freezed.dart';

@freezed
class WordDetailState with _$WordDetailState {
  const factory WordDetailState.initial() = _Initial;
  const factory WordDetailState.loading() = _Loading;
  const factory WordDetailState.success(WordDetail wordDetail) = _Success;
  const factory WordDetailState.error(String message) = _Error;
}

@injectable
class WordDetailCubit extends Cubit<WordDetailState> {
  final DictionaryRepository _repository;

  WordDetailCubit(this._repository) : super(const WordDetailState.initial());

  Future<void> lookupWord(String word) async {
    emit(const WordDetailState.loading());
    final result = await _repository.lookupWord(word);
    switch (result) {
      case Success(data: final data):
        emit(WordDetailState.success(data));
      case Failure(message: final message):
        emit(WordDetailState.error(message ?? 'An error occurred'));
      case Cancelled():
        break;
    }
  }
}
