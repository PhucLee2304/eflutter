import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eflutter/core/auth/auth_interceptor.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/utils/helpers/upload/upload_binary_to_url.dart'
    as upload_helper;
import 'package:eflutter/data/models/exam_detail.dart';
import 'package:eflutter/data/models/exam_page.dart';
import 'package:eflutter/data/models/topic_lesson.dart';
import 'package:eflutter/data/models/topic_lesson_detail.dart';
import 'package:eflutter/data/models/topic_section.dart';
import 'package:eflutter/data/models/topic_summary.dart';
import 'package:eflutter/data/models/user.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: RemoteDataBase)
class RemoteData implements RemoteDataBase {
  final Dio _dio;
  RemoteData(this._dio);

  @override
  Future<(String, String)> login(String idToken) async {
    final response = await _dio.post(
      '/auth/api/v1/login',
      data: {'idToken': idToken},
    );
    final data = response.data;
    return (data['accessToken'] as String, data['refreshToken'] as String);
  }

  @override
  Future<(String, String)> refreshToken(String token) async {
    final response = await _dio.post(
      '/auth/api/v1/refresh',
      data: {'refreshToken': token},
      options: Options(extra: {AuthInterceptor.isRefreshTokenRequestKey: true}),
    );
    final data = response.data;
    return (data['accessToken'] as String, data['refreshToken'] as String);
  }

  @override
  Future<User> getMe() async {
    final response = await _dio.get('/users/api/v1/me');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<User> updateMe({String? name, String? avatar}) async {
    final data = <String, String>{};
    if (name != null) data['name'] = name;
    if (avatar != null) data['avatar'] = avatar;

    final response = await _dio.patch('/users/api/v1/me', data: data);
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<String> getPresignedUploadUrl({
    required String fileName,
    required String contentType,
    required String folder,
  }) async {
    final response = await _dio.post(
      '/storage/api/v1/presign/upload',
      data: {
        'fileName': fileName,
        'contentType': contentType,
        'folder': folder,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String;
  }

  @override
  Future<void> uploadBinaryToUrl({
    required String url,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await upload_helper.uploadBinaryToUrl(
      url: url,
      bytes: bytes,
      contentType: contentType,
    );
  }

  @override
  Future<List<TopicSummary>> getTopics() async {
    final response = await _dio.get('/topics/api/v1/topics');
    final data = response.data as Map<String, dynamic>;
    final topics = (data['topics'] as List<dynamic>? ?? const []);
    return topics
        .map((item) => TopicSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<TopicSection>> getSectionsByTopic(int topicId) async {
    final response = await _dio.get('/topics/api/v1/topics/$topicId');
    final data = response.data as Map<String, dynamic>;
    final sections = (data['sections'] as List<dynamic>? ?? const []);
    return sections
        .map((item) => TopicSection.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<TopicLesson>> getLessonsBySection(int sectionId) async {
    final response = await _dio.get(
      '/topics/api/v1/sections/$sectionId/lessons',
    );
    final data = response.data as Map<String, dynamic>;
    final lessons = (data['lessons'] as List<dynamic>? ?? const []);
    return lessons
        .map((item) => TopicLesson.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TopicLessonDetail> getLessonById(int lessonId) async {
    final response = await _dio.get('/topics/api/v1/lessons/$lessonId');
    final data = response.data as Map<String, dynamic>;
    return TopicLessonDetail.fromJson(data['lesson'] as Map<String, dynamic>);
  }

  @override
  Future<ExamPage> getExams({
    required String type,
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get(
      '/exams/api/v1/exams',
      queryParameters: {'type': type, 'page': page, 'pageSize': pageSize},
    );
    return ExamPage.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ExamDetail> getExamById(int examId) async {
    final response = await _dio.get('/exams/api/v1/exams/$examId');
    return ExamDetail.fromJson(response.data as Map<String, dynamic>);
  }
}
