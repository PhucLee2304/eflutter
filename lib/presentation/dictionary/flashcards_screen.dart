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
        title: const Text('Xoá bộ thẻ'),
        content: Text(
          'Bạn có chắc muốn xoá bộ thẻ "${deck.name}" (${deck.cardCount} từ)?\nCác từ vựng trong từ điển sẽ không bị mất.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _cubit.deleteDeck(deck.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Đã xoá bộ thẻ "${deck.name}"' : 'Xoá bộ thẻ thất bại',
            ),
            backgroundColor: success ? null : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bộ thẻ từ vựng (Flashcards)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
              onPressed: () => _cubit.loadDashboard(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => DeckFormDialog.show(context, cubit: _cubit),
          icon: const Icon(Icons.add),
          label: const Text('Tạo bộ thẻ'),
        ),
        body: BlocBuilder<FlashcardCubit, FlashcardState>(
          builder: (context, state) {
            return switch (state) {
              FlashcardInitial() || FlashcardLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
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
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              FlashcardLoaded(decks: final decks, stats: final stats) =>
                RefreshIndicator(
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
                              'Bộ thẻ của bạn (${decks.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  DeckFormDialog.show(context, cubit: _cubit),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Bộ thẻ mới'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                  title: 'Tổng số từ',
                  value: '${stats.totalCards}',
                  icon: Icons.style,
                  iconColor: const Color(0xFF6366F1),
                  bgColor: const Color(0xFF6366F1).withOpacity(0.08),
                ),
                _buildStatCard(
                  context,
                  title: 'Cần ôn hôm nay',
                  value: '${stats.dueToday}',
                  icon: Icons.alarm,
                  iconColor: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFEF4444).withOpacity(0.08),
                ),
                _buildStatCard(
                  context,
                  title: 'Thành thạo',
                  value: '${stats.masteredCards}',
                  icon: Icons.verified,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFF10B981).withOpacity(0.08),
                ),
                _buildStatCard(
                  context,
                  title: 'Chuỗi ôn tập',
                  value: '${stats.streak} ngày',
                  icon: Icons.local_fire_department,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFF59E0B).withOpacity(0.08),
                ),
              ],
            );
          },
        ),
      ],
    );
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
        border: Border.all(color: iconColor.withOpacity(0.2)),
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
    final theme = Theme.of(context);

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
            color: const Color(0xFF4F46E5).withOpacity(0.3),
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
                  'Thời điểm vàng để ôn tập!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bạn có $dueCount thẻ đến hạn ôn tập (Spaced Repetition)',
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
            onPressed: () {
              context.push('${AppRoutes.flashcards.path}/study');
            },
            child: const Text('Ôn ngay', style: TextStyle(fontWeight: FontWeight.bold)),
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
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.style_outlined,
            size: 64,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có bộ thẻ nào',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo bộ thẻ để lưu từ vựng theo chủ đề hoặc ôn tập thông minh bằng thuật toán lặp lại ngắt quãng SM-2.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => DeckFormDialog.show(context, cubit: _cubit),
            icon: const Icon(Icons.add),
            label: const Text('Tạo bộ thẻ đầu tiên'),
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
        side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('${AppRoutes.flashcards.path}/deck/${deck.id}'),
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
                    backgroundColor: deckColor.withOpacity(0.15),
                    child: Text(
                      deck.name.isNotEmpty ? deck.name[0].toUpperCase() : 'D',
                      style: TextStyle(
                        color: deckColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (deck.description != null && deck.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              deck.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
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
                        DeckFormDialog.show(
                          context,
                          existingDeck: deck,
                          cubit: _cubit,
                        );
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
                            Text('Chỉnh sửa'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Xoá bộ thẻ', style: TextStyle(color: Colors.red)),
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
                      color: colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${deck.cardCount} từ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (deck.dueCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${deck.dueCount} cần ôn',
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
                      onPressed: () =>
                          context.push('${AppRoutes.flashcards.path}/deck/${deck.id}'),
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: const Text('Danh sách', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  Container(width: 1, height: 20, color: theme.dividerColor.withOpacity(0.3)),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: deckColor,
                      ),
                      onPressed: deck.cardCount == 0
                          ? null
                          : () {
                              context.push(
                                '${AppRoutes.flashcards.path}/study?deckId=${deck.id}&title=${Uri.encodeComponent(deck.name)}',
                              );
                            },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text(
                        'Học ngay',
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
