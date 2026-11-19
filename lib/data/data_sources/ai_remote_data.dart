import 'package:dio/dio.dart';
import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:eflutter/data/models/grammar/grammar_unit.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AiRemoteData {
  final Dio _dio;
  AiRemoteData(this._dio);

  /// Gửi tin nhắn đến AI Tutor và nhận câu trả lời.
  Future<String> sendMessage(String message) async {
    final response = await _dio.post(
      '/ai/api/v1/chat',
      data: {'message': message},
    );
    final data = response.data as Map<String, dynamic>;
    return data['answer'] as String? ?? '';
  }

  /// Gọi AI để giải thích chi tiết một từ vựng (Phase 2 RAG).
  /// Flutter gửi kèm dữ liệu từ điển để AI xây dựng context.
  Future<String> explainWord(WordDetail word) async {
    // Chuyển meanings sang format mà backend AI service mong đợi
    final meaningsJson = word.meanings.map((m) => {
      'partOfSpeech': m.partOfSpeech,
      'definitions': m.definitions.take(3).map((d) => d.definition).toList(),
      'examples': m.definitions
          .where((d) => d.example != null && d.example!.isNotEmpty)
          .take(2)
          .map((d) => d.example!)
          .toList(),
      'synonyms': m.synonyms.take(4).toList(),
    }).toList();

    final response = await _dio.post(
      '/ai/api/v1/words/explain',
      data: {
        'word': word.word,
        'phonetic': word.phonetic ?? '',
        'meanings': meaningsJson,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['answer'] as String? ?? '';
  }

  /// Send the displayed grammar practice and selected option to the AI service.
  Future<String> explainGrammar({
    required UnitDetail unit,
    required PracticeQuestion question,
    required int selectedOptionIndex,
  }) async {
    final response = await _dio.post(
      '/ai/api/v1/grammar/explain',
      data: {
        'unitTitle': unit.title,
        'question': question.question,
        'options': question.options,
        'correct': question.correct,
        'explanation': question.explanation,
        'selectedOptionIndex': selectedOptionIndex,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['answer'] as String? ?? '';
  }
}
