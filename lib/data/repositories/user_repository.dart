import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/user.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class UserRepository {
  final RemoteDataBase _remoteData;

  UserRepository(this._remoteData);

  Future<Result<User>> getMe() => _remoteData.getMe().safeResult();

  Future<Result<User>> updateMe({String? name, String? avatar}) =>
      _remoteData.updateMe(name: name, avatar: avatar).safeResult();
}
