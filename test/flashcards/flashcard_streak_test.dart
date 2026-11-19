import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/data_sources/dictionary_remote_data.dart';
import 'package:eflutter/data/models/dictionary/flashcard_models.dart';
import 'package:eflutter/data/repositories/dictionary_repository.dart';
import 'package:eflutter/presentation/dictionary/cubit/flashcard_cubit.dart';
import 'package:eflutter/presentation/dictionary/flashcards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FlashcardCubitStub extends FlashcardCubit {
  _FlashcardCubitStub()
    : super(DictionaryRepository(DictionaryRemoteData(Dio())));

  @override
  Future<void> loadDashboard() async {
    emit(
      const FlashcardLoaded(
        decks: [],
        stats: FlashcardUserStats(dueToday: 2, streak: 4),
      ),
    );
  }

  void showReviewedToday() {
    emit(
      const FlashcardLoaded(
        decks: [],
        stats: FlashcardUserStats(dueToday: 1, streak: 5, reviewedToday: true),
      ),
    );
  }
}

void main() {
  testWidgets('flashcard streak prompts a review then celebrates today', (
    tester,
  ) async {
    final cubit = _FlashcardCubitStub();
    getIt.registerSingleton<FlashcardCubit>(cubit);
    addTearDown(() => getIt.unregister<FlashcardCubit>());

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: FlashcardsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('4 ngày'), findsOneWidget);
    expect(
      find.text('Ôn ít nhất một thẻ hôm nay để giữ chuỗi 4 ngày.'),
      findsOneWidget,
    );

    cubit.showReviewedToday();
    await tester.pumpAndSettle();
    expect(find.text('5 ngày'), findsOneWidget);
    expect(
      find.text('Bạn đã ôn hôm nay. Chuỗi 5 ngày đang tiếp tục!'),
      findsOneWidget,
    );
  });
}
