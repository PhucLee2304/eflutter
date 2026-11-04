import 'package:web/web.dart';

/// Token phiên do server cấp (mục 1.4), giữ trong `sessionStorage` để F5 vẫn dùng
/// được. Tab nhân bản chép cả token nhưng server xoay token mỗi lần claim.
class IntegritySessionStore {
  static String _key(int attemptId) => 'ego.attemptSession.$attemptId';

  String? read(int attemptId) => window.sessionStorage.getItem(_key(attemptId));

  void write(int attemptId, String token) =>
      window.sessionStorage.setItem(_key(attemptId), token);

  void remove(int attemptId) =>
      window.sessionStorage.removeItem(_key(attemptId));
}
