class TopicSection {
  final int id;
  final String name;
  final int topicId;

  const TopicSection({
    required this.id,
    required this.name,
    required this.topicId,
  });

  factory TopicSection.fromJson(Map<String, dynamic> json) {
    return TopicSection(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      topicId: (json['topicId'] as num).toInt(),
    );
  }
}
