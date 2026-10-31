// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Flashcard _$FlashcardFromJson(Map<String, dynamic> json) => _Flashcard(
  id: (json['id'] as num).toInt(),
  note: json['note'] as String,
  createdAt: json['createdAt'] as String,
  word: WordSummary.fromJson(json['word'] as Map<String, dynamic>),
);

Map<String, dynamic> _$FlashcardToJson(_Flashcard instance) =>
    <String, dynamic>{
      'id': instance.id,
      'note': instance.note,
      'createdAt': instance.createdAt,
      'word': instance.word,
    };

_GetFlashcardsResponse _$GetFlashcardsResponseFromJson(
  Map<String, dynamic> json,
) => _GetFlashcardsResponse(
  data:
      (json['data'] as List<dynamic>?)
          ?.map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  page: (json['page'] as num).toInt(),
  pageCounts: (json['pageCounts'] as num).toInt(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$GetFlashcardsResponseToJson(
  _GetFlashcardsResponse instance,
) => <String, dynamic>{
  'data': instance.data,
  'page': instance.page,
  'pageCounts': instance.pageCounts,
  'total': instance.total,
};
