import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/data_sources/ai_remote_data.dart';
import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:eflutter/data/models/grammar/grammar_unit.dart';

class AiService {
  final AiRemoteData _remote;

  AiService()
      : _remote = getIt.isRegistered<AiRemoteData>()
            ? getIt<AiRemoteData>()
            : AiRemoteData(getIt<Dio>());

  /// Gửi tin nhắn của người dùng và trả về câu trả lời từ AI.
  Future<String> sendMessage(String message) {
    return _remote.sendMessage(message);
  }

  /// Gọi AI để giải thích chi tiết một từ vựng (Phase 2 RAG).
  Future<String> explainWord(WordDetail word) {
    return _remote.explainWord(word);
  }

  Future<String> explainGrammar({
    required UnitDetail unit,
    required PracticeQuestion question,
    required int selectedOptionIndex,
  }) {
    return _remote.explainGrammar(
      unit: unit,
      question: question,
      selectedOptionIndex: selectedOptionIndex,
    );
  }
}
