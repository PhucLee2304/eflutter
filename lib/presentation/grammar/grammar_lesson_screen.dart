import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/grammar/grammar_unit.dart';
import 'package:eflutter/presentation/grammar/cubit/grammar_unit_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GrammarLessonScreen extends StatefulWidget {
  final int unitId;

  const GrammarLessonScreen({super.key, required this.unitId});

  @override
  State<GrammarLessonScreen> createState() => _GrammarLessonScreenState();
}

class _GrammarLessonScreenState extends State<GrammarLessonScreen> {
  late final GrammarUnitCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<GrammarUnitCubit>();
    _cubit.loadUnit(widget.unitId);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        body: BlocBuilder<GrammarUnitCubit, GrammarUnitState>(
          builder: (context, state) {
            return state.when(
              initial: () => const SizedBox(),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF7C6CF0)),
              ),
              success: (unit) => _LessonBody(unit: unit, cubit: _cubit),
              error: (message) => _buildError(message),
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFA0A0B8), size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B6B8A), fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C6CF0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () => _cubit.loadUnit(widget.unitId),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Lesson Body ─────────────────────────────────────────────────────────────

class _LessonBody extends StatefulWidget {
  final UnitDetail unit;
  final GrammarUnitCubit cubit;

  const _LessonBody({required this.unit, required this.cubit});

  @override
  State<_LessonBody> createState() => _LessonBodyState();
}

class _LessonBodyState extends State<_LessonBody> {
  bool _inPracticeMode = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _inPracticeMode
          ? _PracticeEngine(
              key: const ValueKey('practice'),
              unit: widget.unit,
              onComplete: () async {
                await widget.cubit.submitProgress(widget.unit.id);
                if (mounted) {
                  setState(() => _inPracticeMode = false);
                }
              },
            )
          : _TheoryView(
              key: const ValueKey('theory'),
              unit: widget.unit,
              onStartPractice: () =>
                  setState(() => _inPracticeMode = true),
            ),
    );
  }
}

// ─── Theory View ─────────────────────────────────────────────────────────────

class _TheoryView extends StatelessWidget {
  final UnitDetail unit;
  final VoidCallback onStartPractice;

  const _TheoryView({
    super.key,
    required this.unit,
    required this.onStartPractice,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 24),
              _buildSectionLabel('📖 Lý thuyết'),
              const SizedBox(height: 12),
              _buildTheoryCard(),
              const SizedBox(height: 28),
              if (unit.examples.isNotEmpty) ...[
                _buildSectionLabel('✨ Ví dụ minh họa'),
                const SizedBox(height: 12),
                ...unit.examples.asMap().entries.map(
                      (e) => _ExampleCard(
                        exampleText: e.value,
                        index: e.key,
                      ),
                    ),
              ],
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        unit.title,
        style: const TextStyle(
          color: Color(0xFF1A1A2E),
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C6CF0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                'Bắt đầu luyện tập (${unit.practices.length} câu)',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              onPressed: unit.practices.isEmpty ? null : onStartPractice,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A2E),
      ),
    );
  }

  Widget _buildTheoryCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8E8F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: _TheoryText(text: unit.theory),
    );
  }
}

/// Renders theory text with **bold** markers highlighted in accent color.
class _TheoryText extends StatelessWidget {
  final String text;

  const _TheoryText({required this.text});

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            color: Color(0xFF2D2D3A),
            fontSize: 15,
            height: 1.7,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          color: Color(0xFF7C6CF0),
          fontWeight: FontWeight.w700,
          fontSize: 15,
          height: 1.7,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          color: Color(0xFF2D2D3A),
          fontSize: 15,
          height: 1.7,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _ExampleCard extends StatelessWidget {
  final String exampleText;
  final int index;

  const _ExampleCard({required this.exampleText, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE8E8F2),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.5,
              color: const Color(0xFF7C6CF0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C6CF0).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'VD ${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF7C6CF0),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    exampleText,
                    style: const TextStyle(
                      color: Color(0xFF2D2D3A),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Practice Engine ──────────────────────────────────────────────────────────

class _PracticeEngine extends StatefulWidget {
  final UnitDetail unit;
  final Future<void> Function() onComplete;

  const _PracticeEngine({
    super.key,
    required this.unit,
    required this.onComplete,
  });

  @override
  State<_PracticeEngine> createState() => _PracticeEngineState();
}

class _PracticeEngineState extends State<_PracticeEngine> {
  int _currentIndex = 0;
  String? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  bool _completed = false;

  PracticeQuestion get _currentQuestion =>
      widget.unit.practices[_currentIndex];

  bool get _isCorrect => _selectedAnswer == _currentQuestion.correct;

  void _selectAnswer(String option) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = option;
      _answered = true;
      if (_isCorrect) _score++;
    });
  }

  Future<void> _nextQuestion() async {
    if (_currentIndex < widget.unit.practices.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      setState(() => _completed = true);
      await widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) return _buildCompletionScreen(context);

    final total = widget.unit.practices.length;
    final progress = total > 0 ? (_currentIndex + 1) / total : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Luyện tập — ${widget.unit.title}',
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFEEEEF5),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF7C6CF0)),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question counter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu ${_currentIndex + 1} / $total',
                    style: const TextStyle(
                      color: Color(0xFF6B6B8A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 18, color: Color(0xFFF77F00)),
                      const SizedBox(width: 4),
                      Text(
                        '$_score/$total',
                        style: const TextStyle(
                          color: Color(0xFFF77F00),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Question card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE8E8F2)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Text(
                  _currentQuestion.question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Options
              ...(_currentQuestion.options.asMap().entries.map(
                (entry) => _OptionButton(
                  optionText: entry.value,
                  index: entry.key,
                  selectedAnswer: _selectedAnswer,
                  correctAnswer: _currentQuestion.correct,
                  answered: _answered,
                  onTap: () => _selectAnswer(entry.value),
                ),
              )),

              const SizedBox(height: 16),

              // Explanation box
              if (_answered) ...[
                _ExplanationBox(
                  explanation: _currentQuestion.explanation,
                  isCorrect: _isCorrect,
                ),
                const SizedBox(height: 20),
              ],

              // Next button
              if (_answered)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C6CF0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _nextQuestion,
                    child: Text(
                      _currentIndex < widget.unit.practices.length - 1
                          ? 'Câu tiếp theo →'
                          : 'Hoàn thành 🎉',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionScreen(BuildContext context) {
    final total = widget.unit.practices.length;
    final percent = total > 0 ? ((_score / total) * 100).round() : 100;
    final emoji = percent == 100
        ? '🏆'
        : percent >= 70
            ? '🌟'
            : '📚';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 24),
              const Text(
                'Bài tập hoàn thành!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Điểm số của bạn',
                style: TextStyle(color: Color(0xFF6B6B8A), fontSize: 16),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C6CF0), Color(0xFF00B4D8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C6CF0).withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  '$_score / $total',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$percent% chính xác',
                style: const TextStyle(
                  color: Color(0xFF6B6B8A),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C6CF0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Quay lại lộ trình',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Option Button ────────────────────────────────────────────────────────────

class _OptionButton extends StatefulWidget {
  final String optionText;
  final int index;
  final String? selectedAnswer;
  final String correctAnswer;
  final bool answered;
  final VoidCallback onTap;

  const _OptionButton({
    required this.optionText,
    required this.index,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.answered,
    required this.onTap,
  });

  @override
  State<_OptionButton> createState() => _OptionButtonState();
}

class _OptionButtonState extends State<_OptionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool get _isSelected => widget.selectedAnswer == widget.optionText;
  bool get _isCorrect => widget.optionText == widget.correctAnswer;
  bool get _shouldHighlightCorrect =>
      widget.answered && _isCorrect && !_isSelected;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_OptionButton old) {
    super.didUpdateWidget(old);
    if (_shouldHighlightCorrect && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!_shouldHighlightCorrect) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _borderColor {
    if (!widget.answered) return const Color(0xFFE0E0EC);
    if (_isSelected && _isCorrect) return const Color(0xFF4CAF50);
    if (_isSelected && !_isCorrect) return const Color(0xFFEF5350);
    if (_shouldHighlightCorrect) return const Color(0xFF4CAF50);
    return const Color(0xFFE0E0EC);
  }

  Color get _backgroundColor {
    if (!widget.answered) return Colors.white;
    if (_isSelected && _isCorrect) return const Color(0xFFE8F5E9);
    if (_isSelected && !_isCorrect) return const Color(0xFFFFEBEE);
    if (_shouldHighlightCorrect) return const Color(0xFFE8F5E9);
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ScaleTransition(
        scale: _shouldHighlightCorrect ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.answered ? null : widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _borderColor, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  _buildOptionLabel(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.optionText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: widget.answered && (_isSelected || _isCorrect)
                            ? (_isCorrect ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C))
                            : const Color(0xFF2D2D3A),
                      ),
                    ),
                  ),
                  if (widget.answered && (_isSelected || _isCorrect))
                    Icon(
                      _isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: _isCorrect
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFEF5350),
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionLabel() {
    const labels = ['A', 'B', 'C', 'D'];
    final label = widget.index < labels.length
        ? labels[widget.index]
        : '${widget.index + 1}';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: !widget.answered
            ? const Color(0xFFF4F5F9)
            : _borderColor.withValues(alpha: 0.15),
        border: Border.all(
          color: !widget.answered ? const Color(0xFFD0D0E0) : _borderColor,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: !widget.answered
                ? const Color(0xFF6B6B8A)
                : (_isCorrect ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C)),
          ),
        ),
      ),
    );
  }
}

// ─── Explanation Box ──────────────────────────────────────────────────────────

class _ExplanationBox extends StatelessWidget {
  final String explanation;
  final bool isCorrect;

  const _ExplanationBox({
    required this.explanation,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 350),
      offset: Offset.zero,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isCorrect
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFF3E0),
          border: Border.all(
            color: isCorrect
                ? const Color(0xFFA5D6A7)
                : const Color(0xFFFFCC80),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isCorrect
                  ? Icons.lightbulb_rounded
                  : Icons.info_outline_rounded,
              color: isCorrect
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFE65100),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCorrect ? 'Chính xác! 🎉' : 'Chưa chính xác! 💡',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isCorrect
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                    ),
                  ),
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      explanation,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D2D3A),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
