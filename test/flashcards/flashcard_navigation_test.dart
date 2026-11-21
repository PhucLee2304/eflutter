import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/data_sources/dictionary_remote_data.dart';
import 'package:eflutter/data/models/dictionary/flashcard_models.dart';
import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:eflutter/data/repositories/dictionary_repository.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/app/navigation/navigation_item.dart';
import 'package:eflutter/presentation/dictionary/cubit/flashcard_cubit.dart';
import 'package:eflutter/presentation/dictionary/cubit/word_detail_cubit.dart';
import 'package:eflutter/presentation/dictionary/deck_detail_screen.dart';
import 'package:eflutter/presentation/dictionary/flashcards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _deck = FlashcardDeck(
  id: 7,
  name: 'Test deck',
  cardCount: 1,
  createdAt: '2026-01-01',
);
const _word = WordDetail(id: 42, word: 'sample');
const _card = FlashcardItem(id: 1, deckId: 7, wordId: 42, word: _word);

DictionaryRepository _repository() =>
    DictionaryRepository(DictionaryRemoteData(Dio()));

class _FlashcardCubitStub extends FlashcardCubit {
  _FlashcardCubitStub() : super(_repository());

  @override
  Future<void> loadDashboard() async =>
      emit(const FlashcardLoaded(decks: [_deck]));

  @override
  Future<List<FlashcardDeck>> getDecksList() async => [_deck];

  @override
  Future<GetDeckCardsResponse?> getDeckCards(
    int deckId, {
    int page = 1,
    int pageSize = 20,
  }) async =>
      const GetDeckCardsResponse(data: [_card], total: 1);

  @override
  Future<WordSaveStatus?> getWordSaveStatus(int wordId) async => null;
}

class _WordDetailCubitStub extends WordDetailCubit {
  _WordDetailCubitStub() : super(_repository());

  @override
  Future<void> loadWord(int id) async => emit(const WordDetailState.success(_word));
}

void main() {
  testWidgets('Back follows word, deck, Flashcards, Dictionary', (tester) async {
    getIt.registerFactory<FlashcardCubit>(_FlashcardCubitStub.new);
    getIt.registerFactory<WordDetailCubit>(_WordDetailCubitStub.new);
    addTearDown(() {
      getIt.unregister<FlashcardCubit>();
      getIt.unregister<WordDetailCubit>();
    });

    final router = GoRouter(
      initialLocation: AppRoutes.dictionary.path,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => navigationShell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.dictionary.path,
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => context.go(AppRoutes.flashcards.path),
                        child: const Text('Open Flashcards'),
                      ),
                    ),
                  ),
                  routes: NavigationItem.dictionaryItem.subRoutes,
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.flashcards.path,
          builder: (context, state) => const FlashcardsScreen(),
          routes: [
            GoRoute(
              path: 'deck/:id',
              builder: (context, state) => DeckDetailScreen(
                deckId: int.parse(state.pathParameters['id']!),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open Flashcards'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/flashcards');

    await tester.tap(find.text('Test deck'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/flashcards/deck/7');

    await tester.tap(find.text('sample'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dictionary/42');
    expect(router.routeInformationProvider.value.uri.queryParameters['returnDeckId'], '7');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/flashcards/deck/7');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/flashcards');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/dictionary');
  });
}
