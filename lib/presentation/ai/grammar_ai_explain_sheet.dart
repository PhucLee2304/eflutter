import 'package:eflutter/data/models/grammar/grammar_unit.dart';
import 'package:eflutter/data/services/ai_service.dart';
import 'package:flutter/material.dart';

/// Explains a wrong answer using the current grammar practice as context.
class GrammarAiExplainSheet extends StatefulWidget {
  final UnitDetail unit;
  final PracticeQuestion question;
  final int selectedOptionIndex;

  const GrammarAiExplainSheet({
    super.key,
    required this.unit,
    required this.question,
    required this.selectedOptionIndex,
  });

  static Future<void> show(
    BuildContext context, {
    required UnitDetail unit,
    required PracticeQuestion question,
    required int selectedOptionIndex,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GrammarAiExplainSheet(
        unit: unit,
        question: question,
        selectedOptionIndex: selectedOptionIndex,
      ),
    );
  }

  @override
  State<GrammarAiExplainSheet> createState() => _GrammarAiExplainSheetState();
}

class _GrammarAiExplainSheetState extends State<GrammarAiExplainSheet> {
  final _aiService = AiService();
  bool _isLoading = true;
  String? _answer;
  String? _error;

  String get _selectedLetter =>
      String.fromCharCode(65 + widget.selectedOptionIndex);

  @override
  void initState() {
    super.initState();
    _fetchExplanation();
  }

  Future<void> _fetchExplanation() async {
    setState(() {
      _isLoading = true;
      _answer = null;
      _error = null;
    });
    try {
      final answer = await _aiService.explainGrammar(
        unit: widget.unit,
        question: widget.question,
        selectedOptionIndex: widget.selectedOptionIndex,
      );
      if (answer.trim().isEmpty) {
        throw StateError('Empty AI explanation');
      }
      if (mounted) {
        setState(() {
          _answer = answer;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load the explanation. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Why was my answer $_selectedLetter wrong?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                Text(
                  widget.question.question,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your answer: $_selectedLetter. '
                  '${widget.question.options[widget.selectedOptionIndex]}',
                  style: TextStyle(color: colors.error),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: colors.primary),
                          const SizedBox(height: 16),
                          const Text('AI is explaining your answer...'),
                        ],
                      ),
                    ),
                  )
                else if (_error != null)
                  Column(
                    children: [
                      Icon(Icons.error_outline, color: colors.error, size: 40),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _fetchExplanation,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: SelectableText(
                      _answer!,
                      style: const TextStyle(fontSize: 15, height: 1.6),
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
