// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SearchResponse _$SearchResponseFromJson(Map<String, dynamic> json) =>
    _SearchResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => WordSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      page: (json['page'] as num).toInt(),
      pageCounts: (json['pageCounts'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$SearchResponseToJson(_SearchResponse instance) =>
    <String, dynamic>{
      'data': instance.data,
      'page': instance.page,
      'pageCounts': instance.pageCounts,
      'total': instance.total,
    };
