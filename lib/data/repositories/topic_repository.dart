import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/topic_lesson.dart';
import 'package:eflutter/data/models/topic_lesson_detail.dart';
import 'package:eflutter/data/models/topic_section.dart';
import 'package:eflutter/data/models/topic_summary.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class TopicRepository {
  final RemoteDataBase _remoteData;

  TopicRepository(this._remoteData);

  Future<Result<List<TopicSummary>>> getTopics() =>
      _remoteData.getTopics().safeResult();

  Future<Result<List<TopicSection>>> getSectionsByTopic(int topicId) =>
      _remoteData.getSectionsByTopic(topicId).safeResult();

  Future<Result<List<TopicLesson>>> getLessonsBySection(int sectionId) =>
      _remoteData.getLessonsBySection(sectionId).safeResult();

  Future<Result<TopicLessonDetail>> getLessonById(int lessonId) =>
      _remoteData.getLessonById(lessonId).safeResult();
}
