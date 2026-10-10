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

class ExamAuditScoreChange {
  const ExamAuditScoreChange({
    required this.attemptId,
    required this.studentId,
    this.beforeScore,
    this.afterScore,
  });

  final int attemptId;
  final String studentId;
  final double? beforeScore;
  final double? afterScore;

  factory ExamAuditScoreChange.fromJson(Map<String, dynamic> json) =>
      ExamAuditScoreChange(
        attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
        studentId: json['studentId'] as String? ?? '',
        beforeScore: (json['beforeScore'] as num?)?.toDouble(),
        afterScore: (json['afterScore'] as num?)?.toDouble(),
      );
}

class ExamAudit {
  const ExamAudit({
    required this.id,
    required this.examId,
    required this.actorId,
    this.actor,
    required this.reason,
    required this.createdAt,
    required this.scoreChanges,
    this.regradedAt,
  });

  final int id;
  final int examId;
  final String actorId;
  final ClassroomUser? actor;
  final String reason;
  final DateTime createdAt;
  final DateTime? regradedAt;
  final List<ExamAuditScoreChange> scoreChanges;

  factory ExamAudit.fromJson(Map<String, dynamic> json) => ExamAudit(
    id: (json['id'] as num?)?.toInt() ?? 0,
    examId: (json['examId'] as num?)?.toInt() ?? 0,
    actorId: json['actorId'] as String? ?? '',
    actor: json['actor'] is Map<String, dynamic>
        ? ClassroomUser.fromJson(json['actor'] as Map<String, dynamic>)
        : null,
    reason: json['reason'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    regradedAt: json['regradedAt'] == null
        ? null
        : DateTime.parse(json['regradedAt'] as String).toLocal(),
    scoreChanges: (json['scoreChanges'] as List<dynamic>? ?? const [])
        .map(
          (item) => ExamAuditScoreChange.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
  );
}

class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.classroomId,
    required this.calendarType,
    required this.title,
    required this.startsAt,
    required this.editable,
    this.description,
    this.endsAt,
    this.relatedAssignmentId,
  });

  final int id;
  final int classroomId;
  final String calendarType;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? relatedAssignmentId;
  final bool editable;

  factory CalendarEntry.fromJson(Map<String, dynamic> json) => CalendarEntry(
    id: (json['id'] as num?)?.toInt() ?? 0,
    classroomId: (json['classroomId'] as num?)?.toInt() ?? 0,
    calendarType: json['calendarType'] as String? ?? 'CLASS_SCHEDULE',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
    endsAt: json['endsAt'] == null
        ? null
        : DateTime.parse(json['endsAt'] as String).toLocal(),
    relatedAssignmentId: (json['relatedAssignmentId'] as num?)?.toInt(),
    editable: json['editable'] as bool? ?? false,
  );
}

class ClassroomScheduleInput {
  const ClassroomScheduleInput({
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.description = '',
  });

  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime endsAt;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
  };
}

class StudentAssignmentProgress {
  const StudentAssignmentProgress({
    required this.assignmentId,
    required this.title,
    required this.dueAt,
    required this.status,
    this.score,
  });
  final int assignmentId;
  final String title;
  final DateTime dueAt;
  final String status;
  final double? score;
  factory StudentAssignmentProgress.fromJson(Map<String, dynamic> json) =>
      StudentAssignmentProgress(
        assignmentId: (json['assignmentId'] as num).toInt(),
        title: json['title'] as String? ?? '',
        dueAt: DateTime.parse(json['dueAt'] as String).toLocal(),
        status: json['status'] as String? ?? 'NOT_STARTED',
        score: (json['score'] as num?)?.toDouble(),
      );
}

class StudentProgress {
  const StudentProgress({
    required this.student,
    required this.assignments,
    required this.completionRate,
    this.averageScore,
  });
  final ClassroomUser student;
  final List<StudentAssignmentProgress> assignments;
  final double? averageScore;
  final double completionRate;
  factory StudentProgress.fromJson(Map<String, dynamic> json) =>
      StudentProgress(
        student: ClassroomUser.fromJson(
          json['student'] as Map<String, dynamic>,
        ),
        assignments: (json['assignments'] as List<dynamic>? ?? const [])
            .map(
              (e) =>
                  StudentAssignmentProgress.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        averageScore: (json['averageScore'] as num?)?.toDouble(),
        completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0,
      );
}

class ClassGradebook {
  const ClassGradebook({
    required this.classroomId,
    required this.assignments,
    required this.students,
    required this.completionRate,
    this.averageScore,
  });
  final int classroomId;
  final List<Map<String, dynamic>> assignments;
  final List<StudentProgress> students;
  final double? averageScore;
  final double completionRate;
  factory ClassGradebook.fromJson(Map<String, dynamic> json) => ClassGradebook(
    classroomId: (json['classroomId'] as num).toInt(),
    assignments: (json['assignments'] as List<dynamic>? ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .toList(),
    students: (json['students'] as List<dynamic>? ?? const [])
        .map((e) => StudentProgress.fromJson(e as Map<String, dynamic>))
        .toList(),
    averageScore: (json['averageScore'] as num?)?.toDouble(),
    completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0,
  );
}

class QuestionAnalytics {
  const QuestionAnalytics({
    required this.questionId,
    required this.content,
    required this.order,
    required this.answeredCount,
    required this.wrongCount,
    required this.wrongRate,
  });
  final int questionId, order, answeredCount, wrongCount;
  final String content;
  final double wrongRate;
  factory QuestionAnalytics.fromJson(Map<String, dynamic> json) =>
      QuestionAnalytics(
        questionId: (json['questionId'] as num).toInt(),
        content: json['content'] as String? ?? '',
        order: (json['order'] as num).toInt(),
        answeredCount: (json['answeredCount'] as num).toInt(),
        wrongCount: (json['wrongCount'] as num).toInt(),
        wrongRate: (json['wrongRate'] as num?)?.toDouble() ?? 0,
      );
}

class AssignmentAnalytics {
  const AssignmentAnalytics({
    required this.totalStudents,
    required this.notStarted,
    required this.inProgress,
    required this.submitted,
    required this.late,
    required this.completionRate,
    required this.questions,
    this.averageScore,
    this.minimumScore,
    this.maximumScore,
  });
  final int totalStudents, notStarted, inProgress, submitted, late;
  final double? averageScore, minimumScore, maximumScore;
  final double completionRate;
  final List<QuestionAnalytics> questions;
  factory AssignmentAnalytics.fromJson(Map<String, dynamic> json) =>
      AssignmentAnalytics(
        totalStudents: (json['totalStudents'] as num).toInt(),
        notStarted: (json['notStarted'] as num).toInt(),
        inProgress: (json['inProgress'] as num).toInt(),
        submitted: (json['submitted'] as num).toInt(),
        late: (json['late'] as num).toInt(),
        averageScore: (json['averageScore'] as num?)?.toDouble(),
        minimumScore: (json['minimumScore'] as num?)?.toDouble(),
        maximumScore: (json['maximumScore'] as num?)?.toDouble(),
        completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0,
        questions: (json['questions'] as List<dynamic>? ?? const [])
            .map((e) => QuestionAnalytics.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
