import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_attempt_page.dart';
import 'package:eflutter/data/models/exam_page.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/presentation/exams/exam_history_refresh.dart';
import 'package:flutter/foundation.dart';

/// Số liệu tự luyện của một loại đề, chỉ tính attempt đã nộp và không phải bài giao.
class SelfStudyStats {
  const SelfStudyStats({
    required this.attempts,
    required this.bestScore,
    required this.lastPracticeAt,
    required this.bestByExam,
    this.attemptsByExam = const {},
    this.averageScore,
    this.examTotal,
  });

  final int attempts;
  final double? bestScore;
  final DateTime? lastPracticeAt;

  /// Điểm cao nhất theo examId, dùng cho nhãn "Best" trên thẻ đề.
  final Map<int, double> bestByExam;

  /// Số lượt đã nộp theo examId (trong mẫu 100 lượt gần nhất).
  final Map<int, int> attemptsByExam;

  final double? averageScore;

  /// Tổng số đề public của loại này, null khi chưa tải được.
  final int? examTotal;

  int get testsDone => bestByExam.length;

  static SelfStudyStats fromAttempts(List<ExamAttempt> attempts, int total, {int? examTotal}) {
    double? best;
    var sum = 0.0;
    var scored = 0;
    DateTime? last;
    final bestByExam = <int, double>{};
    final attemptsByExam = <int, int>{};
    for (final attempt in attempts) {
      attemptsByExam.update(attempt.examId, (n) => n + 1, ifAbsent: () => 1);
      final at = attempt.submittedAt ?? attempt.updatedAt;
      if (at != null && (last == null || at.isAfter(last))) last = at;
      final score = attempt.score;
      if (score == null) continue;
      sum += score;
      scored++;
      if (best == null || score > best) best = score;
      final previous = bestByExam[attempt.examId];
      if (previous == null || score > previous) bestByExam[attempt.examId] = score;
    }
    return SelfStudyStats(
      attempts: total,
      bestScore: best,
      lastPracticeAt: last,
      bestByExam: bestByExam,
      attemptsByExam: attemptsByExam,
      averageScore: scored == 0 ? null : sum / scored,
      examTotal: examTotal,
    );
  }
}

/// Cache dùng chung cho header và lưới đề; tải lại khi có attempt mới nộp/hủy.
class SelfStudyStatsStore {
  SelfStudyStatsStore._() {
    examHistoryRevision.addListener(reload);
  }

  static final instance = SelfStudyStatsStore._();

  static const types = ['TOEIC', 'THPT'];

  /// Backend giới hạn pageSize 100: best/last lấy trong 100 lượt gần nhất, số lượt là tổng thật.
  static const _sampleSize = 100;

  final stats = ValueNotifier<Map<String, SelfStudyStats>>(const {});
  bool _loaded = false;

  void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    reload();
  }

  Future<void> reload() async {
    final repository = ExamRepository(getIt<RemoteDataBase>());
    final results = await Future.wait([
      for (final type in types)
        repository.getAttempts(
          status: 'SUBMITTED',
          page: 1,
          pageSize: _sampleSize,
          excludeMode: 'ASSIGNMENT',
          examTypes: [type],
        ),
      for (final type in types) repository.getExams(type: type, page: 1, pageSize: 1),
    ]);
    final next = <String, SelfStudyStats>{};
    for (var i = 0; i < types.length; i++) {
      final result = results[i];
      final exams = results[types.length + i];
      if (result is Success) {
        final page = result.dataOrNull! as ExamAttemptPage;
        final examTotal = exams is Success ? (exams.dataOrNull! as ExamPage).total : null;
        next[types[i]] = SelfStudyStats.fromAttempts(
          page.attempts,
          page.total,
          examTotal: examTotal,
        );
      }
    }
    stats.value = next;
  }
}
