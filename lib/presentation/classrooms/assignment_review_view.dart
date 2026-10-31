import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_questions.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/classrooms/gradebook_widgets.dart';
import 'package:eflutter/presentation/exams/attempt/question_palette.dart';
import 'package:eflutter/presentation/exams/widgets/exam_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Màn xem lại bài làm của học sinh trong tab Classwork (Figma 30:795).
class AssignmentReviewView extends StatefulWidget {
  const AssignmentReviewView({
    super.key,
    required this.attemptId,
    required this.onBack,
    this.title,
  });

  final int attemptId;
  final VoidCallback onBack;

  /// Tên bài giao (nếu đã có trong danh sách); null thì dùng tên đề.
  final String? title;

  @override
  State<AssignmentReviewView> createState() => _AssignmentReviewViewState();
}

class _AssignmentReviewViewState extends State<AssignmentReviewView> {
  static const _sideWidthBreakpoint = 820.0;

  ExamAttempt? attempt;
  bool loading = true;
  String? error;

  /// Key theo câu để bấm số trên bảng câu hỏi thì cuộn tới câu đó.
  final _questionKeys = <int, GlobalKey>{};

  GlobalKey _keyFor(int questionId) => _questionKeys.putIfAbsent(questionId, GlobalKey.new);

  void _scrollTo(int questionId) {
    final target = _questionKeys[questionId]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), alignment: 0.1);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await ExamRepository(
      getIt<RemoteDataBase>(),
    ).getAttemptHistory(widget.attemptId);
    if (!mounted) return;
    setState(() {
      loading = false;
      switch (result) {
        case Success(data: final data):
          attempt = data;
        case Failure(message: final message):
          error = message ?? 'Could not load this attempt';
        case Cancelled():
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final attempt = this.attempt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GbHeader(onBack: widget.onBack),
        const SizedBox(height: 12),
        if (loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: AppLoader())
        else if (attempt == null)
          GbError(message: error ?? 'Attempt not found', onRetry: load)
        else
          ..._content(attempt),
      ],
    );
  }

  List<Widget> _content(ExamAttempt attempt) {
    final submitted = attempt.status == 'SUBMITTED';
    final questions = [
      for (final section in attempt.questions) ...orderedSectionQuestions(section),
    ];
    final scored = questions.where((question) => !question.excludedFromScore);
    final correct =
        attempt.correctAnswers ?? scored.where((question) => question.isCorrect == true).length;
    final wrong = scored.length - correct;
    final numbers = reviewQuestionNumbers(attempt.questions);
    final maxScore = attempt.exam?.type.toUpperCase() == 'TOEIC' ? 990 : 10;
    final sections = attempt.questions;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections)
          _ReviewSection(
            section: section,
            showTitle: sections.length > 1,
            submitted: submitted,
            numbers: numbers,
            keyFor: _keyFor,
          ),
      ],
    );
    final palette = _PaletteCard(
      groups: _withoutSingleTitle(paletteGroupsForReview(sections, submitted: submitted)),
      onTap: _scrollTo,
    );
    return [
      _Head(attempt: attempt, title: widget.title ?? attempt.exam?.title ?? 'Assignment'),
      const SizedBox(height: 16),
      GbStats(
        children: [
          _Stat(
            label: 'Score',
            value: attempt.score?.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '') ?? '—',
            sub: '/ $maxScore',
          ),
          _Stat(label: 'Correct', value: '$correct', color: Gb.green),
          _Stat(label: 'Wrong', value: '$wrong', color: Gb.red),
          _Stat(
            label: 'Time',
            value: _took(attempt) ?? '—',
            sub: attempt.duration == null ? null : '/ ${attempt.duration}m',
          ),
        ],
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _sideWidthBreakpoint) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [palette, const SizedBox(height: 12), body],
            );
          }
          // Cột bên rộng bằng một ô số liệu để cột câu hỏi thẳng mép với ô Wrong.
          final side = (constraints.maxWidth - 36) / 4;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(child: SelectionArea(child: body)),
              SizedBox(width: side, child: palette),
            ],
          );
        },
      ),
    ];
  }

  /// Chỉ một nhóm thì bỏ tên nhóm, thẻ đã có tiêu đề "Questions".
  static List<PaletteGroup> _withoutSingleTitle(List<PaletteGroup> groups) =>
      groups.length == 1 ? [PaletteGroup(title: '', items: groups.single.items)] : groups;

  static String? _took(ExamAttempt attempt) {
    final start = attempt.startedAt, end = attempt.submittedAt;
    if (start == null || end == null) return null;
    final took = end.difference(start);
    final minutes = took.inMinutes, seconds = took.inSeconds % 60;
    return minutes == 0 ? '${seconds}s' : '${minutes}m ${seconds}s';
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.attempt, required this.title});
  final ExamAttempt attempt;
  final String title;

  @override
  Widget build(BuildContext context) {
    final submittedAt = attempt.submittedAt;
    final violations = attempt.violationCount ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Gb.text),
              ),
              if (submittedAt != null)
                Text(
                  'Submitted ${DateFormat('MMM d, HH:mm').format(submittedAt.toLocal())}',
                  style: const TextStyle(fontSize: 13, color: Gb.muted),
                ),
            ],
          ),
        ),
        if (attempt.isTerminated)
          const GbPill('Suspended', background: Gb.redBg, foreground: Gb.red)
        else
          GbPill.status(attempt.status == 'SUBMITTED' ? 'SUBMITTED' : attempt.status),
        // Chỉ bài có giám sát mới hiện số cảnh báo.
        if (attempt.proctored)
          GbPill(
            'Proctored · $violations ${violations == 1 ? 'warning' : 'warnings'}',
            background: violations > 0 ? Gb.orangeBg : Gb.field,
            foreground: violations > 0 ? Gb.orange : Gb.muted,
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.sub, this.color});
  final String label;
  final String value;
  final String? sub;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Gb.border),
    ),
    child: Column(
      spacing: 4,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Gb.muted),
        ),
        Text.rich(
          TextSpan(
            text: value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color ?? Gb.text),
            children: [
              if (sub != null)
                TextSpan(
                  text: ' $sub',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Gb.faint,
                  ),
                ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({required this.groups, required this.onTap});
  final List<PaletteGroup> groups;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => GbCard(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Questions',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Gb.text),
      ),
      const SizedBox(height: 12),
      QuestionPalette(groups: groups, onTap: onTap, review: true),
    ],
  );
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.section,
    required this.showTitle,
    required this.submitted,
    required this.numbers,
    required this.keyFor,
  });
  final ExamQuestionsSection section;
  final bool showTitle;
  final bool submitted;
  final Map<int, int> numbers;
  final GlobalKey Function(int questionId) keyFor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showTitle)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            section.title.isEmpty ? section.code : section.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Gb.text),
          ),
        ),
      for (final group in section.groups) ...[
        if (group.instruction.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(group.instruction, style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
        for (final imageUrl in group.imageUrls)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Image.network(
                imageUrl,
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
        for (final question in group.questions)
          _QuestionCard(
            key: keyFor(question.id),
            question: question,
            number: numbers[question.id] ?? question.order,
            submitted: submitted,
          ),
        if (group.transcript.isNotEmpty) _Explanation('TRANSCRIPT', group.transcript),
        if (group.explanation.isNotEmpty) _Explanation('GROUP EXPLANATION', group.explanation),
      ],
      // Câu lẻ (không thuộc nhóm) nằm sau các nhóm, như bảng câu hỏi.
      for (final question in section.questions)
        _QuestionCard(
          key: keyFor(question.id),
          question: question,
          number: numbers[question.id] ?? question.order,
          submitted: submitted,
        ),
    ],
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.number,
    required this.submitted,
  });
  final ExamQuestion question;
  final int number;
  final bool submitted;

  @override
  Widget build(BuildContext context) {
    final isCorrect = question.isCorrect;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Gb.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  'Question $number',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Gb.muted,
                  ),
                ),
              ),
              if (question.excludedFromScore) const NotScoredBadge(),
              if (submitted && isCorrect != null)
                isCorrect
                    ? const GbPill('Correct', background: Gb.greenBg, foreground: Gb.green)
                    : question.selectedOptionId == null
                    ? const GbPill('Not answered', background: Gb.field, foreground: Gb.muted)
                    : const GbPill('Wrong', background: Gb.redBg, foreground: Gb.red),
            ],
          ),
          Text(
            question.content.isEmpty ? 'Choose the correct answer.' : question.content,
            style: const TextStyle(fontSize: 15, color: Gb.text),
          ),
          const SizedBox(height: 2),
          for (final option in question.options)
            _OptionRow(
              option: option,
              selected: option.id == question.selectedOptionId,
              correct: submitted && option.id == question.correctOptionId,
            ),
          if (question.explanation.isNotEmpty) _Explanation('EXPLANATION', question.explanation),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.selected, required this.correct});
  final ExamQuestionOption option;
  final bool selected;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final color = correct
        ? Gb.green
        : selected
        ? Gb.red
        : null;
    final filled = selected;
    final note = selected
        ? 'Your answer'
        : correct
        ? 'Correct answer'
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? (correct ? Gb.greenBg : Gb.redBg) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color ?? Gb.border),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? color : Colors.white,
              border: Border.all(color: color ?? Gb.border),
            ),
            child: Text(
              option.key,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : (color ?? Gb.muted),
              ),
            ),
          ),
          Expanded(
            child: Text(
              option.content?.trim() ?? '',
              style: const TextStyle(fontSize: 14, color: Gb.text),
            ),
          ),
          if (note != null)
            Text(
              note,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
            ),
        ],
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation(this.title, this.value);
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Gb.soft, borderRadius: BorderRadius.circular(8)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .4,
            color: Gb.faint,
          ),
        ),
        Text(value, style: const TextStyle(fontSize: 13, color: ColorName.labelSecondary)),
      ],
    ),
  );
}
