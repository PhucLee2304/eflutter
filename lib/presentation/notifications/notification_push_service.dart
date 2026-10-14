import 'dart:async';
import 'dart:math';

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
  static const _deviceIDKey = 'notificationDeviceID';
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> initialize() async {
    if (!kIsWeb) return;
    _messageSubscription ??= FirebaseMessaging.onMessage.listen((_) {
      unawaited(_controller.refresh());
    });
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: vapidKey.isEmpty ? null : vapidKey,
    );
    if (token == null || token.isEmpty) return;
    await _registerToken(token);

    _tokenSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) => unawaited(_registerToken(newToken)),
    );
  }

  Future<void> _registerToken(String token) async {
    final deviceID = await _getOrCreateDeviceID();
    await _repository.registerDeviceToken(token, deviceID, 'WEB');
    await _preferences.setString(_tokenKey, token);
  }

  Future<String> _getOrCreateDeviceID() async {
    final existing = await _preferences.getString(_deviceIDKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final deviceID =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _preferences.setString(_deviceIDKey, deviceID);
    return deviceID;
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
