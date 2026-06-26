import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/data/models/user.dart';
import 'package:eflutter/data/repositories/user_repository.dart';
import 'package:eflutter/presentation/app/models/app_info.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'app_cubit.freezed.dart';

@freezed
abstract class AppState with _$AppState {
  const factory AppState({
    User? user,
    @Default(AppInfo()) AppInfo appInfo,
    Failure? failure,
  }) = _AppState;
}

@singleton
class AppCubit extends Cubit<AppState> {
  AppCubit(this._userRepository) : super(const AppState()) {
    initAppInfo();
  }

  final UserRepository _userRepository;

  Future<void> initAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appInfo = AppInfo.fromPackageInfo(packageInfo);
    emit(state.copyWith(appInfo: appInfo));
  }

  Future<void> load() async {
    final result = await _userRepository.getMe().withLoading();
    switch (result) {
      case Success(data: final user):
        emit(state.copyWith(user: user, failure: null));
      case Failure():
        emit(state.copyWith(failure: result));
        emit(state.copyWith(failure: null));
      case Cancelled():
        break;
    }
  }

  void setUser(User user) => emit(state.copyWith(user: user));

  void clear() => emit(state.copyWith(user: null, failure: null));
}
