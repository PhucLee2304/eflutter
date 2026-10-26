import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/presentation/exams/attempt/attempt_exam_screen.dart';
import 'package:eflutter/presentation/exams/attempt_practice_screen.dart';
import 'package:flutter/material.dart';

/// Route `/attempts/:id/take`: chọn màn theo flow. Flow TOEIC_STRICT dùng màn theo
/// trang; còn lại giữ list cuộn. Vào thẳng route (F5, AttemptLockNotifier) thì không
/// có `extra`: tìm attempt trong danh sách ACTIVE để biết flow.
class AttemptRouteScreen extends StatefulWidget {
  const AttemptRouteScreen({
    super.key,
    required this.attemptId,
    this.initialAttempt,
  });

  final int attemptId;
  final ExamAttempt? initialAttempt;

  @override
  State<AttemptRouteScreen> createState() => _AttemptRouteScreenState();
}

class _AttemptRouteScreenState extends State<AttemptRouteScreen> {
  ExamAttempt? _attempt;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _attempt = widget.initialAttempt;
    _resolved = _attempt != null;
    if (!_resolved) _resolve();
  }

  Future<void> _resolve() async {
    final result = await ExamRepository(
      getIt<RemoteDataBase>(),
    ).getAttempts(status: 'ACTIVE', page: 1, pageSize: 20);
    if (!mounted) return;
    setState(() {
      if (result case Success(data: final page)) {
        _attempt = page.attempts
            .where((attempt) => attempt.id == widget.attemptId)
            .firstOrNull;
      }
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final attempt = _attempt;
    if (attempt != null && attempt.isStrict) {
      return AttemptExamScreen(attempt: attempt);
    }
    // Không thấy trong ACTIVE (đã nộp, không tồn tại…): màn cũ tự xử lý như trước.
    return AttemptPracticeScreen(
      attemptId: widget.attemptId,
      initialAttempt: widget.initialAttempt,
    );
  }
}
