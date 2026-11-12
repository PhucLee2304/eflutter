import 'package:flutter/material.dart';
import 'word.dart';

/// Bộ thẻ từ vựng của người dùng.
class FlashcardDeck {
  final int id;
  final String name;
  final String? description;
  final String? color;
  final int cardCount;
  final int dueCount;
  final String createdAt;

  const FlashcardDeck({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.cardCount = 0,
    this.dueCount = 0,
    required this.createdAt,
  });

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    return FlashcardDeck(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      color: json['color'] as String?,
      cardCount: json['cardCount'] as int? ?? 0,
      dueCount: json['dueCount'] as int? ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (color != null) 'color': color,
        'cardCount': cardCount,
        'dueCount': dueCount,
        'createdAt': createdAt,
      };

  Color get deckColor {
    if (color == null || color!.isEmpty) return const Color(0xFF6366F1); // Indigo
    try {
      String hex = color!.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}

/// Thẻ từ vựng trong bộ thẻ (Spaced Repetition SM-2).
class FlashcardItem {
  final int id;
  final int deckId;
  final int wordId;
  final String? note;
  final String status;
  final int intervalDays;
  final double easeFactor;
  final int repetitions;
  final String nextReviewAt;
  final String? lastReviewedAt;
  final String createdAt;
  final WordDetail? word;
  final String? rawWordText;

  const FlashcardItem({
    required this.id,
    this.deckId = 0,
    required this.wordId,
    this.note,
    this.status = 'new',
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    this.nextReviewAt = '',
    this.lastReviewedAt,
    this.createdAt = '',
    this.word,
    this.rawWordText,
  });

  factory FlashcardItem.fromJson(Map<String, dynamic> json) {
    WordDetail? wordDetail;
    String? fallbackWord;
    if (json['word'] != null && json['word'] is Map<String, dynamic>) {
      final wordMap = json['word'] as Map<String, dynamic>;
      fallbackWord = wordMap['word'] as String?;
      try {
        wordDetail = WordDetail.fromJson(wordMap);
      } catch (_) {
        // Fallback
      }
    }

    return FlashcardItem(
      id: json['id'] as int? ?? 0,
      deckId: json['deckId'] as int? ?? 0,
      wordId: json['wordId'] as int? ?? 0,
      note: json['note'] as String?,
      status: json['status'] as String? ?? 'new',
      intervalDays: json['intervalDays'] as int? ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      repetitions: json['repetitions'] as int? ?? 0,
      nextReviewAt: json['nextReviewAt'] as String? ?? '',
      lastReviewedAt: json['lastReviewedAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      word: wordDetail,
      rawWordText: fallbackWord,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deckId': deckId,
        'wordId': wordId,
        'note': note,
        'status': status,
        'intervalDays': intervalDays,
        'easeFactor': easeFactor,
        'repetitions': repetitions,
        'nextReviewAt': nextReviewAt,
        'lastReviewedAt': lastReviewedAt,
        'createdAt': createdAt,
      };

  String get wordText =>
      word?.word ?? (rawWordText != null && rawWordText!.isNotEmpty ? rawWordText! : 'Word #$wordId');

  String get phoneticText {
    if (word?.phonetic != null && word!.phonetic!.isNotEmpty) return word!.phonetic!;
    if (word?.phonetics.isNotEmpty == true) {
      for (final p in word!.phonetics) {
        if (p.text != null && p.text!.isNotEmpty) return p.text!;
      }
    }
    return '';
  }

  String? get audioUrl {
    if (word?.phonetics.isNotEmpty == true) {
      for (final p in word!.phonetics) {
        if (p.audioUrl != null && p.audioUrl!.isNotEmpty) {
          return p.audioUrl;
        }
      }
    }
    return null;
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'mastered':
        return 'Thành thạo';
      case 'review':
        return 'Ôn tập';
      case 'learning':
        return 'Đang học';
      case 'new':
      default:
        return 'Mới';
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'mastered':
        return const Color(0xFF10B981); // Emerald green
      case 'review':
        return const Color(0xFF3B82F6); // Blue
      case 'learning':
        return const Color(0xFFF59E0B); // Amber
      case 'new':
      default:
        return const Color(0xFF8B5CF6); // Purple
    }
  }
}

/// Thống kê tổng quan ôn tập của người dùng.
class FlashcardUserStats {
  final int totalCards;
  final int masteredCards;
  final int dueToday;
  final int streak;

  const FlashcardUserStats({
    this.totalCards = 0,
    this.masteredCards = 0,
    this.dueToday = 0,
    this.streak = 0,
  });

  factory FlashcardUserStats.fromJson(Map<String, dynamic> json) {
    return FlashcardUserStats(
      totalCards: json['totalCards'] as int? ?? 0,
      masteredCards: json['masteredCards'] as int? ?? 0,
      dueToday: json['dueToday'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
    );
  }
}

/// Trạng thái lưu từ của một từ trong từ điển.
class WordSaveStatus {
  final int wordId;
  final bool isSaved;
  final List<int> savedInDeckIds;

  const WordSaveStatus({
    required this.wordId,
    this.isSaved = false,
    this.savedInDeckIds = const [],
  });

  factory WordSaveStatus.fromJson(Map<String, dynamic> json) {
    return WordSaveStatus(
      wordId: json['wordId'] as int? ?? 0,
      isSaved: json['isSaved'] as bool? ?? false,
      savedInDeckIds: (json['savedInDeckIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );
  }
}

/// Kết quả sau khi nộp đánh giá ôn tập thẻ.
class ReviewCardResponse {
  final int cardId;
  final String nextReviewAt;
  final int intervalDays;
  final int repetitions;
  final String status;

  const ReviewCardResponse({
    required this.cardId,
    required this.nextReviewAt,
    required this.intervalDays,
    required this.repetitions,
    required this.status,
  });

  factory ReviewCardResponse.fromJson(Map<String, dynamic> json) {
    return ReviewCardResponse(
      cardId: json['cardId'] as int? ?? 0,
      nextReviewAt: json['nextReviewAt'] as String? ?? '',
      intervalDays: json['intervalDays'] as int? ?? 0,
      repetitions: json['repetitions'] as int? ?? 0,
      status: json['status'] as String? ?? '',
    );
  }
}

/// Response danh sách thẻ phân trang trong 1 deck.
class GetDeckCardsResponse {
  final List<FlashcardItem> data;
  final int page;
  final int pageCounts;
  final int total;

  const GetDeckCardsResponse({
    this.data = const [],
    this.page = 1,
    this.pageCounts = 1,
    this.total = 0,
  });

  factory GetDeckCardsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>?)
            ?.map((e) => FlashcardItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return GetDeckCardsResponse(
      data: list,
      page: json['page'] as int? ?? 1,
      pageCounts: json['pageCounts'] as int? ?? 1,
      total: json['total'] as int? ?? 0,
    );
  }
}
