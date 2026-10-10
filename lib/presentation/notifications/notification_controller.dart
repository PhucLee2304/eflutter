import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eflutter/data/models/app_notification.dart';
import 'package:eflutter/data/repositories/notification_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

enum NotificationFilter { all, unread, read }

@lazySingleton
class NotificationController extends ChangeNotifier {
  NotificationController(Dio dio) : _repository = NotificationRepository(dio);

  final NotificationRepository _repository;
  final List<AppNotification> _items = [];
  final Set<int> _pendingReadIDs = {};
  Timer? _readTimer;
  int _page = 0;
  int _pageCount = 1;
  bool _loading = false;
  String? _error;
  int _unreadCount = 0;
  NotificationFilter _filter = NotificationFilter.all;

  List<AppNotification> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get canLoadMore => _page < _pageCount;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  NotificationFilter get filter => _filter;

  bool? get _readFilter => switch (_filter) {
    NotificationFilter.all => null,
    NotificationFilter.unread => false,
    NotificationFilter.read => true,
  };

  Future<void> refresh() async {
    if (_loading) return;
    _items.clear();
    _page = 0;
    _pageCount = 1;
    await loadMore();
  }

  Future<void> setFilter(NotificationFilter value) async {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
    await refresh();
  }

  Future<void> loadMore() async {
    if (_loading || !canLoadMore) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.getNotifications(
        page: _page + 1,
        read: _readFilter,
      );
      _items.addAll(result.notifications);
      _page = result.page;
      _pageCount = result.pageCount;
      _unreadCount = result.unreadCount;
    } catch (_) {
      _error = 'Unable to load notifications.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void notificationVisible(AppNotification notification) {
    if (notification.isRead) return;
    _pendingReadIDs.add(notification.id);
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(milliseconds: 600), _flushReadIDs);
  }

  Future<void> _flushReadIDs() async {
    if (_pendingReadIDs.isEmpty) return;
    final ids = _pendingReadIDs.toList();
    _pendingReadIDs.clear();
    try {
      await _repository.markRead(ids);
      final now = DateTime.now();
      for (var i = 0; i < _items.length; i++) {
        if (ids.contains(_items[i].id) && !_items[i].isRead) {
          _items[i] = _items[i].markRead(now);
          if (_unreadCount > 0) _unreadCount--;
        }
      }
      if (_filter == NotificationFilter.unread) {
        await refresh();
        return;
      }
      notifyListeners();
    } catch (_) {
      _pendingReadIDs.addAll(ids);
    }
  }

  Future<bool> deleteMany(Set<int> ids) async {
    if (ids.isEmpty) return false;
    try {
      await _repository.deleteMany(ids.toList());
      final unreadDeleted = _items
          .where((item) => ids.contains(item.id) && !item.isRead)
          .length;
      _items.removeWhere((item) => ids.contains(item.id));
      _unreadCount = (_unreadCount - unreadDeleted).clamp(0, 1 << 31);
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Unable to delete notifications.';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }
}
