// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_topic.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DictionaryTopic _$DictionaryTopicFromJson(Map<String, dynamic> json) => _DictionaryTopic(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  category: json['category'] as String,
  description: json['description'] as String?,
  icon: json['icon'] as String?,
  level: json['level'] as String?,
);

Map<String, dynamic> _$DictionaryTopicToJson(_DictionaryTopic instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'category': instance.category,
  'description': instance.description,
  'icon': instance.icon,
  'level': instance.level,
};

_TopicWordsResponse _$TopicWordsResponseFromJson(Map<String, dynamic> json) => _TopicWordsResponse(
  data:
      (json['data'] as List<dynamic>?)
          ?.map((e) => WordSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  page: (json['page'] as num).toInt(),
  pageCounts: (json['pageCounts'] as num).toInt(),
  total: (json['total'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TopicWordsResponseToJson(_TopicWordsResponse instance) => <String, dynamic>{
  'data': instance.data,
  'page': instance.page,
  'pageCounts': instance.pageCounts,
  'total': instance.total,
};
