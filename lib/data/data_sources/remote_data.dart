import 'package:dio/dio.dart';
import 'package:eflutter/core/auth/auth_interceptor.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: RemoteDataBase)
class RemoteData implements RemoteDataBase {
  final Dio _dio;
  RemoteData(this._dio);

  @override
  Future<(String, String)> login(String idToken) async {
    final response = await _dio.post('/auth/api/v1/login', data: {'idToken': idToken});
    final data = response.data;
    return (data['accessToken'] as String, data['refreshToken'] as String);
  }

  @override
  Future<(String, String)> refreshToken(String token) async {
    final response = await _dio.post(
      'auth/api/v1/refresh',
      data: {'refreshToken': token},
      options: Options(extra: {AuthInterceptor.isRefreshTokenRequestKey: true}),
    );
    final data = response.data;
    return (data['accessToken'] as String, data['refreshToken'] as String);
  }
}
