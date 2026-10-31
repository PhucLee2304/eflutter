import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/dictionary/flashcard.dart';
import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:eflutter/presentation/dictionary/cubit/flashcard_cubit.dart';
import 'package:eflutter/presentation/dictionary/cubit/word_detail_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class WordDetailScreen extends StatefulWidget {
  final String word;
  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final _detailCubit = getIt<WordDetailCubit>();
  final _flashcardCubit = getIt<FlashcardCubit>();

  VideoPlayerController? _audioController;
  String? _playingAudioUrl;
  bool _isLoadingAudio = false;

  @override
  void initState() {
    super.initState();
    _detailCubit.lookupWord(widget.word);
    _flashcardCubit.loadFlashcards();
  }

  @override
  void dispose() {
    _audioController?.dispose();
    _detailCubit.close();
    _flashcardCubit.close();
    super.dispose();
  }

  String _resolveAudioUrl(String audioUrl) {
    if (audioUrl.startsWith('http://') || audioUrl.startsWith('https://')) {
      return audioUrl;
    }
    final base = AppConfig.baseUrl.isNotEmpty ? AppConfig.baseUrl : 'http://localhost:80';
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final normalizedPath = audioUrl.startsWith('/') ? audioUrl : '/$audioUrl';
    return '$normalizedBase$normalizedPath';
  }

  Future<void> _playAudio(String rawUrl) async {
    if (_playingAudioUrl == rawUrl && _audioController != null) {
      if (_audioController!.value.isPlaying) {
        await _audioController!.pause();
        setState(() {
          _playingAudioUrl = null;
        });
        return;
      }
    }

    final fullUrl = _resolveAudioUrl(rawUrl);

    try {
      if (mounted) {
        setState(() {
          _isLoadingAudio = true;
          _playingAudioUrl = rawUrl;
        });
      }

      if (_audioController != null) {
        await _audioController!.dispose();
        _audioController = null;
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      _audioController = controller;
      await controller.initialize();
      await controller.play();

      controller.addListener(() {
        if (!controller.value.isPlaying &&
            controller.value.position >= controller.value.duration &&
            controller.value.duration > Duration.zero) {
          if (mounted && _playingAudioUrl == rawUrl) {
            setState(() {
              _playingAudioUrl = null;
            });
          }
        }
      });

      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
          _playingAudioUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể phát âm thanh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Flashcard? _findSavedFlashcard(WordDetail detail, FlashcardState state) {
    return state.maybeWhen(
      success: (resp) {
        for (final item in resp.data) {
          if (item.word.id == detail.id ||
              item.word.word.trim().toLowerCase() == detail.word.trim().toLowerCase()) {
            return item;
          }
        }
        return null;
      },
      orElse: () => null,
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _showAddFlashcardDialog(int wordId, String wordText) async {
    final noteController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Lưu "$wordText" vào Flashcard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ghi chú cá nhân (tùy chọn):',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Nghĩa hay gặp, mẹo nhớ...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(noteController.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final success = await _flashcardCubit.addFlashcard(wordId, note: result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Đã lưu "$wordText" vào Flashcard' : 'Không thể lưu flashcard'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showFlashcardDetailDialog(Flashcard card) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bookmark, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text(card.word.word)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card.word.phonetic != null && card.word.phonetic!.isNotEmpty)
              Text(card.word.phonetic!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            const Text('Ghi chú của bạn:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(card.note.isNotEmpty ? card.note : '(Không có ghi chú)',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Text('Đã lưu lúc: ${_formatDate(card.createdAt)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop('close'),
            child: const Text('Đóng'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop('delete'),
            child: const Text('Xóa khỏi Flashcard'),
          ),
        ],
      ),
    );

    if (action == 'delete' && mounted) {
      final success = await _flashcardCubit.deleteFlashcard(card.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Đã xóa khỏi Flashcard' : 'Không thể xóa flashcard'),
            backgroundColor: success ? null : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _detailCubit),
        BlocProvider.value(value: _flashcardCubit),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.word),
          actions: [
            BlocBuilder<WordDetailCubit, WordDetailState>(
              builder: (context, detailState) {
                return detailState.maybeWhen(
                  success: (detail) {
                    return BlocBuilder<FlashcardCubit, FlashcardState>(
                      builder: (context, flashState) {
                        final savedCard = _findSavedFlashcard(detail, flashState);
                        final isSaved = savedCard != null;

                        return IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                            color: isSaved
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          tooltip: isSaved ? 'Đã lưu trong Flashcard' : 'Lưu Flashcard',
                          onPressed: () {
                            if (isSaved) {
                              _showFlashcardDetailDialog(savedCard);
                            } else {
                              _showAddFlashcardDialog(detail.id, detail.word);
                            }
                          },
                        );
                      },
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<WordDetailCubit, WordDetailState>(
          builder: (context, state) {
            return state.when(
              initial: () => const SizedBox(),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (message) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _detailCubit.lookupWord(widget.word),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              success: (detail) {
                // Find primary audio if any
                String? primaryAudioUrl;
                for (final p in detail.phonetics) {
                  if (p.audioUrl != null && p.audioUrl!.isNotEmpty) {
                    primaryAudioUrl = p.audioUrl;
                    break;
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Word + Main Speaker + Phonetic
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  detail.word,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                if (detail.phonetic != null && detail.phonetic!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      detail.phonetic!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.secondary,
                                        fontSize: 18,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (primaryAudioUrl != null)
                            IconButton.filledTonal(
                              tooltip: 'Phát âm thanh',
                              icon: (_isLoadingAudio && _playingAudioUrl == primaryAudioUrl)
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(
                                      (_playingAudioUrl == primaryAudioUrl)
                                          ? Icons.volume_up
                                          : Icons.volume_up_outlined,
                                      color: (_playingAudioUrl == primaryAudioUrl)
                                          ? Theme.of(context).colorScheme.primary
                                          : null,
                                    ),
                              onPressed: () => _playAudio(primaryAudioUrl!),
                            ),
                        ],
                      ),

                      // Phonetics variant chips with individual audio buttons
                      if (detail.phonetics.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: detail.phonetics
                              .where((p) =>
                                  p.text.isNotEmpty || (p.audioUrl != null && p.audioUrl!.isNotEmpty))
                              .map(
                                (p) {
                                  final hasAudio = p.audioUrl != null && p.audioUrl!.isNotEmpty;
                                  final isThisPlaying = _playingAudioUrl == p.audioUrl;
                                  return ActionChip(
                                    avatar: hasAudio
                                        ? (_isLoadingAudio && isThisPlaying)
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 1.5),
                                              )
                                            : Icon(
                                                isThisPlaying
                                                    ? Icons.volume_up
                                                    : Icons.volume_up_outlined,
                                                size: 18,
                                                color: isThisPlaying
                                                    ? Theme.of(context).colorScheme.primary
                                                    : null,
                                              )
                                        : null,
                                    label: Text(p.text.isNotEmpty ? p.text : 'Phát âm'),
                                    backgroundColor: isThisPlaying
                                        ? Theme.of(context).colorScheme.primaryContainer
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    onPressed: hasAudio ? () => _playAudio(p.audioUrl!) : null,
                                  );
                                },
                              )
                              .toList(),
                        ),
                      ],

                      const Divider(height: 32),

                      // Meanings grouped by Part of Speech
                      ...detail.meanings.map((meaning) => Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Part of speech badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    meaning.partOfSpeech.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Definitions
                                ...meaning.definitions.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final def = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          margin: const EdgeInsets.only(top: 2, right: 8),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${i + 1}',
                                            style: const TextStyle(
                                                fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                def.definition,
                                                style: const TextStyle(fontSize: 15, height: 1.35),
                                              ),
                                              if (def.example != null && def.example!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Text(
                                                    'Ví dụ: "${def.example}"',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontStyle: FontStyle.italic,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              if (def.synonyms.isNotEmpty)
                                                _WordChipRow(
                                                  label: 'Đồng nghĩa',
                                                  words: def.synonyms,
                                                  color: Colors.green.shade50,
                                                  textColor: Colors.green.shade800,
                                                  onWordTap: (w) => context.push('/dictionary/$w'),
                                                ),
                                              if (def.antonyms.isNotEmpty)
                                                _WordChipRow(
                                                  label: 'Trái nghĩa',
                                                  words: def.antonyms,
                                                  color: Colors.red.shade50,
                                                  textColor: Colors.red.shade800,
                                                  onWordTap: (w) => context.push('/dictionary/$w'),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                // Meaning-level synonyms
                                if (meaning.synonyms.isNotEmpty)
                                  _WordChipRow(
                                    label: 'Từ đồng nghĩa (${meaning.partOfSpeech})',
                                    words: meaning.synonyms,
                                    color: Colors.green.shade50,
                                    textColor: Colors.green.shade800,
                                    onWordTap: (w) => context.push('/dictionary/$w'),
                                  ),

                                // Meaning-level antonyms
                                if (meaning.antonyms.isNotEmpty)
                                  _WordChipRow(
                                    label: 'Từ trái nghĩa (${meaning.partOfSpeech})',
                                    words: meaning.antonyms,
                                    color: Colors.red.shade50,
                                    textColor: Colors.red.shade800,
                                    onWordTap: (w) => context.push('/dictionary/$w'),
                                  ),
                              ],
                            ),
                          )),

                      // Source URLs & License
                      if (detail.sourceUrls.isNotEmpty || detail.licenseName != null) ...[
                        const Divider(),
                        if (detail.licenseName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text(
                              'Giấy phép: ${detail.licenseName}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        if (detail.sourceUrls.isNotEmpty) ...[
                          const Text('Nguồn tham khảo:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          ...detail.sourceUrls.map((url) => Padding(
                                padding: const EdgeInsets.only(bottom: 2.0),
                                child: InkWell(
                                  onTap: () async {
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  },
                                  child: Text(
                                    url,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WordChipRow extends StatelessWidget {
  final String label;
  final List<String> words;
  final Color color;
  final Color textColor;
  final ValueChanged<String>? onWordTap;

  const _WordChipRow({
    required this.label,
    required this.words,
    required this.color,
    required this.textColor,
    this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: words
                .map((w) => InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onWordTap != null ? () => onWordTap!(w) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: textColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          w,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor,
                            decoration: onWordTap != null ? TextDecoration.underline : null,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
