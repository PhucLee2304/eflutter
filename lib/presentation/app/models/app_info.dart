import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'app_info.freezed.dart';

@freezed
sealed class AppInfo with _$AppInfo {
  const factory AppInfo({
    @Default('MyEgo') String appName,
    @Default('vn.kaizengo.ego') String packageName,
    @Default('1.0.0') String version,
    @Default(0) int buildNumber,
  }) = _AppInfo;

  const AppInfo._();

  String get buildName => 'v$version+$buildNumber';

  factory AppInfo.fromPackageInfo(PackageInfo packageInfo) {
    return AppInfo(
      appName: packageInfo.appName,
      packageName: packageInfo.packageName,
      version: packageInfo.version,
      buildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
    );
  }
}