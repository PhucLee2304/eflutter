import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_questions.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/widgets/exam_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class ExamHistoryDetailScreen extends StatefulWidget {
  const ExamHistoryDetailScreen({
    super.key,
    required this.attemptId,
    this.initialAttempt,
  });

  final int attemptId;
  final ExamAttempt? initialAttempt;

  @override
  State<ExamHistoryDetailScreen> createState() =>
      _ExamHistoryDetailScreenState();
}

class _ExamHistoryDetailScreenState extends State<ExamHistoryDetailScreen> {
  ExamAttempt? _attempt;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _attempt = widget.initialAttempt;
    _loading = _attempt == null;
    if (_attempt == null) _load();
  }

  Future<void> _load() async {
    final result = await ExamRepository(
      getIt<RemoteDataBase>(),
    ).getAttemptHistory(widget.attemptId);
    if (!mounted) return;
    switch (result) {
      case Success(data: final attempt):
        setState(() {
          _attempt = attempt;
          _loading = false;
        });
      case Failure():
        setState(() => _loading = false);
        context.handleFailure(result);
      case Cancelled():
        setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : attempt == null
            ? const Center(child: Text('Attempt history not found'))
            : Column(
                children: [
                  _ReviewHeader(attempt: attempt),
                  Expanded(
                    child: SelectionArea(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: attempt.questions
                            .map(
                              (section) => _ReviewSection(
                                section: section,
                                submitted: attempt.status == 'SUBMITTED',
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.attempt});
  final ExamAttempt attempt;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: ColorName.gray5)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Back',
              onPressed: context.pop,
              icon: const Icon(SolarIconsOutline.altArrowLeft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attempt.exam?.title ?? 'Attempt #${attempt.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${attempt.status}  |  ${attempt.answeredCount}/${attempt.totalQuestions} answered',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ColorName.labelSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (attempt.status == 'SUBMITTED') ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ResultMetric(
                label: 'Correct',
                value:
                    '${attempt.correctAnswers ?? 0}/${attempt.totalQuestions}',
              ),
              const SizedBox(width: 8),
              _ResultMetric(
                label: 'Score',
                value: attempt.score?.toStringAsFixed(2) ?? '-',
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: ColorName.gray6,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: ColorName.labelSecondary),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.section, required this.submitted});
  final ExamQuestionsSection section;
  final bool submitted;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 920),
    margin: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          section.title.isEmpty ? section.code : section.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...section.groups.expand(
          (group) => [
            if (group.instruction.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  group.instruction,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            if (group.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: Image.network(
                    group.imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text('Image unavailable'),
                  ),
                ),
              ),
            if (group.audioUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ExamAudioPlayer(url: group.audioUrl!),
              ),
            ...group.questions.map(
              (question) =>
                  _ReviewQuestion(question: question, submitted: submitted),
            ),
            if (group.transcript.isNotEmpty)
              _Explanation(title: 'Transcript', value: group.transcript),
            if (group.explanation.isNotEmpty)
              _Explanation(
                title: 'Group explanation',
                value: group.explanation,
              ),
          ],
        ),
        ...section.questions.map(
          (question) =>
              _ReviewQuestion(question: question, submitted: submitted),
        ),
      ],
    ),
  );
}

class _ReviewQuestion extends StatelessWidget {
  const _ReviewQuestion({required this.question, required this.submitted});
  final ExamQuestion question;
  final bool submitted;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: ColorName.gray5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${question.order}. ${question.content.isEmpty ? 'Choose the correct answer.' : question.content}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (submitted && question.isCorrect != null)
              Icon(
                question.isCorrect!
                    ? SolarIconsOutline.checkCircle
                    : SolarIconsOutline.closeCircle,
                color: question.isCorrect! ? ColorName.green : ColorName.red,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...question.options.map((option) {
          final selected = option.id == question.selectedOptionId;
          final correct = submitted && option.id == question.correctOptionId;
          return Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: correct
                  ? ColorName.green.withValues(alpha: .14)
                  : selected
                  ? ColorName.red.withValues(alpha: .10)
                  : null,
              border: Border.all(
                color: correct
                    ? ColorName.green
                    : selected
                    ? ColorName.red
                    : ColorName.gray5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${option.key}${option.content?.trim().isNotEmpty == true ? '. ${option.content}' : ''}',
            ),
          );
        }),
        if (question.explanation.isNotEmpty)
          _Explanation(title: 'Explanation', value: question.explanation),
      ],
    ),
  );
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      '$title: $value',
      style: const TextStyle(color: ColorName.labelSecondary),
    ),
  );
}
