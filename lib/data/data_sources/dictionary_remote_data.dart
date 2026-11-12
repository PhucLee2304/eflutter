import 'package:dio/dio.dart';
import 'package:eflutter/data/models/dictionary/dictionary_topic.dart';
import 'package:eflutter/data/models/dictionary/flashcard.dart';
import 'package:eflutter/data/models/dictionary/flashcard_models.dart';
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

  @GET('/dictionary/api/v1/words/{id}')
  Future<WordDetail> getWordById(@Path('id') int id);

  @GET('/dictionary/api/v1/words')
  Future<SearchResponse> getWords(
    @Query('query') String query,
    @Query('page') int page,
    @Query('pageSize') int pageSize,
  );

  // Flashcards (Legacy)
  @GET('/dictionary/api/v1/flashcards')
  Future<GetFlashcardsResponse> getFlashcards(
    @Query('page') int page,
    @Query('pageSize') int pageSize,
  );

  @POST('/dictionary/api/v1/flashcards')
  Future<Flashcard> createFlashcard(@Body() Map<String, dynamic> body);

  @DELETE('/dictionary/api/v1/flashcards/{id}')
  Future<void> deleteFlashcard(@Path('id') int id);

  // --- Flashcard Decks ---
  @GET('/dictionary/api/v1/flashcard-decks')
  Future<List<FlashcardDeck>> getDecks();

  @POST('/dictionary/api/v1/flashcard-decks')
  Future<FlashcardDeck> createDeck(@Body() Map<String, dynamic> body);

  @GET('/dictionary/api/v1/flashcard-decks/{id}')
  Future<FlashcardDeck> getDeckById(@Path('id') int id);

  @PUT('/dictionary/api/v1/flashcard-decks/{id}')
  Future<FlashcardDeck> updateDeck(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/dictionary/api/v1/flashcard-decks/{id}')
  Future<void> deleteDeck(@Path('id') int id);

  // --- Flashcard Cards & Save Word ---
  @POST('/dictionary/api/v1/flashcards/save-word')
  Future<void> saveWordToDecks(@Body() Map<String, dynamic> body);

  @GET('/dictionary/api/v1/flashcards/status')
  Future<WordSaveStatus> getWordSaveStatus(@Query('wordId') int wordId);

  @GET('/dictionary/api/v1/flashcard-decks/{id}/cards')
  Future<GetDeckCardsResponse> getDeckCards(
    @Path('id') int deckId,
    @Query('page') int page,
    @Query('pageSize') int pageSize,
  );

  @PUT('/dictionary/api/v1/flashcards/{id}/note')
  Future<FlashcardItem> updateCardNote(
    @Path('id') int cardId,
    @Body() Map<String, dynamic> body,
  );

  // --- Flashcard Study & Review ---
  @GET('/dictionary/api/v1/flashcard-decks/{id}/study')
  Future<List<FlashcardItem>> getStudyCards(@Path('id') int deckId);

  @GET('/dictionary/api/v1/flashcards/study/due-all')
  Future<List<FlashcardItem>> getAllDueCards();

  @POST('/dictionary/api/v1/flashcards/{id}/review')
  Future<ReviewCardResponse> reviewCard(
    @Path('id') int cardId,
    @Body() Map<String, dynamic> body,
  );

  @GET('/dictionary/api/v1/flashcards/stats')
  Future<FlashcardUserStats> getFlashcardStats();

  // Themes
  @GET('/dictionary/api/v1/themes')
  Future<List<DictionaryTopic>> getTopics();

  @GET('/dictionary/api/v1/themes/{id}')
  Future<TopicWordsResponse> getTopicWords(
    @Path('id') int topicId,
    @Query('page') int page,
    @Query('pageSize') int pageSize,
  );
}
