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
import 'package:web_socket_channel/web_socket_channel.dart';

@lazySingleton
class AuthInterceptor extends Interceptor {
  final Dio _retryDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
  Future<String?>? _refreshing;

  static const String isRefreshTokenRequestKey = 'isRefreshTokenRequest';
  static const tokenExpired = 401;
  static const accountBlocked = 403;

  /// Close code server gửi khi admin khoá tài khoản (platform/socket CloseCodeUserBlocked). Trình
  /// duyệt không cho đọc mã 401 của bước bắt tay WebSocket, nên đây là cách duy nhất để socket phân
  /// biệt "bị khoá" với "mất mạng".
  static const socketClosedUserBlocked = 4003;

  /// Lần gần nhất đã đăng xuất vì bị khoá, để nhiều socket cùng bị đóng chỉ hiện một toast.
  DateTime? _blockedLogoutAt;

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
      if (e.response?.statusCode == accountBlocked) _logoutBlocked();
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

  /// Socket bị server đóng thì gọi hàm này trước khi tự nối lại. Server đóng với close code
  /// [socketClosedUserBlocked] là tài khoản vừa bị khoá: đăng xuất ngay và trả true để socket dừng
  /// nối lại, thay vì hiện Offline cho tới lần gọi API kế tiếp.
  bool handleSocketClosed(WebSocketChannel channel) {
    if (channel.closeCode != socketClosedUserBlocked) return false;
    _logoutBlocked();
    return true;
  }

  /// Đăng xuất và báo lý do bị khoá ở màn login; gọi nhiều lần trong vài giây (refresh và các
  /// socket cùng phát hiện) chỉ xử lý lần đầu.
  void _logoutBlocked() {
    final now = DateTime.now();
    final last = _blockedLogoutAt;
    if (last != null && now.difference(last) < const Duration(seconds: 10)) return;
    _blockedLogoutAt = now;
    getIt<AuthCubit>().logout();
    AppRouter.router.routerDelegate.navigatorKey.currentContext?.showToast(
      'Your account has been blocked. Contact the center administrator for help.',
      type: ToastType.error,
      duration: const Duration(seconds: 5),
    );
  }
}
