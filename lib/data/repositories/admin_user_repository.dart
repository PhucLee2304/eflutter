import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/user.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';

/// Quản lý người dùng của admin (`identity`, route bọc RequireRole admin).
class AdminUserRepository {
  AdminUserRepository(this._dio);
  final Dio _dio;
  static const _base = '/users/api/v1/users';

  Future<Result<UserPage>> getUsers({
    int page = 1,
    int pageSize = 20,
    String query = '',
    String? role,
    bool? blocked,
  }) => _dio
      .get(
        _base,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (query.isNotEmpty) 'query': query,
          'role': ?role,
          'blocked': ?blocked,
        },
      )
      .then((r) => UserPage.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<UsersSummary>> getSummary() => _dio
      .get('$_base/summary')
      .then((r) => UsersSummary.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<User>> setBlocked(int id, {required bool blocked}) =>
      (blocked ? _dio.post('$_base/$id/block') : _dio.delete('$_base/$id/block'))
          .then((r) => User.fromJson(r.data as Map<String, dynamic>))
          .safeResult();
}
