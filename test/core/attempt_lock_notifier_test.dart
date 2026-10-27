import 'package:dio/dio.dart';
import 'package:eflutter/core/attempt_lock/attempt_integrity_reporter.dart';
import 'package:eflutter/core/attempt_lock/attempt_lock_notifier.dart';
import 'package:eflutter/core/attempt_lock/leave_guard.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/data/models/exam_attempt_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRemoteData remote;
  late _FakeReporter reporter;
  late _FakeLeaveGuard leaveGuard;
  late AttemptLockNotifier lock;

  setUp(() {
    remote = _FakeRemoteData();
    reporter = _FakeReporter();
    leaveGuard = _FakeLeaveGuard();
    lock = AttemptLockNotifier(remote, reporter, leaveGuard);
  });

  tearDown(() => lock.dispose());

  group('refresh', () {
    test('locks the ACTIVE attempt returned by the server', () async {
      remote.activeAttemptIds = [7];

      await lock.refresh();

      expect(lock.isLocked, isTrue);
      expect(lock.attemptId, 7);
      expect(lock.lockedPath, '/attempts/7/take');
      expect(leaveGuard.enabled, isTrue);
      expect(remote.requestedStatus, 'ACTIVE');
      expect(reporter.types, [AttemptIntegrityEventType.sessionRestored]);
    });

    test('unlocks when the server has no ACTIVE attempt', () async {
      lock.lock(7);
      remote.activeAttemptIds = [];

      await lock.refresh();

      expect(lock.isLocked, isFalse);
      expect(leaveGuard.enabled, isFalse);
    });

    test('keeps the current lock when the request fails', () async {
      lock.lock(7);
      remote.fail = true;

      await lock.refresh();

      expect(lock.attemptId, 7);
    });
  });

  group('redirectFor', () {
    test('lets everything through when unlocked', () {
      expect(lock.redirectFor('/classrooms'), isNull);
      expect(reporter.types, isEmpty);
    });

    test('keeps the user on the attempt screen when locked', () {
      lock.lock(7);

      expect(lock.redirectFor('/attempts/7/take'), isNull);
      expect(lock.redirectFor('/classrooms'), '/attempts/7/take');
      expect(lock.redirectFor('/attempts/8/take'), '/attempts/7/take');
      expect(
        lock.redirectFor('/histories/attempts/7/history'),
        '/attempts/7/take',
      );
      expect(reporter.types, [
        AttemptIntegrityEventType.navigationBlocked,
        AttemptIntegrityEventType.navigationBlocked,
        AttemptIntegrityEventType.navigationBlocked,
      ]);
      expect(reporter.details.first, '/classrooms');
    });
  });

  test('lock and unlock notify listeners only on change', () {
    var notifications = 0;
    lock.addListener(() => notifications++);

    lock.lock(7);
    lock.lock(7);
    lock.unlock();
    lock.unlock();

    expect(notifications, 2);
  });

  testWidgets('router guard sends the user back to the attempt screen', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      refreshListenable: lock,
      redirect: (context, state) => lock.redirectFor(state.uri.path),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/classrooms',
          builder: (_, _) => const Text('classrooms'),
        ),
        GoRoute(
          path: '/attempts/:id/take',
          builder: (_, state) => Text('attempt ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    // Khóa được khôi phục khi đang ở màn khác: bị đưa thẳng vào màn làm bài.
    lock.lock(7);
    await tester.pumpAndSettle();
    expect(find.text('attempt 7'), findsOneWidget);

    router.go('/classrooms');
    await tester.pumpAndSettle();
    expect(find.text('attempt 7'), findsOneWidget);

    lock.unlock();
    router.go('/classrooms');
    await tester.pumpAndSettle();
    expect(find.text('classrooms'), findsOneWidget);
  });
}

class _FakeRemoteData implements RemoteDataBase {
  List<int> activeAttemptIds = [];
  bool fail = false;
  String? requestedStatus;

  @override
  Future<ExamAttemptPage> getAttempts({
    required String status,
    required int page,
    required int pageSize,
  }) async {
    requestedStatus = status;
    if (fail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/exams/api/v1/attempts'),
        type: DioExceptionType.connectionError,
      );
    }
    return ExamAttemptPage.fromResponse(
      activeAttemptIds
          .map(
            (id) => {
              'id': id,
              'examId': 2,
              'mode': 'TEST',
              'status': 'ACTIVE',
              'startedAt': '2026-10-24T01:00:00Z',
              'totalQuestions': 1,
            },
          )
          .toList(),
      requestedPage: page,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReporter implements AttemptIntegrityReporter {
  final events = <AttemptIntegrityEvent>[];

  List<AttemptIntegrityEventType> get types =>
      events.map((event) => event.type).toList();
  List<String?> get details => events.map((event) => event.detail).toList();

  @override
  void report(AttemptIntegrityEvent event) => events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeLeaveGuard implements LeaveGuard {
  bool enabled = false;

  @override
  void enable() => enabled = true;

  @override
  void disable() => enabled = false;
}
