import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';

class ClassroomRepository {
  ClassroomRepository(this._dio);
  final Dio _dio;
  static const _base = '/classrooms/api/v1/classrooms';

  Future<Result<ClassroomPage>> getMine({int page = 1, String query = ''}) =>
      _dio
          .get(
            '$_base/me',
            queryParameters: {
              'page': page,
              'pageSize': 12,
              if (query.isNotEmpty) 'query': query,
            },
          )
          .then((r) => ClassroomPage.fromJson(r.data as Map<String, dynamic>))
          .safeResult();

  Future<Result<Classroom>> get(int id) => _dio
      .get('$_base/$id')
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<Classroom>> preview(String code) => _dio
      .get('$_base/code/${Uri.encodeComponent(code.trim().toUpperCase())}')
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<Classroom>> create(String name, {String? description}) => _dio
      .post(
        _base,
        data: {
          'name': name.trim(),
          if (description != null) 'description': description.trim(),
        },
      )
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<Classroom>> update(
    int id, {
    required String name,
    String? description,
  }) => _dio
      .patch(
        '$_base/$id',
        data: {
          'name': name.trim(),
          if (description != null) 'description': description.trim(),
        },
      )
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<Classroom>> archive(int id) => _dio
      .post('$_base/$id/archive')
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<ClassroomMember>> join(String code) => _dio
      .post('$_base/join', data: {'code': code.trim().toUpperCase()})
      .then((r) => ClassroomMember.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<List<ClassroomMember>>> joinRequests(int id) => _dio
      .get('$_base/$id/members/join-requests')
      .then(
        (r) => (r.data as List<dynamic>)
            .map((e) => ClassroomMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      )
      .safeResult();

  Future<Result<ClassroomMember>> review(int id, String userId, bool approve) =>
      _dio
          .post(
            '$_base/$id/members/${Uri.encodeComponent(userId)}/'
            '${approve ? 'approve' : 'reject'}',
          )
          .then((r) => ClassroomMember.fromJson(r.data as Map<String, dynamic>))
          .safeResult();

  Future<Result<void>> remove(int id, String userId) => _dio
      .delete<void>('$_base/$id/members/${Uri.encodeComponent(userId)}')
      .then((_) {})
      .safeResult();
}
