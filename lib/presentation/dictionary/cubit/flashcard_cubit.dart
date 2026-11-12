import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/dictionary/flashcard_models.dart';
import 'package:eflutter/data/repositories/dictionary_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

sealed class FlashcardState {
  const FlashcardState();
}

class FlashcardInitial extends FlashcardState {
  const FlashcardInitial();
}

class FlashcardLoading extends FlashcardState {
  const FlashcardLoading();
}

class FlashcardLoaded extends FlashcardState {
  final List<FlashcardDeck> decks;
  final FlashcardUserStats? stats;

  const FlashcardLoaded({
    required this.decks,
    this.stats,
  });

  FlashcardLoaded copyWith({
    List<FlashcardDeck>? decks,
    FlashcardUserStats? stats,
  }) {
    return FlashcardLoaded(
      decks: decks ?? this.decks,
      stats: stats ?? this.stats,
    );
  }
}

class FlashcardError extends FlashcardState {
  final String message;
  const FlashcardError(this.message);
}

@injectable
class FlashcardCubit extends Cubit<FlashcardState> {
  final DictionaryRepository _repository;

  FlashcardCubit(this._repository) : super(const FlashcardInitial());

  Future<void> loadDashboard() async {
    emit(const FlashcardLoading());
    final results = await Future.wait([
      _repository.getDecks(),
      _repository.getFlashcardStats(),
    ]);

    final decksRes = results[0] as Result<List<FlashcardDeck>>;
    final statsRes = results[1] as Result<FlashcardUserStats>;

    switch (decksRes) {
      case Failure(message: final msg):
        emit(FlashcardError(msg ?? 'Không thể tải danh sách bộ thẻ'));
        return;
      case Cancelled():
        return;
      case Success(data: final decks):
        final stats = switch (statsRes) {
          Success(data: final s) => s,
          _ => null,
        };
        emit(FlashcardLoaded(decks: decks, stats: stats));
    }
  }

  Future<List<FlashcardDeck>> getDecksList() async {
    final result = await _repository.getDecks();
    if (result is Success<List<FlashcardDeck>>) {
      return result.data;
    }
    return [];
  }

  Future<FlashcardDeck?> createDeck(
    String name, {
    String? description,
    String? color,
  }) async {
    final result = await _repository.createDeck(
      name,
      description: description,
      color: color,
    );
    if (result is Success<FlashcardDeck>) {
      await loadDashboard();
      return result.data;
    }
    return null;
  }

  Future<bool> updateDeck(
    int id, {
    String? name,
    String? description,
    String? color,
  }) async {
    final result = await _repository.updateDeck(
      id,
      name: name,
      description: description,
      color: color,
    );
    if (result is Success<FlashcardDeck>) {
      await loadDashboard();
      return true;
    }
    return false;
  }

  Future<bool> deleteDeck(int id) async {
    final result = await _repository.deleteDeck(id);
    if (result is Success<void>) {
      await loadDashboard();
      return true;
    }
    return false;
  }

  // --- Deck Cards ---
  Future<GetDeckCardsResponse?> getDeckCards(
    int deckId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await _repository.getDeckCards(deckId, page: page, pageSize: pageSize);
    if (result is Success<GetDeckCardsResponse>) {
      return result.data;
    }
    return null;
  }

  Future<bool> updateCardNote(int cardId, String? note) async {
    final result = await _repository.updateCardNote(cardId, note);
    return result is Success<FlashcardItem>;
  }

  Future<bool> deleteDeckCard(int cardId) async {
    final result = await _repository.deleteDeckCard(cardId);
    return result is Success<void>;
  }

  // --- Word Save Status & Saving ---
  Future<WordSaveStatus?> getWordSaveStatus(int wordId) async {
    final result = await _repository.getWordSaveStatus(wordId);
    if (result is Success<WordSaveStatus>) {
      return result.data;
    }
    return null;
  }

  Future<bool> saveWordToDecks(
    int wordId, {
    List<int>? deckIds,
    String? newDeckName,
    String? note,
  }) async {
    final result = await _repository.saveWordToDecks(
      wordId,
      deckIds: deckIds,
      newDeckName: newDeckName,
      note: note,
    );
    return result is Success<void>;
  }

  // --- Study & Review ---
  Future<List<FlashcardItem>?> getStudyCards(int deckId) async {
    final result = await _repository.getStudyCards(deckId);
    if (result is Success<List<FlashcardItem>>) {
      return result.data;
    }
    return null;
  }

  Future<List<FlashcardItem>?> getAllDueCards() async {
    final result = await _repository.getAllDueCards();
    if (result is Success<List<FlashcardItem>>) {
      return result.data;
    }
    return null;
  }

  Future<ReviewCardResponse?> reviewCard(
    int cardId,
    String rating, {
    int reviewTimeMs = 0,
  }) async {
    final result = await _repository.reviewCard(cardId, rating, reviewTimeMs: reviewTimeMs);
    if (result is Success<ReviewCardResponse>) {
      return result.data;
    }
    return null;
  }
}
