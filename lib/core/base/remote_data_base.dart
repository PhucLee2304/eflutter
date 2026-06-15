import 'package:eflutter/data/models/user.dart';

abstract interface class RemoteDataBase {
  Future<(String, String)> login(String idToken);

  Future<(String, String)> refreshToken(String token);

  Future<User> getMe();

  Future<User> updateMe({String? name, String? avatar});
}
