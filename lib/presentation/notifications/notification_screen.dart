import 'dart:async';

import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/data/models/app_notification.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/notifications/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Màn thông báo: danh sách chia nhóm New / Today / Earlier, màn rộng có thêm
/// cột "Filter by type" bên phải.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _controller = getIt<NotificationController>();
  final _scrollController = ScrollController();

  static const _listWidth = 760.0;
  static const _asideWidth = 360.0;
  static const _gap = 24.0;
  static const _line = Color(0xFFE6E8EB);

  @override
  void initState() {
    super.initState();
    _controller.refresh();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 400) {
      _controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _open(AppNotification item) async {
    await _controller.markRead(item);
    if (!mounted) return;
    final path = notificationPath(item.data);
    // Bài viết mở chồng lên để Back quay lại; các trang khác vẫn đi thẳng như cũ.
    if (path == null) return;
    if (path.contains('/posts/')) {
      unawaited(context.push(path, extra: int.tryParse(item.data['commentId'] ?? '')));
    } else {
      context.go(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _listWidth + _gap + _asideWidth + 48;
            // Tiêu đề, tab và khung "Filter by type" đứng yên; chỉ danh sách cuộn.
            return Center(
              child: SizedBox(
                width: wide ? _listWidth + _gap + _asideWidth : _listWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _tabs(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: _gap,
                          children: [
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _controller.refresh,
                                child: ScrollConfiguration(
                                  behavior: ScrollConfiguration.of(
                                    context,
                                  ).copyWith(scrollbars: false),
                                  child: ListView(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.only(bottom: 28),
                                    children: [_list()],
                                  ),
                                ),
                              ),
                            ),
                            if (wide) SizedBox(width: _asideWidth, child: _filterCard()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    final unread = _controller.unreadCount;
    return SizedBox(
      width: _listWidth,
      child: Row(
        spacing: 10,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: ColorName.labelPrimary,
            ),
          ),
          if (unread > 0)
            Text(
              '$unread unread',
              style: const TextStyle(fontSize: 14, color: ColorName.labelSecondary),
            ),
          const Spacer(),
          if (unread > 0)
            TextButton.icon(
              onPressed: _controller.markAllRead,
              style: TextButton.styleFrom(foregroundColor: ColorName.labelSecondary),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all as read', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _tabs() {
    final unread = _controller.unreadCount;
    Widget tab(String label, NotificationFilter value) {
      final on = _controller.filter == value;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _controller.setFilter(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: on ? ColorName.labelPrimary : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: on ? null : Border.all(color: _line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: on ? Colors.white : ColorName.labelSecondary,
            ),
          ),
        ),
      );
    }

    return Row(
      spacing: 8,
      children: [
        tab('All', NotificationFilter.all),
        tab(unread > 0 ? 'Unread · $unread' : 'Unread', NotificationFilter.unread),
      ],
    );
  }

  BoxDecoration get _card => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: _line),
  );

  Widget _list() {
    final items = _controller.items;
    if (items.isEmpty && _controller.loading) {
      return const Padding(padding: EdgeInsets.all(48), child: AppLoader());
    }
    if (items.isEmpty) {
      return Container(
        decoration: _card,
        padding: const EdgeInsets.symmetric(vertical: 56),
        alignment: Alignment.center,
        child: Column(
          spacing: 12,
          children: [
            const Icon(Icons.notifications_none, size: 40, color: ColorName.gray1),
            Text(
              _controller.error ?? 'No notifications yet',
              style: const TextStyle(fontSize: 15, color: ColorName.labelSecondary),
            ),
          ],
        ),
      );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<AppNotification>>{'New': [], 'Today': [], 'Earlier': []};
    for (final item in items) {
      final key = !item.isRead
          ? 'New'
          : item.createdAt.isAfter(today)
          ? 'Today'
          : 'Earlier';
      groups[key]!.add(item);
    }
    return Container(
      decoration: _card,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final MapEntry(:key, :value) in groups.entries)
            if (value.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Text(
                  key,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorName.labelSecondary,
                  ),
                ),
              ),
              for (final item in value)
                _NotificationTile(
                  item: item,
                  onTap: () => _open(item),
                  onMarkRead: () => _controller.markRead(item),
                  onDelete: () => _controller.deleteMany({item.id}),
                ),
            ],
          if (_controller.loading) const Padding(padding: EdgeInsets.all(16), child: AppLoader()),
        ],
      ),
    );
  }

  Widget _filterCard() {
    Widget row(IconData icon, String label, NotificationCategory? value, int count) {
      final on = _controller.category == value;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _controller.setCategory(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFF0F2F5) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            spacing: 12,
            children: [
              Icon(icon, size: 20, color: ColorName.labelSecondary),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                    color: ColorName.labelPrimary,
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ColorName.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: _card,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      child: Column(
        // Khung nằm trong vùng có chiều cao cố định: chỉ cao vừa nội dung.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              'Filter by type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ColorName.labelPrimary,
              ),
            ),
          ),
          row(Icons.notifications_none, 'All notifications', null, _controller.unreadCount),
          for (final c in NotificationCategory.values)
            row(_categoryIcon(c), c.label, c, _controller.unreadIn(c)),
        ],
      ),
    );
  }
}

IconData _categoryIcon(NotificationCategory c) => switch (c) {
  NotificationCategory.posts => Icons.chat_outlined,
  NotificationCategory.classrooms => Icons.school_outlined,
  NotificationCategory.assignments => Icons.assignment_outlined,
  NotificationCategory.rooms => Icons.videocam_outlined,
  NotificationCategory.exams => Icons.check_box_outlined,
};

IconData _typeIcon(String? type) => switch (type) {
  'COMMENT_REPLIED' => Icons.reply,
  'POST_COMMENTED' => Icons.chat_outlined,
  'POST_LIKED' || 'COMMENT_LIKED' => Icons.favorite_border,
  'CLASSROOM_POST' || 'CLASSROOM_POST_PINNED' => Icons.campaign_outlined,
  'CLASSROOM' => Icons.school_outlined,
  'ASSIGNMENT' => Icons.assignment_outlined,
  'ROOM' => Icons.videocam_outlined,
  'ATTEMPT' => Icons.check_box_outlined,
  _ => Icons.notifications_none,
};

/// "5 minutes ago", "3 hours ago", "Yesterday", rồi ngày tháng.
String _timeAgo(DateTime value) {
  final diff = DateTime.now().difference(value);
  String unit(int n, String word) => '$n $word${n == 1 ? '' : 's'} ago';
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return unit(diff.inMinutes, 'minute');
  if (diff.inDays < 1) return unit(diff.inHours, 'hour');
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return unit(diff.inDays, 'day');
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = '${months[value.month - 1]} ${value.day}';
  return value.year == DateTime.now().year ? date : '$date, ${value.year}';
}

/// Một dòng thông báo; rê chuột hiện nút ••• (Mark as read / Delete).
class _NotificationTile extends StatefulWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onMarkRead,
    required this.onDelete,
  });
  final AppNotification item;
  final VoidCallback onTap, onMarkRead, onDelete;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool hover = false, menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final unread = !item.isRead;
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: Material(
        color: hover || menuOpen ? const Color(0xFFF2F4F7) : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            child: Row(
              spacing: 14,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: Color(0xFFF0F2F5), shape: BoxShape.circle),
                  child: Icon(
                    _typeIcon(item.data['type']),
                    size: 22,
                    color: ColorName.labelSecondary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                          color: ColorName.labelPrimary,
                        ),
                      ),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: unread ? const Color(0xFF404040) : ColorName.labelSecondary,
                        ),
                      ),
                      Text(
                        _timeAgo(item.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                          color: unread ? ColorName.primary : ColorName.gray1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hover || menuOpen) _menu(unread),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: unread ? ColorName.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(bool unread) => PopupMenuButton<VoidCallback>(
    tooltip: 'More',
    position: PopupMenuPosition.under,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    constraints: const BoxConstraints(minWidth: 176),
    onOpened: () => setState(() => menuOpen = true),
    onCanceled: () => setState(() => menuOpen = false),
    onSelected: (action) {
      setState(() => menuOpen = false);
      action();
    },
    itemBuilder: (_) => [
      if (unread) _item(Icons.check, 'Mark as read', widget.onMarkRead),
      _item(Icons.close, 'Delete', widget.onDelete, danger: true),
    ],
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE6E8EB)),
      ),
      child: const Icon(Icons.more_horiz, size: 18, color: ColorName.labelSecondary),
    ),
  );

  PopupMenuItem<VoidCallback> _item(
    IconData icon,
    String label,
    VoidCallback action, {
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFE53935) : ColorName.labelPrimary;
    return PopupMenuItem(
      value: action,
      height: 40,
      child: Row(
        spacing: 10,
        children: [
          Icon(icon, size: 18, color: color),
          Text(label, style: TextStyle(fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
