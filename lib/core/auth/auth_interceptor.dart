import 'package:dio/dio.dart';
import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AuthInterceptor extends Interceptor {
  final Dio _retryDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));

  static const String isRefreshTokenRequestKey = 'isRefreshTokenRequest';
  static const tokenExpired = 401;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final localData = getIt<LocalDataBase>();
    final isRefreshTokenRequest =
        options.extra[isRefreshTokenRequestKey] == true;
    final token = isRefreshTokenRequest
        ? await localData.getRefreshToken()
        : await localData.getAccessToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response == null ||
        err.response?.statusCode != tokenExpired ||
        err.requestOptions.extra[isRefreshTokenRequestKey] == true) {
      return handler.next(err);
    }
    final localData = getIt<LocalDataBase>();
    final remoteData = getIt<RemoteDataBase>();
    final authCubit = getIt<AuthCubit>();
    final refreshToken = await localData.getRefreshToken();
    if (refreshToken == null) {
      authCubit.logout();
      return handler.reject(err);
    }

    try {
      final (newAccessToken, newRefreshToken) = await remoteData.refreshToken(
        refreshToken,
      );
      await localData.saveTokens(newAccessToken, newRefreshToken);

      return await _retryRequest(err.requestOptions, handler, newAccessToken);
    } on DioException catch (e) {
      if (e.response?.statusCode == tokenExpired) {
        authCubit.logout();
      }
    }

    return handler.reject(err);
  }

  Future<void> _retryRequest(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
    String newAccessToken,
  ) async {
    try {
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final response = await _retryDio.fetch(requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
