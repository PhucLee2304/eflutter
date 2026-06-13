import 'package:dio/dio.dart';
import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/auth/auth_interceptor.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

@module
abstract class RegisterModule {
  @lazySingleton
  SharedPreferencesAsync get sharedPreferencesAsync => SharedPreferencesAsync();

  @lazySingleton
  Talker get talker => TalkerFlutter.init();

  @lazySingleton
  Dio dio(AuthInterceptor authInterceptor) {
    return Dio(BaseOptions(baseUrl: AppConfig.baseUrl))
      ..interceptors.add(authInterceptor);
  }
}
