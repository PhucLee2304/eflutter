import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: getIt<LoadingService>().isLoading,
      child: child,
      builder: (context, isLoading, cachedChild) {
        return Stack(
          children: [
            cachedChild!,
            if (isLoading)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: ColorName.black.withValues(alpha: 0.1),
                    child: Center(
                      child: LoadingAnimationWidget.dotsTriangle(
                        color: ColorName.primary,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
