class ExamQuestionsSection {
  final int id;
  final String code;
  final String title;
  final int order;
  final int? duration;
  final List<ExamQuestionGroup> groups;
  final List<ExamQuestion> questions;

  const ExamQuestionsSection({
    required this.id,
    required this.code,
    required this.title,
    required this.order,
    required this.duration,
    required this.groups,
    required this.questions,
  });

  factory ExamQuestionsSection.fromJson(Map<String, dynamic> json) {
    final groups = json['groups'] as List<dynamic>? ?? const [];
    final questions = json['questions'] as List<dynamic>? ?? const [];
    return ExamQuestionsSection(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt(),
      groups: groups
          .map(
            (item) => ExamQuestionGroup.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      questions: questions
          .map((item) => ExamQuestion.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExamQuestionGroup {
  final int id;
  final String title;
  final String instruction;
  final String? audioUrl;
  final String? imageUrl;
  final String transcript;
  final String explanation;
  final int order;
  final List<ExamQuestion> questions;

  const ExamQuestionGroup({
    required this.id,
    required this.title,
    required this.instruction,
    required this.audioUrl,
    required this.imageUrl,
    required this.transcript,
    required this.explanation,
    required this.order,
    required this.questions,
  });

  factory ExamQuestionGroup.fromJson(Map<String, dynamic> json) {
    final questions = json['questions'] as List<dynamic>? ?? const [];
    return ExamQuestionGroup(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      instruction: json['instruction'] as String? ?? '',
      audioUrl: json['audioUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      transcript: json['transcript'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      questions: questions
          .map((item) => ExamQuestion.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExamQuestion {
  final int id;
  final String content;
  final String? part;
  final String explanation;
  final int order;
  final int? selectedOptionId;
  final int? correctOptionId;
  final bool? isCorrect;
  final List<ExamQuestionOption> options;

  const ExamQuestion({
    required this.id,
    required this.content,
    required this.part,
    required this.explanation,
    required this.order,
    required this.selectedOptionId,
    required this.correctOptionId,
    required this.isCorrect,
    required this.options,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    final options = json['options'] as List<dynamic>? ?? const [];
    return ExamQuestion(
      id: (json['id'] as num).toInt(),
      content: json['content'] as String? ?? '',
      part: json['part'] as String?,
      explanation: json['explanation'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      selectedOptionId: (json['selectedOptionId'] as num?)?.toInt(),
      correctOptionId: (json['correctOptionId'] as num?)?.toInt(),
      isCorrect: json['isCorrect'] as bool?,
      options: options
          .map(
            (item) => ExamQuestionOption.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ExamQuestionOption {
  final int id;
  final String key;
  final String? content;
  final int order;

  const ExamQuestionOption({
    required this.id,
    required this.key,
    required this.content,
    required this.order,
  });

  factory ExamQuestionOption.fromJson(Map<String, dynamic> json) {
    return ExamQuestionOption(
      id: (json['id'] as num).toInt(),
      key: json['key'] as String? ?? '',
      content: json['content'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}
