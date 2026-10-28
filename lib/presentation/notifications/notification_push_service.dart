import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/data/data_sources/notification_socket_client.dart';
import 'package:eflutter/data/models/app_notification.dart';
import 'package:eflutter/data/repositories/notification_repository.dart';
import 'package:eflutter/presentation/notifications/notification_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

@lazySingleton
class NotificationPushService {
  NotificationPushService(Dio dio, this._controller, this._preferences, LocalDataBase localData)
    : _repository = NotificationRepository(dio) {
    _socket = NotificationSocketClient(
      localData,
      // Mỗi lần (kết nối lại) tải một lần để bù thông báo lỡ khi mất mạng.
      onConnected: () => unawaited(_controller.refresh()),
      onCreated: () => unawaited(_controller.refresh()),
    );
  }

  final NotificationRepository _repository;
  final NotificationController _controller;
  final SharedPreferencesAsync _preferences;
  static const _tokenKey = 'notificationDeviceToken';
  static const _deviceIDKey = 'notificationDeviceID';
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<List<AppNotification>>? _newSubscription;
  late final NotificationSocketClient _socket;
  StreamSubscription<web.Event>? _pageHideSubscription;
  StreamSubscription<web.Event>? _pageShowSubscription;

  Future<void> initialize() async {
    if (!kIsWeb) return;
    // Số chưa đọc chỉ cập nhật khi server báo NOTIFICATION_CREATED qua
    // WebSocket; FCM chỉ dùng để hiện thông báo hệ thống.
    _newSubscription ??= _controller.newNotifications.listen(_showSystem);
    unawaited(_socket.connect());
    // Đóng kết nối khi tắt/rời trang; mở lại nếu trang được khôi phục từ cache.
    _pageHideSubscription ??= web.EventStreamProviders.pageHideEvent
        .forTarget(web.window)
        .listen((_) => unawaited(_socket.close()));
    _pageShowSubscription ??= web.EventStreamProviders.pageShowEvent.forTarget(web.window).listen((
      event,
    ) {
      if ((event as web.PageTransitionEvent).persisted) unawaited(_socket.connect());
    });
    // Không await: hộp thoại xin quyền chờ người dùng bấm, không được chặn app.
    unawaited(
      _enablePush().catchError((Object e) {
        debugPrint('NotificationPushService push setup failed: $e');
      }),
    );
  }

  Future<void> _enablePush() async {
    var settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      settings = await FirebaseMessaging.instance.requestPermission();
    }
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

  /// Hiện thông báo hệ thống (góc phải dưới trên Windows). Khi tab bị ẩn và
  /// push đã bật, service worker của FCM tự hiện nên bỏ qua để không trùng.
  void _showSystem(List<AppNotification> items) {
    if (web.Notification.permission != 'granted') return;
    final hidden = web.document.visibilityState == 'hidden';
    if (hidden && _pushActive) return;
    for (final item in items) {
      final notification = web.Notification(
        item.title,
        web.NotificationOptions(body: item.body, tag: 'ego-${item.id}', icon: 'icons/Icon-192.png'),
      );
      notification.onclick = (web.Event _) {
        web.window.focus();
        notification.close();
      }.toJS;
    }
  }

  bool _pushActive = false;

  Future<void> _registerToken(String token) async {
    final deviceID = await _getOrCreateDeviceID();
    await _repository.registerDeviceToken(token, deviceID, 'WEB');
    await _preferences.setString(_tokenKey, token);
    _pushActive = true;
  }

  Future<String> _getOrCreateDeviceID() async {
    final existing = await _preferences.getString(_deviceIDKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final deviceID =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _preferences.setString(_deviceIDKey, deviceID);
    return deviceID;
  }

  Future<void> disablePush() async {
    await _socket.close();
    await _pageHideSubscription?.cancel();
    _pageHideSubscription = null;
    await _pageShowSubscription?.cancel();
    _pageShowSubscription = null;
    await _newSubscription?.cancel();
    _newSubscription = null;
    _pushActive = false;
    _controller.reset();
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
