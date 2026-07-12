class ExamDetail {
  final int id;
  final String title;
  final String description;
  final bool isPublic;
  final String type;
  final int? year;
  final int duration;
  final int totalSections;
  final int totalQuestions;
  final List<ExamSectionSummary> sections;
  final List<ExamPartSummary> parts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ExamDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.isPublic,
    required this.type,
    required this.year,
    required this.duration,
    required this.totalSections,
    required this.totalQuestions,
    required this.sections,
    required this.parts,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExamDetail.fromJson(Map<String, dynamic> json) {
    final sections = json['sections'] as List<dynamic>? ?? const [];
    final parts = json['parts'] as List<dynamic>? ?? const [];
    return ExamDetail(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isPublic: json['isPublic'] as bool? ?? false,
      type: json['type'] as String? ?? '',
      year: (json['year'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      totalSections: (json['totalSections'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      sections: sections
          .map(
            (item) => ExamSectionSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      parts: parts
          .map((item) => ExamPartSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class ExamSectionSummary {
  final int id;
  final String code;
  final String title;
  final int order;
  final int? duration;
  final int questionCount;

  const ExamSectionSummary({
    required this.id,
    required this.code,
    required this.title,
    required this.order,
    required this.duration,
    required this.questionCount,
  });

  factory ExamSectionSummary.fromJson(Map<String, dynamic> json) {
    return ExamSectionSummary(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt(),
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExamPartSummary {
  final String part;
  final String sectionCode;
  final int questionCount;

  const ExamPartSummary({
    required this.part,
    required this.sectionCode,
    required this.questionCount,
  });

  factory ExamPartSummary.fromJson(Map<String, dynamic> json) {
    return ExamPartSummary(
      part: json['part'] as String? ?? '',
      sectionCode: json['sectionCode'] as String? ?? '',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    );
  }
}
