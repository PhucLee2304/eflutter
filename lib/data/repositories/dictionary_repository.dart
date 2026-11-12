import 'package:eflutter/data/data_sources/dictionary_remote_data.dart';
import 'package:eflutter/data/models/dictionary/dictionary_topic.dart';
import 'package:eflutter/data/models/dictionary/flashcard.dart';
import 'package:eflutter/data/models/dictionary/flashcard_models.dart';
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

  Future<Result<SearchResponse>> getWords(String query, {int page = 1, int pageSize = 20}) async {
    return safeCall(() => _remoteData.getWords(query, page, pageSize));
  }

  Future<Result<GetFlashcardsResponse>> getFlashcards(int page, int pageSize) async {
    return safeCall(() => _remoteData.getFlashcards(page, pageSize));
  }

  Future<Result<Flashcard>> createFlashcard(int wordId, {String note = ""}) async {
    return safeCall(() => _remoteData.createFlashcard({'wordId': wordId, 'note': note}));
  }

  Future<Result<void>> deleteFlashcard(int id) async {
    return safeCall(() => _remoteData.deleteFlashcard(id));
  }

  // --- Flashcard Decks ---
  Future<Result<List<FlashcardDeck>>> getDecks() async {
    return safeCall(() => _remoteData.getDecks());
  }

  Future<Result<FlashcardDeck>> createDeck(
    String name, {
    String? description,
    String? color,
  }) async {
    return safeCall(() => _remoteData.createDeck({
          'name': name,
          if (description != null && description.isNotEmpty) 'description': description,
          if (color != null && color.isNotEmpty) 'color': color,
        }));
  }

  Future<Result<FlashcardDeck>> getDeckById(int id) async {
    return safeCall(() => _remoteData.getDeckById(id));
  }

  Future<Result<FlashcardDeck>> updateDeck(
    int id, {
    String? name,
    String? description,
    String? color,
  }) async {
    return safeCall(() => _remoteData.updateDeck(id, {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (color != null) 'color': color,
        }));
  }

  Future<Result<void>> deleteDeck(int id) async {
    return safeCall(() => _remoteData.deleteDeck(id));
  }

  // --- Flashcards & Save Word ---
  Future<Result<void>> saveWordToDecks(
    int wordId, {
    List<int>? deckIds,
    String? newDeckName,
    String? note,
  }) async {
    return safeCall(() => _remoteData.saveWordToDecks({
          'wordId': wordId,
          if (deckIds != null) 'deckIds': deckIds,
          if (newDeckName != null && newDeckName.isNotEmpty) 'newDeckName': newDeckName,
          if (note != null) 'note': note,
        }));
  }

  Future<Result<WordSaveStatus>> getWordSaveStatus(int wordId) async {
    return safeCall(() => _remoteData.getWordSaveStatus(wordId));
  }

  Future<Result<GetDeckCardsResponse>> getDeckCards(
    int deckId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return safeCall(() => _remoteData.getDeckCards(deckId, page, pageSize));
  }

  Future<Result<FlashcardItem>> updateCardNote(int cardId, String? note) async {
    return safeCall(() => _remoteData.updateCardNote(cardId, {'note': note}));
  }

  Future<Result<void>> deleteDeckCard(int cardId) async {
    return safeCall(() => _remoteData.deleteFlashcard(cardId));
  }

  // --- Flashcard Study & Review ---
  Future<Result<List<FlashcardItem>>> getStudyCards(int deckId) async {
    return safeCall(() => _remoteData.getStudyCards(deckId));
  }

  Future<Result<List<FlashcardItem>>> getAllDueCards() async {
    return safeCall(() => _remoteData.getAllDueCards());
  }

  Future<Result<ReviewCardResponse>> reviewCard(
    int cardId,
    String rating, {
    int reviewTimeMs = 0,
  }) async {
    return safeCall(() => _remoteData.reviewCard(cardId, {
          'rating': rating,
          'reviewTimeMs': reviewTimeMs,
        }));
  }

  Future<Result<FlashcardUserStats>> getFlashcardStats() async {
    return safeCall(() => _remoteData.getFlashcardStats());
  }

  // --- Themes ---
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
