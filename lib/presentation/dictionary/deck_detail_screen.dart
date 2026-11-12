import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/dictionary/flashcard_models.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/dictionary/cubit/flashcard_cubit.dart';
import 'package:eflutter/presentation/dictionary/widgets/deck_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DeckDetailScreen extends StatefulWidget {
  final int deckId;

  const DeckDetailScreen({super.key, required this.deckId});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  final _cubit = getIt<FlashcardCubit>();

  bool _isLoading = true;
  String? _errorMessage;
  FlashcardDeck? _deck;
  List<FlashcardItem> _cards = [];
  int _currentPage = 1;
  int _totalCards = 0;
  bool _isLoadingMore = false;
  bool _hasMore = false;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDeckAndCards();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreCards();
    }
  }

  Future<void> _loadDeckAndCards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final decks = await _cubit.getDecksList();
      final deck = decks.where((d) => d.id == widget.deckId).firstOrNull;

      final cardsResp = await _cubit.getDeckCards(widget.deckId, page: 1, pageSize: 25);

      if (mounted) {
        setState(() {
          _deck = deck;
          _cards = cardsResp?.data ?? [];
          _currentPage = 1;
          _totalCards = cardsResp?.total ?? _cards.length;
          _hasMore = (_currentPage < (cardsResp?.pageCounts ?? 1));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreCards() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final cardsResp = await _cubit.getDeckCards(widget.deckId, page: nextPage, pageSize: 25);

    if (mounted) {
      setState(() {
        if (cardsResp != null && cardsResp.data.isNotEmpty) {
          _cards.addAll(cardsResp.data);
          _currentPage = nextPage;
          _hasMore = (_currentPage < cardsResp.pageCounts);
        } else {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _showEditNoteDialog(FlashcardItem card) async {
    final controller = TextEditingController(text: card.note ?? '');
    final updatedNote = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ghi chú cho "${card.wordText}"'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập ghi chú, mẹo ghi nhớ...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Lưu ghi chú'),
          ),
        ],
      ),
    );

    if (updatedNote != null && mounted) {
      final success = await _cubit.updateCardNote(card.id, updatedNote);
      if (success && mounted) {
        setState(() {
          final idx = _cards.indexWhere((c) => c.id == card.id);
          if (idx != -1) {
            _cards[idx] = FlashcardItem(
              id: card.id,
              deckId: card.deckId,
              wordId: card.wordId,
              note: updatedNote.isNotEmpty ? updatedNote : null,
              status: card.status,
              intervalDays: card.intervalDays,
              easeFactor: card.easeFactor,
              repetitions: card.repetitions,
              nextReviewAt: card.nextReviewAt,
              lastReviewedAt: card.lastReviewedAt,
              createdAt: card.createdAt,
              word: card.word,
              rawWordText: card.rawWordText,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ghi chú')),
        );
      }
    }
  }

  Future<void> _confirmDeleteCard(FlashcardItem card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá từ khỏi bộ thẻ'),
        content: Text(
          'Bạn có chắc muốn xoá từ "${card.wordText}" khỏi bộ thẻ này?',
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
      final success = await _cubit.deleteDeckCard(card.id);
      if (success && mounted) {
        setState(() {
          _cards.removeWhere((c) => c.id == card.id);
          _totalCards = (_totalCards > 0) ? _totalCards - 1 : 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xoá từ "${card.wordText}" khỏi bộ thẻ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final deck = _deck;
    final deckColor = deck?.deckColor ?? colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(deck?.name ?? 'Chi tiết bộ thẻ'),
        actions: [
          if (deck != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Sửa bộ thẻ',
              onPressed: () async {
                final updated = await DeckFormDialog.show(
                  context,
                  existingDeck: deck,
                  cubit: _cubit,
                );
                if (updated == true) {
                  _loadDeckAndCards();
                }
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadDeckAndCards,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadDeckAndCards,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Header card
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: deckColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: deckColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: deckColor,
                                  child: Text(
                                    deck?.name.isNotEmpty == true
                                        ? deck!.name[0].toUpperCase()
                                        : 'D',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        deck?.name ?? '',
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (deck?.description != null &&
                                          deck!.description!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            deck.description!,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: theme.textTheme.bodySmall?.color,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildBadge(
                                  context,
                                  icon: Icons.style_outlined,
                                  label: '$_totalCards từ vựng',
                                  color: deckColor,
                                ),
                                const SizedBox(width: 10),
                                if (deck != null && deck.dueCount > 0)
                                  _buildBadge(
                                    context,
                                    icon: Icons.alarm,
                                    label: '${deck.dueCount} cần ôn hôm nay',
                                    color: Colors.red,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: deckColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _cards.isEmpty
                                    ? null
                                    : () {
                                        context.push(
                                          '${AppRoutes.flashcards.path}/study?deckId=${widget.deckId}&title=${Uri.encodeComponent(deck?.name ?? '')}',
                                        );
                                      },
                                icon: const Icon(Icons.psychology, size: 22),
                                label: Text(
                                  deck != null && deck.dueCount > 0
                                      ? 'Bắt đầu ôn tập (${deck.dueCount} từ)'
                                      : 'Học bộ thẻ này',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Section title
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Danh sách từ trong bộ thẻ ($_totalCards)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Cards list
                    if (_cards.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_outlined,
                                  size: 56,
                                  color: colorScheme.outline.withOpacity(0.5),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Chưa có từ nào trong bộ thẻ này',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tra cứu từ điển và nhấn biểu tượng bookmark để thêm từ vào đây.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () => context.go(AppRoutes.dictionary.path),
                                  icon: const Icon(Icons.search),
                                  label: const Text('Tra cứu từ điển'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final card = _cards[index];
                              return _buildCardItem(context, card);
                            },
                            childCount: _cards.length,
                          ),
                        ),
                      ),

                    if (_isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(BuildContext context, FlashcardItem card) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // Mở chi tiết từ trong từ điển
          context.push('/dictionary/${card.wordId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              card.wordText,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: card.statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                card.statusLabel,
                                style: TextStyle(
                                  color: card.statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (card.phoneticText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              card.phoneticText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Actions menu
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_note, size: 20),
                        tooltip: 'Ghi chú',
                        onPressed: () => _showEditNoteDialog(card),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        tooltip: 'Xoá từ',
                        onPressed: () => _confirmDeleteCard(card),
                      ),
                    ],
                  ),
                ],
              ),

              // Ghi chú cá nhân
              if (card.note != null && card.note!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          card.note!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // SRS metrics
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Lặp lại: ${card.repetitions} lần',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Khoảng cách: ${card.intervalDays} ngày',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Spacer(),
                  if (card.nextReviewAt.isNotEmpty)
                    Text(
                      'Ôn tiếp: ${_formatDate(card.nextReviewAt)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

