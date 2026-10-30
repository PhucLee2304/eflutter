enum AppRoutes {
  login(path: '/login'),
  log(path: '/log'),
  home(path: '/'),
  postDetail(path: 'posts/:id'),
  notifications(path: '/notifications'),
  topic(path: '/topic'),
  topicLesson(path: 'lessons/:id'),
  examThpt(path: '/exams/thpt'),
  examToeic(path: '/exams/toeic'),
  examDetail(path: 'details/:id'),
  histories(path: '/histories'),
  attemptPractice(path: '/attempts/:id/take'),
  attemptPracticeLegacy(path: 'attempts/:id/practice'),
  attemptHistoryDetail(path: 'attempts/:id/history'),
  profile(path: '/profile'),
  classrooms(path: '/classrooms'),
  classroomDetail(path: ':id'),
  classroomGradebook(path: 'assignments/:assignmentId/gradebook'),
  classGradebook(path: 'gradebook'),
  classroomPost(path: 'posts/:postId'),
  classroomClasswork(path: 'classwork'),
  classroomCalendar(path: 'calendar'),
  classroomPeople(path: 'people'),
  studentProgress(path: 'students/:userId/progress'),
  classroomRoom(path: 'rooms/:roomId'),
  roomAttendance(path: 'rooms/:roomId/attendance'),

  other(path: '/other'),
  subOther(path: 'other-sub-route');

  final String path;
  const AppRoutes({required this.path});
}

final publicPaths = [AppRoutes.login.path];

String get notificationsPath => AppRoutes.notifications.path;

String topicLessonPath(int lessonId) => '${AppRoutes.topic.path}/lessons/$lessonId';

String examDetailPath(String examType, int examId) {
  final basePath = examType.toUpperCase() == 'TOEIC'
      ? AppRoutes.examToeic.path
      : AppRoutes.examThpt.path;
  return '$basePath/details/$examId';
}

String attemptPracticePath(int attemptId) => '/attempts/$attemptId/take';

String attemptHistoryDetailPath(int attemptId) =>
    '${AppRoutes.histories.path}/attempts/$attemptId/history';

String classroomPath(int classroomId) => '${AppRoutes.classrooms.path}/$classroomId';

String classworkPath(int classroomId) => '${classroomPath(classroomId)}/classwork';

/// Các màn con của tab Classwork: mỗi màn có URL riêng để reload, Back và nút Back của
/// trình duyệt đều đúng.
String createAssignmentPath(int classroomId) => '${classworkPath(classroomId)}/new';

String editAssignmentPath(int classroomId, int assignmentId) =>
    '${classworkPath(classroomId)}/$assignmentId/edit';

/// [fromClassGradebook]: mở từ bảng điểm lớp thì Back quay lại bảng điểm lớp.
String classroomGradebookPath(
  int classroomId,
  int assignmentId, {
  bool fromClassGradebook = false,
}) =>
    '${classworkPath(classroomId)}/$assignmentId/gradebook${fromClassGradebook ? '?from=class' : ''}';

String classGradebookPath(int classroomId) => '${classworkPath(classroomId)}/gradebook';

String studentProgressPath(int classroomId, String userId) =>
    '${classGradebookPath(classroomId)}/students/${Uri.encodeComponent(userId)}';

String classroomRoomPath(int classroomId, int roomId) =>
    '${classroomPath(classroomId)}/rooms/$roomId';

String roomAttendancePath(int classroomId, int roomId) =>
    '${classroomRoomPath(classroomId, roomId)}/attendance';

String postDetailPath(int postId) => '/posts/$postId';

/// URL của từng tab trang lớp (0 Announcements, 1 Classwork, 2 Calendar, 3 People) để reload
/// vẫn ở đúng tab.
String classroomTabPath(int classroomId, int tab) => switch (tab) {
  1 => '${classroomPath(classroomId)}/${AppRoutes.classroomClasswork.path}',
  2 => '${classroomPath(classroomId)}/${AppRoutes.classroomCalendar.path}',
  3 => '${classroomPath(classroomId)}/${AppRoutes.classroomPeople.path}',
  _ => classroomPath(classroomId),
};

/// Bài viết của lớp mở ngay trong tab Announcements của lớp đó.
String classroomPostPath(int classroomId, int postId) =>
    '${classroomPath(classroomId)}/posts/$postId';

/// Đường dẫn mở khi bấm một thông báo, từ `data` (`type`, `id`, `classroomId`).
/// Comment cần cuộn tới (`commentId`) không nằm trong URL mà truyền qua `extra`.
/// Giữ khớp với `notificationPath` trong `web/firebase-messaging-sw.js`.
String? notificationPath(Map<String, String> data) {
  final id = int.tryParse(data['id'] ?? '');
  final classroomId = int.tryParse(data['classroomId'] ?? '');
  switch (data['type']) {
    case 'CLASSROOM':
      return id == null ? null : classroomPath(id);
    case 'ASSIGNMENT':
      return classroomId == null ? null : classroomTabPath(classroomId, 1);
    case 'ATTEMPT':
      return id == null ? null : attemptHistoryDetailPath(id);
    case 'ROOM':
      return id == null || classroomId == null ? null : classroomRoomPath(classroomId, id);
    case 'CLASSROOM_POST':
    case 'CLASSROOM_POST_PINNED':
    case 'POST_LIKED':
    case 'POST_COMMENTED':
    case 'COMMENT_REPLIED':
    case 'COMMENT_LIKED':
      if (id == null) return null;
      return classroomId == null ? postDetailPath(id) : classroomPostPath(classroomId, id);
  }
  // Loại chưa biết: mở lớp nếu có, để thông báo nào cũng bấm được.
  return classroomId == null ? null : classroomPath(classroomId);
}
