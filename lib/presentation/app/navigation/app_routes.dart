enum AppRoutes {
  login(path: '/login'),
  log(path: '/log'),
  home(path: '/'),
  notifications(path: '/notifications'),
  topic(path: '/topic'),
  topicLesson(path: 'lessons/:id'),
  examThpt(path: '/exams/thpt'),
  examToeic(path: '/exams/toeic'),
  examDetail(path: 'details/:id'),
  histories(path: '/histories'),
  attemptPractice(path: 'attempts/:id/practice'),
  attemptHistoryDetail(path: 'attempts/:id/history'),
  profile(path: '/profile'),
  classrooms(path: '/classrooms'),
  classroomDetail(path: ':id'),
  classroomGradebook(path: 'assignments/:assignmentId/gradebook'),
  classGradebook(path: 'gradebook'),
  studentProgress(path: 'students/:userId/progress'),

  other(path: '/other'),
  subOther(path: 'other-sub-route');

  final String path;
  const AppRoutes({required this.path});
}

final publicPaths = [AppRoutes.login.path];

String get notificationsPath => AppRoutes.notifications.path;

String topicLessonPath(int lessonId) =>
    '${AppRoutes.topic.path}/lessons/$lessonId';

String examDetailPath(String examType, int examId) {
  final basePath = examType.toUpperCase() == 'TOEIC'
      ? AppRoutes.examToeic.path
      : AppRoutes.examThpt.path;
  return '$basePath/details/$examId';
}

String attemptPracticePath(int attemptId) =>
    '${AppRoutes.histories.path}/attempts/$attemptId/practice';

String attemptHistoryDetailPath(int attemptId) =>
    '${AppRoutes.histories.path}/attempts/$attemptId/history';

String classroomPath(int classroomId) =>
    '${AppRoutes.classrooms.path}/$classroomId';

String classroomGradebookPath(int classroomId, int assignmentId) =>
    '${classroomPath(classroomId)}/assignments/$assignmentId/gradebook';

String classGradebookPath(int classroomId) =>
    '${classroomPath(classroomId)}/gradebook';

String studentProgressPath(int classroomId, String userId) =>
    '${classroomPath(classroomId)}/students/${Uri.encodeComponent(userId)}/progress';
