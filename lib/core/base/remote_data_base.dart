import 'dart:typed_data';

import 'package:eflutter/data/models/exam_detail.dart';
import 'package:eflutter/data/models/exam_page.dart';
import 'package:eflutter/data/models/topic_lesson.dart';
import 'package:eflutter/data/models/topic_lesson_detail.dart';
import 'package:eflutter/data/models/topic_section.dart';
import 'package:eflutter/data/models/topic_summary.dart';
import 'package:eflutter/data/models/user.dart';

abstract interface class RemoteDataBase {
  Future<(String, String)> login(String idToken);

  Future<(String, String)> refreshToken(String token);

  Future<User> getMe();

  Future<User> updateMe({String? name, String? avatar});

  Future<String> getPresignedUploadUrl({
    required String fileName,
    required String contentType,
    required String folder,
  });

  Future<void> uploadBinaryToUrl({
    required String url,
    required Uint8List bytes,
    required String contentType,
  });

  Future<List<TopicSummary>> getTopics();

  Future<List<TopicSection>> getSectionsByTopic(int topicId);

  Future<List<TopicLesson>> getLessonsBySection(int sectionId);

  Future<TopicLessonDetail> getLessonById(int lessonId);

  Future<ExamPage> getExams({
    required String type,
    required int page,
    required int pageSize,
  });

  Future<ExamDetail> getExamById(int examId);
}
