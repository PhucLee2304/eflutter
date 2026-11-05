import 'package:freezed_annotation/freezed_annotation.dart';

part 'grammar_unit.freezed.dart';
part 'grammar_unit.g.dart';

// ─── Curriculum models ────────────────────────────────────────────────────────

@freezed
abstract class UnitSummary with _$UnitSummary {
  const UnitSummary._();

  const factory UnitSummary({
    required int id,
    @Default(1) int unit,
    required String title,
    @Default(false) bool completed,
    @Default(0) int total,
  }) = _UnitSummary;

  int get progressCompleted => completed ? 1 : 0;
  int get progressTotal => 1;
  double get progressPercent => completed ? 1.0 : 0.0;

  factory UnitSummary.fromJson(Map<String, dynamic> json) =>
      _$UnitSummaryFromJson(json);
}

@freezed
abstract class CurriculumResponse with _$CurriculumResponse {
  const CurriculumResponse._();

  const factory CurriculumResponse({
    @Default([]) List<UnitSummary> data,
    @Default(0) int total,
  }) = _CurriculumResponse;

  List<UnitSummary> get units => data;

  factory CurriculumResponse.fromJson(Map<String, dynamic> json) =>
      _$CurriculumResponseFromJson(json);
}

// ─── Lesson / Unit Detail models ─────────────────────────────────────────────

@freezed
abstract class PracticeQuestion with _$PracticeQuestion {
  const PracticeQuestion._();

  const factory PracticeQuestion({
    required int id,
    required String question,
    @Default([]) List<String> options,
    required String correct,
    required String explanation,
    int? sortOrder,
  }) = _PracticeQuestion;

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) =>
      _$PracticeQuestionFromJson(json);
}

@freezed
abstract class UnitDetail with _$UnitDetail {
  const UnitDetail._();

  const factory UnitDetail({
    required int id,
    @Default(1) int unit,
    required String title,
    required String theory,
    @Default([]) List<String> examples,
    @Default([]) List<PracticeQuestion> practices,
    @Default(false) bool completed,
  }) = _UnitDetail;

  List<PracticeQuestion> get practice => practices;

  factory UnitDetail.fromJson(Map<String, dynamic> json) =>
      _$UnitDetailFromJson(json);
}
