import 'package:eflutter/data/models/attempt_page.dart';
import 'package:eflutter/data/models/exam_questions.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_navigator_cubit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Màn rộng hơn mức này: hai cột trang, bảng câu hỏi trượt từ phải như drawer.
const attemptWideBreakpoint = 900.0;

class PaletteItem {
  const PaletteItem({
    required this.questionId,
    required this.number,
    required this.status,
    this.enabled = true,
  });
  final int questionId;
  final int number;
  final PaletteStatus status;

  /// Câu đã khóa (trang nghe đã qua / chưa tới): giữ màu, chỉ không bấm được.
  final bool enabled;
}

class PaletteGroup {
  const PaletteGroup({required this.title, required this.items});
  final String title;
  final List<PaletteItem> items;
}

/// Nhóm theo Part từ navigator (flow TOEIC_STRICT).
List<PaletteGroup> paletteGroupsFromNavigator(AttemptNavigatorState state) {
  final groups = <String, List<PaletteItem>>{};
  for (final page in state.navigator?.pages ?? const <AttemptNavigatorPage>[]) {
    final title = partLabel(page.part) ?? _sectionLabel(page.section);
    final items = groups.putIfAbsent(title, () => []);
    for (final question in page.questions) {
      items.add(
        PaletteItem(
          questionId: question.id,
          number: question.number,
          status: state.statusOf(page.index, question),
          enabled: state.isPageOpen(page.index),
        ),
      );
    }
  }
  return [for (final entry in groups.entries) PaletteGroup(title: entry.key, items: entry.value)];
}

/// Số hiển thị của từng câu (flow FREE): `number` gốc, không có thì thứ tự toàn bài.
/// Bảng câu hỏi và tiêu đề câu cùng dùng hàm này để không lệch nhau.
Map<int, int> attemptQuestionNumbers(List<ExamQuestionsSection> sections) {
  var number = 0;
  return {
    for (final section in sections)
      for (final question in orderedSectionQuestions(section))
        question.id: question.number ?? ++number,
  };
}

/// Nhóm theo section từ danh sách câu (flow FREE).
List<PaletteGroup> paletteGroupsFromSections(
  List<ExamQuestionsSection> sections,
  Map<int, int?> selectedOptions,
) {
  final numbers = attemptQuestionNumbers(sections);
  return [
    for (final section in sections)
      PaletteGroup(
        title: section.title.isEmpty ? section.code : section.title,
        items: [
          for (final question in orderedSectionQuestions(section))
            PaletteItem(
              questionId: question.id,
              number: numbers[question.id]!,
              status: selectedOptions[question.id] != null
                  ? PaletteStatus.answered
                  : PaletteStatus.empty,
            ),
        ],
      ),
  ];
}

/// Bảng câu hỏi màn lịch sử (Q9): đúng = xanh lá, sai = đỏ, bỏ trống = xám; nhóm theo
/// Part nếu có, không thì theo section. Số câu: `number` gốc, không có thì thứ tự toàn bài.
List<PaletteGroup> paletteGroupsForReview(
  List<ExamQuestionsSection> sections, {
  required bool submitted,
}) {
  final groups = <String, List<PaletteItem>>{};
  final numbers = reviewQuestionNumbers(sections);
  for (final section in sections) {
    for (final question in orderedSectionQuestions(section)) {
      final title =
          partLabel(question.part) ?? (section.title.isEmpty ? section.code : section.title);
      groups
          .putIfAbsent(title, () => [])
          .add(
            PaletteItem(
              questionId: question.id,
              number: numbers[question.id]!,
              status: question.excludedFromScore
                  ? PaletteStatus.notScored
                  : question.selectedOptionId == null
                  ? PaletteStatus.empty
                  : !submitted || question.isCorrect == null
                  ? PaletteStatus.answered
                  : question.isCorrect!
                  ? PaletteStatus.correct
                  : PaletteStatus.wrong,
            ),
          );
    }
  }
  return [for (final entry in groups.entries) PaletteGroup(title: entry.key, items: entry.value)];
}

/// Câu của section theo thứ tự hiển thị: các group trước, câu lẻ sau.
List<ExamQuestion> orderedSectionQuestions(ExamQuestionsSection section) => [
  ...section.groups.expand((group) => group.questions),
  ...section.questions,
];

Map<int, int> reviewQuestionNumbers(List<ExamQuestionsSection> sections) {
  var position = 0;
  return {
    for (final section in sections)
      for (final question in orderedSectionQuestions(section))
        question.id: question.number ?? ++position,
  };
}

String? partLabel(String? part) {
  if (part == null || part.isEmpty) return null;
  final match = RegExp(r'(\d+)$').firstMatch(part);
  return match == null ? part : 'Part ${match.group(1)}';
}

String _sectionLabel(String section) => switch (section) {
  'LISTENING' => 'Listening',
  'READING' => 'Reading',
  _ => section,
};

/// Bảng số câu. [onTap] null thì chỉ để xem (vd đang nghe).
class QuestionPalette extends StatelessWidget {
  const QuestionPalette({super.key, required this.groups, this.onTap, this.review = false});

  final List<PaletteGroup> groups;
  final ValueChanged<int>? onTap;

  /// Màn lịch sử: chú thích đúng/sai thay cho đã làm/khóa.
  final bool review;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final group in groups) ...[
          if (group.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in group.items)
                _PaletteCell(
                  item: item,
                  onTap: onTap == null || !item.enabled ? null : () => onTap!(item.questionId),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _PaletteLegend(review: review),
      ],
    );
  }
}

class _PaletteCell extends StatelessWidget {
  const _PaletteCell({required this.item, required this.onTap});
  final PaletteItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = _colors(item.status);
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: border, width: 2),
      ),
      child: InkWell(
        key: ValueKey('palette-${item.questionId}'),
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 34,
          child: Center(
            child: Text(
              '${item.number}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

(Color, Color, Color) _colors(PaletteStatus status) => switch (status) {
  PaletteStatus.answered => (ColorName.primary, ColorName.white, ColorName.primary),
  PaletteStatus.empty => (ColorName.white, ColorName.labelPrimary, ColorName.gray4),
  PaletteStatus.correct => (ColorName.green, ColorName.white, ColorName.green),
  PaletteStatus.wrong => (ColorName.red, ColorName.white, ColorName.red),
  PaletteStatus.notScored => (ColorName.purple, ColorName.white, ColorName.purple),
};

/// Nhãn tím "Not scored" cạnh câu không tính điểm, cùng màu với ô trong bảng câu hỏi.
class NotScoredBadge extends StatelessWidget {
  const NotScoredBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(10)),
    child: const Text(
      'Not scored',
      style: TextStyle(color: Color(0xFF475467), fontSize: 11, fontWeight: FontWeight.w500),
    ),
  );
}

class _PaletteLegend extends StatelessWidget {
  const _PaletteLegend({required this.review});
  final bool review;

  @override
  Widget build(BuildContext context) {
    Widget entry(PaletteStatus status, String label) {
      final (background, _, border) = _colors(status);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: border, width: 2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: ColorName.labelSecondary)),
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: review
          ? [
              entry(PaletteStatus.correct, 'Correct'),
              entry(PaletteStatus.wrong, 'Wrong'),
              entry(PaletteStatus.empty, 'Blank'),
              entry(PaletteStatus.notScored, 'Not scored'),
            ]
          : [entry(PaletteStatus.answered, 'Answered'), entry(PaletteStatus.empty, 'Not answered')],
    );
  }
}

/// Mở bảng câu hỏi: drawer bên phải trên màn rộng, bottom sheet trên mobile.
/// [builder] được gọi lại khi state đổi (bọc BlocBuilder ở phía gọi); chọn một câu
/// thì đóng bảng rồi gọi [onSelect].
Future<void> showQuestionPalette(
  BuildContext context, {
  required Widget Function(BuildContext, ValueChanged<int>? onTap) builder,
  ValueChanged<int>? onSelect,
}) {
  Widget content(BuildContext sheetContext) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    child: builder(
      sheetContext,
      onSelect == null
          ? null
          : (questionId) {
              sheetContext.pop();
              onSelect(questionId);
            },
    ),
  );

  Widget titleBar(BuildContext sheetContext) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
    child: Row(
      children: [
        const Expanded(
          child: Text('Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => sheetContext.pop(),
          icon: const Icon(SolarIconsOutline.closeCircle),
        ),
      ],
    ),
  );

  if (MediaQuery.sizeOf(context).width >= attemptWideBreakpoint) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Questions',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (sheetContext, _, _) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: ColorName.white,
          child: SizedBox(
            width: 380,
            height: double.infinity,
            child: SafeArea(
              child: Column(
                children: [
                  titleBar(sheetContext),
                  Expanded(child: content(sheetContext)),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColorName.white,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          titleBar(sheetContext),
          Flexible(child: content(sheetContext)),
        ],
      ),
    ),
  );
}
