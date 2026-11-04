import 'dart:async';

import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/data/models/exam_summary.dart';
import 'package:eflutter/data/repositories/exam_repository.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/exams/cubit/exam_list_cubit.dart';
import 'package:eflutter/presentation/exams/self_study/self_study_header.dart';
import 'package:eflutter/presentation/exams/self_study/self_study_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Tab TOEIC / THPT của Self-study: header chọn kỳ thi, tìm kiếm, lưới đề và phân trang.
class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key, required this.examType});

  final String examType;

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  late ExamListCubit _cubit;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _cubit = _createCubit();
  }

  ExamListCubit _createCubit() =>
      ExamListCubit(ExamRepository(getIt<RemoteDataBase>()), examType: widget.examType)
        ..load()
        ..loadYears();

  @override
  void didUpdateWidget(covariant ExamListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.examType == widget.examType) return;
    final previous = _cubit;
    _searchController.clear();
    _cubit = _createCubit();
    previous.close();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _cubit.setSearch(value));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _ExamTypeProfile.fromType(widget.examType);
    return BlocConsumer<ExamListCubit, ExamListState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state.failure != null) {
          context.handleFailure(state.failure);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF1F3F7),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_cubit.refresh(), SelfStudyStatsStore.instance.reload()]);
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Centered(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 20,
                        children: [
                          SelfStudyHeader(examType: profile.type),
                          _Toolbar(
                            profile: profile,
                            controller: _searchController,
                            year: state.year,
                            years: state.years,
                            onSearchChanged: _onSearchChanged,
                            onYearChanged: _cubit.setYear,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.isLoading && state.exams.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: AppLoader())
                  else if (state.exams.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyExams(profile: profile, filtered: state.isFiltered),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: _Centered(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: ValueListenableBuilder(
                          valueListenable: SelfStudyStatsStore.instance.stats,
                          builder: (context, stats, _) => _ExamGrid(
                            exams: state.exams,
                            profile: profile,
                            bestByExam: stats[profile.type]?.bestByExam ?? const {},
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _Centered(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                        child: PageNumberBar(
                          page: state.page,
                          pageCounts: state.pageCounts,
                          enabled: !state.isLoading,
                          onSelect: _cubit.goToPage,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1048),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.profile,
    required this.controller,
    required this.year,
    required this.years,
    required this.onSearchChanged,
    required this.onYearChanged,
  });

  final _ExamTypeProfile profile;
  final TextEditingController controller;
  final int? year;
  final List<int> years;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onYearChanged;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: selfStudyBorder),
    );
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search ${profile.type} tests',
              hintStyle: const TextStyle(color: selfStudyMuted, fontSize: 14),
              prefixIcon: const Icon(SolarIconsOutline.magnifier, size: 18, color: selfStudyMuted),
              isDense: true,
              filled: true,
              fillColor: ColorName.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: ColorName.primary),
              ),
            ),
          ),
        ),
        _YearFilter(years: years, value: year, onChanged: onYearChanged),
      ],
    );
  }
}

/// Nút lọc năm: menu thả xuống liệt kê các năm có đề, dấu tick ở năm đang chọn.
class _YearFilter extends StatelessWidget {
  const _YearFilter({required this.years, required this.value, required this.onChanged});

  final List<int> years;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(ColorName.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.12)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        minimumSize: const WidgetStatePropertyAll(Size(168, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            side: const BorderSide(color: selfStudyBorder),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      menuChildren: [
        _yearItem(null, 'All years'),
        if (years.isNotEmpty) const Divider(height: 9, indent: 8, endIndent: 8),
        for (final y in years) _yearItem(y, '$y'),
      ],
      builder: (context, controller, _) => Material(
        color: active ? selfStudyTint : ColorName.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: active || controller.isOpen ? ColorName.primary : selfStudyBorder,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(
                  SolarIconsOutline.calendar,
                  size: 18,
                  color: active ? ColorName.primary : selfStudyMuted,
                ),
                Text(
                  value == null ? 'All years' : '$value',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: active ? ColorName.primary : ColorName.labelPrimary,
                  ),
                ),
                Icon(
                  controller.isOpen ? SolarIconsOutline.altArrowUp : SolarIconsOutline.altArrowDown,
                  size: 16,
                  color: active ? ColorName.primary : selfStudyMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _yearItem(int? year, String label) {
    final selected = year == value;
    return MenuItemButton(
      onPressed: () => onChanged(year),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(156, 40)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        backgroundColor: WidgetStatePropertyAll(selected ? selfStudyTint : null),
      ),
      trailingIcon: selected
          ? const Icon(Icons.check_rounded, size: 18, color: ColorName.primary)
          : null,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? ColorName.primary : ColorName.labelPrimary,
        ),
      ),
    );
  }
}

class _ExamGrid extends StatelessWidget {
  const _ExamGrid({required this.exams, required this.profile, required this.bestByExam});

  final List<ExamSummary> exams;
  final _ExamTypeProfile profile;
  final Map<int, double> bestByExam;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 3
            : width >= 560
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: exams.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 172,
          ),
          itemBuilder: (context, index) {
            final exam = exams[index];
            return _ExamCard(exam: exam, profile: profile, best: bestByExam[exam.id]);
          },
        );
      },
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.profile, required this.best});

  final ExamSummary exam;
  final _ExamTypeProfile profile;
  final double? best;

  @override
  Widget build(BuildContext context) {
    final practiced = best != null;
    void open() => context.push(examDetailPath(exam.type, exam.id));
    return Material(
      color: ColorName.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: selfStudyBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (exam.year != null)
                    _Chip(
                      label: '${exam.year}',
                      color: selfStudyMuted,
                      background: const Color(0xFFF1F3F7),
                    ),
                  const Spacer(),
                  if (practiced)
                    _Chip(
                      label: 'Best ${formatSelfStudyScore(best!)}',
                      color: ColorName.primary,
                      background: selfStudyTint,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                exam.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: ColorName.labelPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${profile.questionCount} · ${profile.duration}',
                style: const TextStyle(fontSize: 13, color: selfStudyMuted),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: open,
                  style: TextButton.styleFrom(
                    backgroundColor: selfStudyTint,
                    foregroundColor: ColorName.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(practiced ? 'Practice again' : 'Start'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _EmptyExams extends StatelessWidget {
  const _EmptyExams({required this.profile, required this.filtered});

  final _ExamTypeProfile profile;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(profile.icon, size: 44, color: ColorName.labelSecondary),
          const SizedBox(height: 12),
          Text(
            filtered
                ? 'No ${profile.type} tests match your filters'
                : 'No ${profile.type} tests yet',
            style: const TextStyle(fontWeight: FontWeight.w700, color: ColorName.labelPrimary),
          ),
        ],
      ),
    );
  }
}

class _ExamTypeProfile {
  const _ExamTypeProfile({
    required this.type,
    required this.duration,
    required this.questionCount,
    required this.icon,
  });

  final String type;
  final String duration;
  final String questionCount;
  final IconData icon;

  static _ExamTypeProfile fromType(String type) {
    return switch (type.toUpperCase()) {
      'TOEIC' => const _ExamTypeProfile(
        type: 'TOEIC',
        duration: '120 min',
        questionCount: '200 questions',
        icon: SolarIconsOutline.headphonesRound,
      ),
      _ => const _ExamTypeProfile(
        type: 'THPT',
        duration: '60 min',
        questionCount: '50 questions',
        icon: SolarIconsOutline.squareAcademicCap,
      ),
    };
  }
}
