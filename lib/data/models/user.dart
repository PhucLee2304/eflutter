import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class User with _$User {
  const factory User({
    required int id,
    required String email,
    required String name,
    String? avatar,
    @Default('') String role,
    DateTime? blockedAt,
    DateTime? createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

class UserPage {
  const UserPage({required this.items, required this.pageCounts, this.total = 0});
  final List<User> items;
  final int pageCounts;
  final int total;

  factory UserPage.fromJson(Map<String, dynamic> json) => UserPage(
    items: (json['data'] as List<dynamic>? ?? const [])
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList(),
    pageCounts: (json['pageCounts'] as num?)?.toInt() ?? 1,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );
}

/// Số liệu trên thẻ tiêu đề màn Users của admin, không phụ thuộc bộ lọc.
class UsersSummary {
  const UsersSummary({this.total = 0, this.admins = 0, this.blocked = 0});
  final int total;
  final int admins;
  final int blocked;

  factory UsersSummary.fromJson(Map<String, dynamic> json) => UsersSummary(
    total: (json['total'] as num?)?.toInt() ?? 0,
    admins: (json['admins'] as num?)?.toInt() ?? 0,
    blocked: (json['blocked'] as num?)?.toInt() ?? 0,
  );
}
