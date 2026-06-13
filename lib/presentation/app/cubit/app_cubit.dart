import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/user.dart';
import 'package:eflutter/presentation/app/models/app_info.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'app_cubit.freezed.dart';

@freezed
abstract class AppState with _$AppState {
  const factory AppState({User? user, @Default(AppInfo()) AppInfo appInfo, Failure? failure}) =
      _AppState;
}

@injectable
class AppCubit extends Cubit<AppState> {
  AppCubit() : super(const AppState()) {
    initAppInfo();
  }

  Future<void> initAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appInfo = AppInfo.fromPackageInfo(packageInfo);
    emit(state.copyWith(appInfo: appInfo));
  }

  Future<void> load() async {}

  void clear() => emit(const AppState());
}