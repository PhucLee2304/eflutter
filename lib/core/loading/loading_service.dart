import 'package:eflutter/core/di/injection.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@singleton
class LoadingService {
  final isLoading = ValueNotifier<bool>(false);
  int _loadingCount = 0;

  void show() {
    _loadingCount++;
    if (!isLoading.value) {
      isLoading.value = true;
    }
  }

  void hide() {
    _loadingCount--;
    if (_loadingCount <= 0) {
      _loadingCount = 0;
      if (isLoading.value) {
        isLoading.value = false;
      }
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
    isLoading.dispose();
  }
}

extension FutureLoadingExtension<T> on Future<T> {
  Future<T> withLoading() {
    return getIt<LoadingService>().wrapLoading(() => this);
  }
}