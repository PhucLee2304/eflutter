class ExamSummary {
  final int id;
  final String title;
  final String description;
  final bool isPublic;
  final String type;
  final int? year;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ExamSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.isPublic,
    required this.type,
    required this.year,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExamSummary.fromJson(Map<String, dynamic> json) {
    return ExamSummary(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isPublic: json['isPublic'] as bool? ?? false,
      type: json['type'] as String? ?? '',
      year: (json['year'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
