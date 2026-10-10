import 'package:eflutter/core/utils/helpers/platform/platform_helper.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/app/widgets/app_logo.dart';
import 'package:eflutter/presentation/notifications/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class MainAppBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onNotificationPressed;

  const MainAppBar({super.key, required this.onNotificationPressed});

  @override
  State<MainAppBar> createState() => _MainAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _MainAppBarState extends State<MainAppBar> {
  final _notificationController = getIt<NotificationController>();

  @override
  void initState() {
    super.initState();
    _notificationController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        final avatarUrl = state.user?.avatar?.trim();
        return AppBar(
          title: GestureDetector(
            onTap: () => refreshPage(),
            onLongPressEnd: (details) {
              if (details.localPosition.dx + details.localPosition.dy > 800) {
                context.push(AppRoutes.log.path);
              }
            },
            child: SizedBox(
              height: 54,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const AppLogo(width: 40),
                  Text(
                    state.appInfo.buildName,
                    style: const TextStyle(
                      fontSize: 10,
                      color: ColorName.labelSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          titleSpacing: 4,
          centerTitle: false,
          actions: [
            AnimatedBuilder(
              animation: _notificationController,
              builder: (context, _) => IconButton(
                tooltip: 'Notifications',
                onPressed: widget.onNotificationPressed,
                icon: Badge(
                  isLabelVisible: _notificationController.unreadCount > 0,
                  label: Text(
                    _notificationController.unreadCount > 99
                        ? '99+'
                        : '${_notificationController.unreadCount}',
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        state.user?.name ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ColorName.labelPrimary,
                        ),
                      ),
                      const Text(
                        'Hello',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorName.labelPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ColorName.primary,
                      borderRadius: BorderRadius.circular(8),
                      image: avatarUrl == null || avatarUrl.isEmpty
                          ? null
                          : DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? const Icon(SolarIconsBold.user, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(height: 1.0),
          ),
        );
      },
    );
  }
}
