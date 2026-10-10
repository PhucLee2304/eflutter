class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final String title;
  final String body;
  final Map<String, String> data;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as Map<String, dynamic>? ?? const {};
    return AppNotification(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      data: rawData.map((key, value) => MapEntry(key, value.toString())),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String).toLocal(),
    );
  }

  AppNotification markRead(DateTime value) => AppNotification(
    id: id,
    title: title,
    body: body,
    data: data,
    createdAt: createdAt,
    readAt: value,
  );
}

class NotificationPage {
  const NotificationPage({
    required this.notifications,
    required this.page,
    required this.pageCount,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int page;
  final int pageCount;
  final int unreadCount;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    return NotificationPage(
      notifications: (json['notifications'] as List<dynamic>? ?? const [])
          .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      pageCount: json['pageCount'] as int,
      unreadCount: json['unreadCount'] as int,
    );
  }
}
