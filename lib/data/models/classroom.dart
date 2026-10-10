class AssignmentScheduleInput {
  const AssignmentScheduleInput({
    required this.classroomId,
    required this.duration,
    required this.opensAt,
    required this.dueAt,
  });

  final int classroomId;
  final int duration;
  final DateTime opensAt;
  final DateTime dueAt;
}

class CreateAssignmentQuestion {
  const CreateAssignmentQuestion({
    required this.content,
    required this.explanation,
    required this.options,
    required this.correctOptionIndex,
    this.excludedFromScore = false,
    this.id = 0,
    this.optionIds = const [],
  });

  final String content;
  final String explanation;
  final List<String> options;
  final int correctOptionIndex;
  final bool excludedFromScore;
  final int id;
  final List<int> optionIds;
}

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

class AssignmentSubmission {
  const AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.attemptId,
    required this.status,
    this.syncStatus = 'NOT_STARTED',
    this.student,
    this.score,
  });

  final int id;
  final int assignmentId;
  final int attemptId;
  final String status;
  final String syncStatus;
  final ClassroomUser? student;
  final double? score;

  factory AssignmentSubmission.fromJson(Map<String, dynamic> json) =>
      AssignmentSubmission(
        id: (json['id'] as num?)?.toInt() ?? 0,
        assignmentId: (json['assignmentId'] as num?)?.toInt() ?? 0,
        attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'NOT_STARTED',
        syncStatus: json['syncStatus'] as String? ?? 'NOT_STARTED',
        student: json['student'] is Map<String, dynamic>
            ? ClassroomUser.fromJson(json['student'] as Map<String, dynamic>)
            : null,
        score: (json['score'] as num?)?.toDouble(),
      );
}

class ClassroomAssignment {
  const ClassroomAssignment({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.examId,
    required this.duration,
    required this.opensAt,
    required this.dueAt,
    required this.active,
    this.description,
    this.submission,
    this.submissions = const [],
  });

  final int id;
  final int classroomId;
  final String title;
  final String? description;
  final int examId;
  final int duration;
  final DateTime opensAt;
  final DateTime dueAt;
  final bool active;
  final AssignmentSubmission? submission;
  final List<AssignmentSubmission> submissions;

  factory ClassroomAssignment.fromJson(Map<String, dynamic> json) =>
      ClassroomAssignment(
        id: (json['id'] as num).toInt(),
        classroomId: (json['classroomId'] as num).toInt(),
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        examId: (json['examId'] as num).toInt(),
        duration: (json['duration'] as num?)?.toInt() ?? 60,
        opensAt: DateTime.parse(json['opensAt'] as String).toLocal(),
        dueAt: DateTime.parse(json['dueAt'] as String).toLocal(),
        active: json['active'] as bool? ?? true,
        submission: json['submission'] is Map<String, dynamic>
            ? AssignmentSubmission.fromJson(
                json['submission'] as Map<String, dynamic>,
              )
            : null,
        submissions: (json['submissions'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  AssignmentSubmission.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class ClassroomAssignmentPage {
  const ClassroomAssignmentPage({
    required this.items,
    required this.pageCounts,
  });

  final List<ClassroomAssignment> items;
  final int pageCounts;

  factory ClassroomAssignmentPage.fromJson(Map<String, dynamic> json) =>
      ClassroomAssignmentPage(
        items: (json['data'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  ClassroomAssignment.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        pageCounts: (json['pageCounts'] as num?)?.toInt() ?? 1,
      );
}

class EditableAssignment {
  const EditableAssignment({
    required this.id,
    required this.examId,
    required this.title,
    this.description,
    required this.questions,
    required this.hasAttempts,
    required this.activeAttempts,
    required this.submittedAttempts,
    required this.affectedAssignments,
  });
  final int id;
  final int examId;
  final String title;
  final String? description;
  final List<EditableAssignmentQuestion> questions;
  final bool hasAttempts;
  final int activeAttempts;
  final int submittedAttempts;
  final List<AffectedAssignment> affectedAssignments;

  factory EditableAssignment.fromJson(
    Map<String, dynamic> json,
  ) => EditableAssignment(
    id: (json['id'] as num).toInt(),
    examId: (json['examId'] as num).toInt(),
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    questions: (json['questions'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              EditableAssignmentQuestion.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    hasAttempts: json['hasAttempts'] as bool? ?? false,
    activeAttempts: (json['activeAttempts'] as num?)?.toInt() ?? 0,
    submittedAttempts: (json['submittedAttempts'] as num?)?.toInt() ?? 0,
    affectedAssignments:
        (json['affectedAssignments'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  AffectedAssignment.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
  );
}

class AffectedAssignment {
  const AffectedAssignment({
    required this.id,
    required this.classroomId,
    required this.classroomName,
    required this.active,
  });
  final int id;
  final int classroomId;
  final String classroomName;
  final bool active;

  factory AffectedAssignment.fromJson(Map<String, dynamic> json) =>
      AffectedAssignment(
        id: (json['id'] as num).toInt(),
        classroomId: (json['classroomId'] as num).toInt(),
        classroomName: json['classroomName'] as String? ?? '',
        active: json['active'] as bool? ?? false,
      );
}

class EditableAssignmentQuestion {
  const EditableAssignmentQuestion({
    required this.content,
    this.explanation,
    required this.options,
    required this.correctOptionIndex,
    required this.excludedFromScore,
    required this.id,
    required this.optionIds,
  });
  final String content;
  final String? explanation;
  final List<String> options;
  final int correctOptionIndex;
  final bool excludedFromScore;
  final int id;
  final List<int> optionIds;

  factory EditableAssignmentQuestion.fromJson(Map<String, dynamic> json) =>
      EditableAssignmentQuestion(
        content: json['content'] as String? ?? '',
        explanation: json['explanation'] as String?,
        options: (json['options'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
        correctOptionIndex: (json['correctOptionIndex'] as num?)?.toInt() ?? 0,
        excludedFromScore: json['excludedFromScore'] as bool? ?? false,
        id: (json['id'] as num?)?.toInt() ?? 0,
        optionIds: (json['optionIds'] as List<dynamic>? ?? const [])
            .map((item) => (item as num).toInt())
            .toList(),
      );
}

class CreatedAssignments {
  const CreatedAssignments(this.assignments);

  final List<ClassroomAssignment> assignments;

  factory CreatedAssignments.fromJson(Map<String, dynamic> json) =>
      CreatedAssignments(
        (json['assignments'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  ClassroomAssignment.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}
