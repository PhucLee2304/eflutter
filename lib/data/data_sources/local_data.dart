import 'package:eflutter/core/base/local_data_base.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@LazySingleton(as: LocalDataBase)
class LocalData implements LocalDataBase {
  final SharedPreferencesAsync _prefs;
  LocalData(this._prefs);

  static const _accessTokenKey = 'accessToken';
  @override
  Future<void> saveAccessToken(String token) =>
      _prefs.setString(_accessTokenKey, token);
  @override
  Future<String?> getAccessToken() => _prefs.getString(_accessTokenKey);

  static const _refreshTokenKey = 'refreshToken';
  @override
  Future<void> saveRefreshToken(String token) =>
      _prefs.setString(_refreshTokenKey, token);
  @override
  Future<String?> getRefreshToken() => _prefs.getString(_refreshTokenKey);

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await [saveAccessToken(accessToken), saveRefreshToken(refreshToken)].wait;
  }

  @override
  Future<void> clearTokens() async {
    await [
      _prefs.remove(_accessTokenKey),
      _prefs.remove(_refreshTokenKey),
    ].wait;
  }
}
