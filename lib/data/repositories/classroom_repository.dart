import 'package:eflutter/data/models/attempt_integrity.dart';
import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';

class ClassroomRepository {
  ClassroomRepository(this._dio);
  final Dio _dio;
  static const _base = '/classrooms/api/v1/classrooms';

  Future<Result<ClassroomPage>> getMine({int page = 1, String query = '', bool? active}) => _dio
      .get(
        '$_base/me',
        queryParameters: {
          'page': page,
          'pageSize': 12,
          if (query.isNotEmpty) 'query': query,
          'active': ?active,
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

  /// [avatar] là tên file đã upload vào thư mục `avatars`; backend đổi thành URL công khai.
  Future<Result<Classroom>> create(String name, {String? description, String? avatar}) => _dio
      .post(
        _base,
        data: {
          'name': name.trim(),
          if (description != null) 'description': description.trim(),
          'avatar': ?avatar,
        },
      )
      .then((r) => Classroom.fromJson(r.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<Classroom>> update(int id, {required String name, String? description}) => _dio
      .patch(
        '$_base/$id',
        data: {'name': name.trim(), if (description != null) 'description': description.trim()},
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

  Future<Result<ClassroomMember>> review(int id, String userId, bool approve) => _dio
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
      .get('$_base/$classroomId/assignments', queryParameters: {'page': page, 'pageSize': pageSize})
      .then((response) => ClassroomAssignmentPage.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<ClassroomAssignment>> getAssignment(int classroomId, int assignmentId) => _dio
      .get('$_base/$classroomId/assignments/$assignmentId')
      .then((response) => ClassroomAssignment.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<ClassroomAssignment>> getGradebook(int classroomId, int assignmentId) => _dio
      .get('$_base/$classroomId/assignments/$assignmentId/gradebook')
      .then((response) => ClassroomAssignment.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<ClassGradebook>> getClassGradebook(
    int classroomId, {
    DateTime? from,
    DateTime? to,
  }) => _dio
      .get(
        '$_base/$classroomId/gradebook',
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
        },
      )
      .then((response) => ClassGradebook.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<StudentProgress>> getStudentProgress(int classroomId, String studentId) => _dio
      .get('$_base/$classroomId/students/${Uri.encodeComponent(studentId)}/progress')
      .then((response) => StudentProgress.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<AssignmentAnalytics>> getAssignmentAnalytics(int classroomId, int assignmentId) =>
      _dio
          .get('$_base/$classroomId/assignments/$assignmentId/analytics')
          .then((response) => AssignmentAnalytics.fromJson(response.data as Map<String, dynamic>))
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

  // Giám sát (PLAN_ATTEMPT_INTEGRITY.md mục 1.9).

  Future<Result<IntegrityEventPage>> getIntegrityEvents({
    required int classroomId,
    required int assignmentId,
    String? studentId,
    bool pending = false,
    String? level,
    int page = 1,
    int pageSize = 100,
  }) => _dio
      .get(
        '$_base/$classroomId/assignments/$assignmentId/integrity-events',
        queryParameters: {
          'studentId': ?studentId,
          if (pending) 'pending': true,
          'level': ?level,
          'page': page,
          'pageSize': pageSize,
        },
      )
      .then((response) => IntegrityEventPage.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<void>> reviewIntegrityEvent({
    required int classroomId,
    required int assignmentId,
    required String eventId,
    required String action,
  }) => _dio
      .post<void>(
        '$_base/$classroomId/assignments/$assignmentId/integrity-events/'
        '${Uri.encodeComponent(eventId)}/review',
        data: {'action': action},
      )
      .then((_) {})
      .safeResult();

  Future<Result<void>> banAttempt({
    required int classroomId,
    required int assignmentId,
    required String studentId,
    String? note,
  }) => _studentAttemptAction(classroomId, assignmentId, studentId, 'ban', {'note': ?note});

  Future<Result<void>> releaseAttemptSession({
    required int classroomId,
    required int assignmentId,
    required String studentId,
  }) => _studentAttemptAction(classroomId, assignmentId, studentId, 'release-session', const {});

  Future<Result<void>> reinstateAttempt({
    required int classroomId,
    required int assignmentId,
    required String studentId,
    required String note,
  }) => _studentAttemptAction(classroomId, assignmentId, studentId, 'reinstate', {
    'note': note.trim(),
  });

  Future<Result<void>> _studentAttemptAction(
    int classroomId,
    int assignmentId,
    String studentId,
    String action,
    Map<String, dynamic> body,
  ) => _dio
      .post<void>(
        '$_base/$classroomId/assignments/$assignmentId/students/'
        '${Uri.encodeComponent(studentId)}/attempt/$action',
        data: body,
      )
      .then((_) {})
      .safeResult();

  Future<Result<int>> reconcileGradebook({required int classroomId, required int assignmentId}) =>
      _dio
          .post('$_base/$classroomId/assignments/$assignmentId/gradebook/reconcile')
          .then((response) => (response.data['enqueuedCount'] as num?)?.toInt() ?? 0)
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
      .then((response) => CalendarEntry.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<CalendarEntry>> updateSchedule({
    required int classroomId,
    required int scheduleId,
    required ClassroomScheduleInput input,
  }) => _dio
      .patch('$_base/$classroomId/schedules/$scheduleId', data: input.toJson())
      .then((response) => CalendarEntry.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<void>> deleteSchedule({required int classroomId, required int scheduleId}) =>
      _dio.delete<void>('$_base/$classroomId/schedules/$scheduleId').then((_) {}).safeResult();

  Future<Result<ClassroomRoom>> getRoom(int classroomId, int roomId) => _dio
      .get('$_base/$classroomId/rooms/$roomId')
      .then((response) => ClassroomRoom.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<RoomActivity>> getRoomActivity(int classroomId, int roomId) => _dio
      .get('$_base/$classroomId/rooms/$roomId/activity')
      .then((response) => RoomActivity.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<ClassroomRoom>> startRoom(int classroomId, int roomId) => _dio
      .post('$_base/$classroomId/rooms/$roomId/start')
      .then((response) => ClassroomRoom.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<RoomConnection>> joinRoom(int classroomId, int roomId) => _dio
      .post('$_base/$classroomId/rooms/$roomId/join')
      .then((response) => RoomConnection.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<ClassroomRoom>> endRoom(int classroomId, int roomId) => _dio
      .post('$_base/$classroomId/rooms/$roomId/end')
      .then((response) => ClassroomRoom.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  String _screenSharePath(int classroomId, int roomId, [String? userId]) =>
      '$_base/$classroomId/rooms/$roomId/screen-share'
      '${userId == null ? '' : '/${Uri.encodeComponent(userId)}'}';

  Future<Result<RoomParticipantState>> requestScreenShare(int classroomId, int roomId) => _dio
      .post('${_screenSharePath(classroomId, roomId)}/request')
      .then((response) => RoomParticipantState.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<RoomParticipantState>> reviewScreenShare(
    int classroomId,
    int roomId,
    String userId, {
    required bool approve,
  }) => _dio
      .post('${_screenSharePath(classroomId, roomId, userId)}/${approve ? 'approve' : 'reject'}')
      .then((response) => RoomParticipantState.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<RoomParticipantState>> setHandRaised(
    int classroomId,
    int roomId, {
    required bool raised,
  }) => _dio
      .patch('$_base/$classroomId/rooms/$roomId/hand', data: {'raised': raised})
      .then((response) => RoomParticipantState.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  /// Giáo viên hạ tay một học sinh ([userId]) hoặc tất cả; trả về user đã hạ.
  Future<Result<List<String>>> lowerHands(int classroomId, int roomId, {String? userId}) => _dio
      .delete(
        '$_base/$classroomId/rooms/$roomId/hands'
        '${userId == null ? '' : '/${Uri.encodeComponent(userId)}'}',
      )
      .then(
        (response) =>
            ((response.data as Map<String, dynamic>)['userIds'] as List<dynamic>? ?? const [])
                .cast<String>(),
      )
      .safeResult();

  /// Giáo viên đổi quyền thiết bị của một học sinh. Cho phép lại chỉ cấp
  /// quyền; học sinh vẫn tự bật thiết bị của mình.
  Future<Result<RoomParticipantState>> moderateParticipantDevice(
    int classroomId,
    int roomId,
    String userId,
    RoomDeviceModeration action,
  ) => _dio
      .post(
        '$_base/$classroomId/rooms/$roomId/participants/'
        '${Uri.encodeComponent(userId)}/${action.path}',
      )
      .then((response) => RoomParticipantState.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<List<String>>> muteAllParticipants(int classroomId, int roomId) => _dio
      .post('$_base/$classroomId/rooms/$roomId/participants/mute-all')
      .then(
        (response) =>
            ((response.data as Map<String, dynamic>)['userIds'] as List<dynamic>? ?? const [])
                .cast<String>(),
      )
      .safeResult();

  /// Đưa học sinh ra khỏi phòng (không xóa khỏi lớp) và khóa vào lại đến hết
  /// buổi học.
  Future<Result<RoomParticipantState>> removeParticipant(
    int classroomId,
    int roomId,
    String userId, {
    String? reason,
  }) => _dio
      .post(
        '$_base/$classroomId/rooms/$roomId/participants/'
        '${Uri.encodeComponent(userId)}/remove',
        data: reason == null || reason.trim().isEmpty ? null : {'reason': reason.trim()},
      )
      .then((response) => RoomParticipantState.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  /// Gọi ngay trước khi publish; backend dừng lượt chia sẻ khác trong phòng.
  Future<Result<void>> startScreenShare(int classroomId, int roomId) =>
      _dio.post<void>('${_screenSharePath(classroomId, roomId)}/start').then((_) {}).safeResult();

  Future<Result<void>> stopScreenShare(int classroomId, int roomId, String userId) => _dio
      .post<void>('${_screenSharePath(classroomId, roomId, userId)}/stop')
      .then((_) {})
      .safeResult();

  Future<Result<List<RoomAttendanceSession>>> getRoomAttendance(int classroomId, int roomId) => _dio
      .get('$_base/$classroomId/rooms/$roomId/attendance')
      .then(
        (response) => (response.data as List<dynamic>)
            .map((item) => RoomAttendanceSession.fromJson(item as Map<String, dynamic>))
            .toList(),
      )
      .safeResult();

  Future<Result<ClassroomAssignment>> setAssignmentActive(
    int classroomId,
    int assignmentId,
    bool active,
  ) => _dio
      .patch('$_base/$classroomId/assignments/$assignmentId/active', data: {'active': active})
      .then((response) => ClassroomAssignment.fromJson(response.data as Map<String, dynamic>))
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
                  'excludedFromScore': question.excludedFromScore,
                },
              )
              .toList(),
          'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
        },
      )
      .then((response) => CreatedAssignments.fromJson(response.data as Map<String, dynamic>))
      .safeResult();

  Future<Result<EditableAssignment>> getEditableAssignment(int classroomId, int assignmentId) =>
      _dio
          .get('$_base/$classroomId/assignments/$assignmentId/edit')
          .then((response) => EditableAssignment.fromJson(response.data as Map<String, dynamic>))
          .safeResult();

  /// Lưu màn sửa bài, cùng dạng với lúc tạo: cả nội dung đề và lịch các lớp được tích.
  /// Backend tự so với dữ liệu hiện có và chỉ ghi phần thay đổi (một transaction).
  /// 409 nghĩa là thay đổi ảnh hưởng bài đang làm, cần gửi lại với [confirm].
  Future<Result<ClassroomAssignment>> updateAssignment({
    required int classroomId,
    required int assignmentId,
    required String title,
    required String description,
    required List<CreateAssignmentQuestion> questions,
    required List<AssignmentScheduleInput> schedules,
    bool confirm = false,
    String reason = '',
  }) => _dio
      .put(
        '$_base/$classroomId/assignments/$assignmentId',
        data: {
          'title': title.trim(),
          'description': description.trim(),
          'questions': questions
              .map(
                (question) => {
                  'id': question.id,
                  'content': question.content.trim(),
                  'explanation': question.explanation.trim(),
                  'options': question.options.map((option) => option.trim()).toList(),
                  'optionIds': question.optionIds,
                  'correctOptionIndex': question.correctOptionIndex,
                  'excludedFromScore': question.excludedFromScore,
                },
              )
              .toList(),
          'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
          'confirm': confirm,
          'reason': reason.trim(),
        },
      )
      .then((response) => ClassroomAssignment.fromJson(response.data as Map<String, dynamic>))
      .safeResult();
}

enum RoomDeviceModeration {
  mute('mute'),
  allowMicrophone('allow-microphone'),
  disableCamera('disable-camera'),
  allowCamera('allow-camera');

  const RoomDeviceModeration(this.path);
  final String path;
}
