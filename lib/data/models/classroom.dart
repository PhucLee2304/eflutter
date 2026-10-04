class ClassroomUser {
  const ClassroomUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
  });
  final String id;
  final String name;
  final String email;
  final String? avatar;

  factory ClassroomUser.fromJson(Map<String, dynamic> json) => ClassroomUser(
    id: json['id'].toString(),
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    avatar: json['avatar'] as String?,
  );
}

class ClassroomMember {
  const ClassroomMember({required this.id, this.user, this.approved});
  final int id;
  final ClassroomUser? user;
  final bool? approved;

  factory ClassroomMember.fromJson(Map<String, dynamic> json) =>
      ClassroomMember(
        id: (json['id'] as num).toInt(),
        user: json['user'] is Map<String, dynamic>
            ? ClassroomUser.fromJson(json['user'] as Map<String, dynamic>)
            : null,
        approved: json['approved'] as bool?,
      );
}

class Classroom {
  const Classroom({
    required this.id,
    required this.code,
    required this.name,
    required this.active,
    this.description,
    this.avatar,
    this.teacher,
    this.members = const [],
    this.countApprovedMembers,
  });
  final int id;
  final String code;
  final String name;
  final bool active;
  final String? description;
  final String? avatar;
  final ClassroomUser? teacher;
  final List<ClassroomMember> members;
  final int? countApprovedMembers;

  factory Classroom.fromJson(Map<String, dynamic> json) => Classroom(
    id: (json['id'] as num).toInt(),
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    active: json['active'] as bool? ?? false,
    description: json['description'] as String?,
    avatar: json['avatar'] as String?,
    teacher: json['teacher'] is Map<String, dynamic>
        ? ClassroomUser.fromJson(json['teacher'] as Map<String, dynamic>)
        : null,
    members: (json['members'] as List<dynamic>? ?? const [])
        .map((e) => ClassroomMember.fromJson(e as Map<String, dynamic>))
        .toList(),
    countApprovedMembers: (json['countApprovedMembers'] as num?)?.toInt(),
  );
}

class ClassroomPage {
  const ClassroomPage({required this.items, required this.pageCounts});
  final List<Classroom> items;
  final int pageCounts;

  factory ClassroomPage.fromJson(Map<String, dynamic> json) => ClassroomPage(
    items: (json['data'] as List<dynamic>? ?? const [])
        .map((e) => Classroom.fromJson(e as Map<String, dynamic>))
        .toList(),
    pageCounts: (json['pageCounts'] as num?)?.toInt() ?? 1,
  );
}
