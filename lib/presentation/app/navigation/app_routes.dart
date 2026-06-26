enum AppRoutes {
  login(path: '/login'),
  log(path: '/log'),
  home(path: '/'),
  topic(path: '/topic'),
  topicLesson(path: 'lessons/:id'),
  profile(path: '/profile'),

  other(path: '/other'),
  subOther(path: 'other-sub-route');

  final String path;
  const AppRoutes({required this.path});
}

final publicPaths = [AppRoutes.login.path];

String topicLessonPath(int lessonId) => '${AppRoutes.topic.path}/lessons/$lessonId';
