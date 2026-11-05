import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/dictionary/dictionary_topic.dart';
import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:eflutter/data/repositories/dictionary_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'dictionary_topic_cubit.freezed.dart';

// ─── State ───────────────────────────────────────────────────────────────────

@freezed
class DictionaryTopicState with _$DictionaryTopicState {
  /// Chưa tải gì
  const factory DictionaryTopicState.initial() = _Initial;

  /// Đang tải danh sách chủ điểm
  const factory DictionaryTopicState.loadingTopics() = _LoadingTopics;

  /// Đã có danh sách chủ điểm, chưa chọn topic nào
  const factory DictionaryTopicState.topicsLoaded(
    List<DictionaryTopic> topics,
  ) = _TopicsLoaded;

  /// Đang tải từ của topic đang chọn (load trang đầu)
  const factory DictionaryTopicState.loadingWords({
    required List<DictionaryTopic> topics,
    required DictionaryTopic selectedTopic,
  }) = _LoadingWords;

  /// Đã có từ của topic đang chọn
  const factory DictionaryTopicState.wordsLoaded({
    required List<DictionaryTopic> topics,
    required DictionaryTopic selectedTopic,
    required List<WordSummary> words,
    required int currentPage,
    required int totalPages,
    @Default(false) bool isLoadingMore,
  }) = _WordsLoaded;

  /// Lỗi
  const factory DictionaryTopicState.error(String message) = _Error;
}

// ─── Cubit ────────────────────────────────────────────────────────────────────

@injectable
class DictionaryTopicCubit extends Cubit<DictionaryTopicState> {
  final DictionaryRepository _repository;

  DictionaryTopicCubit(this._repository)
      : super(const DictionaryTopicState.initial());

  /// Tải danh sách chủ điểm
  Future<void> loadTopics() async {
    emit(const DictionaryTopicState.loadingTopics());
    final result = await _repository.getTopics();
    switch (result) {
      case Success(data: final data):
        emit(DictionaryTopicState.topicsLoaded(data));
      case Failure(message: final msg):
        emit(DictionaryTopicState.error(msg ?? 'Failed to load topics'));
      case Cancelled():
        break;
    }
  }

  /// Chọn một topic và tải trang đầu
  Future<void> selectTopic(DictionaryTopic topic) async {
    final currentTopics = _currentTopics;
    if (currentTopics == null) return;

    emit(DictionaryTopicState.loadingWords(
      topics: currentTopics,
      selectedTopic: topic,
    ));

    final result = await _repository.getTopicWords(topic.id, page: 1);
    switch (result) {
      case Success(data: final data):
        emit(DictionaryTopicState.wordsLoaded(
          topics: currentTopics,
          selectedTopic: topic,
          words: data.data,
          currentPage: 1,
          totalPages: data.pageCounts,
        ));
      case Failure(message: final msg):
        emit(DictionaryTopicState.error(msg ?? 'Failed to load words'));
      case Cancelled():
        break;
    }
  }

  /// Tải thêm trang tiếp theo (lazy loading)
  Future<void> loadMoreWords() async {
    final current = state;
    if (current is! _WordsLoaded) return;
    if (current.isLoadingMore) return;
    if (current.currentPage >= current.totalPages) return;

    emit(current.copyWith(isLoadingMore: true));

    final nextPage = current.currentPage + 1;
    final result = await _repository.getTopicWords(
      current.selectedTopic.id,
      page: nextPage,
    );

    switch (result) {
      case Success(data: final data):
        emit(current.copyWith(
          words: [...current.words, ...data.data],
          currentPage: nextPage,
          totalPages: data.pageCounts,
          isLoadingMore: false,
        ));
      case Failure(message: final msg):
        emit(current.copyWith(isLoadingMore: false));
        emit(DictionaryTopicState.error(msg ?? 'Failed to load more words'));
      case Cancelled():
        emit(current.copyWith(isLoadingMore: false));
    }
  }

  /// Helper: lấy danh sách topics hiện tại
  List<DictionaryTopic>? get _currentTopics => state.when(
        initial: () => null,
        loadingTopics: () => null,
        topicsLoaded: (topics) => topics,
        loadingWords: (topics, _) => topics,
        wordsLoaded: (topics, a, b, c, d, e) => topics,
        error: (_) => null,
      );
}
