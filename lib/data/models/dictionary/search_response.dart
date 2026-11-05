import 'package:freezed_annotation/freezed_annotation.dart';
import 'word.dart';

part 'search_response.freezed.dart';
part 'search_response.g.dart';

@freezed
abstract class SearchResponse with _$SearchResponse {
  const factory SearchResponse({
    @Default([]) List<WordSummary> data,
    required int page,
    required int pageCounts,
    // httpx.PaginatedResponse bỏ `total` khi bằng 0.
    @Default(0) int total,
  }) = _SearchResponse;

  factory SearchResponse.fromJson(Map<String, dynamic> json) => _$SearchResponseFromJson(json);
}
