class TopicTranscript {
  final int id;
  final String content;
  final int order;
  final double timeStart;
  final double timeEnd;
  final String url;
  final int lessonId;

  const TopicTranscript({
    required this.id,
    required this.content,
    required this.order,
    required this.timeStart,
    required this.timeEnd,
    required this.url,
    required this.lessonId,
  });

  factory TopicTranscript.fromJson(Map<String, dynamic> json) {
    return TopicTranscript(
      id: (json['id'] as num).toInt(),
      content: json['content'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      timeStart: (json['timeStart'] as num?)?.toDouble() ?? 0,
      timeEnd: (json['timeEnd'] as num?)?.toDouble() ?? 0,
      url: json['url'] as String? ?? '',
      lessonId: (json['lessonId'] as num?)?.toInt() ?? 0,
    );
  }
}
