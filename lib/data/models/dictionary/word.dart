import 'package:freezed_annotation/freezed_annotation.dart';

part 'word.freezed.dart';
part 'word.g.dart';

@freezed
abstract class Phonetic with _$Phonetic {
  const factory Phonetic({String? text, String? audioUrl, String? sourceUrl}) = _Phonetic;

  factory Phonetic.fromJson(Map<String, dynamic> json) => _$PhoneticFromJson(json);
}

@freezed
abstract class Definition with _$Definition {
  const factory Definition({
    required String definition,
    String? example,
    @Default([]) List<String> synonyms,
    @Default([]) List<String> antonyms,
  }) = _Definition;

  factory Definition.fromJson(Map<String, dynamic> json) => _$DefinitionFromJson(json);
}

@freezed
abstract class Meaning with _$Meaning {
  const factory Meaning({
    required String partOfSpeech,
    @Default([]) List<Definition> definitions,
    @Default([]) List<String> synonyms,
    @Default([]) List<String> antonyms,
  }) = _Meaning;

  factory Meaning.fromJson(Map<String, dynamic> json) => _$MeaningFromJson(json);
}

@freezed
abstract class WordDetail with _$WordDetail {
  const factory WordDetail({
    required int id,
    required String word,
    String? phonetic,
    @Default([]) List<Phonetic> phonetics,
    @Default([]) List<Meaning> meanings,
    String? licenseName,
    String? licenseUrl,
    @Default([]) List<String> sourceUrls,
  }) = _WordDetail;

  factory WordDetail.fromJson(Map<String, dynamic> json) => _$WordDetailFromJson(json);
}

@freezed
abstract class WordSummary with _$WordSummary {
  const factory WordSummary({required int id, required String word, String? phonetic}) =
      _WordSummary;

  factory WordSummary.fromJson(Map<String, dynamic> json) => _$WordSummaryFromJson(json);
}
