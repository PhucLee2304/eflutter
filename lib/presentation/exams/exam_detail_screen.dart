import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_detail.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/exams/cubit/exam_detail_cubit.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

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
    _cubit = ExamDetailCubit(ExamRepository(getIt<RemoteDataBase>()))
      ..load(widget.examId);
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
            body: SafeArea(
              child: state.isLoading && exam == null
                  ? const Center(child: CircularProgressIndicator())
                  : exam == null
                  ? _MissingExam(onBack: context.pop)
                  : _ExamDetailBody(exam: exam, state: state),
            ),
          );
        },
      ),
    );
  }
}

class _ExamDetailBody extends StatelessWidget {
  const _ExamDetailBody({required this.exam, required this.state});

  final ExamDetail exam;
  final ExamDetailState state;

  @override
  Widget build(BuildContext context) {
    final profile = _ExamTypeProfile.fromType(exam.type);
    final isToeic = exam.type.toUpperCase() == 'TOEIC';
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _DetailHeader(exam: exam, profile: profile),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              _MetricGrid(exam: exam),
              const SizedBox(height: 16),
              _AttemptSetupCard(exam: exam, isStarting: state.isStarting),
              if (isToeic) ...[
                const SizedBox(height: 16),
                _SectionOverview(sections: exam.sections),
                const SizedBox(height: 16),
                _PartOverview(parts: exam.parts),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.exam, required this.profile});

  final ExamDetail exam;
  final _ExamTypeProfile profile;

  @override
  Widget build(BuildContext context) {
    final description = exam.description.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.outlined(
                tooltip: 'Back',
                onPressed: context.pop,
                icon: const Icon(SolarIconsOutline.arrowLeft),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: profile.tintColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(profile.icon, color: profile.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ColorName.labelPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(label: exam.type, color: profile.color),
                        if (exam.year != null)
                          _Pill(
                            label: exam.year.toString(),
                            color: ColorName.labelSecondary,
                          ),
                        _Pill(
                          label: exam.isPublic ? 'Public' : 'Private',
                          color: exam.isPublic
                              ? ColorName.green
                              : ColorName.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            description.isEmpty ? profile.emptyDescription : description,
            style: const TextStyle(
              height: 1.4,
              color: ColorName.labelSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.exam});

  final ExamDetail exam;

  @override
  Widget build(BuildContext context) {
    final isToeic = exam.type.toUpperCase() == 'TOEIC';
    final cards = [
      _MetricCard(
        icon: SolarIconsOutline.playCircle,
        label: 'Duration',
        value: '${exam.duration} min',
      ),
      _MetricCard(
        icon: SolarIconsOutline.documentText,
        label: 'Questions',
        value: '${exam.totalQuestions}',
      ),
      if (isToeic) ...[
        _MetricCard(
          icon: SolarIconsOutline.layers,
          label: 'Sections',
          value: '${exam.totalSections}',
        ),
        _MetricCard(
          icon: SolarIconsOutline.book,
          label: 'Parts',
          value: exam.parts.isEmpty ? '-' : '${exam.parts.length}',
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxColumns = isToeic ? 4 : 2;
        final columns =
            (constraints.maxWidth >= 860
                    ? maxColumns
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1)
                .clamp(1, cards.length);
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 94,
          ),
          children: cards,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorName.gray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: ColorName.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColorName.labelSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ColorName.labelPrimary,
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

enum _AttemptScopeType {
  full('Full test'),
  section('Section'),
  part('Part');

  const _AttemptScopeType(this.label);

  final String label;
}

class _AttemptSetupCard extends StatefulWidget {
  const _AttemptSetupCard({required this.exam, required this.isStarting});

  final ExamDetail exam;
  final bool isStarting;

  @override
  State<_AttemptSetupCard> createState() => _AttemptSetupCardState();
}

class _AttemptSetupCardState extends State<_AttemptSetupCard> {
  static const _thptPracticeDurations = <int?>[null, 10, 15, 20, 30, 45, 60];
  static const _toeicPracticeDurations = <int?>[
    null,
    10,
    15,
    20,
    30,
    45,
    60,
    75,
    90,
    120,
  ];

  _AttemptMode _mode = _AttemptMode.practice;
  _AttemptScopeType _scopeType = _AttemptScopeType.full;
  String? _selectedSection;
  final Set<String> _selectedParts = {};
  int? _duration;

  bool get _isToeic => widget.exam.type.toUpperCase() == 'TOEIC';
  bool get _isThpt => widget.exam.type.toUpperCase() == 'THPT';
  List<int?> get _practiceDurations =>
      _isToeic ? _toeicPracticeDurations : _thptPracticeDurations;

  bool get _canUsePart => _mode == _AttemptMode.practice && _isToeic;

  bool get _canUseSection => _mode == _AttemptMode.practice && _isToeic;

  bool get _canStart =>
      !widget.isStarting &&
      (_scopeType != _AttemptScopeType.part || _selectedParts.isNotEmpty);

  @override
  void didUpdateWidget(covariant _AttemptSetupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exam.id != widget.exam.id) {
      _mode = _AttemptMode.practice;
      _scopeType = _AttemptScopeType.full;
      _selectedSection = null;
      _selectedParts.clear();
      _duration = null;
    }
  }

  void _setMode(_AttemptMode mode) {
    setState(() {
      _mode = mode;
      if (mode == _AttemptMode.test) {
        _scopeType = _AttemptScopeType.full;
        _selectedSection = null;
        _selectedParts.clear();
        _duration = null;
      }
    });
  }

  void _setScope(_AttemptScopeType scopeType) {
    setState(() {
      _scopeType = scopeType;
      if (scopeType != _AttemptScopeType.section) {
        _selectedSection = null;
      } else {
        _selectedSection ??= widget.exam.sections.firstOrNull?.code;
      }
      if (scopeType != _AttemptScopeType.part) {
        _selectedParts.clear();
      } else if (_selectedParts.isEmpty) {
        final firstPart = _partCode(widget.exam.parts.firstOrNull?.part);
        if (firstPart != null) {
          _selectedParts.add(firstPart);
        }
      }
    });
  }

  void _startAttempt() {
    final section = _isThpt
        ? null
        : _scopeType == _AttemptScopeType.section
        ? _selectedSection
        : null;
    final parts = _isThpt || _scopeType != _AttemptScopeType.part
        ? <String>[]
        : _selectedParts.toList();
    parts.sort();

    context.read<ExamDetailCubit>().createAttempt(
      widget.exam.id,
      CreateExamAttemptRequest(
        mode: _mode.value,
        section: section,
        parts: parts,
        duration: _mode == _AttemptMode.practice ? _duration : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final testDuration = widget.exam.type.toUpperCase() == 'TOEIC' ? 120 : 60;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Start attempt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColorName.labelPrimary,
                  ),
                ),
              ),
              if (_mode == _AttemptMode.test)
                _Pill(label: '$testDuration min', color: ColorName.orange),
            ],
          ),
          _SegmentedBlock<_AttemptMode>(
            title: 'Mode',
            values: _AttemptMode.values,
            selected: _mode,
            labelBuilder: (value) => value.label,
            onSelected: widget.isStarting ? null : _setMode,
          ),
          if (_isToeic)
            _SegmentedBlock<_AttemptScopeType>(
              title: 'Scope',
              values: [
                _AttemptScopeType.full,
                if (_canUseSection) _AttemptScopeType.section,
                if (_canUsePart) _AttemptScopeType.part,
              ],
              selected: _scopeType,
              labelBuilder: (value) => value.label,
              onSelected: widget.isStarting ? null : _setScope,
            ),
          if (_isToeic && _scopeType == _AttemptScopeType.section)
            _ChoiceBlock(
              title: 'Section',
              children: widget.exam.sections
                  .map(
                    (section) => ChoiceChip(
                      label: Text(section.title),
                      selected: _selectedSection == section.code,
                      onSelected: widget.isStarting
                          ? null
                          : (_) => setState(() {
                              _selectedSection = section.code;
                            }),
                    ),
                  )
                  .toList(),
            ),
          if (_isToeic && _scopeType == _AttemptScopeType.part)
            _ChoiceBlock(
              title: 'Part',
              children: widget.exam.parts.map((part) {
                final partCode = _partCode(part.part);
                return ChoiceChip(
                  label: Text(part.part),
                  selected:
                      partCode != null && _selectedParts.contains(partCode),
                  onSelected: widget.isStarting
                      ? null
                      : (selected) => setState(() {
                          if (partCode == null) {
                            return;
                          }
                          if (selected) {
                            _selectedParts.add(partCode);
                          } else {
                            _selectedParts.remove(partCode);
                          }
                        }),
                );
              }).toList(),
            ),
          if (_isToeic &&
              _scopeType == _AttemptScopeType.part &&
              _selectedParts.isEmpty)
            const Text(
              'Select at least one part.',
              style: TextStyle(color: ColorName.red),
            ),
          if (_mode == _AttemptMode.practice)
            _ChoiceBlock(
              title: 'Duration',
              children: _practiceDurations
                  .map(
                    (duration) => ChoiceChip(
                      label: Text(
                        duration == null ? 'Unlimited' : '$duration min',
                      ),
                      selected: _duration == duration,
                      onSelected: widget.isStarting
                          ? null
                          : (_) => setState(() {
                              _duration = duration;
                            }),
                    ),
                  )
                  .toList(),
            ),
          FilledButton.icon(
            onPressed: _canStart ? _startAttempt : null,
            icon: widget.isStarting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(SolarIconsOutline.playCircle),
            label: const Text('Start attempt'),
          ),
        ],
      ),
    );
  }

  String? _partCode(String? partLabel) {
    if (partLabel == null) return null;
    final match = RegExp(r'\d+').firstMatch(partLabel);
    return match?.group(0);
  }
}

class _SegmentedBlock<T> extends StatelessWidget {
  const _SegmentedBlock({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: ColorName.labelPrimary,
          ),
        ),
        SegmentedButton<T>(
          segments: values
              .map(
                (value) => ButtonSegment<T>(
                  value: value,
                  label: Text(labelBuilder(value)),
                ),
              )
              .toList(),
          selected: {selected},
          onSelectionChanged: onSelected == null
              ? null
              : (values) => onSelected!(values.first),
        ),
      ],
    );
  }
}

class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: ColorName.labelPrimary,
          ),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _SectionOverview extends StatelessWidget {
  const _SectionOverview({required this.sections});

  final List<ExamSectionSummary> sections;

  @override
  Widget build(BuildContext context) {
    return _OverviewBlock(
      title: 'Sections',
      children: sections
          .map(
            (section) => _OverviewRow(
              icon: SolarIconsOutline.layers,
              title: section.title,
              subtitle: [
                section.code,
                '${section.questionCount} questions',
                if (section.duration != null) '${section.duration} min',
              ].join(' · '),
            ),
          )
          .toList(),
    );
  }
}

class _PartOverview extends StatelessWidget {
  const _PartOverview({required this.parts});

  final List<ExamPartSummary> parts;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return _OverviewBlock(
        title: 'Parts',
        children: [
          _OverviewRow(
            icon: SolarIconsOutline.documentText,
            title: 'No parts',
            subtitle: 'No part summary available.',
          ),
        ],
      );
    }

    return _OverviewBlock(
      title: 'Parts',
      children: parts
          .map(
            (part) => _OverviewRow(
              icon: SolarIconsOutline.book,
              title: part.part,
              subtitle: '${part.sectionCode} · ${part.questionCount} questions',
            ),
          )
          .toList(),
    );
  }
}

class _OverviewBlock extends StatelessWidget {
  const _OverviewBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ColorName.gray5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorName.labelPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: ColorName.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ColorName.labelPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColorName.labelSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
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
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(SolarIconsOutline.arrowLeft),
            label: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

class _ExamTypeProfile {
  const _ExamTypeProfile({
    required this.icon,
    required this.color,
    required this.emptyDescription,
  });

  final IconData icon;
  final Color color;
  final String emptyDescription;

  Color get tintColor => color.withValues(alpha: 0.12);

  static _ExamTypeProfile fromType(String type) {
    return switch (type.toUpperCase()) {
      'TOEIC' => const _ExamTypeProfile(
        icon: SolarIconsOutline.headphonesRound,
        color: ColorName.blue,
        emptyDescription: 'TOEIC listening and reading practice test.',
      ),
      _ => const _ExamTypeProfile(
        icon: SolarIconsOutline.documentText,
        color: ColorName.primary,
        emptyDescription: 'THPT English practice exam.',
      ),
    };
  }
}
