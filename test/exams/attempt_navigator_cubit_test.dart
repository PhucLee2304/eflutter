import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_navigator_cubit.dart';
import 'package:eflutter/presentation/exams/cubit/attempt_session_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/strict_attempt_fakes.dart';

void main() {
  late FakeStrictRemote remote;
  late FakeStrictSocket socket;
  late AttemptSessionCubit session;
  late AttemptNavigatorCubit navigator;

  setUp(() async {
    remote = FakeStrictRemote();
    socket = FakeStrictSocket();
    final repository = ExamRepository(remote);
    session = AttemptSessionCubit(repository, socket);
    await session.load(1, initialAttempt: strictAttempt());
    navigator = AttemptNavigatorCubit(repository, session, 1);
  });

  tearDown(() async {
    await navigator.close();
    await session.close();
  });

  test('đang nghe: chỉ trang nghe hiện tại mở, trang đọc khóa', () async {
    await navigator.load();
    final state = navigator.state;

    expect(state.viewingPage, 0);
    expect(state.isPageOpen(0), isTrue);
    expect(state.isPageOpen(1), isFalse);
    expect(state.isPageOpen(2), isFalse);
    final pages = state.navigator!.pages;
    expect(
      state.statusOf(0, pages[0].questions.single),
      PaletteStatus.answered,
    );
    expect(state.statusOf(2, pages[2].questions.single), PaletteStatus.empty);
    expect(state.answeredCount, 1);

    await navigator.openPage(2);
    expect(remote.pageCalls, isEmpty);
  });

  test('sang phần đọc thì về trang đọc đầu, mở và cache trang', () async {
    remote.navigator = navigatorJson(stage: 'READING', current: null);
    await navigator.load();
    expect(navigator.state.viewingPage, 2);
    expect(navigator.state.isPageOpen(0), isFalse);

    await navigator.openPage(2);
    await navigator.openPage(2);
    expect(remote.pageCalls, [2]);
    expect(navigator.state.currentPage?.index, 2);
  });

  test('answered theo đáp án local của session', () async {
    remote.navigator = navigatorJson(stage: 'READING', current: null);
    await navigator.load();
    session.selectAnswer(13, 121);
    await Future<void>.delayed(Duration.zero);

    final question = navigator.state.navigator!.pages[2].questions.single;
    expect(navigator.state.isAnswered(question), isTrue);
    expect(navigator.state.answeredCount, 2);
  });

  test('QUESTION_LOCKED làm tải lại navigator', () async {
    await navigator.load();
    session.selectAnswer(11, 101);
    socket.reply(socket.answers.single, code: 'QUESTION_LOCKED');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(session.state.syncStatuses[11], AnswerSyncStatus.rejected);
    expect(remote.navigatorCalls, 2);
  });

  test(
    'registerPage nạp đáp án đã lưu vào session, không ghi đè local',
    () async {
      await navigator.load();
      session.selectAnswer(12, 999);
      remote.pages[1]!['questions'][0]['selectedOptionId'] = 111;
      navigator.registerPage(await remote.getAttemptPage(1, 1));
      navigator.registerPage(await remote.getAttemptPage(1, 0));

      expect(session.state.selectedOptions[12], 999);
      expect(session.state.selectedOptions[11], 101);
      expect(navigator.state.pages, isEmpty, reason: 'trang nghe không cache');
    },
  );

  test('Trước/Sau bỏ qua trang nghe đã khóa; đổi trang giữ đáp án', () async {
    remote.navigator = navigatorJson(stage: 'READING', current: null);
    (remote.navigator['pages'] as List).add({
      'index': 3,
      'section': 'READING',
      'part': 'PART_6',
      'questions': [
        {'id': 14, 'number': 131, 'answered': false, 'locked': false},
      ],
    });
    remote.pages[3] = pageJson(3);
    await navigator.load();
    await navigator.openPage(2);

    expect(navigator.adjacentPage(-1), isNull);
    expect(navigator.adjacentPage(1), 3);
    session.selectAnswer(13, 121);
    await navigator.openAdjacent(1);
    expect(navigator.state.viewingPage, 3);
    expect(navigator.adjacentPage(1), isNull);
    await navigator.openAdjacent(-1);
    expect(navigator.state.viewingPage, 2);
    expect(remote.pageCalls, [2, 3]);
    expect(session.state.selectedOptions[13], 121);
  });
}
