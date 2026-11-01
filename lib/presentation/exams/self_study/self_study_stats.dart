import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
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
  });

  final int attempts;
  final double? bestScore;
  final DateTime? lastPracticeAt;

  /// Điểm cao nhất theo examId, dùng cho nhãn "Best" trên thẻ đề.
  final Map<int, double> bestByExam;

  static SelfStudyStats fromAttempts(List<ExamAttempt> attempts, int total) {
    double? best;
    DateTime? last;
    final bestByExam = <int, double>{};
    for (final attempt in attempts) {
      final at = attempt.submittedAt ?? attempt.updatedAt;
      if (at != null && (last == null || at.isAfter(last))) last = at;
      final score = attempt.score;
      if (score == null) continue;
      if (best == null || score > best) best = score;
      final previous = bestByExam[attempt.examId];
      if (previous == null || score > previous) bestByExam[attempt.examId] = score;
    }
    return SelfStudyStats(
      attempts: total,
      bestScore: best,
      lastPracticeAt: last,
      bestByExam: bestByExam,
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
    ]);
    final next = <String, SelfStudyStats>{};
    for (var i = 0; i < types.length; i++) {
      final result = results[i];
      if (result is Success) {
        final page = result.dataOrNull!;
        next[types[i]] = SelfStudyStats.fromAttempts(page.attempts, page.total);
      }
    }
    stats.value = next;
  }
}
