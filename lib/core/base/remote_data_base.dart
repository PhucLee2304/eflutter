import 'dart:typed_data';

import 'package:eflutter/data/models/attempt_page.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_attempt_page.dart';
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

  /// Xin URL PUT để upload ảnh đại diện. [fileName] là tên gốc; server tự đặt tên lưu và trả về
  /// trong `fileName`, client gửi lại giá trị đó khi gắn avatar. [folder] là `avatars/users`
  /// hoặc `avatars/classrooms`.
  Future<({String url, String fileName})> getPresignedUploadUrl({
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
    String? search,
    int? year,
  });

  /// Các năm có đề public của loại này, mới nhất trước.
  Future<List<int>> getExamYears(String type);

  Future<ExamDetail> getExamById(int examId);

  Future<ExamAttempt> createExamAttempt(int examId, CreateExamAttemptRequest request);

  /// [excludeMode] bỏ attempt theo mode, [examTypes] chỉ lấy đề thuộc các loại này.
  Future<ExamAttemptPage> getAttempts({
    required String status,
    required int page,
    required int pageSize,
    String? excludeMode,
    List<String> examTypes = const [],
    String? search,
  });

  Future<ExamAttempt> getAttemptQuestions(int attemptId);

  Future<ExamAttempt> submitAttempt(int attemptId, List<SubmitAttemptAnswer> answers);

  Future<ExamAttempt> cancelAttempt(int attemptId);

  Future<ExamAttempt> getAttemptHistory(int attemptId);

  Future<AttemptNavigator> getAttemptNavigator(int attemptId);

  Future<AttemptPage> getAttemptPage(int attemptId, int index);
}
