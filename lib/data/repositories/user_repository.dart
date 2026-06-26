import 'dart:typed_data';

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

  Future<Result<String>> getPresignedUploadUrl({
    required String fileName,
    required String contentType,
    required String folder,
  }) => _remoteData
      .getPresignedUploadUrl(
        fileName: fileName,
        contentType: contentType,
        folder: folder,
      )
      .safeResult();

  Future<Result<void>> uploadBinaryToUrl({
    required String url,
    required Uint8List bytes,
    required String contentType,
  }) => _remoteData
      .uploadBinaryToUrl(url: url, bytes: bytes, contentType: contentType)
      .safeResult();
}
