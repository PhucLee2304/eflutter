import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/attempt_lock/attempt_integrity_reporter.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_questions.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/attempt/attempt_header.dart';
import 'package:eflutter/presentation/exams/attempt/attempt_session_scope.dart';
import 'package:eflutter/presentation/exams/attempt/question_palette.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:eflutter/presentation/exams/widgets/exam_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AttemptPracticeScreen extends StatefulWidget {
  const AttemptPracticeScreen({super.key, required this.attemptId, this.initialAttempt});

  final int attemptId;
  final ExamAttempt? initialAttempt;

  @override
  State<AttemptPracticeScreen> createState() => _AttemptPracticeScreenState();
}

class _AttemptPracticeScreenState extends State<AttemptPracticeScreen> {
  late final AttemptSessionCubit _cubit;

  /// Key theo câu để bấm số trên bảng câu hỏi thì cuộn tới câu đó (Q7).
  final _questionKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _cubit = AttemptSessionCubit(
      ExamRepository(getIt<RemoteDataBase>()),
      AttemptSocketClient(getIt<LocalDataBase>()),
      reporter: getIt<AttemptIntegrityReporter>(),
    )..load(widget.attemptId, initialAttempt: widget.initialAttempt);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  GlobalKey _keyFor(int questionId) => _questionKeys.putIfAbsent(questionId, GlobalKey.new);

  void _scrollTo(int questionId) {
    final target = _questionKeys[questionId]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), alignment: 0.1);
  }

  void _openPalette(ExamAttempt attempt) {
    showQuestionPalette(
      context,
      onSelect: _scrollTo,
      builder: (context, onTap) => BlocBuilder<AttemptSessionCubit, AttemptSessionState>(
        bloc: _cubit,
        builder: (context, state) => QuestionPalette(
          groups: paletteGroupsFromSections(attempt.questions, state.selectedOptions),
          onTap: onTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AttemptSessionScope(
      cubit: _cubit,
      child: BlocBuilder<AttemptSessionCubit, AttemptSessionState>(
        bloc: _cubit,
        builder: (context, state) {
          final attempt = state.attempt;
          return Scaffold(
            body: SafeArea(
              child: state.isLoading && attempt == null
                  ? const AppLoader()
                  : attempt == null
                  ? const MissingAttempt()
                  : _AttemptBody(
                      attempt: attempt,
                      state: state,
                      keyFor: _keyFor,
                      onSelect: _cubit.selectAnswer,
                      onOpenPalette: () => _openPalette(attempt),
                      onJump: _scrollTo,
                      onSubmit: () => confirmSubmitAttempt(context, _cubit),
                      onCancel: attempt.isAssignment
                          ? null
                          : () => confirmCancelAttempt(context, _cubit),
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// Màn làm bài dạng cuộn (Figma 30:676): thẻ đầu bài, các câu hỏi, cột tiến độ bên phải
/// trên màn rộng; màn hẹp dùng bảng câu hỏi dạng popup như cũ.
class _AttemptBody extends StatelessWidget {
  const _AttemptBody({
    required this.attempt,
    required this.state,
    required this.keyFor,
    required this.onSelect,
    required this.onOpenPalette,
    required this.onSubmit,
    required this.onCancel,
    required this.onJump,
  });

  final ExamAttempt attempt;
  final AttemptSessionState state;
  final GlobalKey Function(int questionId) keyFor;
  final void Function(int, int?) onSelect;
  final VoidCallback onOpenPalette;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;
  final ValueChanged<int> onJump;

  static const _sideBreakpoint = 960.0;

  @override
  Widget build(BuildContext context) {
    final title = attempt.exam?.title.trim().isNotEmpty == true
        ? attempt.exam!.title
        : 'Attempt #${attempt.id}';
    final numbers = attemptQuestionNumbers(attempt.questions);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _sideBreakpoint;
        final questions = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IntroCard(attempt: attempt, title: title),
            for (final section in attempt.questions)
              _SectionBlock(
                section: section,
                showTitle: attempt.questions.length > 1,
                numbers: numbers,
                state: state,
                keyFor: keyFor,
                onSelect: onSelect,
              ),
          ],
        );
        return Column(
          children: [
            AttemptHeader(
              // Màn rộng đã có thẻ đầu bài và cột tiến độ nên bỏ khối bên trái; màn hẹp giữ tiến độ.
              title: wide ? null : (attempt.isAssignment ? 'Assignment' : 'Practice'),
              state: state,
              answeredCount: state.answeredCount,
              totalQuestions: attempt.totalQuestions,
              onOpenPalette: wide ? null : onOpenPalette,
              showSubmit: !wide,
              onSubmit: onSubmit,
              onCancel: onCancel,
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF7F9FB),
                // Dựng hết câu (không lazy) để ensureVisible tới được câu ngoài màn hình.
                child: SelectionArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: wide ? 1144 : 820),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 24,
                                children: [
                                  Expanded(child: questions),
                                  SizedBox(
                                    width: 300,
                                    child: _ProgressPanel(
                                      attempt: attempt,
                                      state: state,
                                      numbers: numbers,
                                      onJump: onJump,
                                      onSubmit: onSubmit,
                                    ),
                                  ),
                                ],
                              )
                            : questions,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

const _border = Color(0xFFE5E6EB);
const _muted = Color(0xFF646A73);
const _faint = Color(0xFF8F959E);

BoxDecoration _cardDecoration() => BoxDecoration(
  color: ColorName.white,
  border: Border.all(color: _border),
  borderRadius: BorderRadius.circular(12),
);

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.attempt, required this.title});
  final ExamAttempt attempt;
  final String title;

  @override
  Widget build(BuildContext context) {
    final description = attempt.exam?.description.trim() ?? '';
    final meta = [
      attempt.isAssignment ? 'Assignment' : 'Practice',
      '${attempt.totalQuestions} question${attempt.totalQuestions == 1 ? '' : 's'}',
      if (attempt.duration case final minutes? when minutes > 0) 'Time limit ${_minutes(minutes)}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: ColorName.primary, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            if (description.isNotEmpty)
              Text(description, style: const TextStyle(fontSize: 14, color: _muted, height: 1.4)),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                meta.join('   ·   '),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _faint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _minutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  return minutes % 60 == 0 ? '${minutes ~/ 60}h' : '${minutes ~/ 60}h ${minutes % 60}m';
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.attempt,
    required this.state,
    required this.numbers,
    required this.onJump,
    required this.onSubmit,
  });
  final ExamAttempt attempt;
  final AttemptSessionState state;
  final Map<int, int> numbers;
  final ValueChanged<int> onJump;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final total = attempt.totalQuestions;
    final answered = state.answeredCount;
    final ordered = numbers.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final integrity = state.integrity;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          const Text('Progress', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : answered / total,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEEF0F3),
                    color: ColorName.primary,
                  ),
                ),
              ),
              Text(
                '$answered / $total',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _muted),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(key: id, value: number) in ordered)
                _NumberCell(
                  number: number,
                  answered: state.selectedOptions[id] != null,
                  onTap: () => onJump(id),
                ),
            ],
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              _LegendItem(fill: ColorName.primary, label: 'Answered'),
              _LegendItem(fill: ColorName.white, border: _border, label: 'Not answered'),
            ],
          ),
          if (integrity != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Leaving this tab or exiting full screen counts as a warning. '
                '${integrity.maxViolations} warnings submit the attempt automatically.',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB26A00), height: 1.4),
              ),
            ),
          FilledButton(
            onPressed: state.isSubmitting || state.isCancelling ? null : onSubmit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Submit attempt'),
          ),
        ],
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({required this.number, required this.answered, required this.onTap});
  final int number;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 36,
    child: Material(
      color: answered ? ColorName.primary : ColorName.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: answered ? BorderSide.none : const BorderSide(color: _border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: answered ? ColorName.white : _muted,
            ),
          ),
        ),
      ),
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.fill, required this.label, this.border});
  final Color fill;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(3),
          border: border == null ? null : Border.all(color: border!),
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
    ],
  );
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.showTitle,
    required this.numbers,
    required this.section,
    required this.state,
    required this.keyFor,
    required this.onSelect,
  });
  final bool showTitle;
  final ExamQuestionsSection section;
  final Map<int, int> numbers;
  final GlobalKey Function(int questionId) keyFor;
  final AttemptSessionState state;
  final void Function(int, int?) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            Text(
              section.title.isEmpty ? section.code : section.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
          ],
          ...section.groups.map(
            (group) => _GroupBlock(
              group: group,
              numbers: numbers,
              state: state,
              keyFor: keyFor,
              onSelect: onSelect,
            ),
          ),
          ...section.questions.map(
            (question) => _QuestionCard(
              key: keyFor(question.id),
              question: question,
              number: numbers[question.id] ?? question.order,
              state: state,
              onSelect: onSelect,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.numbers,
    required this.group,
    required this.state,
    required this.keyFor,
    required this.onSelect,
  });
  final ExamQuestionGroup group;
  final Map<int, int> numbers;
  final GlobalKey Function(int questionId) keyFor;
  final AttemptSessionState state;
  final void Function(int, int?) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (group.title.isNotEmpty || group.instruction.isNotEmpty || group.imageUrls.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ColorName.gray6,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (group.title.isNotEmpty)
                  Text(group.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (group.instruction.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(group.instruction)),
                for (final imageUrl in group.imageUrls)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
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
                    padding: const EdgeInsets.only(top: 10),
                    child: ExamAudioPlayer(url: group.audioUrl!),
                  ),
              ],
            ),
          ),
        ...group.questions.map(
          (question) => _QuestionCard(
            key: keyFor(question.id),
            question: question,
            number: numbers[question.id] ?? question.order,
            state: state,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.number,
    required this.state,
    required this.onSelect,
  });
  final ExamQuestion question;
  final int number;
  final AttemptSessionState state;
  final void Function(int, int?) onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedOptions[question.id];
    return Container(
      key: ValueKey('question-${question.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question $number',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _faint),
                ),
              ),
              if (question.excludedFromScore) const NotScoredBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.content.isEmpty ? 'Choose the correct answer.' : question.content,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
          ),
          const SizedBox(height: 14),
          for (final option in question.options)
            _OptionRow(
              option: option,
              selected: selected == option.id,
              locked: state.isLocked,
              // Bấm lại đáp án đang chọn để bỏ chọn.
              onTap: () => onSelect(question.id, selected == option.id ? null : option.id),
            ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final ExamQuestionOption option;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = option.content?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? const Color(0xFFEEF7FD) : ColorName.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected ? ColorName.primary : _border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: locked ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? ColorName.primary : ColorName.white,
                      border: selected ? null : Border.all(color: _border),
                    ),
                    child: Text(
                      option.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? ColorName.white : _muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      content.isEmpty ? option.key : content,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
