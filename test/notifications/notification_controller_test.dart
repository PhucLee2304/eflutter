import 'package:dio/dio.dart';
import 'package:eflutter/presentation/notifications/notification_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads pages, marks clicked items or all items read, and deletes items',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (options.method == 'GET') {
              final page = options.queryParameters['page'] as int;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'notifications': [
                      {
                        'id': page,
                        'title': 'Notification $page',
                        'body': 'Body',
                        'data': {'id': '$page', 'type': 'HOME'},
                        'createdAt': '2026-10-10T05:00:00Z',
                      },
                    ],
                    'page': page,
                    'pageCount': 2,
                    'unreadCount': 2,
                  },
                ),
              );
              return;
            }
            handler.resolve(Response(requestOptions: options, statusCode: 204));
          },
        ),
      );

      final controller = NotificationController(dio);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.items.map((item) => item.id), [1, 2]);
      expect(controller.canLoadMore, isFalse);
      expect(controller.unreadCount, 2);
      expect(requests.where((request) => request.method == 'PATCH'), isEmpty);

      await controller.markRead(controller.items.first);
      expect(controller.items.first.isRead, isTrue);
      expect(controller.unreadCount, 1);
      expect(
        requests.any(
          (request) =>
              request.method == 'PATCH' &&
              (request.data as Map<String, dynamic>)['ids'].first == 1,
        ),
        isTrue,
      );

      await controller.markAllRead();
      expect(controller.items.every((item) => item.isRead), isTrue);
      expect(controller.unreadCount, 0);
      expect(
        requests.any(
          (request) =>
              request.method == 'PATCH' &&
              (request.data as Map<String, dynamic>)['ids'].isEmpty,
        ),
        isTrue,
      );

      expect(await controller.deleteMany({2}), isTrue);
      expect(controller.items.map((item) => item.id), [1]);
      expect(requests.any((request) => request.method == 'DELETE'), isTrue);
      controller.dispose();
    },
  );
}
