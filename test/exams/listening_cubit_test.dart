import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_navigator_cubit.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:eflutter/presentation/exams/cubit/listening_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/strict_attempt_fakes.dart';

void main() {
  late FakeStrictRemote remote;
  late FakeStrictSocket socket;
  late AttemptSessionCubit session;
  late AttemptNavigatorCubit navigator;
  late ListeningCubit listening;

  void setUpCubits(FakeAsync async) {
    remote = FakeStrictRemote();
    socket = FakeStrictSocket();
    final repository = ExamRepository(remote);
    session = AttemptSessionCubit(repository, socket)
      ..load(1, initialAttempt: strictAttempt());
    navigator = AttemptNavigatorCubit(repository, session, 1)..load();
    async.flushMicrotasks();
    listening = ListeningCubit(repository, socket, navigator)..start();
    async.flushMicrotasks();
  }

  void tearDownCubits(FakeAsync async) {
    listening.close();
    navigator.close();
    session.close();
    async.flushMicrotasks();
  }

  Map<String, dynamic> ack(int? page) => {
    'stage': page == null ? 'READING' : 'LISTENING',
    'currentPage': ?page,
    'serverTime': '2026-10-26T01:00:10Z',
  };

  test('phát xong → đếm gap → gửi advance → ACK tải trang sau', () {
    fakeAsync((async) {
      setUpCubits(async);
      expect(listening.state.phase, ListeningPhase.playing);
      expect(listening.state.page?.index, 0);

      listening.audioCompleted();
      expect(listening.state.phase, ListeningPhase.gap);
      expect(listening.state.gapRemaining, const Duration(seconds: 5));
      async.elapse(const Duration(seconds: 4));
      expect(socket.advances, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(socket.advances.single.page, 0);
      expect(listening.state.phase, ListeningPhase.advancing);

      socket.reply(socket.advances.single.requestId, payload: ack(1));
      async.flushMicrotasks();
      expect(listening.state.page?.index, 1);
      expect(navigator.state.navigator?.currentPage, 1);
      expect(navigator.state.viewingPage, 1);
      tearDownCubits(async);
    });
  });

  test('ACK sang READING thì kết thúc phần nghe', () {
    fakeAsync((async) {
      setUpCubits(async);
      listening.audioCompleted();
      async.elapse(const Duration(seconds: 5));
      socket.reply(socket.advances.single.requestId, payload: ack(null));
      async.flushMicrotasks();

      expect(listening.state.phase, ListeningPhase.finished);
      expect(navigator.state.isListening, isFalse);
      expect(navigator.state.viewingPage, 2);
      tearDownCubits(async);
    });
  });

  test('TOO_EARLY thử lại, MISMATCH tải lại navigator và đi theo server', () {
    fakeAsync((async) {
      setUpCubits(async);
      listening.audioCompleted();
      async.elapse(const Duration(seconds: 5));
      socket.reply(
        socket.advances.last.requestId,
        code: 'LISTENING_ADVANCE_TOO_EARLY',
      );
      async.elapse(const Duration(seconds: 1));
      expect(socket.advances, hasLength(2));

      remote.navigator = navigatorJson(current: 1);
      socket.reply(
        socket.advances.last.requestId,
        code: 'LISTENING_PAGE_MISMATCH',
      );
      async.flushMicrotasks();
      expect(remote.navigatorCalls, 2);
      expect(listening.state.page?.index, 1);
      tearDownCubits(async);
    });
  });

  test('F5 giữa gap: chỉ đếm phần gap còn lại', () {
    fakeAsync((async) {
      remote = FakeStrictRemote();
      setUpCubits(async);
      tearDownCubits(async);

      remote = FakeStrictRemote();
      remote.pages[0] = pageJson(0, elapsedMs: 6000, audioMs: 4000);
      socket = FakeStrictSocket();
      final repository = ExamRepository(remote);
      session = AttemptSessionCubit(repository, socket)
        ..load(1, initialAttempt: strictAttempt());
      navigator = AttemptNavigatorCubit(repository, session, 1)..load();
      async.flushMicrotasks();
      listening = ListeningCubit(repository, socket, navigator)..start();
      async.flushMicrotasks();

      expect(listening.state.phase, ListeningPhase.gap);
      expect(listening.state.gapRemaining, const Duration(seconds: 3));
      async.elapse(const Duration(seconds: 3));
      expect(socket.advances.single.page, 0);
      tearDownCubits(async);
    });
  });

  test('trang nghe đã bị server tự tiến (409) thì resync', () {
    fakeAsync((async) {
      remote = FakeStrictRemote();
      socket = FakeStrictSocket();
      final repository = ExamRepository(remote);
      session = AttemptSessionCubit(repository, socket)
        ..load(1, initialAttempt: strictAttempt());
      navigator = AttemptNavigatorCubit(repository, session, 1)..load();
      async.flushMicrotasks();
      remote.lockedPages.add(0);
      remote.navigator = navigatorJson(current: 1);
      listening = ListeningCubit(repository, socket, navigator)..start();
      async.flushMicrotasks();

      expect(remote.pageCalls, [0, 1]);
      expect(listening.state.page?.index, 1);
      tearDownCubits(async);
    });
  });

  test('socket chưa kết nối thì thử gửi advance lại', () {
    fakeAsync((async) {
      setUpCubits(async);
      socket.connected = false;
      listening.audioCompleted();
      async.elapse(const Duration(seconds: 5));
      expect(socket.advances, isEmpty);
      socket.connected = true;
      async.elapse(const Duration(seconds: 1));
      expect(socket.advances.single.page, 0);
      tearDownCubits(async);
    });
  });
}
