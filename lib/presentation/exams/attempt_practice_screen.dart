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
import 'package:solar_icons/solar_icons.dart';

class AttemptPracticeScreen extends StatefulWidget {
  const AttemptPracticeScreen({
    super.key,
    required this.attemptId,
    this.initialAttempt,
  });

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

  GlobalKey _keyFor(int questionId) =>
      _questionKeys.putIfAbsent(questionId, GlobalKey.new);

  void _scrollTo(int questionId) {
    final target = _questionKeys[questionId]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      alignment: 0.1,
    );
  }

  void _openPalette(ExamAttempt attempt) {
    showQuestionPalette(
      context,
      onSelect: _scrollTo,
      builder: (context, onTap) =>
          BlocBuilder<AttemptSessionCubit, AttemptSessionState>(
            bloc: _cubit,
            builder: (context, state) => QuestionPalette(
              groups: paletteGroupsFromSections(
                attempt.questions,
                state.selectedOptions,
              ),
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
                  ? const Center(child: CircularProgressIndicator())
                  : attempt == null
                  ? const MissingAttempt()
                  : _AttemptBody(
                      attempt: attempt,
                      state: state,
                      keyFor: _keyFor,
                      onSelect: _cubit.selectAnswer,
                      onOpenPalette: () => _openPalette(attempt),
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

class _AttemptBody extends StatelessWidget {
  const _AttemptBody({
    required this.attempt,
    required this.state,
    required this.keyFor,
    required this.onSelect,
    required this.onOpenPalette,
    required this.onSubmit,
    required this.onCancel,
  });

  final ExamAttempt attempt;
  final AttemptSessionState state;
  final GlobalKey Function(int questionId) keyFor;
  final void Function(int, int?) onSelect;
  final VoidCallback onOpenPalette;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final title = attempt.exam?.title.trim().isNotEmpty == true
        ? attempt.exam!.title
        : 'Attempt #${attempt.id}';
    final numbers = attemptQuestionNumbers(attempt.questions);
    return Column(
      children: [
        AttemptHeader(
          title: title,
          state: state,
          answeredCount: state.answeredCount,
          totalQuestions: attempt.totalQuestions,
          onOpenPalette: onOpenPalette,
          onSubmit: onSubmit,
          onCancel: onCancel,
        ),
        Expanded(
          // Dựng hết câu (không lazy) để ensureVisible tới được câu ngoài màn hình.
          child: SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
                  for (final section in attempt.questions)
                    _SectionBlock(
                      section: section,
                      numbers: numbers,
                      state: state,
                      keyFor: keyFor,
                      onSelect: onSelect,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.numbers,
    required this.section,
    required this.state,
    required this.keyFor,
    required this.onSelect,
  });
  final ExamQuestionsSection section;
  final Map<int, int> numbers;
  final GlobalKey Function(int questionId) keyFor;
  final AttemptSessionState state;
  final void Function(int, int?) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        if (group.title.isNotEmpty ||
            group.instruction.isNotEmpty ||
            group.imageUrl != null)
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
                  Text(
                    group.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (group.instruction.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(group.instruction),
                  ),
                if (group.imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: Image.network(
                        group.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Text('Image unavailable'),
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
    final sync = state.syncStatuses[question.id];
    return Container(
      key: ValueKey('question-${question.id}'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '$number. ${question.content.isEmpty ? 'Choose the correct answer.' : question.content}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (question.excludedFromScore) const NotScoredBadge(),
              if (sync != null) AttemptSyncIcon(status: sync),
            ],
          ),
          const SizedBox(height: 10),
          RadioGroup<int>(
            groupValue: selected,
            onChanged: state.isLocked
                ? (_) {}
                : (value) => onSelect(question.id, value),
            child: Column(
              children: question.options.map((option) {
                final isSelected = selected == option.id;
                return RadioListTile<int>(
                  value: option.id,
                  enabled: !state.isLocked,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '${option.key}${option.content?.trim().isNotEmpty == true ? '. ${option.content}' : ''}',
                  ),
                  secondary: isSelected
                      ? IconButton(
                          tooltip: 'Clear answer',
                          onPressed: state.isLocked
                              ? null
                              : () => onSelect(question.id, null),
                          icon: const Icon(
                            SolarIconsOutline.closeCircle,
                            size: 20,
                          ),
                        )
                      : null,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
