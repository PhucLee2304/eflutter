import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/data_sources/ai_remote_data.dart';
import 'package:eflutter/data/models/grammar/grammar_unit.dart';
import 'package:eflutter/presentation/ai/grammar_ai_explain_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'grammar sheet sends selected answer and displays AI explanation',
    (tester) async {
      RequestOptions? sentRequest;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sentRequest = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'answer': 'He is wrong because am goes with I.'},
              ),
            );
          },
        ),
      );
      getIt.registerSingleton<AiRemoteData>(AiRemoteData(dio));
      addTearDown(() => getIt.unregister<AiRemoteData>());

      const question = PracticeQuestion(
        id: 3,
        question: '___ am ready.',
        options: ['I', 'He'],
        correct: 'I',
        explanation: 'Use I with am.',
      );
      const unit = UnitDetail(
        id: 7,
        title: 'Pronouns',
        theory: 'Pronouns',
        practices: [question],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => GrammarAiExplainSheet.show(
                    context,
                    unit: unit,
                    question: question,
                    selectedOptionIndex: 1,
                  ),
                  child: const Text('Ask why'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ask why'));
      await tester.pumpAndSettle();

      expect(sentRequest?.path, '/ai/api/v1/grammar/explain');
      expect(sentRequest?.data, {
        'unitTitle': 'Pronouns',
        'question': '___ am ready.',
        'options': ['I', 'He'],
        'correct': 'I',
        'explanation': 'Use I with am.',
        'selectedOptionIndex': 1,
      });
      expect(find.text('Why was my answer B wrong?'), findsOneWidget);
      expect(find.text('He is wrong because am goes with I.'), findsOneWidget);
    },
  );
}
