import 'package:eflutter/core/utils/helpers/platform/platform_helper.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/app/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onNotificationPressed;

  const MainAppBar({super.key, required this.onNotificationPressed});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
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
                    style: const TextStyle(fontSize: 10, color: ColorName.labelSecondary),
                  ),
                ],
              ),
            ),
          ),
          titleSpacing: 4,
          centerTitle: false,
          actions: [
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
                        'xin chào',
                        style: TextStyle(fontSize: 12, color: ColorName.labelPrimary),
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
                    ),
                    child: const Icon(SolarIconsBold.user, color: Colors.white),
                  ),
                ],
              ),
            ),
            // IconButton(onPressed: onNotificationPressed, icon: const Icon(SolarIconsOutline.bell)),
            // const SizedBox(width: 8),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(height: 1.0),
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
