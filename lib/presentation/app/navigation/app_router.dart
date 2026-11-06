import 'package:eflutter/core/attempt_lock/attempt_lock_notifier.dart';
import 'package:eflutter/core/auth/auth_notifier.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/app/navigation/navigation_item.dart';
import 'package:eflutter/presentation/app/widgets/mobile_layout.dart';
import 'package:eflutter/presentation/app/widgets/web_layout.dart';
import 'package:eflutter/presentation/auth/cubit/login_screen.dart';
import 'package:eflutter/presentation/dictionary/flashcards_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _authNotifier = getIt<AuthNotifier>();
  static final _attemptLock = getIt<AttemptLockNotifier>();

  static final router = GoRouter(
    debugLogDiagnostics: kDebugMode,
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home.path,
    refreshListenable: Listenable.merge([_authNotifier, _attemptLock]),
    redirect: _redirect,
    routes: kIsWeb ? _webRoutes : _mobileRoutes,
  );

  static final _mobileRoutes = [
    GoRoute(path: AppRoutes.login.path, builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: AppRoutes.log.path,
      builder: (context, state) => TalkerScreen(talker: getIt<Talker>()),
    ),
    NavigationItem.attemptRoute,
    GoRoute(
      path: AppRoutes.flashcards.path,
      builder: (context, state) => const FlashcardsScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MobileLayout(navigationShell: navigationShell),
      branches: NavigationItem.mobileShellBranches.map((e) => e.shellBranch).toList(),
    ),
    ...NavigationItem.mobileOtherItems.expand((e) => e.routes),
  ];

  static final _webRoutes = [
    GoRoute(path: AppRoutes.login.path, builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: AppRoutes.log.path,
      builder: (context, state) => TalkerScreen(talker: getIt<Talker>()),
    ),
    NavigationItem.attemptRoute,
    GoRoute(
      path: AppRoutes.flashcards.path,
      builder: (context, state) => const FlashcardsScreen(),
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

    // Người không phải admin gõ thẳng /admin/... thì về Home. Lúc user chưa tải xong (mở lại
    // trang) vẫn cho vào; API admin tự chặn bằng RequireRole.
    final user = getIt<AppCubit>().state.user;
    if (state.uri.path.startsWith(adminPathPrefix) &&
        user != null &&
        user.role.toUpperCase() != 'ADMIN') {
      return AppRoutes.home.path;
    }

    // Đang làm bài: mọi điều hướng ra ngoài màn làm bài đều bị đưa về lại.
    return _attemptLock.redirectFor(state.uri.path);
  }
}
