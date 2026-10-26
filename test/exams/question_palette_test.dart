import 'package:eflutter/data/models/exam_questions.dart';
import 'package:eflutter/presentation/exams/attempt/question_palette.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_navigator_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bấm ô mở thì gọi onTap, ô khóa thì không', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionPalette(
            groups: const [
              PaletteGroup(
                title: 'Part 1',
                items: [
                  PaletteItem(
                    questionId: 11,
                    number: 1,
                    status: PaletteStatus.locked,
                  ),
                  PaletteItem(
                    questionId: 12,
                    number: 2,
                    status: PaletteStatus.answered,
                  ),
                ],
              ),
            ],
            onTap: tapped.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('palette-11')));
    await tester.tap(find.byKey(const ValueKey('palette-12')));
    expect(tapped, [12]);
    expect(find.text('Part 1'), findsOneWidget);
  });

  test('partLabel đổi PART_5 thành Part 5', () {
    expect(partLabel('PART_5'), 'Part 5');
    expect(partLabel(null), isNull);
  });

  test('bảng lịch sử: đúng/sai/bỏ trống, số gốc, nhóm theo Part', () {
    Map<String, dynamic> q(
      int id, {
      int? number,
      int? selected,
      bool? correct,
      String part = 'PART_5',
      bool excluded = false,
    }) => {
      'id': id,
      'content': '',
      'part': part,
      'number': ?number,
      'order': id,
      'excludedFromScore': excluded,
      'selectedOptionId': ?selected,
      'isCorrect': ?correct,
      'options': [],
    };
    final sections = [
      ExamQuestionsSection.fromJson({
        'id': 1,
        'code': 'READING',
        'title': 'Reading',
        'order': 1,
        'groups': [],
        'questions': [
          q(1, number: 101, selected: 9, correct: true),
          q(2, number: 102, selected: 9, correct: false, excluded: true),
          q(3, part: 'PART_6'),
        ],
      }),
    ];

    final groups = paletteGroupsForReview(sections, submitted: true);
    expect(groups.map((g) => g.title), ['Part 5', 'Part 6']);
    final items = groups.expand((g) => g.items).toList();
    expect(items.map((i) => i.number), [101, 102, 1]);
    expect(items.map((i) => i.status), [
      PaletteStatus.correct,
      PaletteStatus.wrong,
      PaletteStatus.empty,
    ]);
    expect(items[1].excluded, isTrue);
  });
}
