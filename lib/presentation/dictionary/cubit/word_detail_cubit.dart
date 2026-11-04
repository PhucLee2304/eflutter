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

  Future<void> loadWord(int id) async {
    emit(const WordDetailState.loading());
    final result = await _repository.getWordById(id);
    switch (result) {
      case Success(data: final data):
        emit(WordDetailState.success(data));
      case Failure(message: final message):
        emit(WordDetailState.error(message ?? 'An error occurred'));
      case Cancelled():
        break;
    }
  }

  /// Tìm id của một từ theo chữ (dùng khi bấm synonym/antonym, vốn chỉ có chữ).
  /// Tìm theo tiền tố, sắp theo chữ cái nên từ khớp chính xác luôn đứng đầu.
  /// Trả null nếu từ không có trong từ điển hoặc gọi API lỗi.
  Future<int?> findWordId(String word) async {
    final normalized = word.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final result = await _repository.getWords(normalized, pageSize: 1);
    if (result case Success(data: final data)
        when data.data.isNotEmpty && data.data.first.word == normalized) {
      return data.data.first.id;
    }
    return null;
  }
}
