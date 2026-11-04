import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_detail.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/exams/attempt/question_palette.dart';
import 'package:eflutter/presentation/exams/cubit/exam_detail_cubit.dart';
import 'package:eflutter/presentation/exams/self_study/self_study_header.dart';
import 'package:eflutter/presentation/exams/self_study/self_study_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const _thptAccent = Color(0xFFC2410C);
const _thptTint = Color(0xFFFFF4EC);
const _rowFill = Color(0xFFF7F9FB);

class ExamDetailScreen extends StatefulWidget {
  const ExamDetailScreen({super.key, required this.examId});

  final int examId;

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  late final ExamDetailCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ExamDetailCubit(ExamRepository(getIt<RemoteDataBase>()))..load(widget.examId);
    SelfStudyStatsStore.instance.ensureLoaded();
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
      child: BlocConsumer<ExamDetailCubit, ExamDetailState>(
        listener: (context, state) {
          if (state.failure != null) {
            context.handleFailure(state.failure);
          }
          if (state.attemptStarted) {
            final attempt = state.startedAttempt;
            if (attempt != null) {
              context.go(attemptPracticePath(attempt.id), extra: attempt);
            }
          }
        },
        builder: (context, state) {
          final exam = state.exam;
          return Scaffold(
            backgroundColor: const Color(0xFFF1F3F7),
            body: SafeArea(
              child: state.isLoading && exam == null
                  ? const AppLoader()
                  : exam == null
                  ? _MissingExam(onBack: () => _back(context, null))
                  : _ExamDetailBody(exam: exam, state: state),
            ),
          );
        },
      ),
    );
  }
}

/// Quay lại danh sách đề; mở thẳng bằng URL thì không có trang trước để pop.
void _back(BuildContext context, String? examType) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(
      examType?.toUpperCase() == 'THPT' ? AppRoutes.examThpt.path : AppRoutes.examToeic.path,
    );
  }
}

bool _isToeic(ExamDetail exam) => exam.type.toUpperCase() == 'TOEIC';

class _ExamDetailBody extends StatelessWidget {
  const _ExamDetailBody({required this.exam, required this.state});

  final ExamDetail exam;
  final ExamDetailState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1048),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _back(context, exam.type),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
                _HeaderCard(exam: exam),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final info = _isToeic(exam)
                        ? _StructureCard(exam: exam)
                        : const _ThptRulesCard();
                    if (constraints.maxWidth < 860) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 20,
                        children: [
                          _AttemptSetupCard(exam: exam, isStarting: state.isStarting),
                          info,
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 20,
                        children: [
                          Expanded(child: info),
                          SizedBox(
                            width: 380,
                            child: _AttemptSetupCard(
                              exam: exam,
                              isStarting: state.isStarting,
                              fillHeight: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColorName.white,
        border: Border.all(color: selfStudyBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.foreground, required this.background});

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

const _cardTitle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: ColorName.labelPrimary,
);

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.exam});

  final ExamDetail exam;

  @override
  Widget build(BuildContext context) {
    final toeic = _isToeic(exam);
    final accent = toeic ? ColorName.primary : _thptAccent;
    final description = exam.description.trim();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(
                label: exam.type.toUpperCase(),
                foreground: accent,
                background: toeic ? selfStudyTint : _thptTint,
              ),
              if (exam.year != null)
                _Tag(
                  label: '${exam.year}',
                  foreground: selfStudyMuted,
                  background: const Color(0xFFF1F3F7),
                ),
            ],
          ),
          Text(
            exam.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: ColorName.labelPrimary,
            ),
          ),
          Text(
            description.isNotEmpty
                ? description
                : toeic
                ? 'Full Listening & Reading test. Take it as a timed test or practise by '
                      'section and part.'
                : 'English paper from the national high school graduation exam, scored out of 10.',
            style: const TextStyle(fontSize: 14, height: 1.4, color: selfStudyMuted),
          ),
          const SizedBox(height: 2),
          ValueListenableBuilder(
            valueListenable: SelfStudyStatsStore.instance.stats,
            builder: (context, stats, _) {
              final typeStats = stats[exam.type.toUpperCase()];
              final best = typeStats?.bestByExam[exam.id];
              final scale = toeic ? '990' : '10';
              final metrics = [
                ('Duration', '${exam.duration} min', null),
                ('Questions', '${exam.totalQuestions}', null),
                if (toeic) ...[
                  ('Sections', '${exam.totalSections}', null),
                  ('Parts', exam.parts.isEmpty ? '–' : '${exam.parts.length}', null),
                ],
                (
                  'Your best',
                  best == null ? '–' : '${formatSelfStudyScore(best)} / $scale',
                  best == null ? null : accent,
                ),
                ('Attempts', '${typeStats?.attemptsByExam[exam.id] ?? 0}', null),
              ];
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 560 ? 3 : metrics.length;
                  final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (label, value, color) in metrics)
                        SizedBox(
                          width: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 2,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: selfStudyMuted,
                                ),
                              ),
                              Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: color ?? ColorName.labelPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

const _toeicPartNames = {
  '1': 'Photographs',
  '2': 'Question–response',
  '3': 'Conversations',
  '4': 'Talks',
  '5': 'Incomplete sentences',
  '6': 'Text completion',
  '7': 'Reading comprehension',
};

String? _partNumber(String? part) {
  if (part == null) return null;
  return RegExp(r'\d+').firstMatch(part)?.group(0);
}

/// Cấu trúc đề TOEIC: từng section và các Part bên trong.
class _StructureCard extends StatelessWidget {
  const _StructureCard({required this.exam});

  final ExamDetail exam;

  @override
  Widget build(BuildContext context) {
    final sections = [...exam.sections]..sort((a, b) => a.order.compareTo(b.order));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const Text('Test structure', style: _cardTitle),
          for (final section in sections) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: section.code.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColorName.primary,
                      ),
                    ),
                    TextSpan(
                      text:
                          '   ${[if (section.duration != null) '${section.duration} min', '${section.questionCount} questions'].join(' · ')}',
                      style: const TextStyle(fontSize: 12, color: selfStudyMuted),
                    ),
                  ],
                ),
              ),
            ),
            for (final part in exam.parts.where((p) => p.sectionCode == section.code))
              _InfoRow(
                title: partLabel(part.part) ?? part.part,
                subtitle: _toeicPartNames[_partNumber(part.part)] ?? '',
                trailing: '${part.questionCount} questions',
              ),
          ],
          if (exam.parts.isEmpty)
            const Text('No part summary available.', style: TextStyle(color: selfStudyMuted)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.subtitle, required this.trailing});

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _rowFill, borderRadius: BorderRadius.circular(10)),
      child: Row(
        spacing: 12,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColorName.labelPrimary,
            ),
          ),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: selfStudyMuted),
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selfStudyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Đề THPT không có nhóm câu trong dữ liệu, nên chỉ nêu thể thức chung.
class _ThptRulesCard extends StatelessWidget {
  const _ThptRulesCard();

  static const _rules = [
    ('One paper, 50 questions', 'All multiple-choice, answered in a single section.'),
    (
      'Scored out of 10',
      'Your score is the share of correct answers, scaled to 10. Wrong answers lose no points.',
    ),
    ('Move freely', 'Jump between questions and change answers any time before you submit.'),
    ('Review after submitting', 'See the correct answers and explanations for every question.'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const Text('How it works', style: _cardTitle),
          for (var i = 0; i < _rules.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: _rowFill, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: _thptTint, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _thptAccent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          _rules[i].$1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ColorName.labelPrimary,
                          ),
                        ),
                        Text(
                          _rules[i].$2,
                          style: const TextStyle(fontSize: 13, color: selfStudyMuted),
                        ),
                      ],
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

enum _AttemptMode {
  practice('PRACTICE', 'Practice'),
  test('TEST', 'Test');

  const _AttemptMode(this.value, this.label);

  final String value;
  final String label;
}

/// Phạm vi luyện TOEIC: cả bài, một section (theo code) hoặc chọn Part.
sealed class _Scope {
  const _Scope();
}

class _FullScope extends _Scope {
  const _FullScope();

  @override
  bool operator ==(Object other) => other is _FullScope;

  @override
  int get hashCode => 0;
}

class _SectionScope extends _Scope {
  const _SectionScope(this.code);

  final String code;

  @override
  bool operator ==(Object other) => other is _SectionScope && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class _PartsScope extends _Scope {
  const _PartsScope();

  @override
  bool operator ==(Object other) => other is _PartsScope;

  @override
  int get hashCode => 1;
}

class _AttemptSetupCard extends StatefulWidget {
  const _AttemptSetupCard({required this.exam, required this.isStarting, this.fillHeight = false});

  final ExamDetail exam;
  final bool isStarting;

  /// Đẩy nút Start xuống đáy khi thẻ được kéo cao bằng cột bên cạnh.
  final bool fillHeight;

  @override
  State<_AttemptSetupCard> createState() => _AttemptSetupCardState();
}

class _AttemptSetupCardState extends State<_AttemptSetupCard> {
  static const _thptPracticeDurations = <int?>[null, 10, 15, 20, 30, 45, 60];
  static const _toeicPracticeDurations = <int?>[null, 10, 15, 20, 30, 45, 60, 75, 90, 120];

  _AttemptMode _mode = _AttemptMode.practice;
  _Scope _scope = const _FullScope();
  final Set<String> _selectedParts = {};
  int? _duration;

  bool get _toeic => _isToeic(widget.exam);
  List<int?> get _practiceDurations => _toeic ? _toeicPracticeDurations : _thptPracticeDurations;
  int get _testDuration => _toeic ? 120 : 60;

  bool get _canStart => !widget.isStarting && (_scope is! _PartsScope || _selectedParts.isNotEmpty);

  @override
  void didUpdateWidget(covariant _AttemptSetupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exam.id != widget.exam.id) {
      _mode = _AttemptMode.practice;
      _scope = const _FullScope();
      _selectedParts.clear();
      _duration = null;
    }
  }

  void _setMode(_AttemptMode mode) {
    setState(() {
      _mode = mode;
      if (mode == _AttemptMode.test) {
        _scope = const _FullScope();
        _selectedParts.clear();
        _duration = null;
      }
    });
  }

  void _setScope(_Scope scope) {
    setState(() {
      _scope = scope;
      if (scope is! _PartsScope) {
        _selectedParts.clear();
      } else if (_selectedParts.isEmpty) {
        final first = _partNumber(widget.exam.parts.firstOrNull?.part);
        if (first != null) _selectedParts.add(first);
      }
    });
  }

  void _startAttempt() {
    final scope = _scope;
    final parts = _toeic && scope is _PartsScope ? (_selectedParts.toList()..sort()) : <String>[];
    context.read<ExamDetailCubit>().createAttempt(
      widget.exam.id,
      CreateExamAttemptRequest(
        mode: _mode.value,
        section: _toeic && scope is _SectionScope ? scope.code : null,
        parts: parts,
        duration: _mode == _AttemptMode.practice ? _duration : null,
      ),
    );
  }

  String get _hint {
    if (_mode == _AttemptMode.test) {
      return 'Test runs the full $_testDuration minutes like the real exam.';
    }
    return _toeic
        ? 'Choose a section or specific parts and set your own time limit.'
        : 'Practice lets you set your own time limit.';
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.isStarting;
    final sections = [...widget.exam.sections]..sort((a, b) => a.order.compareTo(b.order));
    final showScope = _toeic && _mode == _AttemptMode.practice;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          const Text('Start a new attempt', style: _cardTitle),
          _Field(
            label: 'MODE',
            child: _Segmented<_AttemptMode>(
              values: _AttemptMode.values,
              selected: _mode,
              labelOf: (mode) => mode.label,
              onSelected: busy ? null : _setMode,
            ),
          ),
          Text(_hint, style: const TextStyle(fontSize: 12, height: 1.4, color: selfStudyMuted)),
          if (showScope)
            _Field(
              label: 'SCOPE',
              child: _Segmented<_Scope>(
                values: [
                  const _FullScope(),
                  for (final section in sections) _SectionScope(section.code),
                  if (widget.exam.parts.isNotEmpty) const _PartsScope(),
                ],
                selected: _scope,
                labelOf: (scope) => switch (scope) {
                  _FullScope() => 'Full',
                  _SectionScope(:final code) =>
                    sections.firstWhere((s) => s.code == code).title.isNotEmpty
                        ? sections.firstWhere((s) => s.code == code).title
                        : code,
                  _PartsScope() => 'Parts',
                },
                onSelected: busy ? null : _setScope,
              ),
            ),
          if (showScope && _scope is _PartsScope)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final part in widget.exam.parts)
                      if (_partNumber(part.part) case final code?)
                        _PartChip(
                          label: partLabel(part.part) ?? part.part,
                          selected: _selectedParts.contains(code),
                          onTap: busy
                              ? null
                              : () => setState(() {
                                  if (!_selectedParts.remove(code)) _selectedParts.add(code);
                                }),
                        ),
                  ],
                ),
                if (_selectedParts.isEmpty)
                  const Text(
                    'Select at least one part.',
                    style: TextStyle(fontSize: 12, color: ColorName.red),
                  ),
              ],
            ),
          _Field(
            label: 'DURATION',
            child: _mode == _AttemptMode.practice
                ? _DurationDropdown(
                    values: _practiceDurations,
                    value: _duration,
                    onChanged: busy ? null : (value) => setState(() => _duration = value),
                  )
                : _FixedDuration(minutes: _testDuration),
          ),
          if (widget.fillHeight) const Spacer(),
          FilledButton.icon(
            onPressed: _canStart ? _startAttempt : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: AppLoader())
                : const Icon(SolarIconsBold.play, size: 16),
            label: Text(_mode == _AttemptMode.test ? 'Start test' : 'Start practice'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: selfStudyMuted,
          ),
        ),
        child,
      ],
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        spacing: 4,
        children: [
          for (final value in values)
            Expanded(
              child: Material(
                color: value == selected ? ColorName.white : Colors.transparent,
                elevation: value == selected ? 1 : 0,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(7),
                child: InkWell(
                  onTap: onSelected == null || value == selected ? null : () => onSelected!(value),
                  borderRadius: BorderRadius.circular(7),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(
                      labelOf(value),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: value == selected ? ColorName.labelPrimary : selfStudyMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PartChip extends StatelessWidget {
  const _PartChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selfStudyTint : ColorName.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? ColorName.primary : selfStudyBorder)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              if (selected) const Icon(Icons.check_rounded, size: 14, color: ColorName.primary),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? ColorName.primary : selfStudyMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _durationLabel(int? minutes) => minutes == null ? 'Unlimited' : '$minutes min';

class _DurationBox extends StatelessWidget {
  const _DurationBox({required this.label, this.trailing, this.highlighted = false});

  final String label;
  final Widget? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ColorName.white,
        border: Border.all(color: highlighted ? ColorName.primary : selfStudyBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        spacing: 8,
        children: [
          const Icon(SolarIconsOutline.clockCircle, size: 18, color: selfStudyMuted),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ColorName.labelPrimary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _FixedDuration extends StatelessWidget {
  const _FixedDuration({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return _DurationBox(
      label: '$minutes min',
      trailing: const Text('Fixed', style: TextStyle(fontSize: 12, color: selfStudyMuted)),
    );
  }
}

class _DurationDropdown extends StatelessWidget {
  const _DurationDropdown({required this.values, required this.value, required this.onChanged});

  final List<int?> values;
  final int? value;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    // Không dùng LayoutBuilder: thẻ nằm trong IntrinsicHeight, vốn không hỗ trợ nó.
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(ColorName.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.12)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        minimumSize: const WidgetStatePropertyAll(Size(338, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            side: const BorderSide(color: selfStudyBorder),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      menuChildren: [
        for (final minutes in values)
          MenuItemButton(
            onPressed: onChanged == null ? null : () => onChanged!(minutes),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(326, 40)),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              backgroundColor: WidgetStatePropertyAll(minutes == value ? selfStudyTint : null),
            ),
            trailingIcon: minutes == value
                ? const Icon(Icons.check_rounded, size: 18, color: ColorName.primary)
                : null,
            child: Text(
              _durationLabel(minutes),
              style: TextStyle(
                fontSize: 14,
                fontWeight: minutes == value ? FontWeight.w600 : FontWeight.w500,
                color: minutes == value ? ColorName.primary : ColorName.labelPrimary,
              ),
            ),
          ),
      ],
      builder: (context, controller, _) => InkWell(
        onTap: onChanged == null
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
        borderRadius: BorderRadius.circular(10),
        child: _DurationBox(
          label: _durationLabel(value),
          highlighted: controller.isOpen,
          trailing: Icon(
            controller.isOpen ? SolarIconsOutline.altArrowUp : SolarIconsOutline.altArrowDown,
            size: 16,
            color: selfStudyMuted,
          ),
        ),
      ),
    );
  }
}

class _MissingExam extends StatelessWidget {
  const _MissingExam({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Exam not found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ColorName.labelPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
