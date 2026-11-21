import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/dictionary/flashcard_models.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/dictionary/cubit/flashcard_cubit.dart';
import 'package:eflutter/presentation/dictionary/widgets/deck_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final _cubit = getIt<FlashcardCubit>();

  @override
  void initState() {
    super.initState();
    _cubit.loadDashboard();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _handleDeleteDeck(FlashcardDeck deck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete deck'),
        content: Text(
          'Delete "${deck.name}" (${deck.cardCount} ${deck.cardCount == 1 ? 'word' : 'words'})?\nWords in the dictionary will remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _cubit.deleteDeck(deck.id);
      if (mounted) {
        context.showToast(
          success ? 'Deleted deck "${deck.name}"' : 'Failed to delete deck',
          type: success ? ToastType.success : ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flashcards'),
          leading: BackButton(onPressed: () => context.go(AppRoutes.dictionary.path)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => _cubit.loadDashboard(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => DeckFormDialog.show(context, cubit: _cubit),
          icon: const Icon(Icons.add),
          label: const Text('Create deck'),
        ),
        body: BlocBuilder<FlashcardCubit, FlashcardState>(
          builder: (context, state) {
            return switch (state) {
              FlashcardInitial() ||
              FlashcardLoading() => const Center(child: AppLoader()),
              FlashcardError(message: final msg) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          msg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _cubit.loadDashboard(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              FlashcardLoaded(decks: final decks, stats: final stats) => RefreshIndicator(
                onRefresh: () => _cubit.loadDashboard(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thống kê SRS
                      if (stats != null) _buildStatsSection(context, stats),

                      // Banner nhắc nhở ôn tập hôm nay nếu có thẻ cần ôn
                      if (stats != null && stats.dueToday > 0)
                        _buildDueTodayBanner(context, stats.dueToday),

                      const SizedBox(height: 20),

                        // Tiêu đề danh sách bộ thẻ
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your decks (${decks.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  DeckFormDialog.show(context, cubit: _cubit),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('New deck'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                      // Danh sách bộ thẻ
                      if (decks.isEmpty)
                        _buildEmptyDecks(context)
                      else
                        _buildDeckGrid(context, decks),
                    ],
                  ),
                ),
              ),
            };
          },
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, FlashcardUserStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            return GridView.count(
              crossAxisCount: isNarrow ? 2 : 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: isNarrow ? 1.6 : 1.8,
              children: [
                _buildStatCard(
                  context,
                  title: 'Total words',
                  value: '${stats.totalCards}',
                  icon: Icons.style,
                  iconColor: const Color(0xFF6366F1),
                  bgColor: const Color(0xFF6366F1).withValues(alpha: 0.08),
                ),
                _buildStatCard(
                  context,
                  title: 'Due today',
                  value: '${stats.dueToday}',
                  icon: Icons.alarm,
                  iconColor: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFEF4444).withValues(alpha: 0.08),
                ),
                _buildStatCard(
                  context,
                  title: 'Mastered',
                  value: '${stats.masteredCards}',
                  icon: Icons.verified,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFF10B981).withValues(alpha: 0.08),
                ),
                _buildStatCard(
                  context,
                  title: 'Review streak',
                  value: '${stats.streak} ${stats.streak == 1 ? 'day' : 'days'}',
                  icon: Icons.local_fire_department,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _streakMessage(stats),
                  style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _streakMessage(FlashcardUserStats stats) {
    if (stats.reviewedToday) {
      return 'You reviewed today. Your ${stats.streak}-day streak continues!';
    }
    if (stats.streak > 0 && stats.dueToday > 0) {
      return 'Review at least one card today to keep your ${stats.streak}-day streak.';
    }
    if (stats.streak > 0) {
      return 'No cards are due today. Add and review new words to keep your streak.';
    }
    if (stats.dueToday > 0) {
      return 'Review a card today to start a daily streak.';
    }
    return 'Save and review a new word today to start a daily streak.';
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueTodayBanner(BuildContext context, int dueCount) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 24,
            child: Icon(Icons.psychology, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Time to review!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You have $dueCount ${dueCount == 1 ? 'card' : 'cards'} due for review',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () async {
              await context.push('${AppRoutes.flashcards.path}/study');
              if (mounted) await _cubit.loadDashboard();
            },
            child: const Text('Review now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDecks(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_outlined, size: 64, color: colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No decks yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a deck to save words by topic and review them with spaced repetition.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => DeckFormDialog.show(context, cubit: _cubit),
            icon: const Icon(Icons.add),
            label: const Text('Create your first deck'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckGrid(BuildContext context, List<FlashcardDeck> decks) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final crossAxisCount = isWide ? 3 : (constraints.maxWidth > 480 ? 2 : 1);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: isWide ? 1.4 : 1.35,
          ),
          itemCount: decks.length,
          itemBuilder: (context, index) {
            final deck = decks[index];
            return _buildDeckCard(context, deck);
          },
        );
      },
    );
  }

  Widget _buildDeckCard(BuildContext context, FlashcardDeck deck) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final deckColor = deck.deckColor;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('${AppRoutes.flashcards.path}/deck/${deck.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh màu trên cùng
            Container(height: 6, color: deckColor),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: deckColor.withValues(alpha: 0.15),
                    child: Text(
                      deck.name.isNotEmpty ? deck.name[0].toUpperCase() : 'D',
                      style: TextStyle(color: deckColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (deck.description != null && deck.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              deck.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      if (val == 'edit') {
                        DeckFormDialog.show(context, existingDeck: deck, cubit: _cubit);
                      } else if (val == 'delete') {
                        _handleDeleteDeck(deck);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete deck', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Thống kê số lượng từ & cần ôn
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${deck.cardCount} ${deck.cardCount == 1 ? 'word' : 'words'}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (deck.dueCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${deck.dueCount} due',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),

            // Nút Thao tác
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: theme.textTheme.bodyMedium?.color,
                      ),
                      onPressed: () => context.go('${AppRoutes.flashcards.path}/deck/${deck.id}'),
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: const Text('View words', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  Container(width: 1, height: 20, color: theme.dividerColor.withValues(alpha: 0.3)),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: deckColor,
                      ),
                      onPressed: deck.cardCount == 0
                          ? null
                          : () async {
                              await context.push(
                                '${AppRoutes.flashcards.path}/study?deckId=${deck.id}&title=${Uri.encodeComponent(deck.name)}',
                              );
                              if (mounted) await _cubit.loadDashboard();
                            },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text(
                        'Study now',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
