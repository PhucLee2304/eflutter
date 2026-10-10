import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';

class ClassroomRepository {
  ClassroomRepository(this._dio);
  final Dio _dio;
  static const _base = '/classrooms/api/v1/classrooms';

  Future<Result<ClassroomPage>> getMine({int page = 1, String query = ''}) =>
      _dio
          .get(
            '$_base/me',
            queryParameters: {
              'page': page,
              'pageSize': 12,
              if (query.isNotEmpty) 'query': query,
            },
          )
          .then((r) => ClassroomPage.fromJson(r.data as Map<String, dynamic>))
          .safeResult();

  Future<Result<Classroom>> get(int id) => _dio
      .get('$_base/$id')
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<Classroom>> preview(String code) => _dio
      .get('$_base/code', queryParameters: {'code': code.trim().toUpperCase()})
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<Classroom>> create(String name, {String? description}) => _dio
      .post(
        _base,
        data: {
          'name': name.trim(),
          if (description != null) 'description': description.trim(),
        },
      )
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<Classroom>> update(
    int id, {
    required String name,
    String? description,
  }) => _dio
      .patch(
        '$_base/$id',
        data: {
          'name': name.trim(),
          if (description != null) 'description': description.trim(),
        },
      )
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<Classroom>> archive(int id) => _dio
      .post('$_base/$id/archive')
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<ClassroomMember>> join(String code) => _dio
      .post('$_base/join', data: {'code': code.trim().toUpperCase()})
      .then((r) => ClassroomMember.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<List<ClassroomMember>>> joinRequests(int id) => _dio
      .get('$_base/$id/members/join-requests')
      .then(
        (r) => (r.data as List<dynamic>)
            .map((e) => ClassroomMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      )
      .safeResult();

  Future<Result<ClassroomMember>> review(int id, String userId, bool approve) =>
      _dio
          .post(
            '$_base/$id/members/${Uri.encodeComponent(userId)}/'
            '${approve ? 'approve' : 'reject'}',
          )
          .then((r) => ClassroomMember.fromJson(r.data as Map<String, dynamic>))
          .safeResult();

  Future<Result<void>> remove(int id, String userId) => _dio
      .delete<void>('$_base/$id/members/${Uri.encodeComponent(userId)}')
      .then((_) {})
      .safeResult();

  Future<Result<ClassroomAssignmentPage>> getAssignments(
    int classroomId, {
    int page = 1,
    int pageSize = 20,
  }) => _dio
      .get(
        '$_base/$classroomId/assignments',
        queryParameters: {'page': page, 'pageSize': pageSize},
      )
      .then(
        (response) => ClassroomAssignmentPage.fromJson(
          response.data as Map<String, dynamic>,
        ),
      )
      .safeResult();

  Future<Result<ClassroomAssignment>> getAssignment(
    int classroomId,
    int assignmentId,
  ) => _dio
      .get('$_base/$classroomId/assignments/$assignmentId')
      .then(
        (response) =>
            ClassroomAssignment.fromJson(response.data as Map<String, dynamic>),
      )
      .safeResult();

  Future<Result<ClassroomAssignment>> getGradebook(
    int classroomId,
    int assignmentId,
  ) => _dio
      .get('$_base/$classroomId/assignments/$assignmentId/gradebook')
      .then(
        (response) =>
            ClassroomAssignment.fromJson(response.data as Map<String, dynamic>),
      )
      .safeResult();

  Future<Result<void>> resetAssignmentAttempt({
    required int classroomId,
    required int assignmentId,
    required String studentId,
  }) => _dio
      .delete<void>(
        '$_base/$classroomId/assignments/$assignmentId/students/'
        '${Uri.encodeComponent(studentId)}/attempt',
      )
      .then((_) {})
      .safeResult();

  Future<Result<int>> reconcileGradebook({
    required int classroomId,
    required int assignmentId,
  }) => _dio
      .post('$_base/$classroomId/assignments/$assignmentId/gradebook/reconcile')
      .then(
        (response) => (response.data['enqueuedCount'] as num?)?.toInt() ?? 0,
      )
      .safeResult();

  Future<Result<List<ExamAudit>>> getAssignmentAudits({
    required int classroomId,
    required int assignmentId,
  }) => _dio
      .get('$_base/$classroomId/assignments/$assignmentId/audits')
      .then(
        (response) => (response.data as List<dynamic>)
            .map((item) => ExamAudit.fromJson(item as Map<String, dynamic>))
            .toList(),
      )
      .safeResult();

  Future<Result<List<CalendarEntry>>> getCalendar({
    required int classroomId,
    required DateTime from,
    required DateTime to,
  }) => _dio
      .get(
        '$_base/$classroomId/calendar',
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      )
      .then(
        (response) => (response.data as List<dynamic>)
            .map((item) => CalendarEntry.fromJson(item as Map<String, dynamic>))
            .toList(),
      )
      .safeResult();

  Future<Result<CalendarEntry>> createSchedule({
    required int classroomId,
    required ClassroomScheduleInput input,
  }) => _dio
      .post('$_base/$classroomId/schedules', data: input.toJson())
      .then(
        (response) =>
            CalendarEntry.fromJson(response.data as Map<String, dynamic>),
      )
      .safeResult();

  Future<Result<CalendarEntry>> updateSchedule({
    required int classroomId,
    required int scheduleId,
    required ClassroomScheduleInput input,
  }) => _dio
      .patch('$_base/$classroomId/schedules/$scheduleId', data: input.toJson())
      .then(
        (response) =>
            CalendarEntry.fromJson(response.data as Map<String, dynamic>),
      )
      .safeResult();

  Future<Result<void>> deleteSchedule({
    required int classroomId,
    required int scheduleId,
  }) => _dio
      .delete<void>('$_base/$classroomId/schedules/$scheduleId')
      .then((_) {})
      .safeResult();

  Future<Result<ClassroomAssignment>> setAssignmentActive(
    int classroomId,
    int assignmentId,
    bool active,
  ) => _dio
      .patch(
        '$_base/$classroomId/assignments/$assignmentId/active',
        data: {'active': active},
      )
      .then(
        (response) =>
            ClassroomAssignment.fromJson(response.data as Map<String, dynamic>),
      )
      .safeResult();

  Future<Result<CreatedAssignments>> createAssignments({
    required List<AssignmentScheduleInput> schedules,
    required String title,
    required String description,
    required List<CreateAssignmentQuestion> questions,
  }) => _dio
      .post(
        '$_base/assignments',
        data: {
          'title': title.trim(),
          'description': description.trim(),
          'questions': questions
              .map(
                (question) => {
                  'content': question.content,
                  'explanation': question.explanation,
                  'options': question.options,
                  'correctOptionIndex': question.correctOptionIndex,
                },
              )
              .toList(),
          'schedules': schedules
              .map(
                (schedule) => {
                  'classroomId': schedule.classroomId,
                  'duration': schedule.duration,
                  'opensAt': schedule.opensAt.toUtc().toIso8601String(),
                  'dueAt': schedule.dueAt.toUtc().toIso8601String(),
                },
              )
              .toList(),
        },
      )
      .then(
        (response) =>
            CreatedAssignments.fromJson(response.data as Map<String, dynamic>),
      )
      .safeResult();

  Future<Result<EditableAssignment>> getEditableAssignment(
    int classroomId,
    int assignmentId,
  ) => _dio
      .get('$_base/$classroomId/assignments/$assignmentId/edit')
      .then(
        (response) =>
            EditableAssignment.fromJson(response.data as Map<String, dynamic>),
      )
      .safeResult();

  Future<Result<EditableAssignment>> updateAssignmentContent({
    required int classroomId,
    required int assignmentId,
    required String title,
    required String description,
    required List<CreateAssignmentQuestion> questions,
    required bool confirm,
    required String reason,
  }) => _dio
      .patch(
        '$_base/$classroomId/assignments/$assignmentId',
        data: {
          'title': title.trim(),
          'description': description.trim(),
          'confirm': confirm,
          'reason': reason.trim(),
          'questions': questions
              .map(
                (question) => {
                  'content': question.content.trim(),
                  'explanation': question.explanation.trim(),
                  'options': question.options
                      .map((option) => option.trim())
                      .toList(),
                  'correctOptionIndex': question.correctOptionIndex,
                  'excludedFromScore': question.excludedFromScore,
                  'id': question.id,
                  'optionIds': question.optionIds,
                },
              )
              .toList(),
        },
      )
      .then(
        (response) =>
            EditableAssignment.fromJson(response.data as Map<String, dynamic>),
      )
      .safeResult();

  Future<Result<CreatedAssignments>> assignExistingExam({
    required int classroomId,
    required int assignmentId,
    required List<AssignmentScheduleInput> schedules,
  }) => _dio
      .post(
        '$_base/$classroomId/assignments/$assignmentId/classrooms',
        data: {
          'schedules': schedules
              .map(
                (schedule) => {
                  'classroomId': schedule.classroomId,
                  'duration': schedule.duration,
                  'opensAt': schedule.opensAt.toUtc().toIso8601String(),
                  'dueAt': schedule.dueAt.toUtc().toIso8601String(),
                },
              )
              .toList(),
        },
      )
      .then(
        (response) =>
            CreatedAssignments.fromJson(response.data as Map<String, dynamic>),
      )
      .safeResult();

  Future<Result<ClassroomAssignment>> updateAssignmentSchedule({
    required int classroomId,
    required int assignmentId,
    required int duration,
    required DateTime opensAt,
    required DateTime dueAt,
    bool confirm = false,
  }) => _dio
      .patch(
        '$_base/$classroomId/assignments/$assignmentId/schedule',
        data: {
          'duration': duration,
          'opensAt': opensAt.toUtc().toIso8601String(),
          'dueAt': dueAt.toUtc().toIso8601String(),
          'confirm': confirm,
        },
      )
      .then(
        (response) =>
            ClassroomAssignment.fromJson(response.data as Map<String, dynamic>),
      )
      .safeResult();
}
