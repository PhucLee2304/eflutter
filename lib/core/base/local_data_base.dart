abstract interface class LocalDataBase {
  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();

  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();

  Future<void> saveTokens(String accessToken, String refreshToken);

  Future<void> clearTokens();
}
