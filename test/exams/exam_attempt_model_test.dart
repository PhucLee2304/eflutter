import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses submitted review fields and nullable option content', () {
    final attempt = ExamAttempt.fromJson({
      'id': 7,
      'examId': 3,
      'mode': 'TEST',
      'status': 'SUBMITTED',
      'startedAt': '2026-09-09T01:00:00Z',
      'totalQuestions': 1,
      'answeredCount': 1,
      'correctAnswers': 1,
      'score': 10,
      'sections': [
        {
          'id': 1,
          'code': 'LISTENING',
          'title': 'Listening',
          'order': 1,
          'groups': [],
          'questions': [
            {
              'id': 11,
              'content': '',
              'order': 1,
              'selectedOptionId': 101,
              'correctOptionId': 101,
              'isCorrect': true,
              'options': [
                {'id': 101, 'key': 'A', 'content': null, 'order': 1},
              ],
            },
          ],
        },
      ],
    });

    final question = attempt.questions.single.questions.single;
    expect(question.correctOptionId, 101);
    expect(question.isCorrect, isTrue);
    expect(question.options.single.content, isNull);
  });

  test('submit answer includes null selection for cleared answers', () {
    const answer = SubmitAttemptAnswer(questionId: 12, selectedOptionId: null);

    expect(answer.toJson(), {'questionId': 12, 'selectedOptionId': null});
  });
}
