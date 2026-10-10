import 'package:dio/dio.dart';
import 'package:eflutter/data/models/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;
  static const _base = '/notifications/api/v1/notifications';

  Future<NotificationPage> getNotifications({
    required int page,
    int pageSize = 20,
    bool? read,
  }) async {
    final response = await _dio.get(
      _base,
      queryParameters: {'page': page, 'pageSize': pageSize, 'read': ?read},
    );
    return NotificationPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markRead(List<int> ids) =>
      _dio.patch('$_base/read', data: {'ids': ids});

  Future<void> deleteMany(List<int> ids) =>
      _dio.delete(_base, data: {'ids': ids});

  Future<void> registerDeviceToken(String token, String platform) => _dio.post(
    '$_base/device-tokens',
    data: {'token': token, 'platform': platform},
  );

  Future<void> deleteDeviceToken(String token) =>
      _dio.delete('$_base/device-tokens', data: {'token': token});
}
