// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: (json['id'] as num).toInt(),
  email: json['email'] as String,
  name: json['name'] as String,
  avatar: json['avatar'] as String?,
  role: json['role'] as String? ?? '',
  blockedAt: json['blockedAt'] == null ? null : DateTime.parse(json['blockedAt'] as String),
  createdAt: json['createdAt'] == null ? null : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'name': instance.name,
  'avatar': instance.avatar,
  'role': instance.role,
  'blockedAt': instance.blockedAt?.toIso8601String(),
  'createdAt': instance.createdAt?.toIso8601String(),
};
