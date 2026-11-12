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
