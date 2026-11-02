import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/dictionary/dictionary_topic.dart';
import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:eflutter/presentation/dictionary/cubit/dictionary_search_cubit.dart';
import 'package:eflutter/presentation/dictionary/cubit/dictionary_topic_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:go_router/go_router.dart';

class DictionarySearchScreen extends StatefulWidget {
  const DictionarySearchScreen({super.key});

  @override
  State<DictionarySearchScreen> createState() => _DictionarySearchScreenState();
}

class _DictionarySearchScreenState extends State<DictionarySearchScreen> {
  final _searchController = TextEditingController();
  final _cubit = getIt<DictionarySearchCubit>();
  final _topicCubit = getIt<DictionaryTopicCubit>();
  final _scrollController = ScrollController();

  // Khi nào tab topic đang active (false = tab tìm kiếm)
  bool _isTopicMode = false;

  @override
  void initState() {
    super.initState();
    _topicCubit.loadTopics();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cubit.close();
    _topicCubit.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isTopicMode = false);
    _cubit.search(query);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (currentScroll >= maxScroll - 200) {
      _topicCubit.loadMoreWords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
        BlocProvider.value(value: _topicCubit),
      ],
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text('Dictionary'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              tooltip: 'Flashcards',
              onPressed: () => context.push(AppRoutes.flashcards.path),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for a word...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _isTopicMode = true);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _onSearch(),
                onChanged: (val) {
                  setState(() {});
                  if (val.isEmpty) setState(() => _isTopicMode = true);
                },
              ),
            ),

            // ── Topic chips ─────────────────────────────────────────────────
            BlocBuilder<DictionaryTopicCubit, DictionaryTopicState>(
              builder: (context, topicState) {
                final topics = topicState.maybeWhen(
                  topicsLoaded: (t) => t,
                  loadingWords: (t, _) => t,
                  wordsLoaded: (t, _, a, b, c, d) => t,
                  orElse: () => null,
                );

                if (topics == null || topics.isEmpty) {
                  return topicState.maybeWhen(
                    loadingTopics: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: LinearProgressIndicator()),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  );
                }

                final selectedTopic = topicState.maybeWhen(
                  loadingWords: (_, t) => t,
                  wordsLoaded: (_, t, a, b, c, d) => t,
                  orElse: () => null,
                );

                return _TopicChipsBar(
                  topics: topics,
                  selectedTopic: selectedTopic,
                  onTopicSelected: (topic) {
                    setState(() => _isTopicMode = true);
                    _topicCubit.selectTopic(topic);
                  },
                );
              },
            ),

            const Divider(height: 1),

            // ── Content area ────────────────────────────────────────────────
            Expanded(
              child: _isTopicMode
                  ? _TopicWordsView(scrollController: _scrollController)
                  : _SearchResultsView(scrollController: _scrollController),
            ),
          ],
        ),
      ),
    );
  }
}

IconData? _resolveTopicIcon(String? iconName) {
  if (iconName == null || iconName.isEmpty) return null;
  switch (iconName.toLowerCase()) {
    case 'badge':
      return Icons.badge_outlined;
    case 'paid':
      return Icons.paid_outlined;
    case 'flight_takeoff':
      return Icons.flight_takeoff_outlined;
    case 'precision_manufacturing':
      return Icons.precision_manufacturing_outlined;
    case 'school':
      return Icons.school_outlined;
    case 'eco':
      return Icons.eco_outlined;
    case 'diversity_3':
      return Icons.diversity_3_outlined;
    case 'psychology':
      return Icons.psychology_outlined;
    case 'favorite':
      return Icons.favorite_outline;
    case 'hub':
      return Icons.hub_outlined;
    default:
      return null;
  }
}

// ─── Topic chips multi-line panel ─────────────────────────────────────────────

class _TopicChipsBar extends StatelessWidget {
  final List<DictionaryTopic> topics;
  final DictionaryTopic? selectedTopic;
  final ValueChanged<DictionaryTopic> onTopicSelected;

  const _TopicChipsBar({
    required this.topics,
    required this.selectedTopic,
    required this.onTopicSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_mosaic_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Vocabulary Topics (${topics.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topics.map((topic) {
              final isSelected = selectedTopic?.id == topic.id;
              final iconData = _resolveTopicIcon(topic.icon);
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onTopicSelected(topic),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (iconData != null) ...[
                        Icon(
                          iconData,
                          size: 15,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                      ] else if (topic.icon != null && topic.icon!.isNotEmpty) ...[
                        Text(topic.icon!, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        topic.name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Topic words view ──────────────────────────────────────────────────────────

class _TopicWordsView extends StatelessWidget {
  final ScrollController scrollController;

  const _TopicWordsView({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DictionaryTopicCubit, DictionaryTopicState>(
      builder: (context, state) {
        return state.when(
          initial: () => _emptyHint(),
          loadingTopics: () => const Center(child: CircularProgressIndicator()),
          topicsLoaded: (_) => _emptyHint(),
          loadingWords: (_, topic) => Column(
            children: [
              _TopicHeader(topic: topic),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
          wordsLoaded: (_, topic, words, currentPage, totalPages, isLoadingMore) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopicHeader(topic: topic, wordCount: words.length),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: words.length + (isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == words.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _WordListTile(word: words[index]);
                    },
                  ),
                ),
              ],
            );
          },
          error: (message) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Select a topic above\nto browse vocabulary',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─── Topic header ─────────────────────────────────────────────────────────────

class _TopicHeader extends StatelessWidget {
  final DictionaryTopic topic;
  final int? wordCount;

  const _TopicHeader({required this.topic, this.wordCount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              final iconData = _resolveTopicIcon(topic.icon);
              if (iconData != null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(iconData, size: 24, color: colorScheme.primary),
                );
              }
              if (topic.icon != null && topic.icon!.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(topic.icon!, style: const TextStyle(fontSize: 22)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (topic.description != null && topic.description!.isNotEmpty)
                  Text(
                    topic.description!,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (wordCount != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$wordCount words',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Word list tile ────────────────────────────────────────────────────────────

class _WordListTile extends StatelessWidget {
  final WordSummary word;

  const _WordListTile({required this.word});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.push('/dictionary/${word.word}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.word,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (word.phonetic != null && word.phonetic!.isNotEmpty)
                    Text(
                      word.phonetic!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Search results view ───────────────────────────────────────────────────────

class _SearchResultsView extends StatelessWidget {
  final ScrollController scrollController;

  const _SearchResultsView({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DictionarySearchCubit, DictionarySearchState>(
      builder: (context, state) {
        return state.when(
          initial: () => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Type a word to search',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          success: (response) {
            if (response.data.isEmpty) {
              return const Center(child: Text('No words found.'));
            }
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: response.data.length,
              itemBuilder: (context, index) {
                final word = response.data[index];
                return _WordListTile(word: word);
              },
            );
          },
          error: (message) => Center(
            child: Text(message, style: const TextStyle(color: Colors.red)),
          ),
        );
      },
    );
  }
}
