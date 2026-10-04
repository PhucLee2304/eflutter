import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  setUpAll(() {
    if (!getIt.isRegistered<Talker>()) {
      getIt.registerSingleton<Talker>(Talker());
    }
  });

  test('list uses current user route, query, and pagination', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': [
                    {
                      'id': 3,
                      'code': 'ABC12345',
                      'name': 'Lop 12',
                      'active': true,
                    },
                  ],
                  'page': 2,
                  'pageCounts': 4,
                },
              ),
            );
          },
        ),
      );
    final result = await ClassroomRepository(
      dio,
    ).getMine(page: 2, query: 'Lop');
    expect(captured.path, '/classrooms/api/v1/classrooms/me');
    expect(captured.queryParameters['page'], 2);
    expect(captured.queryParameters['query'], 'Lop');
    expect(result.dataOrNull?.items.single.id, 3);
  });

  test('join and review use backend contract', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'id': 7,
                  'approved': null,
                  'user': {
                    'id': 'student-1',
                    'name': 'Student',
                    'email': 's@example.com',
                  },
                },
              ),
            );
          },
        ),
      );
    final repository = ClassroomRepository(dio);
    expect(await repository.join(' abc12345 '), isA<Success>());
    expect(requests.first.path, '/classrooms/api/v1/classrooms/join');
    expect((requests.first.data as Map)['code'], 'ABC12345');
    expect(await repository.review(5, 'student-1', true), isA<Success>());
    expect(
      requests.last.path,
      '/classrooms/api/v1/classrooms/5/members/student-1/approve',
    );
  });

  test(
    'sends the full description and an empty value when clearing it',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'id': 1,
                    'code': 'ABC12345',
                    'name': 'Class',
                    'active': true,
                  },
                ),
              );
            },
          ),
        );
      final repository = ClassroomRepository(dio);
      final longDescription = 'A long description. ' * 1000;
      expect(
        await repository.create('Class', description: longDescription),
        isA<Success>(),
      );
      expect((requests.last.data as Map)['description'], longDescription.trim());

      expect(
        await repository.update(1, name: 'Class', description: ''),
        isA<Success>(),
      );
      expect((requests.last.data as Map).containsKey('description'), isTrue);
      expect((requests.last.data as Map)['description'], '');
    },
  );
}
