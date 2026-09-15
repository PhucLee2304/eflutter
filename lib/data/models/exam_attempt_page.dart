import 'package:eflutter/data/models/exam_attempt.dart';

class ExamAttemptPage {
  final List<ExamAttempt> attempts;
  final int page;
  final int pageCounts;

  const ExamAttemptPage({
    required this.attempts,
    required this.page,
    required this.pageCounts,
  });

  factory ExamAttemptPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? const [];
    return ExamAttemptPage(
      attempts: data
          .map((item) => ExamAttempt.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageCounts: (json['pageCounts'] as num?)?.toInt() ?? 1,
    );
  }

  factory ExamAttemptPage.fromResponse(
    Object? data, {
    required int requestedPage,
  }) {
    if (data is List<dynamic>) {
      return ExamAttemptPage(
        attempts: data
            .map((item) => ExamAttempt.fromJson(item as Map<String, dynamic>))
            .toList(),
        page: requestedPage,
        pageCounts: 1,
      );
    }

    if (data is Map<String, dynamic>) {
      return ExamAttemptPage.fromJson(data);
    }

    return ExamAttemptPage(
      attempts: const [],
      page: requestedPage,
      pageCounts: 1,
    );
  }
}
