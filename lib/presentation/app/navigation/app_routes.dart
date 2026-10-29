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

String classroomGradebookPath(int classroomId, int assignmentId) =>
    '${classroomPath(classroomId)}/assignments/$assignmentId/gradebook';

String classGradebookPath(int classroomId) => '${classroomPath(classroomId)}/gradebook';

String studentProgressPath(int classroomId, String userId) =>
    '${classroomPath(classroomId)}/students/${Uri.encodeComponent(userId)}/progress';

String classroomRoomPath(int classroomId, int roomId) =>
    '${classroomPath(classroomId)}/rooms/$roomId';

String roomAttendancePath(int classroomId, int roomId) =>
    '${classroomRoomPath(classroomId, roomId)}/attendance';

String postDetailPath(int postId) => '/posts/$postId';

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
      return classroomId == null ? null : classroomPath(classroomId);
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
