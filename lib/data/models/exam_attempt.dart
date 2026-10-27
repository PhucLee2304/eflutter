import 'package:eflutter/data/models/exam_questions.dart';

class CreateExamAttemptRequest {
  final String? mode;
  final String? section;
  final List<String> parts;
  final int? duration;
  final String contextType;
  final int? contextId;

  /// Phiên bản quy chế đã đồng ý; bắt buộc với bài có giám sát.
  final String? integrityConsentVersion;

  const CreateExamAttemptRequest({
    this.mode,
    this.section,
    this.parts = const [],
    this.duration,
    this.contextType = 'STANDALONE',
    this.contextId,
    this.integrityConsentVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      if (mode != null && mode!.isNotEmpty) 'mode': mode,
      'contextType': contextType,
      if (section != null) 'section': section,
      if (parts.isNotEmpty) 'parts': parts,
      if (duration != null) 'duration': duration,
      if (contextId != null) 'contextId': contextId,
      if (integrityConsentVersion != null)
        'integrityConsent': {'version': integrityConsentVersion},
    };
  }
}

class SubmitAttemptAnswer {
  final int questionId;
  final int? selectedOptionId;

  const SubmitAttemptAnswer({
    required this.questionId,
    required this.selectedOptionId,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'selectedOptionId': selectedOptionId,
  };
}

/// Kết quả giám sát của attempt (PLAN_ATTEMPT_INTEGRITY.md mục 1.2).
abstract final class IntegrityOutcome {
  static const none = 'NONE';
  static const terminated = 'TERMINATED';
  static const reinstated = 'REINSTATED';
}

/// Luồng làm bài do server chốt lúc tạo attempt (PLAN_TOEIC_ATTEMPT.md mục 1.1).
abstract final class AttemptFlow {
  static const free = 'FREE';
  static const toeicStrict = 'TOEIC_STRICT';
}

/// Giai đoạn của attempt TOEIC_STRICT.
abstract final class AttemptStage {
  static const listening = 'LISTENING';
  static const reading = 'READING';
}

class ExamAttempt {
  final int id;
  final int examId;
  final AttemptExamSummary? exam;
  final String mode;
  final String status;
  final String flow;
  final String? stage;
  final String? section;
  final List<String> parts;
  final int? duration;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? submittedAt;
  final int totalQuestions;
  final int answeredCount;
  final int? correctAnswers;
  final double? score;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ExamQuestionsSection> questions;

  // Giám sát: chỉ có giá trị khi proctored.
  final bool proctored;
  final int? maxViolations;
  final int? violationCount;
  final String? integrityOutcome;
  final String? terminationReason;

  bool get isTerminated => integrityOutcome == IntegrityOutcome.terminated;

  /// Bài giao trong lớp: không hủy được, chỉ nộp.
  bool get isAssignment => mode == 'ASSIGNMENT';

  const ExamAttempt({
    required this.id,
    required this.examId,
    required this.exam,
    required this.mode,
    required this.status,
    this.flow = AttemptFlow.free,
    this.stage,
    required this.section,
    required this.parts,
    required this.duration,
    required this.startedAt,
    required this.expiresAt,
    required this.submittedAt,
    required this.totalQuestions,
    required this.answeredCount,
    required this.correctAnswers,
    required this.score,
    required this.createdAt,
    required this.updatedAt,
    required this.questions,
    this.proctored = false,
    this.maxViolations,
    this.violationCount,
    this.integrityOutcome,
    this.terminationReason,
  });

  factory ExamAttempt.fromJson(Map<String, dynamic> json) {
    final questions =
        json['questions'] as List<dynamic>? ??
        json['sections'] as List<dynamic>? ??
        const [];
    final parts = json['parts'] as List<dynamic>? ?? const [];
    final examId = (json['examId'] as num? ?? json['examid'] as num? ?? 0)
        .toInt();
    return ExamAttempt(
      id: (json['id'] as num).toInt(),
      examId: examId,
      exam: json['exam'] is Map<String, dynamic>
          ? AttemptExamSummary.fromJson(json['exam'] as Map<String, dynamic>)
          : _flatExamFromJson(json, examId),
      mode: json['mode'] as String? ?? '',
      status: json['status'] as String? ?? '',
      flow: json['flow'] as String? ?? AttemptFlow.free,
      stage: json['stage'] as String?,
      section: json['section'] as String?,
      parts: parts.map((item) => item.toString()).toList(),
      duration: (json['duration'] as num?)?.toInt(),
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? ''),
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correctAnswers'] as num?)?.toInt(),
      score: (json['score'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      questions: questions
          .map(
            (item) =>
                ExamQuestionsSection.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      proctored: json['proctored'] as bool? ?? false,
      maxViolations: (json['maxViolations'] as num?)?.toInt(),
      violationCount: (json['violationCount'] as num?)?.toInt(),
      integrityOutcome: json['integrityOutcome'] as String?,
      terminationReason: json['terminationReason'] as String?,
    );
  }

  bool get isStrict => flow == AttemptFlow.toeicStrict;

  factory ExamAttempt.fromQuestionsResponse(Map<String, dynamic> json) {
    final attemptJson = json['attempt'];
    final examJson = json['exam'];
    if (attemptJson is! Map<String, dynamic>) {
      return ExamAttempt.fromJson(json);
    }

    final merged = Map<String, dynamic>.from(attemptJson);
    if (examJson is Map<String, dynamic>) {
      merged['sections'] = examJson['sections'];
      merged['exam'] ??= {
        'id': examJson['id'],
        'title': examJson['title'],
        'description': examJson['description'],
        'type': examJson['type'],
        'year': examJson['year'],
      };
    }

    return ExamAttempt.fromJson(merged);
  }

  static AttemptExamSummary? _flatExamFromJson(
    Map<String, dynamic> json,
    int examId,
  ) {
    final hasFlatExam =
        json['title'] != null ||
        json['description'] != null ||
        json['type'] != null ||
        json['year'] != null;
    if (!hasFlatExam) return null;
    return AttemptExamSummary(
      id: examId,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? '',
      year: (json['year'] as num?)?.toInt(),
    );
  }
}

class AttemptExamSummary {
  final int id;
  final String title;
  final String description;
  final String type;
  final int? year;

  const AttemptExamSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.year,
  });

  factory AttemptExamSummary.fromJson(Map<String, dynamic> json) {
    return AttemptExamSummary(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? '',
      year: (json['year'] as num?)?.toInt(),
    );
  }
}
