// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:eflutter/core/auth/auth_interceptor.dart' as _i393;
import 'package:eflutter/core/auth/auth_notifier.dart' as _i549;
import 'package:eflutter/core/base/local_data_base.dart' as _i942;
import 'package:eflutter/core/base/remote_data_base.dart' as _i90;
import 'package:eflutter/core/di/register_module.dart' as _i63;
import 'package:eflutter/core/loading/loading_service.dart' as _i513;
import 'package:eflutter/data/data_sources/local_data.dart' as _i264;
import 'package:eflutter/data/data_sources/remote_data.dart' as _i81;
import 'package:eflutter/data/repositories/auth_repository.dart' as _i695;
import 'package:eflutter/presentation/app/cubit/app_cubit.dart' as _i912;
import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart' as _i744;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;
import 'package:talker_flutter/talker_flutter.dart' as _i207;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.factory<_i912.AppCubit>(() => _i912.AppCubit());
    gh.singleton<_i513.LoadingService>(
      () => _i513.LoadingService(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i393.AuthInterceptor>(() => _i393.AuthInterceptor());
    gh.lazySingleton<_i460.SharedPreferencesAsync>(
      () => registerModule.sharedPreferencesAsync,
    );
    gh.lazySingleton<_i207.Talker>(() => registerModule.talker);
    gh.lazySingleton<_i942.LocalDataBase>(
      () => _i264.LocalData(gh<_i460.SharedPreferencesAsync>()),
    );
    gh.lazySingleton<_i361.Dio>(
      () => registerModule.dio(gh<_i393.AuthInterceptor>()),
    );
    gh.lazySingleton<_i90.RemoteDataBase>(
      () => _i81.RemoteData(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i695.AuthRepository>(
      () => _i695.AuthRepository(
        gh<_i942.LocalDataBase>(),
        gh<_i207.Talker>(),
        gh<_i90.RemoteDataBase>(),
      ),
    );
    gh.singleton<_i744.AuthCubit>(
      () => _i744.AuthCubit(gh<_i695.AuthRepository>()),
    );
    gh.lazySingleton<_i549.AuthNotifier>(
      () => _i549.AuthNotifier(gh<_i744.AuthCubit>()),
    );
    return this;
  }
}

class _$RegisterModule extends _i63.RegisterModule {}
