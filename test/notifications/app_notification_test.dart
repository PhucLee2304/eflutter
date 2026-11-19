import 'package:eflutter/data/models/app_notification.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/notifications/notification_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flashcard due notification opens the relevant study deck', () {
    final notification = AppNotification.fromJson({
      'id': 9,
      'title': 'Review due',
      'body': 'Review adjective',
      'data': {'type': 'FLASHCARD_DUE', 'deckId': '7', 'cardId': '42'},
      'createdAt': '2026-11-19T05:00:00Z',
    });
    expect(NotificationCategory.of(notification), NotificationCategory.flashcards);
    expect(notificationPath(notification.data), flashcardStudyPath(deckId: 7));
  });

  test('parses a notification page and preserves navigation data', () {
    final page = NotificationPage.fromJson({
      'notifications': [
        {
          'id': 8,
          'title': 'Class started',
          'body': 'Join now',
          'data': {'id': '4', 'type': 'ROOM'},
          'createdAt': '2026-10-10T05:00:00Z',
          'readAt': null,
        },
      ],
      'page': 1,
      'pageCount': 3,
      'unreadCount': 5,
    });

    expect(page.notifications.single.id, 8);
    expect(page.notifications.single.data, {'id': '4', 'type': 'ROOM'});
    expect(page.notifications.single.isRead, isFalse);
    expect(page.pageCount, 3);
    expect(page.unreadCount, 5);
  });

  test('markRead returns a read copy without changing navigation data', () {
    final notification = AppNotification.fromJson({
      'id': 1,
      'title': 'Title',
      'body': 'Body',
      'data': {'id': '2', 'type': 'CLASSROOM'},
      'createdAt': '2026-10-10T05:00:00Z',
    });

    final read = notification.markRead(DateTime(2026, 10, 10));
    expect(notification.isRead, isFalse);
    expect(read.isRead, isTrue);
    expect(read.data, notification.data);
  });
}
