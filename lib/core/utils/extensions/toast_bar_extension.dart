import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

enum ToastType {
  success,
  info,
  warning,
  error;

  Color get color => switch (this) {
    ToastType.success => ColorName.green,
    ToastType.info => ColorName.blue,
    ToastType.warning => ColorName.orange,
    ToastType.error => ColorName.red,
  };

  IconData get icon => switch (this) {
    ToastType.success => SolarIconsOutline.checkCircle,
    ToastType.info => SolarIconsOutline.dangerCircle,
    ToastType.warning => SolarIconsOutline.dangerTriangle,
    ToastType.error => SolarIconsOutline.danger,
  };
}

OverlayEntry? _currentToast;

extension ToastExtension on BuildContext {
  void showToast(
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentToast?.remove();
    _currentToast = null;

    final overlayState = Overlay.of(this);
    final overlayEntry = OverlayEntry(
      builder: (context) {
        final topPadding = MediaQuery.of(context).padding.top;

        return Positioned(
          top: topPadding + 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: type.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Icon(type.icon, color: ColorName.white),
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColorName.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    _currentToast = overlayEntry;
    overlayState.insert(overlayEntry);

    Future.delayed(duration, () {
      if (overlayEntry.mounted && _currentToast == overlayEntry) {
        overlayEntry.remove();
        _currentToast = null;
      }
    });
  }

  void handleFailure(Failure? failure) {
    if (failure != null) {
      showToast(
        failure.message ?? 'Occurred an unexpected error. Please try again.',
        type: ToastType.error,
        duration: const Duration(seconds: 3),
      );
    }
  }
}
