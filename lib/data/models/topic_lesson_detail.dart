import 'package:eflutter/data/models/topic_transcript.dart';

class TopicLessonDetail {
  final int id;
  final String title;
  final String description;
  final String subtitle;
  final String url;
  final int sectionId;
  final List<TopicTranscript> transcripts;

  const TopicLessonDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.subtitle,
    required this.url,
    required this.sectionId,
    required this.transcripts,
  });

  factory TopicLessonDetail.fromJson(Map<String, dynamic> json) {
    final transcripts = (json['transcripts'] as List<dynamic>? ?? const []);
    return TopicLessonDetail(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      url: json['url'] as String? ?? '',
      sectionId: (json['sectionId'] as num?)?.toInt() ?? 0,
      transcripts: transcripts
          .map((item) => TopicTranscript.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
