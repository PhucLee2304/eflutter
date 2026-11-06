import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/presentation/app/navigation/app_router.dart';
import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AuthInterceptor extends Interceptor {
  final Dio _retryDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
  Future<String?>? _refreshing;

  static const String isRefreshTokenRequestKey = 'isRefreshTokenRequest';
  static const tokenExpired = 401;
  static const accountBlocked = 403;

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
    final newAccessToken = await _refresh();
    if (newAccessToken == null) return handler.reject(err);
    return _retryRequest(err.requestOptions, handler, newAccessToken);
  }

  /// Access token còn hạn ít nhất 1 phút, refresh trước nếu sắp hết. Dùng khi mở WebSocket:
  /// handshake không đi qua Dio nên không được refresh lúc bị từ chối. Refresh lỗi (mất mạng)
  /// thì trả token cũ, lần nối lại sau sẽ thử refresh tiếp.
  Future<String?> freshAccessToken() async {
    final token = await getIt<LocalDataBase>().getAccessToken();
    if (token == null || token.isEmpty) return token;
    final parts = token.split('.');
    final payload = parts.length == 3
        ? jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
        : null;
    final exp = payload is Map ? payload['exp'] : null;
    final expiresAt = exp is int ? DateTime.fromMillisecondsSinceEpoch(exp * 1000) : null;
    if (expiresAt != null && expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return token;
    }
    return await _refresh() ?? token;
  }

  /// Một lần refresh dùng chung cho mọi request và socket cùng gặp token hết hạn. Trả null khi
  /// refresh thất bại; refresh token hết hạn hoặc không có thì đăng xuất.
  Future<String?> _refresh() => _refreshing ??= () async {
    final localData = getIt<LocalDataBase>();
    final authCubit = getIt<AuthCubit>();
    try {
      final refreshToken = await localData.getRefreshToken();
      if (refreshToken == null) {
        authCubit.logout();
        return null;
      }
      final (newAccessToken, newRefreshToken) = await getIt<RemoteDataBase>().refreshToken(
        refreshToken,
      );
      await localData.saveTokens(newAccessToken, newRefreshToken);
      return newAccessToken;
    } on DioException catch (e) {
      if (e.response?.statusCode == tokenExpired) {
        authCubit.logout();
      }
      // Admin vừa khoá tài khoản: đăng xuất và báo lý do ở màn login.
      if (e.response?.statusCode == accountBlocked) {
        authCubit.logout();
        AppRouter.router.routerDelegate.navigatorKey.currentContext?.showToast(
          'Your account has been blocked. Contact the center administrator for help.',
          type: ToastType.error,
          duration: const Duration(seconds: 5),
        );
      }
      return null;
    } finally {
      _refreshing = null;
    }
  }();

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
