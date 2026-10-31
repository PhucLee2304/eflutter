import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/data/repositories/topic_repository.dart';
import 'package:eflutter/presentation/exams/attempt/attempt_route_screen.dart';
import 'package:eflutter/presentation/exams/exam_detail_screen.dart';
import 'package:eflutter/presentation/exams/exam_history_screen.dart';
import 'package:eflutter/presentation/exams/exam_history_detail_screen.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/presentation/exams/exam_list_screen.dart';
import 'package:eflutter/presentation/profile/profile_screen.dart';
import 'package:eflutter/presentation/classrooms/classroom_list_screen.dart';
import 'package:eflutter/presentation/classrooms/classroom_detail_screen.dart';
import 'package:eflutter/presentation/classrooms/classwork_page.dart';
import 'package:eflutter/presentation/notifications/notification_screen.dart';
import 'package:eflutter/presentation/classrooms/classroom_room_screen.dart';
import 'package:eflutter/presentation/classrooms/classroom_attendance_screen.dart';
import 'package:eflutter/presentation/posts/post_detail_screen.dart';
import 'package:eflutter/presentation/posts/post_list.dart';
import 'package:eflutter/presentation/topics/cubit/lesson_detail_cubit.dart';
import 'package:eflutter/presentation/topics/lesson_detail_screen.dart';
import 'package:eflutter/presentation/topics/topic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

enum NavigationItemGroup {
  general('General');

  final String title;

  const NavigationItemGroup(this.title);
}

class NavigationItem {
  final String title;
  final String? shortTitle;
  final IconData icon;
  final IconData selectedIcon;
  final AppRoutes route;
  final Widget screen;
  final List<RouteBase> subRoutes;
  final String? parentTitle;
  final IconData? parentIcon;
  final bool isChild;

  const NavigationItem({
    required this.title,
    this.shortTitle,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    required this.screen,
    this.subRoutes = const [],
    this.parentTitle,
    this.parentIcon,
    this.isChild = false,
  });

  StatefulShellBranch get shellBranch => StatefulShellBranch(
    routes: [GoRoute(path: route.path, builder: (context, state) => screen, routes: subRoutes)],
  );

  GoRoute get goRoute =>
      GoRoute(path: route.path, builder: (context, state) => screen, routes: subRoutes);

  static final allItems = itemGroups.values.expand((e) => e).toList();
  static final webShellBranches = [...allItems, notificationItem];
  static final mobileShellBranches = [homeItem, topicItem, classroomsItem, profileItem, otherItem];
  static final mobileOtherItems = [
    ...allItems.where((e) => !mobileShellBranches.contains(e)),
    notificationItem,
  ];

  static final Map<NavigationItemGroup, List<NavigationItem>> itemGroups = {
    NavigationItemGroup.general: [
      homeItem,
      topicItem,
      classroomsItem,
      examThptItem,
      examToeicItem,
      historiesItem,
      profileItem,
      otherItem,
    ],
  };

  static final homeItem = NavigationItem(
    title: 'Home',
    shortTitle: 'Home',
    icon: SolarIconsOutline.home2,
    selectedIcon: SolarIconsBold.home2,
    route: AppRoutes.home,
    screen: CommunityPostsScreen(),
    subRoutes: [
      GoRoute(
        path: AppRoutes.postDetail.path,
        builder: (context, state) => PostDetailScreen(
          postId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          // Từ thông báo trong app: qua extra. Từ push nền (service worker): qua
          // ?comment=, màn chi tiết sẽ tự xóa khỏi URL.
          commentId: state.extra is int
              ? state.extra! as int
              : int.tryParse(state.uri.queryParameters['comment'] ?? ''),
        ),
      ),
    ],
  );

  static final notificationItem = const NavigationItem(
    title: 'Notifications',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    route: AppRoutes.notifications,
    screen: NotificationScreen(),
  );

  static final profileItem = const NavigationItem(
    title: 'Profile',
    shortTitle: 'Profile',
    icon: SolarIconsOutline.user,
    selectedIcon: SolarIconsBold.user,
    route: AppRoutes.profile,
    screen: ProfileScreen(),
  );

  static final classroomsItem = NavigationItem(
    title: 'Classrooms',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    route: AppRoutes.classrooms,
    screen: const ClassroomListScreen(),
    // Mọi URL của một lớp dùng chung page key nên đổi tab/màn con chỉ cập nhật
    // ClassroomDetailScreen tại chỗ (không tải lại lớp), Back của trình duyệt vẫn đúng.
    subRoutes: [
      GoRoute(
        path: AppRoutes.classroomDetail.path,
        pageBuilder: (context, state) => _classroomPage(state),
        routes: [
          GoRoute(
            path: AppRoutes.classroomRoom.path,
            builder: (context, state) {
              final classroomId = int.tryParse(state.pathParameters['id'] ?? '');
              final roomId = int.tryParse(state.pathParameters['roomId'] ?? '');
              return classroomId == null || roomId == null
                  ? const Scaffold(body: Center(child: Text('Invalid room URL')))
                  : ClassroomRoomScreen(classroomId: classroomId, roomId: roomId);
            },
            routes: [
              GoRoute(
                path: 'attendance',
                builder: (context, state) {
                  final classroomId = int.tryParse(state.pathParameters['id'] ?? '');
                  final roomId = int.tryParse(state.pathParameters['roomId'] ?? '');
                  return classroomId == null || roomId == null
                      ? const Scaffold(body: Center(child: Text('Invalid attendance URL')))
                      : RoomAttendanceScreen(classroomId: classroomId, roomId: roomId);
                },
              ),
            ],
          ),
        ],
      ),
      for (final path in [
        ':id/classwork',
        ':id/calendar',
        ':id/people',
        ':id/posts/:postId',
        ':id/classwork/new',
        ':id/classwork/gradebook',
        ':id/classwork/gradebook/students/:userId',
        ':id/classwork/:assignmentId/edit',
        ':id/classwork/:assignmentId/gradebook',
        ':id/classwork/:assignmentId/attempts/:attemptId',
      ])
        GoRoute(path: path, pageBuilder: (context, state) => _classroomPage(state)),
      // URL cũ trước khi các màn con nằm trong tab Classwork.
      GoRoute(
        path: ':id/gradebook',
        redirect: (context, state) =>
            '${state.uri.path.replaceFirst('/gradebook', '')}'
            '/classwork/gradebook',
      ),
      GoRoute(
        path: ':id/assignments/:assignmentId/gradebook',
        redirect: (context, state) =>
            '/classrooms/${state.pathParameters['id']}/classwork/'
            '${state.pathParameters['assignmentId']}/gradebook',
      ),
      GoRoute(
        path: ':id/students/:userId/progress',
        redirect: (context, state) =>
            '/classrooms/${state.pathParameters['id']}/classwork/gradebook/students/'
            '${state.pathParameters['userId']}',
      ),
    ],
  );

  static final topicItem = NavigationItem(
    title: 'Topics',
    shortTitle: 'Topics',
    icon: SolarIconsOutline.notebook,
    selectedIcon: SolarIconsBold.notebook,
    route: AppRoutes.topic,
    screen: TopicScreen(),
    subRoutes: [
      GoRoute(
        path: AppRoutes.topicLesson.path,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const Scaffold(body: Center(child: Text('Invalid lesson ID')));
          }
          return BlocProvider(
            create: (_) => LessonDetailCubit(TopicRepository(getIt<RemoteDataBase>())),
            child: LessonDetailScreen(lessonId: id),
          );
        },
      ),
    ],
  );

  static final examThptItem = NavigationItem(
    title: 'THPT',
    shortTitle: 'THPT',
    icon: SolarIconsOutline.documentText,
    selectedIcon: SolarIconsBold.notebook,
    route: AppRoutes.examThpt,
    screen: const ExamListScreen(examType: 'THPT'),
    parentTitle: 'Exams',
    parentIcon: SolarIconsOutline.documentText,
    isChild: true,
    subRoutes: [_examDetailRoute],
  );

  static final examToeicItem = NavigationItem(
    title: 'TOEIC',
    shortTitle: 'TOEIC',
    icon: SolarIconsOutline.microphone,
    selectedIcon: SolarIconsBold.microphoneLarge,
    route: AppRoutes.examToeic,
    screen: const ExamListScreen(examType: 'TOEIC'),
    parentTitle: 'Exams',
    parentIcon: SolarIconsOutline.documentText,
    isChild: true,
    subRoutes: [_examDetailRoute],
  );

  static final _examDetailRoute = GoRoute(
    path: AppRoutes.examDetail.path,
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null) {
        return const Scaffold(body: Center(child: Text('Invalid exam ID')));
      }
      return ExamDetailScreen(examId: id);
    },
  );

  static final historiesItem = NavigationItem(
    title: 'History',
    shortTitle: 'History',
    icon: SolarIconsOutline.documentText,
    selectedIcon: SolarIconsBold.notebook,
    route: AppRoutes.histories,
    screen: const ExamHistoryScreen(),
    parentTitle: 'Exams',
    parentIcon: SolarIconsOutline.documentText,
    isChild: true,
    subRoutes: [
      GoRoute(
        path: AppRoutes.attemptPracticeLegacy.path,
        redirect: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null ? AppRoutes.histories.path : attemptPracticePath(id);
        },
      ),
      GoRoute(
        path: AppRoutes.attemptHistoryDetail.path,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const Scaffold(body: Center(child: Text('Invalid attempt ID')));
          }
          return ExamHistoryDetailScreen(
            attemptId: id,
            initialAttempt: state.extra is ExamAttempt ? state.extra as ExamAttempt : null,
          );
        },
      ),
    ],
  );

  /// Màn làm bài nằm ngoài shell (không sidebar/bottom nav): khi đang làm bài
  /// người dùng chỉ thao tác được trong màn này (xem AttemptLockNotifier).
  static final attemptRoute = GoRoute(
    path: AppRoutes.attemptPractice.path,
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null) {
        return const Scaffold(body: Center(child: Text('Invalid attempt ID')));
      }
      return AttemptRouteScreen(
        attemptId: id,
        initialAttempt: state.extra is ExamAttempt ? state.extra as ExamAttempt : null,
      );
    },
  );

  static final otherItem = NavigationItem(
    title: 'Other',
    icon: SolarIconsOutline.plain3,
    selectedIcon: SolarIconsBold.plain3,
    route: AppRoutes.other,
    screen: const Placeholder(),
    subRoutes: [
      GoRoute(path: AppRoutes.subOther.path, builder: (context, state) => const Placeholder()),
    ],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationItem && runtimeType == other.runtimeType && route == other.route;

  @override
  int get hashCode => route.hashCode;
}

/// Trang chi tiết lớp cho mọi URL `/classrooms/:id/...`: tab và màn con lấy từ đường dẫn.
Page<void> _classroomPage(GoRouterState state) {
  final params = state.pathParameters;
  final classroomId = int.tryParse(params['id'] ?? '');
  if (classroomId == null) {
    return const NoTransitionPage(
      child: Scaffold(body: Center(child: Text('Invalid classroom ID'))),
    );
  }
  final segments = state.uri.pathSegments.skip(2).toList();
  final section = segments.firstOrNull;
  final assignmentId = int.tryParse(params['assignmentId'] ?? '');
  final classwork = section != 'classwork'
      ? const ClassworkPage.list()
      : params['userId'] != null
      ? ClassworkPage(ClassworkView.student, studentId: params['userId'])
      : segments.length == 2 && segments[1] == 'new'
      ? const ClassworkPage(ClassworkView.create)
      : segments.length == 2 && segments[1] == 'gradebook'
      ? const ClassworkPage(ClassworkView.classGradebook)
      : assignmentId != null && params['attemptId'] != null
      ? ClassworkPage(
          ClassworkView.review,
          assignmentId: assignmentId,
          attemptId: int.tryParse(params['attemptId']!),
        )
      : assignmentId != null && segments.last == 'edit'
      ? ClassworkPage(ClassworkView.edit, assignmentId: assignmentId)
      : assignmentId != null
      ? ClassworkPage(
          ClassworkView.gradebook,
          assignmentId: assignmentId,
          // Chỉ nhận đường dẫn trong chính lớp này.
          backTo: switch (state.uri.queryParameters['from']) {
            final from? when from.startsWith('/classrooms/$classroomId/') => from,
            _ => null,
          },
        )
      : const ClassworkPage.list();
  return NoTransitionPage(
    key: ValueKey('classroom-$classroomId'),
    child: ClassroomDetailScreen(
      classroomId: classroomId,
      initialTab: switch (section) {
        'classwork' => 1,
        'calendar' => 2,
        'people' => 3,
        _ => 0,
      },
      classwork: classwork,
      postId: int.tryParse(params['postId'] ?? ''),
      // Như /posts/:id: comment cần mở tới qua extra hoặc ?comment=.
      commentId: state.extra is int
          ? state.extra! as int
          : int.tryParse(state.uri.queryParameters['comment'] ?? ''),
    ),
  );
}
