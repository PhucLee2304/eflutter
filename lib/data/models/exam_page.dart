import 'package:eflutter/data/models/exam_summary.dart';

class ExamPage {
  final List<ExamSummary> exams;
  final int page;
  final int pageCounts;

  const ExamPage({
    required this.exams,
    required this.page,
    required this.pageCounts,
  });

  factory ExamPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? const [];
    return ExamPage(
      exams: data
          .map((item) => ExamSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageCounts: (json['pageCounts'] as num?)?.toInt() ?? 1,
    );
  }
}
