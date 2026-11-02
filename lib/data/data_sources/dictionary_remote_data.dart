import 'package:dio/dio.dart';
import 'package:eflutter/data/models/dictionary/dictionary_topic.dart';
import 'package:eflutter/data/models/dictionary/flashcard.dart';
import 'package:eflutter/data/models/dictionary/search_response.dart';
import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

part 'dictionary_remote_data.g.dart';

@RestApi()
@LazySingleton()
abstract class DictionaryRemoteData {
  @factoryMethod
  factory DictionaryRemoteData(Dio dio) = _DictionaryRemoteData;

  @GET('/dictionary/api/v1/words/{word}')
  Future<WordDetail> lookupWord(@Path('word') String word);

  @GET('/dictionary/api/v1/words')
  Future<SearchResponse> searchWords(
    @Query('q') String query,
    @Query('page') int page,
    @Query('pageSize') int pageSize,
  );

  // Note: thesaurus is available on the backend, but we can stick to WordDetail which already has synonyms/antonyms
  // For flashcards:
  @GET('/dictionary/api/v1/flashcards')
  Future<GetFlashcardsResponse> getFlashcards(
    @Query('page') int page,
    @Query('pageSize') int pageSize,
  );

  @POST('/dictionary/api/v1/flashcards')
  Future<Flashcard> addFlashcard(@Body() Map<String, dynamic> body);

  @DELETE('/dictionary/api/v1/flashcards/{id}')
  Future<void> deleteFlashcard(@Path('id') int id);

  // Topics
  @GET('/dictionary/api/v1/topics')
  Future<List<DictionaryTopic>> getTopics();

  @GET('/dictionary/api/v1/topics/{id}/words')
  Future<TopicWordsResponse> getTopicWords(
    @Path('id') String topicId,
    @Query('page') int page,
    @Query('pageSize') int pageSize,
  );
}
