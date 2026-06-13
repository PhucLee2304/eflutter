abstract interface class RemoteDataBase {
  Future<(String, String)> login(String idToken);

  Future<(String, String)> refreshToken(String token);
}
