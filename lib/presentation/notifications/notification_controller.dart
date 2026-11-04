import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:eflutter/data/models/app_notification.dart';
import 'package:eflutter/data/repositories/notification_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

enum NotificationFilter { all, unread, read }

/// Nhóm thông báo cho bộ lọc "Filter by type"; [value] khớp `category` của API.
enum NotificationCategory {
  posts('POSTS', 'Posts & comments'),
  classrooms('CLASSROOMS', 'Classrooms'),
  assignments('ASSIGNMENTS', 'Assignments'),
  rooms('ROOMS', 'Live classes'),
  exams('EXAMS', 'Exam results');

  const NotificationCategory(this.value, this.label);
  final String value;
  final String label;

  static NotificationCategory? of(AppNotification item) => switch (item.data['type']) {
    'CLASSROOM_POST' ||
    'CLASSROOM_POST_PINNED' ||
    'POST_LIKED' ||
    'POST_COMMENTED' ||
    'COMMENT_REPLIED' ||
    'COMMENT_LIKED' => posts,
    'CLASSROOM' => classrooms,
    'ASSIGNMENT' => assignments,
    'ROOM' => rooms,
    'ATTEMPT' => exams,
    _ => null,
  };
}

@lazySingleton
class NotificationController extends ChangeNotifier {
  NotificationController(Dio dio) : _repository = NotificationRepository(dio);

  final NotificationRepository _repository;
  final List<AppNotification> _items = [];
  int _page = 0;
  int _pageCount = 1;
  bool _loading = false;
  String? _error;
  int _unreadCount = 0;
  NotificationFilter _filter = NotificationFilter.all;
  NotificationCategory? _category;
  Map<String, int> _unreadByCategory = const {};
  int? _latestSeenID;
  // Tăng khi reset để bỏ kết quả của request bắt đầu trước khi đăng xuất.
  int _generation = 0;
  final _newNotifications = StreamController<List<AppNotification>>.broadcast();

  /// Thông báo chưa đọc mới xuất hiện kể từ lần tải trước (không phát ở lần
  /// tải đầu tiên để không bắn lại cả danh sách cũ).
  Stream<List<AppNotification>> get newNotifications => _newNotifications.stream;

  List<AppNotification> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get canLoadMore => _page < _pageCount;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  NotificationFilter get filter => _filter;
  NotificationCategory? get category => _category;
  int unreadIn(NotificationCategory category) => _unreadByCategory[category.value] ?? 0;

  bool? get _readFilter => switch (_filter) {
    NotificationFilter.all => null,
    NotificationFilter.unread => false,
    NotificationFilter.read => true,
  };

  /// Xoá dữ liệu của tài khoản cũ khi đăng xuất.
  void reset() {
    _items.clear();
    _page = 0;
    _pageCount = 1;
    _unreadCount = 0;
    _unreadByCategory = const {};
    _error = null;
    _latestSeenID = null;
    _loading = false;
    _generation++;
    notifyListeners();
  }

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

  Future<void> setCategory(NotificationCategory? value) async {
    if (_category == value) return;
    _category = value;
    notifyListeners();
    await refresh();
  }

  void _decrementUnread(AppNotification item) {
    if (_unreadCount > 0) _unreadCount--;
    final key = NotificationCategory.of(item)?.value;
    final count = _unreadByCategory[key];
    if (key != null && count != null && count > 0) {
      _unreadByCategory = {..._unreadByCategory, key: count - 1};
    }
  }

  Future<void> loadMore() async {
    if (_loading || !canLoadMore) return;
    _loading = true;
    _error = null;
    notifyListeners();
    final generation = _generation;
    try {
      final result = await _repository.getNotifications(
        page: _page + 1,
        read: _readFilter,
        category: _category?.value,
      );
      if (generation != _generation) return;
      _items.addAll(result.notifications);
      if (_page == 0) _detectNew(result.notifications);
      _page = result.page;
      _pageCount = result.pageCount;
      _unreadCount = result.unreadCount;
      _unreadByCategory = result.unreadByCategory;
    } catch (_) {
      if (generation == _generation) _error = 'Unable to load notifications.';
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void _detectNew(List<AppNotification> firstPage) {
    if (firstPage.isEmpty) return;
    final maxID = firstPage.map((item) => item.id).reduce(max);
    final previous = _latestSeenID;
    if (previous != null && maxID > previous) {
      final fresh = firstPage.where((item) => item.id > previous && !item.isRead).toList();
      if (fresh.isNotEmpty) _newNotifications.add(fresh);
    }
    if (previous == null || maxID > previous) _latestSeenID = maxID;
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await _repository.markRead([notification.id]);
      final now = DateTime.now();
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].id == notification.id && !_items[i].isRead) {
          _decrementUnread(_items[i]);
          _items[i] = _items[i].markRead(now);
          break;
        }
      }
      if (_filter == NotificationFilter.unread) {
        _items.removeWhere((item) => item.id == notification.id);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    if (_unreadCount == 0) return;
    try {
      await _repository.markRead(const []);
      final now = DateTime.now();
      for (var i = 0; i < _items.length; i++) {
        if (!_items[i].isRead) {
          _items[i] = _items[i].markRead(now);
        }
      }
      _unreadCount = 0;
      _unreadByCategory = const {};
      if (_filter == NotificationFilter.unread) {
        _items.clear();
        _page = 0;
        _pageCount = 1;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> deleteMany(Set<int> ids) async {
    if (ids.isEmpty) return false;
    try {
      await _repository.deleteMany(ids.toList());
      _items.where((item) => ids.contains(item.id) && !item.isRead).forEach(_decrementUnread);
      _items.removeWhere((item) => ids.contains(item.id));
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Unable to delete notifications.';
      notifyListeners();
      return false;
    }
  }
}
