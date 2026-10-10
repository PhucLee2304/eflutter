import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/presentation/classrooms/classroom_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('shows classroom list and primary actions', (tester) async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': [
                    {
                      'id': 1,
                      'code': 'ABC12345',
                      'name': 'Lop Toan',
                      'active': true,
                      'teacher': {
                        'id': '12',
                        'name': 'Co Lan',
                        'email': 'teacher@example.com',
                      },
                    },
                  ],
                  'page': 1,
                  'pageCounts': 1,
                },
              ),
            );
          },
        ),
      );
    getIt.registerSingleton<Dio>(dio);
    addTearDown(() => getIt.unregister<Dio>());

    await tester.pumpWidget(const MaterialApp(home: ClassroomListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Lop Toan'), findsOneWidget);
    expect(find.textContaining('ABC12345'), findsOneWidget);
    expect(find.byTooltip('Create classroom'), findsOneWidget);
    expect(find.byTooltip('Join classroom'), findsOneWidget);
  });

  testWidgets('sends the active filter to the classrooms API', (tester) async {
    RequestOptions? lastRequest;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastRequest = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'data': <dynamic>[], 'page': 1, 'pageCounts': 1},
              ),
            );
          },
        ),
      );
    getIt.registerSingleton<Dio>(dio);
    addTearDown(() => getIt.unregister<Dio>());

    await tester.pumpWidget(const MaterialApp(home: ClassroomListScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();

    expect(lastRequest?.queryParameters['active'], isTrue);
    expect(lastRequest?.queryParameters.containsKey('role'), isFalse);
    expect(lastRequest?.queryParameters.containsKey('sortBy'), isFalse);
  });

  testWidgets('loads the next classroom page while scrolling', (tester) async {
    final requestedPages = <int>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final page = options.queryParameters['page'] as int;
            requestedPages.add(page);
            final start = page == 1 ? 1 : 13;
            final count = page == 1 ? 12 : 1;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': List.generate(count, (index) {
                    final id = start + index;
                    return {
                      'id': id,
                      'code': 'CLASS$id',
                      'name': 'Classroom $id',
                      'active': true,
                    };
                  }),
                  'page': page,
                  'pageCounts': 2,
                },
              ),
            );
          },
        ),
      );
    getIt.registerSingleton<Dio>(dio);
    addTearDown(() => getIt.unregister<Dio>());

    await tester.pumpWidget(const MaterialApp(home: ClassroomListScreen()));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(requestedPages, containsAllInOrder([1, 2]));
    expect(find.text('Classroom 13'), findsOneWidget);
  });

  testWidgets(
    'creates a classroom and closes the dialog without disposed controllers',
    (tester) async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final data = options.method == 'POST'
                  ? {
                      'id': 2,
                      'code': 'NEW12345',
                      'name': 'New class',
                      'active': true,
                    }
                  : {'data': <dynamic>[], 'page': 1, 'pageCounts': 1};
              handler.resolve(Response(requestOptions: options, data: data));
            },
          ),
        );
      getIt.registerSingleton<Dio>(dio);
      addTearDown(() => getIt.unregister<Dio>());
      final router = GoRouter(
        initialLocation: '/classrooms',
        routes: [
          GoRoute(
            path: '/classrooms',
            builder: (_, _) => const ClassroomListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, _) =>
                    const Scaffold(body: Text('Created classroom')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Create classroom'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Classroom name'),
        'New class',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Created classroom'), findsOneWidget);
    },
  );

  testWidgets('closes join dialog without disposed controllers', (
    tester,
  ) async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'data': <dynamic>[], 'page': 1, 'pageCounts': 1},
              ),
            );
          },
        ),
      );
    getIt.registerSingleton<Dio>(dio);
    addTearDown(() => getIt.unregister<Dio>());
    await tester.pumpWidget(const MaterialApp(home: ClassroomListScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Join classroom'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Class code'),
      'ABC12345',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('centers search within the content area beside navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'data': <dynamic>[], 'page': 1, 'pageCounts': 1},
              ),
            );
          },
        ),
      );
    getIt.registerSingleton<Dio>(dio);
    addTearDown(() => getIt.unregister<Dio>());

    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            SizedBox(width: 240),
            Expanded(child: ClassroomListScreen()),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.widgetWithText(
      TextField,
      'Search by name, description, or teacher',
    );
    expect(tester.getCenter(search).dx, closeTo(840, 1));
    expect(tester.takeException(), isNull);
  });
}
