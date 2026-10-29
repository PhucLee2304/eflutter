import 'package:eflutter/data/models/attempt_page.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/attempt/attempt_header.dart';
import 'package:eflutter/presentation/exams/attempt/question_palette.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Một trang của attempt strict: trái là đề chung (instruction, ảnh, đoạn văn), phải là
/// câu hỏi + đáp án. Dưới [attemptWideBreakpoint] thì xếp một cột.
class AttemptPageViewTwoPane extends StatelessWidget {
  const AttemptPageViewTwoPane({
    super.key,
    required this.page,
    required this.session,
    required this.locked,
    required this.onSelect,
    this.top,
  });

  final AttemptPage page;
  final AttemptSessionState session;

  /// Trang không chọn được đáp án (đã khóa, hoặc đang nộp).
  final bool locked;
  final void Function(int questionId, int? optionId) onSelect;

  /// Widget đặt trên cùng (vd khối phát audio của phần nghe).
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final pageContext = _PageContext(page: page);
    final questions = _PageQuestions(
      page: page,
      session: session,
      locked: locked,
      onSelect: onSelect,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < attemptWideBreakpoint) {
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                ?top,
                pageContext,
                const SizedBox(height: 16),
                questions,
              ],
            ),
          );
        }
        return SelectionArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [?top, pageContext],
                ),
              ),
              const VerticalDivider(width: 1, color: ColorName.gray5),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [questions],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PageContext extends StatelessWidget {
  const _PageContext({required this.page});
  final AttemptPage page;

  @override
  Widget build(BuildContext context) {
    final group = page.group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group != null && group.instruction.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(group.instruction),
          ),
        // TOEIC Part 6/7 có thể nhiều ảnh, hiển thị theo thứ tự.
        for (final imageUrl in group?.imageUrls ?? const <String>[])
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('Image unavailable'),
              ),
            ),
          ),
      ],
    );
  }
}

class _PageQuestions extends StatelessWidget {
  const _PageQuestions({
    required this.page,
    required this.session,
    required this.locked,
    required this.onSelect,
  });

  final AttemptPage page;
  final AttemptSessionState session;
  final bool locked;
  final void Function(int, int?) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final question in page.questions)
          _PageQuestionCard(
            question: question,
            selected: session.selectedOptions[question.id],
            sync: session.syncStatuses[question.id],
            locked: locked || session.isLocked,
            onSelect: onSelect,
          ),
      ],
    );
  }
}

class _PageQuestionCard extends StatelessWidget {
  const _PageQuestionCard({
    required this.question,
    required this.selected,
    required this.sync,
    required this.locked,
    required this.onSelect,
  });

  final AttemptPageQuestion question;
  final int? selected;
  final AnswerSyncStatus? sync;
  final bool locked;
  final void Function(int, int?) onSelect;

  @override
  Widget build(BuildContext context) {
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
                  // Part 1/2 không có nội dung câu khi đang làm (như đề thật).
                  '${question.number}. ${question.content.isEmpty ? 'Choose the correct answer.' : question.content}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (question.excludedFromScore) const NotScoredBadge(),
              if (sync != null) AttemptSyncIcon(status: sync!),
            ],
          ),
          const SizedBox(height: 10),
          RadioGroup<int>(
            groupValue: selected,
            onChanged: locked
                ? (_) {}
                : (value) => onSelect(question.id, value),
            child: Column(
              children: question.options.map((option) {
                final isSelected = selected == option.id;
                return RadioListTile<int>(
                  value: option.id,
                  enabled: !locked,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '${option.key}${option.content?.trim().isNotEmpty == true ? '. ${option.content}' : ''}',
                  ),
                  secondary: isSelected && !locked
                      ? IconButton(
                          tooltip: 'Clear answer',
                          onPressed: () => onSelect(question.id, null),
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
