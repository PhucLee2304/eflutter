import 'package:eflutter/core/auth/auth_notifier.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/app/navigation/navigation_item.dart';
import 'package:eflutter/presentation/app/widgets/mobile_layout.dart';
import 'package:eflutter/presentation/app/widgets/web_layout.dart';
import 'package:eflutter/presentation/auth/cubit/login_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _authNotifier = getIt<AuthNotifier>();

  static final router = GoRouter(
    debugLogDiagnostics: kDebugMode,
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home.path,
    refreshListenable: _authNotifier,
    redirect: _redirect,
    routes: kIsWeb ? _webRoutes : _mobileRoutes,
  );

  static final _mobileRoutes = [
    GoRoute(path: AppRoutes.login.path, builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: AppRoutes.log.path,
      builder: (context, state) => TalkerScreen(talker: getIt<Talker>()),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MobileLayout(navigationShell: navigationShell),
      branches: NavigationItem.mobileShellBranches.map((e) => e.shellBranch).toList(),
    ),
    ...NavigationItem.mobileOtherItems.map((e) => e.goRoute),
  ];

  static final _webRoutes = [
    GoRoute(path: AppRoutes.login.path, builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: AppRoutes.log.path,
      builder: (context, state) => TalkerScreen(talker: getIt<Talker>()),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => WebLayout(navigationShell: navigationShell),
      branches: NavigationItem.webShellBranches.map((e) => e.shellBranch).toList(),
    ),
  ];

  static String? _redirect(BuildContext context, GoRouterState state) {
    final isPublicPath = publicPaths.contains(state.uri.path);
    final isAuthenticated = _authNotifier.isAuthenticated;

    if (!isAuthenticated && !isPublicPath) {
      return AppRoutes.login.path;
    }

    if (isAuthenticated && isPublicPath) {
      return AppRoutes.home.path;
    }

    return null;
  }
}