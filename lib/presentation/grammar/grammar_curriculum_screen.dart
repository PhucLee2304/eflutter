import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/grammar/grammar_unit.dart';
import 'package:eflutter/presentation/grammar/cubit/grammar_curriculum_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class GrammarCurriculumScreen extends StatefulWidget {
  const GrammarCurriculumScreen({super.key});

  @override
  State<GrammarCurriculumScreen> createState() =>
      _GrammarCurriculumScreenState();
}

class _GrammarCurriculumScreenState extends State<GrammarCurriculumScreen> {
  late final GrammarCurriculumCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<GrammarCurriculumCubit>();
    _cubit.load();
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
        body: RefreshIndicator(
          color: const Color(0xFF7C6CF0),
          backgroundColor: Colors.white,
          onRefresh: () => _cubit.load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                sliver: BlocBuilder<GrammarCurriculumCubit,
                    GrammarCurriculumState>(
                  builder: (context, state) {
                    return state.when(
                      initial: () {
                        _cubit.load();
                        return const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 120),
                              child: CircularProgressIndicator(
                                color: Color(0xFF7C6CF0),
                              ),
                            ),
                          ),
                        );
                      },
                      loading: () => const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 120),
                            child: CircularProgressIndicator(
                              color: Color(0xFF7C6CF0),
                            ),
                          ),
                        ),
                      ),
                      success: (response) => _buildUnitList(response.units),
                      error: (message) => SliverToBoxAdapter(
                        child: _buildErrorWidget(message),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4A4A6A)),
          onPressed: () => _cubit.load(),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: const Text(
          'Grammar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.5,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF3F0FF), Color(0xFFF8F9FD)],
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C6CF0).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 20,
              top: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GRAMMAR LEARNING PATHWAY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C6CF0),
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'A 22-unit curriculum, from basic to advanced levels',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B6B8A),
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

  Widget _buildUnitList(List<UnitSummary> units) {
    if (units.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: Text(
              'No lessons yet',
              style: TextStyle(color: Color(0xFF6B6B8A), fontSize: 16),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final unit = units[index];
          return _UnitCard(
            unit: unit,
            index: index,
            onTap: () async {
              await context.push('/grammar/units/${unit.id}');
              if (mounted) {
                _cubit.load();
              }
            },
          );
        },
        childCount: units.length,
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 56, color: Color(0xFFA0A0B8)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B6B8A), fontSize: 15),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C6CF0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _cubit.load,
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final UnitSummary unit;
  final int index;
  final VoidCallback onTap;

  const _UnitCard({
    required this.unit,
    required this.index,
    required this.onTap,
  });

  bool get _isCompleted => unit.completed;

  double get _progressValue => unit.completed ? 1.0 : 0.0;

  Color get _accentColor {
    const colors = [
      Color(0xFF7C6CF0),
      Color(0xFF00B4D8),
      Color(0xFFE91E63),
      Color(0xFFF77F00),
      Color(0xFF2EC4B6),
      Color(0xFF4361EE),
      Color(0xFFE63946),
      Color(0xFF8338EC),
      Color(0xFF06D6A0),
      Color(0xFFFF9F1C),
      Color(0xFF2A9D8F),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              border: Border.all(
                color: _isCompleted
                    ? _accentColor.withValues(alpha: 0.4)
                    : const Color(0xFFE8E8F2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isCompleted
                      ? _accentColor.withValues(alpha: 0.08)
                      : const Color(0x08000000),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildUnitIcon(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unit ${unit.unit > 0 ? unit.unit : index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _accentColor,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              unit.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildProgressBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitIcon() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentColor,
            _accentColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: _isCompleted
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
            : Text(
                '${unit.unit > 0 ? unit.unit : index + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (_isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF81C784)),
        ),
        child: const Text(
          '✓ Complete',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E0EC)),
      ),
      child: Text(
        '${unit.progressCompleted}/${unit.progressTotal}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B6B8A),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress: ${unit.progressCompleted}/${unit.progressTotal}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B8A)),
            ),
            Text(
              '${(_progressValue * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progressValue,
            minHeight: 6,
            backgroundColor: const Color(0xFFEEEEF5),
            valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
          ),
        ),
      ],
    );
  }
}
