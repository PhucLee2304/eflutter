import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:eflutter/data/services/ai_service.dart';
import 'package:flutter/material.dart';

/// BottomSheet giải thích từ vựng bằng AI (Phase 2 RAG).
/// Mở ra khi người dùng bấm nút ✨ trên màn hình từ điển / flashcard.
class WordAiExplainSheet extends StatefulWidget {
  final WordDetail word;

  const WordAiExplainSheet({super.key, required this.word});

  /// Mở BottomSheet. Trả về khi người dùng đóng.
  static Future<void> show(BuildContext context, WordDetail word) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WordAiExplainSheet(word: word),
    );
  }

  @override
  State<WordAiExplainSheet> createState() => _WordAiExplainSheetState();
}

class _WordAiExplainSheetState extends State<WordAiExplainSheet> {
  final _aiService = AiService();

  bool _isLoading = true;
  String? _answer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchExplanation();
  }

  Future<void> _fetchExplanation() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _answer = null;
    });
    try {
      final answer = await _aiService.explainWord(widget.word);
      if (mounted) {
        setState(() {
          _answer = answer;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể lấy giải thích từ AI. Vui lòng thử lại.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Giải thích từ',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              widget.word.word,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (widget.word.phonetic != null &&
                                widget.word.phonetic!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                widget.word.phonetic!,
                                style: TextStyle(
                                  color: colorScheme.secondary,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Nội dung chính
            Expanded(
              child: _buildContent(context, scrollController),
            ),

            // Footer padding
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, ScrollController scrollController) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'AI đang soạn giải thích...',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fetchExplanation,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        // AI answer card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: SelectableText(
            _answer ?? '',
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Nút mở chat đầy đủ
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            // Có thể navigate đến AiChatScreen nếu muốn tiếp tục hội thoại
          },
          icon: const Icon(Icons.chat_outlined, size: 18),
          label: const Text('Hỏi thêm trong AI Chat'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
