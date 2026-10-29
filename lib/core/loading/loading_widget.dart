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

/// Đặt vào chỗ đang tải thay cho spinner: không tự vẽ gì mà bật overlay tam giác của
/// [LoadingWidget]. Nhiều chỗ cùng tải vẫn chỉ hiện một overlay nhờ bộ đếm của [LoadingService].
class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  final _service = getIt<LoadingService>();

  @override
  void initState() {
    super.initState();
    _service.show();
  }

  @override
  void dispose() {
    _service.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
