// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Phonetic _$PhoneticFromJson(Map<String, dynamic> json) => _Phonetic(
  text: json['text'] as String,
  audioUrl: json['audioUrl'] as String?,
  sourceUrl: json['sourceUrl'] as String?,
);

Map<String, dynamic> _$PhoneticToJson(_Phonetic instance) => <String, dynamic>{
  'text': instance.text,
  'audioUrl': instance.audioUrl,
  'sourceUrl': instance.sourceUrl,
};

_Definition _$DefinitionFromJson(Map<String, dynamic> json) => _Definition(
  definition: json['definition'] as String,
  example: json['example'] as String?,
  synonyms:
      (json['synonyms'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  antonyms:
      (json['antonyms'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$DefinitionToJson(_Definition instance) =>
    <String, dynamic>{
      'definition': instance.definition,
      'example': instance.example,
      'synonyms': instance.synonyms,
      'antonyms': instance.antonyms,
    };

_Meaning _$MeaningFromJson(Map<String, dynamic> json) => _Meaning(
  partOfSpeech: json['partOfSpeech'] as String,
  definitions:
      (json['definitions'] as List<dynamic>?)
          ?.map((e) => Definition.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  synonyms:
      (json['synonyms'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  antonyms:
      (json['antonyms'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$MeaningToJson(_Meaning instance) => <String, dynamic>{
  'partOfSpeech': instance.partOfSpeech,
  'definitions': instance.definitions,
  'synonyms': instance.synonyms,
  'antonyms': instance.antonyms,
};

_WordDetail _$WordDetailFromJson(Map<String, dynamic> json) => _WordDetail(
  id: (json['id'] as num?)?.toInt() ?? 0,
  word: json['word'] as String,
  phonetic: json['phonetic'] as String?,
  phonetics:
      (json['phonetics'] as List<dynamic>?)
          ?.map((e) => Phonetic.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  meanings:
      (json['meanings'] as List<dynamic>?)
          ?.map((e) => Meaning.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  licenseName: json['licenseName'] as String?,
  licenseUrl: json['licenseUrl'] as String?,
  sourceUrls:
      (json['sourceUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$WordDetailToJson(_WordDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'word': instance.word,
      'phonetic': instance.phonetic,
      'phonetics': instance.phonetics,
      'meanings': instance.meanings,
      'licenseName': instance.licenseName,
      'licenseUrl': instance.licenseUrl,
      'sourceUrls': instance.sourceUrls,
    };

_WordSummary _$WordSummaryFromJson(Map<String, dynamic> json) => _WordSummary(
  id: (json['id'] as num?)?.toInt() ?? 0,
  word: json['word'] as String,
  phonetic: json['phonetic'] as String?,
);

Map<String, dynamic> _$WordSummaryToJson(_WordSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'word': instance.word,
      'phonetic': instance.phonetic,
    };
