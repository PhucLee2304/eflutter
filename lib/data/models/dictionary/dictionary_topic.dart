import 'package:freezed_annotation/freezed_annotation.dart';
import 'word.dart';

part 'dictionary_topic.freezed.dart';
part 'dictionary_topic.g.dart';

@freezed
abstract class DictionaryTopic with _$DictionaryTopic {
  const factory DictionaryTopic({
    required int id,
    required String name,
    required String category,
    String? description,
    String? icon,
    String? level,
  }) = _DictionaryTopic;

  factory DictionaryTopic.fromJson(Map<String, dynamic> json) => _$DictionaryTopicFromJson(json);
}

@freezed
abstract class TopicWordsResponse with _$TopicWordsResponse {
  const factory TopicWordsResponse({
    @Default([]) List<WordSummary> data,
    required int page,
    required int pageCounts,
    @Default(0) int total,
  }) = _TopicWordsResponse;

  factory TopicWordsResponse.fromJson(Map<String, dynamic> json) =>
      _$TopicWordsResponseFromJson(json);
}
