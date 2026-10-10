import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_questions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create attempt request sends standalone context by default', () {
    const request = CreateExamAttemptRequest(
      mode: 'PRACTICE',
      section: 'LISTENING',
      duration: 30,
    );

    expect(request.toJson(), {
      'mode': 'PRACTICE',
      'contextType': 'STANDALONE',
      'section': 'LISTENING',
      'duration': 30,
    });
  });

  test('assignment attempt omits mode and sends assignment context', () {
    const request = CreateExamAttemptRequest(
      contextType: 'CLASSROOM_ASSIGNMENT',
      contextId: 21,
    );

    expect(request.toJson(), {
      'contextType': 'CLASSROOM_ASSIGNMENT',
      'contextId': 21,
    });
  });

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
              'excludedFromScore': true,
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
    expect(question.excludedFromScore, isTrue);
    expect(question.options.single.content, isNull);
  });

  test('submit answer includes null selection for cleared answers', () {
    const answer = SubmitAttemptAnswer(questionId: 12, selectedOptionId: null);

    expect(answer.toJson(), {'questionId': 12, 'selectedOptionId': null});
  });

  test('history without score exclusion remains scored', () {
    final question = ExamQuestion.fromJson({
      'id': 11,
      'content': 'Legacy question',
      'order': 1,
      'options': const [],
    });

    expect(question.excludedFromScore, isFalse);
  });

  test('legacy isScored field maps to score exclusion', () {
    final question = ExamQuestion.fromJson({
      'id': 12,
      'content': 'Legacy excluded question',
      'order': 2,
      'isScored': false,
      'options': const [],
    });

    expect(question.excludedFromScore, isTrue);
  });
}
