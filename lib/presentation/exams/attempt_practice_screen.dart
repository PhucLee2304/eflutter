import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/data_sources/attempt_socket_client.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_questions.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:eflutter/presentation/exams/widgets/exam_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();
    _cubit = AttemptSessionCubit(
      ExamRepository(getIt<RemoteDataBase>()),
      AttemptSocketClient(getIt<LocalDataBase>()),
    )..load(widget.attemptId, initialAttempt: widget.initialAttempt);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _confirmSubmit() async {
    final accepted = await _confirm(
      title: 'Submit attempt?',
      message: 'Your current answers will be graded and cannot be changed.',
      action: 'Submit',
    );
    if (accepted) await _cubit.submit();
  }

  Future<void> _confirmCancel() async {
    final accepted = await _confirm(
      title: 'Cancel attempt?',
      message: 'The attempt will be saved as cancelled without a score.',
      action: 'Cancel attempt',
      destructive: true,
    );
    if (accepted) await _cubit.cancel();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Back'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: ColorName.red)
                  : null,
              onPressed: () => context.pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AttemptSessionCubit, AttemptSessionState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state.failure != null) context.handleFailure(state.failure);
        if (state.socketMessage != null) {
          context.showToast(state.socketMessage!, type: ToastType.error);
        }
        final completed = state.completedAttempt;
        if (completed != null) {
          context.go(attemptHistoryDetailPath(completed.id), extra: completed);
        }
      },
      builder: (context, state) {
        final attempt = state.attempt;
        return Scaffold(
          body: SafeArea(
            child: state.isLoading && attempt == null
                ? const Center(child: CircularProgressIndicator())
                : attempt == null
                ? _MissingAttempt(onBack: context.pop)
                : _AttemptBody(
                    attempt: attempt,
                    state: state,
                    onSelect: _cubit.selectAnswer,
                    onSubmit: _confirmSubmit,
                    onCancel: _confirmCancel,
                  ),
          ),
        );
      },
    );
  }
}

class _AttemptBody extends StatelessWidget {
  const _AttemptBody({
    required this.attempt,
    required this.state,
    required this.onSelect,
    required this.onSubmit,
    required this.onCancel,
  });

  final ExamAttempt attempt;
  final AttemptSessionState state;
  final void Function(int, int?) onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final title = attempt.exam?.title.trim().isNotEmpty == true
        ? attempt.exam!.title
        : 'Attempt #${attempt.id}';
    return Column(
      children: [
        _SessionHeader(
          title: title,
          state: state,
          totalQuestions: attempt.totalQuestions,
          onSubmit: onSubmit,
          onCancel: onCancel,
        ),
        Expanded(
          child: SelectionArea(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: attempt.questions.length,
              itemBuilder: (context, index) => _SectionBlock(
                section: attempt.questions[index],
                state: state,
                onSelect: onSelect,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.title,
    required this.state,
    required this.totalQuestions,
    required this.onSubmit,
    required this.onCancel,
  });

  final String title;
  final AttemptSessionState state;
  final int totalQuestions;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final busy = state.isSubmitting || state.isCancelling;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: ColorName.white,
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
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${state.answeredCount}/$totalQuestions answered  |  ${_socketLabel(state.socketStatus)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ColorName.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TimerBadge(remaining: state.remaining),
              const Spacer(),
              IconButton.outlined(
                tooltip: 'Cancel attempt',
                onPressed: busy ? null : onCancel,
                icon: state.isCancelling
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(SolarIconsOutline.closeCircle),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: busy ? null : onSubmit,
                icon: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(SolarIconsOutline.checkCircle),
                label: const Text('Submit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.state,
    required this.onSelect,
  });
  final ExamQuestionsSection section;
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
            (group) =>
                _GroupBlock(group: group, state: state, onSelect: onSelect),
          ),
          ...section.questions.map(
            (question) => _QuestionCard(
              question: question,
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
    required this.group,
    required this.state,
    required this.onSelect,
  });
  final ExamQuestionGroup group;
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
            question: question,
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
    required this.question,
    required this.state,
    required this.onSelect,
  });
  final ExamQuestion question;
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
                  '${question.order}. ${question.content.isEmpty ? 'Choose the correct answer.' : question.content}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (sync != null) _SyncIcon(status: sync),
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

class _SyncIcon extends StatelessWidget {
  const _SyncIcon({required this.status});
  final AnswerSyncStatus status;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: switch (status) {
      AnswerSyncStatus.pending => 'Saving',
      AnswerSyncStatus.synced => 'Saved',
      AnswerSyncStatus.failed => 'Will retry',
    },
    child: Icon(
      switch (status) {
        AnswerSyncStatus.pending => SolarIconsOutline.clockCircle,
        AnswerSyncStatus.synced => SolarIconsOutline.checkCircle,
        AnswerSyncStatus.failed => SolarIconsOutline.refreshCircle,
      },
      size: 20,
      color: status == AnswerSyncStatus.failed
          ? ColorName.orange
          : ColorName.labelSecondary,
    ),
  );
}

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.remaining});
  final Duration? remaining;
  @override
  Widget build(BuildContext context) {
    final value = remaining == null
        ? 'No limit'
        : '${remaining!.inHours.toString().padLeft(2, '0')}:${(remaining!.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining!.inSeconds % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColorName.gray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _MissingAttempt extends StatelessWidget {
  const _MissingAttempt({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Attempt not found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(SolarIconsOutline.altArrowLeft),
          label: const Text('Back'),
        ),
      ],
    ),
  );
}

String _socketLabel(AttemptSocketStatus status) => switch (status) {
  AttemptSocketStatus.connected => 'Saved online',
  AttemptSocketStatus.connecting => 'Connecting',
  AttemptSocketStatus.disconnected => 'Offline, answers kept locally',
};
