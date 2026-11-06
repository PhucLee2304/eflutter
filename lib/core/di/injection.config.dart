// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:eflutter/core/attempt_lock/attempt_integrity_reporter.dart'
    as _i649;
import 'package:eflutter/core/attempt_lock/attempt_lock_notifier.dart' as _i668;
import 'package:eflutter/core/attempt_lock/leave_guard.dart' as _i744;
import 'package:eflutter/core/auth/auth_interceptor.dart' as _i393;
import 'package:eflutter/core/auth/auth_notifier.dart' as _i549;
import 'package:eflutter/core/base/local_data_base.dart' as _i942;
import 'package:eflutter/core/base/remote_data_base.dart' as _i90;
import 'package:eflutter/core/di/register_module.dart' as _i63;
import 'package:eflutter/core/loading/loading_service.dart' as _i513;
import 'package:eflutter/data/data_sources/dictionary_remote_data.dart'
    as _i100;
import 'package:eflutter/data/data_sources/grammar_remote_data.dart' as _i123;
import 'package:eflutter/data/data_sources/local_data.dart' as _i264;
import 'package:eflutter/data/data_sources/remote_data.dart' as _i81;
import 'package:eflutter/data/repositories/auth_repository.dart' as _i695;
import 'package:eflutter/data/repositories/dictionary_repository.dart' as _i23;
import 'package:eflutter/data/repositories/grammar_repository.dart' as _i234;
import 'package:eflutter/data/repositories/topic_repository.dart' as _i441;
import 'package:eflutter/data/repositories/user_repository.dart' as _i180;
import 'package:eflutter/presentation/app/cubit/app_cubit.dart' as _i912;
import 'package:eflutter/presentation/auth/cubit/auth_cubit.dart' as _i744;
import 'package:eflutter/presentation/dictionary/cubit/dictionary_search_cubit.dart'
    as _i303;
import 'package:eflutter/presentation/dictionary/cubit/dictionary_topic_cubit.dart'
    as _i1071;
import 'package:eflutter/presentation/dictionary/cubit/flashcard_cubit.dart'
    as _i358;
import 'package:eflutter/presentation/dictionary/cubit/word_detail_cubit.dart'
    as _i673;
import 'package:eflutter/presentation/grammar/cubit/grammar_curriculum_cubit.dart'
    as _i436;
import 'package:eflutter/presentation/grammar/cubit/grammar_unit_cubit.dart'
    as _i690;
import 'package:eflutter/presentation/notifications/notification_controller.dart'
    as _i834;
import 'package:eflutter/presentation/notifications/notification_push_service.dart'
    as _i339;
import 'package:eflutter/presentation/profile/cubit/profile_cubit.dart'
    as _i1004;
import 'package:eflutter/presentation/topics/cubit/topic_cubit.dart' as _i1049;
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
    gh.singleton<_i513.LoadingService>(
      () => _i513.LoadingService(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i393.AuthInterceptor>(() => _i393.AuthInterceptor());
    gh.lazySingleton<_i460.SharedPreferencesAsync>(
      () => registerModule.sharedPreferencesAsync,
    );
    gh.lazySingleton<_i207.Talker>(() => registerModule.talker);
    gh.lazySingleton<_i744.LeaveGuard>(() => registerModule.leaveGuard);
    gh.lazySingleton<_i942.LocalDataBase>(
      () => _i264.LocalData(gh<_i460.SharedPreferencesAsync>()),
    );
    gh.lazySingleton<_i649.AttemptIntegrityReporter>(
      () => _i649.SocketAttemptIntegrityReporter(gh<_i207.Talker>()),
    );
    gh.lazySingleton<_i361.Dio>(
      () => registerModule.dio(gh<_i393.AuthInterceptor>()),
    );
    gh.lazySingleton<_i90.RemoteDataBase>(
      () => _i81.RemoteData(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i100.DictionaryRemoteData>(
      () => _i100.DictionaryRemoteData(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i123.GrammarRemoteData>(
      () => _i123.GrammarRemoteData(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i834.NotificationController>(
      () => _i834.NotificationController(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i668.AttemptLockNotifier>(
      () => _i668.AttemptLockNotifier(
        gh<_i90.RemoteDataBase>(),
        gh<_i649.AttemptIntegrityReporter>(),
        gh<_i744.LeaveGuard>(),
      ),
    );
    gh.lazySingleton<_i234.GrammarRepository>(
      () => _i234.GrammarRepository(gh<_i123.GrammarRemoteData>()),
    );
    gh.factory<_i436.GrammarCurriculumCubit>(
      () => _i436.GrammarCurriculumCubit(gh<_i234.GrammarRepository>()),
    );
    gh.factory<_i690.GrammarUnitCubit>(
      () => _i690.GrammarUnitCubit(gh<_i234.GrammarRepository>()),
    );
    gh.lazySingleton<_i23.DictionaryRepository>(
      () => _i23.DictionaryRepository(gh<_i100.DictionaryRemoteData>()),
    );
    gh.lazySingleton<_i339.NotificationPushService>(
      () => _i339.NotificationPushService(
        gh<_i361.Dio>(),
        gh<_i834.NotificationController>(),
        gh<_i460.SharedPreferencesAsync>(),
        gh<_i393.AuthInterceptor>(),
      ),
    );
    gh.lazySingleton<_i695.AuthRepository>(
      () => _i695.AuthRepository(
        gh<_i942.LocalDataBase>(),
        gh<_i207.Talker>(),
        gh<_i90.RemoteDataBase>(),
      ),
    );
    gh.lazySingleton<_i441.TopicRepository>(
      () => _i441.TopicRepository(gh<_i90.RemoteDataBase>()),
    );
    gh.lazySingleton<_i180.UserRepository>(
      () => _i180.UserRepository(gh<_i90.RemoteDataBase>()),
    );
    gh.singleton<_i744.AuthCubit>(
      () => _i744.AuthCubit(
        gh<_i695.AuthRepository>(),
        gh<_i339.NotificationPushService>(),
      ),
    );
    gh.lazySingleton<_i549.AuthNotifier>(
      () => _i549.AuthNotifier(gh<_i744.AuthCubit>()),
    );
    gh.singleton<_i912.AppCubit>(
      () => _i912.AppCubit(gh<_i180.UserRepository>()),
    );
    gh.factory<_i303.DictionarySearchCubit>(
      () => _i303.DictionarySearchCubit(gh<_i23.DictionaryRepository>()),
    );
    gh.factory<_i1071.DictionaryTopicCubit>(
      () => _i1071.DictionaryTopicCubit(gh<_i23.DictionaryRepository>()),
    );
    gh.factory<_i358.FlashcardCubit>(
      () => _i358.FlashcardCubit(gh<_i23.DictionaryRepository>()),
    );
    gh.factory<_i673.WordDetailCubit>(
      () => _i673.WordDetailCubit(gh<_i23.DictionaryRepository>()),
    );
    gh.factory<_i1004.ProfileCubit>(
      () =>
          _i1004.ProfileCubit(gh<_i180.UserRepository>(), gh<_i912.AppCubit>()),
    );
    gh.factory<_i1049.TopicCubit>(
      () => _i1049.TopicCubit(gh<_i441.TopicRepository>()),
    );
    return this;
  }
}

class _$RegisterModule extends _i63.RegisterModule {}
