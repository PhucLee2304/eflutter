import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/data/repositories/topic_repository.dart';
import 'package:eflutter/presentation/exams/exam_detail_screen.dart';
import 'package:eflutter/presentation/exams/exam_list_screen.dart';
import 'package:eflutter/presentation/profile/profile_screen.dart';
import 'package:eflutter/presentation/topics/cubit/lesson_detail_cubit.dart';
import 'package:eflutter/presentation/topics/lesson_detail_screen.dart';
import 'package:eflutter/presentation/topics/topic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

enum NavigationItemGroup {
  general('Global');

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
    routes: [
      GoRoute(
        path: route.path,
        builder: (context, state) => screen,
        routes: subRoutes,
      ),
    ],
  );

  GoRoute get goRoute => GoRoute(
    path: route.path,
    builder: (context, state) => screen,
    routes: subRoutes,
  );

  static final allItems = itemGroups.values.expand((e) => e).toList();
  static final webShellBranches = allItems;
  static final mobileShellBranches = [
    homeItem,
    topicItem,
    profileItem,
    otherItem,
  ];
  static final mobileOtherItems = allItems
      .where((e) => !mobileShellBranches.contains(e))
      .toList();

  static final Map<NavigationItemGroup, List<NavigationItem>> itemGroups = {
    NavigationItemGroup.general: [
      homeItem,
      topicItem,
      examThptItem,
      examToeicItem,
      profileItem,
      otherItem,
    ],
  };

  static final homeItem = const NavigationItem(
    title: 'Home',
    shortTitle: 'Home',
    icon: SolarIconsOutline.home2,
    selectedIcon: SolarIconsBold.home2,
    route: AppRoutes.home,
    screen: Placeholder(),
  );

  static final profileItem = const NavigationItem(
    title: 'Profile',
    shortTitle: 'Profile',
    icon: SolarIconsOutline.user,
    selectedIcon: SolarIconsBold.user,
    route: AppRoutes.profile,
    screen: ProfileScreen(),
  );

  static final topicItem = NavigationItem(
    title: 'Topic',
    shortTitle: 'Topic',
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
            return const Scaffold(
              body: Center(child: Text('Invalid lesson id')),
            );
          }
          return BlocProvider(
            create: (_) =>
                LessonDetailCubit(TopicRepository(getIt<RemoteDataBase>())),
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
    parentTitle: 'Exam',
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
    parentTitle: 'Exam',
    parentIcon: SolarIconsOutline.documentText,
    isChild: true,
    subRoutes: [_examDetailRoute],
  );

  static final _examDetailRoute = GoRoute(
    path: AppRoutes.examDetail.path,
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null) {
        return const Scaffold(body: Center(child: Text('Invalid exam id')));
      }
      return ExamDetailScreen(examId: id);
    },
  );

  static final otherItem = NavigationItem(
    title: 'Other',
    icon: SolarIconsOutline.plain3,
    selectedIcon: SolarIconsBold.plain3,
    route: AppRoutes.other,
    screen: const Placeholder(),
    subRoutes: [
      GoRoute(
        path: AppRoutes.subOther.path,
        builder: (context, state) => const Placeholder(),
      ),
    ],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationItem &&
          runtimeType == other.runtimeType &&
          route == other.route;

  @override
  int get hashCode => route.hashCode;
}
