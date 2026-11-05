import 'package:eflutter/data/models/dictionary/flashcard.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/repositories/dictionary_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'flashcard_cubit.freezed.dart';

@freezed
class FlashcardState with _$FlashcardState {
  const factory FlashcardState.initial() = _Initial;
  const factory FlashcardState.loading() = _Loading;
  const factory FlashcardState.success(GetFlashcardsResponse response) = _Success;
  const factory FlashcardState.error(String message) = _Error;
}

@injectable
class FlashcardCubit extends Cubit<FlashcardState> {
  final DictionaryRepository _repository;

  FlashcardCubit(this._repository) : super(const FlashcardState.initial());

  Future<void> loadFlashcards({int page = 1, int pageSize = 20}) async {
    emit(const FlashcardState.loading());
    final result = await _repository.getFlashcards(page, pageSize);
    switch (result) {
      case Success(data: final data):
        emit(FlashcardState.success(data));
      case Failure(message: final message):
        emit(FlashcardState.error(message ?? 'An error occurred'));
      case Cancelled():
        break;
    }
  }

  Future<bool> createFlashcard(int wordId, {String note = ""}) async {
    final result = await _repository.createFlashcard(wordId, note: note);
    switch (result) {
      case Success():
        loadFlashcards();
        return true;
      case Failure():
        return false;
      case Cancelled():
        return false;
    }
  }

  Future<bool> deleteFlashcard(int id) async {
    final result = await _repository.deleteFlashcard(id);
    switch (result) {
      case Success():
        loadFlashcards();
        return true;
      case Failure():
        return false;
      case Cancelled():
        return false;
    }
  }
}
