import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/profile/profile_screen.dart';
import 'package:flutter/material.dart';
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

  const NavigationItem({
    required this.title,
    this.shortTitle,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    required this.screen,
    this.subRoutes = const [],
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
  static final mobileShellBranches = [homeItem, profileItem, otherItem];
  static final mobileOtherItems = allItems
      .where((e) => !mobileShellBranches.contains(e))
      .toList();

  static final Map<NavigationItemGroup, List<NavigationItem>> itemGroups = {
    NavigationItemGroup.general: [homeItem, profileItem, otherItem],
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
