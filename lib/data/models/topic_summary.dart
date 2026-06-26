class TopicSummary {
  final int id;
  final String name;
  final bool isAudio;
  final String url;

  const TopicSummary({
    required this.id,
    required this.name,
    required this.isAudio,
    required this.url,
  });

  factory TopicSummary.fromJson(Map<String, dynamic> json) {
    return TopicSummary(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      isAudio: json['isAudio'] as bool? ?? false,
      url: json['url'] as String? ?? '',
    );
  }
}
