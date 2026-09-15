import 'package:eflutter/core/di/injection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:injectable/injectable.dart';

@singleton
class LoadingService {
  final isLoading = ValueNotifier<bool>(false);
  int _loadingCount = 0;
  bool _notificationScheduled = false;
  bool _disposed = false;

  void show() {
    _loadingCount++;
    _syncNotifier();
  }

  void hide() {
    _loadingCount--;
    if (_loadingCount <= 0) {
      _loadingCount = 0;
    }
    _syncNotifier();
  }

  void _syncNotifier() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final isBuilding =
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.persistentCallbacks;
    if (!isBuilding) {
      _setNotifierValue();
      return;
    }
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      _setNotifierValue();
    });
  }

  void _setNotifierValue() {
    if (_disposed) return;
    final nextValue = _loadingCount > 0;
    if (isLoading.value != nextValue) {
      isLoading.value = nextValue;
    }
  }

  Future<T> wrapLoading<T>(Future<T> Function() operation) async {
    try {
      show();
      return await operation();
    } finally {
      hide();
    }
  }

  @disposeMethod
  void dispose() {
    _disposed = true;
    isLoading.dispose();
  }
}

extension FutureLoadingExtension<T> on Future<T> {
  Future<T> withLoading() {
    return getIt<LoadingService>().wrapLoading(() => this);
  }
}
