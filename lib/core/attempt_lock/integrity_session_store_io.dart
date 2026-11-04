/// Token phiên do server cấp (mục 1.4). Mobile/desktop: chỉ giữ trong bộ nhớ.
class IntegritySessionStore {
  static final _tokens = <int, String>{};

  String? read(int attemptId) => _tokens[attemptId];

  void write(int attemptId, String token) => _tokens[attemptId] = token;

  void remove(int attemptId) => _tokens.remove(attemptId);
}
