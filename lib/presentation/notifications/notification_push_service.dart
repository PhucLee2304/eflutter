import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eflutter/data/repositories/notification_repository.dart';
import 'package:eflutter/presentation/notifications/notification_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class NotificationPushService {
  NotificationPushService(Dio dio, this._controller, this._preferences)
    : _repository = NotificationRepository(dio);

  final NotificationRepository _repository;
  final NotificationController _controller;
  final SharedPreferencesAsync _preferences;
  static const _tokenKey = 'notificationDeviceToken';
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> initialize() async {
    if (!kIsWeb) return;
    _messageSubscription ??= FirebaseMessaging.onMessage.listen((_) {
      unawaited(_controller.refresh());
    });
  }

  Future<bool> enablePush() async {
    if (!kIsWeb) return false;
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }

    const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: vapidKey.isEmpty ? null : vapidKey,
    );
    if (token == null || token.isEmpty) return false;
    await _repository.registerDeviceToken(token, 'WEB');
    await _preferences.setString(_tokenKey, token);

    _tokenSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) => unawaited(_repository.registerDeviceToken(newToken, 'WEB')),
    );
    return true;
  }

  Future<void> disablePush() async {
    final token = await _preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) return;
    try {
      await _repository.deleteDeviceToken(token);
      await FirebaseMessaging.instance.deleteToken();
      await _preferences.remove(_tokenKey);
    } catch (_) {
      // Keep the token locally so a later logout attempt can retry removal.
    }
  }
}
