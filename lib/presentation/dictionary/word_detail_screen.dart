import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/dictionary/word.dart';
import 'package:eflutter/presentation/dictionary/cubit/flashcard_cubit.dart';
import 'package:eflutter/presentation/dictionary/cubit/word_detail_cubit.dart';
import 'package:eflutter/presentation/dictionary/widgets/save_word_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class WordDetailScreen extends StatefulWidget {
  final int wordId;
  const WordDetailScreen({super.key, required this.wordId});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final _detailCubit = getIt<WordDetailCubit>();
  final _flashcardCubit = getIt<FlashcardCubit>();

  VideoPlayerController? _audioController;
  String? _playingAudioUrl;
  bool _isLoadingAudio = false;
  bool _isWordSaved = false;

  @override
  void initState() {
    super.initState();
    _detailCubit.loadWord(widget.wordId);
    _checkWordSaveStatus();
  }

  Future<void> _checkWordSaveStatus() async {
    final status = await _flashcardCubit.getWordSaveStatus(widget.wordId);
    if (mounted && status != null) {
      setState(() {
        _isWordSaved = status.isSaved;
      });
    }
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

  /// Synonym/antonym chỉ có chữ: tìm id trước rồi mới mở trang chi tiết.
  Future<void> _openWord(String word) async {
    final id = await _detailCubit.findWordId(word);
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$word" is not in the dictionary')),
      );
      return;
    }
    context.push('/dictionary/$id');
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
            content: Text('Failed to play audio: $e'),
            backgroundColor: Colors.red,
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
          title: BlocBuilder<WordDetailCubit, WordDetailState>(
            builder: (context, state) => Text(
              state.maybeWhen(success: (detail) => detail.word, orElse: () => ''),
            ),
          ),
          actions: [
            BlocBuilder<WordDetailCubit, WordDetailState>(
              builder: (context, detailState) {
                return detailState.maybeWhen(
                  success: (detail) {
                    return IconButton(
                      icon: Icon(
                        _isWordSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                        color: _isWordSaved
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      tooltip: _isWordSaved ? 'Đã lưu trong bộ thẻ' : 'Lưu vào bộ thẻ',
                      onPressed: () async {
                        final saved = await SaveWordToDecksDialog.show(
                          context,
                          wordId: detail.id,
                          wordText: detail.word,
                          phonetic: detail.phonetic,
                          cubit: _flashcardCubit,
                        );
                        if (saved == true && mounted) {
                          await _checkWordSaveStatus();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã cập nhật bộ thẻ cho "${detail.word}"'),
                              ),
                            );
                          }
                        }
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
                        onPressed: () => _detailCubit.loadWord(widget.wordId),
                        child: const Text('Retry'),
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
                              tooltip: 'Play audio',
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
                                  (p.text?.isNotEmpty ?? false) || (p.audioUrl != null && p.audioUrl!.isNotEmpty))
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
                                    label: Text((p.text?.isNotEmpty ?? false) ? p.text! : 'Pronounce'),
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
                                                    'Example: "${def.example}"',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontStyle: FontStyle.italic,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              if (def.synonyms.isNotEmpty)
                                                _WordChipRow(
                                                  label: 'Synonyms',
                                                  words: def.synonyms,
                                                  color: Colors.green.shade50,
                                                  textColor: Colors.green.shade800,
                                                  onWordTap: _openWord,
                                                ),
                                              if (def.antonyms.isNotEmpty)
                                                _WordChipRow(
                                                  label: 'Antonyms',
                                                  words: def.antonyms,
                                                  color: Colors.red.shade50,
                                                  textColor: Colors.red.shade800,
                                                  onWordTap: _openWord,
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
                                    label: 'Synonyms (${meaning.partOfSpeech})',
                                    words: meaning.synonyms,
                                    color: Colors.green.shade50,
                                    textColor: Colors.green.shade800,
                                    onWordTap: _openWord,
                                  ),

                                // Meaning-level antonyms
                                if (meaning.antonyms.isNotEmpty)
                                  _WordChipRow(
                                    label: 'Antonyms (${meaning.partOfSpeech})',
                                    words: meaning.antonyms,
                                    color: Colors.red.shade50,
                                    textColor: Colors.red.shade800,
                                    onWordTap: _openWord,
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
                              'License: ${detail.licenseName}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        if (detail.sourceUrls.isNotEmpty) ...[
                          const Text('Sources:',
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
