import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/admin_stats.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';

/// Thống kê admin: mỗi service một `GET /admin/stats?from&to` (bọc RequireRole admin).
/// [from]/[to] là ngày YYYY-MM-DD tính cả hai đầu; bỏ trống là toàn thời gian.
class AdminStatsRepository {
  AdminStatsRepository(this._dio);
  final Dio _dio;

  Future<Result<T>> _get<T>(
    String prefix,
    T Function(Map<String, dynamic>) parse, {
    String? from,
    String? to,
  }) => _dio
      .get('$prefix/api/v1/admin/stats', queryParameters: {'from': ?from, 'to': ?to})
      .then((r) => parse(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<LearningStats>> getLearning({String? from, String? to}) =>
      _get('/classrooms', LearningStats.fromJson, from: from, to: to);

  Future<Result<PostStats>> getPosts({String? from, String? to}) =>
      _get('/posts', PostStats.fromJson, from: from, to: to);

  Future<Result<KnowledgeStats>> getKnowledge({String? from, String? to}) =>
      _get('/topics', KnowledgeStats.fromJson, from: from, to: to);

  Future<Result<NotificationStats>> getNotifications({String? from, String? to}) =>
      _get('/notifications', NotificationStats.fromJson, from: from, to: to);
}
