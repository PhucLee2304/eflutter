class TopicLesson {
  final int id;
  final String title;
  final String description;
  final String subtitle;
  final String url;
  final int sectionId;

  const TopicLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.subtitle,
    required this.url,
    required this.sectionId,
  });

  factory TopicLesson.fromJson(Map<String, dynamic> json) {
    return TopicLesson(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      url: json['url'] as String? ?? '',
      sectionId: (json['sectionId'] as num).toInt(),
    );
  }
}
