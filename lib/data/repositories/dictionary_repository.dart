import 'package:eflutter/data/data_sources/dictionary_remote_data.dart';
import 'package:eflutter/data/models/dictionary/dictionary_topic.dart';
import 'package:eflutter/data/models/dictionary/flashcard.dart';
import 'package:eflutter/data/models/dictionary/search_response.dart';
import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class DictionaryRepository with RepositorySafeCall {
  final DictionaryRemoteData _remoteData;

  DictionaryRepository(this._remoteData);

  Future<Result<WordDetail>> getWordById(int id) async {
    return safeCall(() => _remoteData.getWordById(id));
  }

  Future<Result<SearchResponse>> getWords(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return safeCall(() => _remoteData.getWords(query, page, pageSize));
  }

  Future<Result<GetFlashcardsResponse>> getFlashcards(int page, int pageSize) async {
    return safeCall(() => _remoteData.getFlashcards(page, pageSize));
  }

  Future<Result<Flashcard>> createFlashcard(int wordId, {String note = ""}) async {
    return safeCall(() => _remoteData.createFlashcard({
          'wordId': wordId,
          'note': note,
        }));
  }

  Future<Result<void>> deleteFlashcard(int id) async {
    return safeCall(() => _remoteData.deleteFlashcard(id));
  }

  Future<Result<List<DictionaryTopic>>> getTopics() async {
    return safeCall(() => _remoteData.getTopics());
  }

  Future<Result<TopicWordsResponse>> getTopicWords(
    int topicId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return safeCall(() => _remoteData.getTopicWords(topicId, page, pageSize));
  }
}
