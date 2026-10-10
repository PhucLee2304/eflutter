import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/date_time_extension.dart';
import 'package:eflutter/data/models/app_notification.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/notifications/notification_controller.dart';
import 'package:eflutter/presentation/notifications/notification_push_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _controller = getIt<NotificationController>();
  final _scrollController = ScrollController();
  final _selectedIDs = <int>{};

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

  Future<void> _deleteSelected() async {
    if (await _controller.deleteMany(_selectedIDs)) {
      setState(_selectedIDs.clear);
    }
  }

  void _open(AppNotification item) {
    final id = int.tryParse(item.data['id'] ?? '');
    switch (item.data['type']) {
      case 'CLASSROOM':
        if (id != null) context.go(classroomPath(id));
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Enable push notifications',
                          onPressed: () async {
                            final enabled =
                                await getIt<NotificationPushService>()
                                    .enablePush();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  enabled
                                      ? 'Push notifications enabled.'
                                      : 'Push notifications are unavailable.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.notifications_active_outlined),
                        ),
                        if (_selectedIDs.isNotEmpty)
                          IconButton(
                            tooltip: 'Delete selected',
                            onPressed: _deleteSelected,
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SegmentedButton<NotificationFilter>(
                      segments: const [
                        ButtonSegment(
                          value: NotificationFilter.all,
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: NotificationFilter.unread,
                          label: Text('Unread'),
                        ),
                        ButtonSegment(
                          value: NotificationFilter.read,
                          label: Text('Read'),
                        ),
                      ],
                      selected: {_controller.filter},
                      onSelectionChanged: (values) =>
                          _controller.setFilter(values.first),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _buildList()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList() {
    if (_controller.items.isEmpty && _controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.items.isEmpty) {
      return Center(child: Text(_controller.error ?? 'No notifications.'));
    }
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: _controller.items.length + (_controller.loading ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _controller.items.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _controller.items[index];
          return VisibilityDetector(
            key: ValueKey('notification-${item.id}'),
            onVisibilityChanged: (info) {
              if (info.visibleFraction >= 0.75) {
                _controller.notificationVisible(item);
              }
            },
            child: ListTile(
              minTileHeight: 82,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              leading: Checkbox(
                value: _selectedIDs.contains(item.id),
                onChanged: (selected) => setState(() {
                  if (selected ?? false) {
                    _selectedIDs.add(item.id);
                  } else {
                    _selectedIDs.remove(item.id);
                  }
                }),
              ),
              title: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: Text(
                item.createdAt.toFormatString(pattern: 'dd/MM HH:mm'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () => _open(item),
            ),
          );
        },
      ),
    );
  }
}
