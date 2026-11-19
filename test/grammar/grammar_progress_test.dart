import 'package:eflutter/data/models/grammar/grammar_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unit progress reflects correct answers, including partial scores', () {
    final unit = UnitSummary.fromJson({
      'id': 4,
      'unit': 2,
      'title': 'Articles',
      'completed': true,
      'total': 1,
      'correctAnswers': 2,
      'totalQuestions': 5,
    });
    expect(unit.progressCompleted, 2);
    expect(unit.progressTotal, 5);
    expect(unit.progressPercent, 0.4);

    final oldUnit = UnitSummary.fromJson({
      'id': 5,
      'title': 'Pronouns',
      'completed': true,
    });
    expect(oldUnit.progressPercent, 0);
  });
}
