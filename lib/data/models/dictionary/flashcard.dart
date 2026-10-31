import 'package:freezed_annotation/freezed_annotation.dart';
import 'word.dart';

part 'flashcard.freezed.dart';
part 'flashcard.g.dart';

@freezed
abstract class Flashcard with _$Flashcard {
  const factory Flashcard({
    required int id,
    required String note,
    required String createdAt,
    required WordSummary word,
  }) = _Flashcard;

  factory Flashcard.fromJson(Map<String, dynamic> json) => _$FlashcardFromJson(json);
}

@freezed
abstract class GetFlashcardsResponse with _$GetFlashcardsResponse {
  const factory GetFlashcardsResponse({
    @Default([]) List<Flashcard> data,
    required int page,
    required int pageCounts,
    required int total,
  }) = _GetFlashcardsResponse;

  factory GetFlashcardsResponse.fromJson(Map<String, dynamic> json) => _$GetFlashcardsResponseFromJson(json);
}
