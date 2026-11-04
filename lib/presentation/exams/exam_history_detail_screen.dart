import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/classrooms/assignment_review_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Xem lại lượt tự luyện đã nộp: dùng chung giao diện xem lại bài giao trong lớp (Figma 68:1189).
class ExamHistoryDetailScreen extends StatelessWidget {
  const ExamHistoryDetailScreen({super.key, required this.attemptId, this.initialAttempt});

  final int attemptId;
  final ExamAttempt? initialAttempt;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.histories.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1048),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: AssignmentReviewView(
                  attemptId: attemptId,
                  title: initialAttempt?.exam?.title,
                  onBack: () => _back(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
