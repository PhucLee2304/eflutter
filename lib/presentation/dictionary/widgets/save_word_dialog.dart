import 'package:eflutter/data/models/dictionary/flashcard_models.dart';
import 'package:eflutter/presentation/dictionary/cubit/flashcard_cubit.dart';
import 'package:flutter/material.dart';

class SaveWordToDecksDialog extends StatefulWidget {
  final int wordId;
  final String wordText;
  final String? phonetic;
  final FlashcardCubit cubit;

  const SaveWordToDecksDialog({
    super.key,
    required this.wordId,
    required this.wordText,
    this.phonetic,
    required this.cubit,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int wordId,
    required String wordText,
    String? phonetic,
    required FlashcardCubit cubit,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SaveWordToDecksDialog(
        wordId: wordId,
        wordText: wordText,
        phonetic: phonetic,
        cubit: cubit,
      ),
    );
  }

  @override
  State<SaveWordToDecksDialog> createState() => _SaveWordToDecksDialogState();
}

class _SaveWordToDecksDialogState extends State<SaveWordToDecksDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<FlashcardDeck> _decks = [];
  final Set<int> _selectedDeckIds = {};
  final _newDeckController = TextEditingController();
  final _noteController = TextEditingController();
  bool _showNewDeckInput = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _newDeckController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        widget.cubit.getDecksList(),
        widget.cubit.getWordSaveStatus(widget.wordId),
      ]);

      final decks = results[0] as List<FlashcardDeck>;
      final status = results[1] as WordSaveStatus?;

      if (mounted) {
        setState(() {
          _decks = decks;
          if (status != null) {
            _selectedDeckIds.addAll(status.savedInDeckIds);
          }
          // Nếu chưa có bộ thẻ nào, tự động mở ô tạo bộ thẻ mới
          if (decks.isEmpty) {
            _showNewDeckInput = true;
          }
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

  Future<void> _handleSave() async {
    final newDeckName = _newDeckController.text.trim();
    if (_selectedDeckIds.isEmpty && newDeckName.isEmpty && _decks.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bỏ lưu từ?'),
          content: Text(
            'Từ "${widget.wordText}" sẽ được gỡ khỏi tất cả các bộ thẻ. Bạn có chắc chắn không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đồng ý gỡ'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSaving = true);

    final note = _noteController.text.trim();
    final success = await widget.cubit.saveWordToDecks(
      widget.wordId,
      deckIds: _selectedDeckIds.toList(),
      newDeckName: newDeckName.isNotEmpty ? newDeckName : null,
      note: note.isNotEmpty ? note : null,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu thẻ từ vựng. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    radius: 20,
                    child: const Icon(Icons.bookmark_add, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lưu từ vựng',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              widget.wordText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                            if (widget.phonetic != null && widget.phonetic!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                widget.phonetic!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chọn bộ thẻ muốn lưu:',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              if (_decks.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceVariant.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'Bạn chưa có bộ thẻ nào. Hãy tạo bộ thẻ đầu tiên bên dưới!',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ..._decks.map((deck) {
                                  final isChecked = _selectedDeckIds.contains(deck.id);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isChecked
                                            ? colorScheme.primary
                                            : theme.dividerColor.withOpacity(0.3),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      color: isChecked
                                          ? colorScheme.primary.withOpacity(0.06)
                                          : null,
                                    ),
                                    child: CheckboxListTile(
                                      value: isChecked,
                                      dense: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      secondary: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: deck.deckColor,
                                        child: Text(
                                          deck.name.isNotEmpty ? deck.name[0].toUpperCase() : 'D',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        deck.name,
                                        style: TextStyle(
                                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${deck.cardCount} từ ${deck.dueCount > 0 ? '• ${deck.dueCount} cần ôn' : ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: deck.dueCount > 0 ? Colors.orange.shade800 : null,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedDeckIds.add(deck.id);
                                          } else {
                                            _selectedDeckIds.remove(deck.id);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                }),

                              const SizedBox(height: 12),

                              // Nút / ô tạo bộ thẻ mới
                              if (!_showNewDeckInput)
                                TextButton.icon(
                                  onPressed: () => setState(() => _showNewDeckInput = true),
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  label: const Text('Tạo bộ thẻ mới'),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Tạo & thêm vào bộ thẻ mới:',
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                          if (_decks.isNotEmpty)
                                            GestureDetector(
                                              onTap: () => setState(() {
                                                _showNewDeckInput = false;
                                                _newDeckController.clear();
                                              }),
                                              child: const Icon(Icons.close, size: 16),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _newDeckController,
                                        autofocus: _decks.isEmpty,
                                        decoration: InputDecoration(
                                          hintText: 'Nhập tên bộ thẻ (vd: TOEIC 600, Idioms...)',
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          prefixIcon: const Icon(Icons.folder_outlined, size: 20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Personal note
                              Text(
                                'Ghi chú cá nhân (tuỳ chọn):',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _noteController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'Mẹo nhớ từ, ngữ cảnh áp dụng, ví dụ riêng...',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Huỷ'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isSaving ? 'Đang lưu...' : 'Lưu vào thẻ'),
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

