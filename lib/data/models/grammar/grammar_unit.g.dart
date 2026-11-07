// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grammar_unit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UnitSummary _$UnitSummaryFromJson(Map<String, dynamic> json) => _UnitSummary(
  id: (json['id'] as num).toInt(),
  unit: (json['unit'] as num?)?.toInt() ?? 1,
  title: json['title'] as String,
  completed: json['completed'] as bool? ?? false,
  total: (json['total'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$UnitSummaryToJson(_UnitSummary instance) => <String, dynamic>{
  'id': instance.id,
  'unit': instance.unit,
  'title': instance.title,
  'completed': instance.completed,
  'total': instance.total,
};

_CurriculumResponse _$CurriculumResponseFromJson(Map<String, dynamic> json) => _CurriculumResponse(
  data:
      (json['data'] as List<dynamic>?)
          ?.map((e) => UnitSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  total: (json['total'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CurriculumResponseToJson(_CurriculumResponse instance) => <String, dynamic>{
  'data': instance.data,
  'total': instance.total,
};

_PracticeQuestion _$PracticeQuestionFromJson(Map<String, dynamic> json) => _PracticeQuestion(
  id: (json['id'] as num).toInt(),
  question: json['question'] as String,
  options: (json['options'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  correct: json['correct'] as String,
  explanation: json['explanation'] as String,
  sortOrder: (json['sortOrder'] as num?)?.toInt(),
);

Map<String, dynamic> _$PracticeQuestionToJson(_PracticeQuestion instance) => <String, dynamic>{
  'id': instance.id,
  'question': instance.question,
  'options': instance.options,
  'correct': instance.correct,
  'explanation': instance.explanation,
  'sortOrder': instance.sortOrder,
};

_UnitDetail _$UnitDetailFromJson(Map<String, dynamic> json) => _UnitDetail(
  id: (json['id'] as num).toInt(),
  unit: (json['unit'] as num?)?.toInt() ?? 1,
  title: json['title'] as String,
  theory: json['theory'] as String,
  examples: (json['examples'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  practices:
      (json['practices'] as List<dynamic>?)
          ?.map((e) => PracticeQuestion.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  completed: json['completed'] as bool? ?? false,
);

Map<String, dynamic> _$UnitDetailToJson(_UnitDetail instance) => <String, dynamic>{
  'id': instance.id,
  'unit': instance.unit,
  'title': instance.title,
  'theory': instance.theory,
  'examples': instance.examples,
  'practices': instance.practices,
  'completed': instance.completed,
};
