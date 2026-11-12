import 'dart:math';
import 'package:eflutter/app/config/app_config.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/dictionary/flashcard_models.dart';
import 'package:eflutter/presentation/dictionary/cubit/flashcard_cubit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final int? deckId;
  final String? deckTitle;

  const FlashcardStudyScreen({
    super.key,
    this.deckId,
    this.deckTitle,
  });

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen>
    with SingleTickerProviderStateMixin {
  final _cubit = getIt<FlashcardCubit>();

  bool _isLoading = true;
  String? _errorMessage;
  List<FlashcardItem> _cards = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isSubmitting = false;

  // Session stats
  int _reviewedCount = 0;
  final Map<String, int> _ratingStats = {
    'again': 0,
    'hard': 0,
    'good': 0,
    'easy': 0,
  };
  DateTime _cardStartTime = DateTime.now();

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  VideoPlayerController? _audioController;
  String? _playingAudioUrl;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _loadCards();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _audioController?.dispose();
    _cubit.close();
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
    final fullUrl = _resolveAudioUrl(rawUrl);
    try {
      if (mounted) {
        setState(() {
          _isPlayingAudio = true;
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
              _isPlayingAudio = false;
              _playingAudioUrl = null;
            });
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _playingAudioUrl = null;
        });
      }
    }
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<FlashcardItem>? cards;
      if (widget.deckId != null) {
        cards = await _cubit.getStudyCards(widget.deckId!);
      } else {
        cards = await _cubit.getAllDueCards();
      }

      if (mounted) {
        setState(() {
          _cards = cards ?? [];
          _currentIndex = 0;
          _isFlipped = false;
          _reviewedCount = 0;
          _isLoading = false;
          _cardStartTime = DateTime.now();
        });
        _flipController.reset();
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

  void _flipCard() {
    if (_flipController.isAnimating) return;
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  Future<void> _rateCard(String rating) async {
    if (_isSubmitting || _currentIndex >= _cards.length) return;
    setState(() => _isSubmitting = true);

    final currentCard = _cards[_currentIndex];
    final reviewTimeMs = DateTime.now().difference(_cardStartTime).inMilliseconds;

    await _cubit.reviewCard(currentCard.id, rating, reviewTimeMs: reviewTimeMs);

    _ratingStats[rating] = (_ratingStats[rating] ?? 0) + 1;
    _reviewedCount++;

    if (mounted) {
      if (_isFlipped) {
        _flipController.reverse();
      }

      // Đợi lật về mặt trước rồi chuyển thẻ tiếp theo
      await Future.delayed(const Duration(milliseconds: 200));

      setState(() {
        _currentIndex++;
        _isFlipped = false;
        _isSubmitting = false;
        _cardStartTime = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = widget.deckTitle ?? 'Ôn tập thẻ ghi nhớ';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadCards,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFE0E7FF),
                  child: Icon(Icons.done_all, size: 36, color: Color(0xFF4F46E5)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Không có thẻ nào cần ôn tập!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tất cả các thẻ trong bộ đã được hoàn thành hoặc chưa đến thời hạn ôn tập tiếp theo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Nếu đã hoàn thành hết các thẻ trong phiên
    if (_currentIndex >= _cards.length) {
      return _buildCelebrationScreen(context);
    }

    final currentCard = _cards[_currentIndex];
    final progress = (_currentIndex + 1) / _cards.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1} / ${_cards.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Thẻ Flashcard 3D Flip
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: GestureDetector(
                      onTap: _flipCard,
                      child: AnimatedBuilder(
                        animation: _flipAnimation,
                        builder: (context, child) {
                          final angle = _flipAnimation.value * pi;
                          final isBack = _flipAnimation.value >= 0.5;

                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            alignment: Alignment.center,
                            child: isBack
                                ? Transform(
                                    transform: Matrix4.identity()..rotateY(pi),
                                    alignment: Alignment.center,
                                    child: _buildCardBack(context, currentCard),
                                  )
                                : _buildCardFront(context, currentCard),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Thanh điều khiển đánh giá SM-2 (hiển thị khi thẻ đã lật)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isFlipped)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _flipCard,
                          icon: const Icon(Icons.flip),
                          label: const Text(
                            'Xem đáp án (Lật thẻ)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      )
                    else ...[
                      const Text(
                        'Bạn nhớ từ này ở mức độ nào?',
                        style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRatingButton(
                              label: 'Quên',
                              subLabel: '< 1 ngày',
                              color: const Color(0xFFEF4444),
                              onPressed: () => _rateCard('again'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRatingButton(
                              label: 'Khó',
                              subLabel: 'Ôn sớm',
                              color: const Color(0xFFF59E0B),
                              onPressed: () => _rateCard('hard'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRatingButton(
                              label: 'Nhớ',
                              subLabel: 'Chu kỳ chuẩn',
                              color: const Color(0xFF10B981),
                              onPressed: () => _rateCard('good'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildRatingButton(
                              label: 'Rất dễ',
                              subLabel: 'Khoảng cách dài',
                              color: const Color(0xFF3B82F6),
                              onPressed: () => _rateCard('easy'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront(BuildContext context, FlashcardItem card) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final audio = card.audioUrl;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Container(
        height: 380,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: card.statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                card.statusLabel,
                style: TextStyle(
                  color: card.statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),

            // Word
            Text(
              card.wordText,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            // Phonetic & Audio
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (card.phoneticText.isNotEmpty)
                  Text(
                    card.phoneticText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (audio != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    iconSize: 22,
                    onPressed: () => _playAudio(audio),
                    icon: _isPlayingAudio && _playingAudioUrl == audio
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.volume_up),
                  ),
                ],
              ],
            ),

            const Spacer(),

            // Hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_outlined, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Chạm để xem định nghĩa & ví dụ',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack(BuildContext context, FlashcardItem card) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final meanings = card.word?.meanings ?? [];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.primary.withOpacity(0.4)),
      ),
      child: Container(
        height: 380,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Word header nhỏ ở trên
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.wordText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                if (card.phoneticText.isNotEmpty) ...[
                  Text(
                    card.phoneticText,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                ],
                if (card.audioUrl != null && card.audioUrl!.isNotEmpty)
                  IconButton(
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Nghe phát âm',
                    onPressed: () => _playAudio(card.audioUrl),
                    icon: _isPlayingAudio && _playingAudioUrl == card.audioUrl
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.volume_up, color: colorScheme.primary, size: 20),
                  ),
              ],
            ),
            const Divider(height: 16),

            // Danh sách nghĩa & ví dụ
            Expanded(
              child: meanings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 44,
                            color: colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Chưa có dữ liệu định nghĩa chi tiết',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bạn có thể thêm ghi chú/nghĩa cá nhân để ôn tập từ này',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: meanings.length,
                      itemBuilder: (context, mIdx) {
                        final meaning = meanings[mIdx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  meaning.partOfSpeech,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...meaning.definitions.take(2).map((def) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '• ${def.definition}',
                                        style: const TextStyle(fontSize: 13.5),
                                      ),
                                      if (def.example != null && def.example!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 10, top: 2),
                                          child: Text(
                                            '"${def.example!}"',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                              if (meaning.synonyms.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, left: 4),
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        'Đồng nghĩa: ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      ...meaning.synonyms.take(4).map(
                                        (s) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceVariant.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            s,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Note của người dùng nếu có
            if (card.note != null && card.note!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.edit_note, size: 20, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ghi chú của bạn:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.note!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

  Widget _buildRatingButton({
    required String label,
    required String subLabel,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: _isSubmitting ? null : onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subLabel,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationScreen(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Hoàn thành phiên học')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 46,
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.emoji_events, size: 52, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tuyệt vời!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn đã hoàn thành phiên ôn tập với $_reviewedCount thẻ ghi nhớ.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(height: 24),

                // Thống kê kết quả phiên học
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Quên', '${_ratingStats['again']}', const Color(0xFFEF4444)),
                      _buildSummaryItem('Khó', '${_ratingStats['hard']}', const Color(0xFFF59E0B)),
                      _buildSummaryItem('Nhớ', '${_ratingStats['good']}', const Color(0xFF10B981)),
                      _buildSummaryItem('Dễ', '${_ratingStats['easy']}', const Color(0xFF3B82F6)),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.pop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Về trang Flashcards', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loadCards,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Ôn tập lại'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

