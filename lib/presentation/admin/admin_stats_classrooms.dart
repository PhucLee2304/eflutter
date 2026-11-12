import 'dart:math' as math;

import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:eflutter/data/models/admin_stats.dart';
import 'package:eflutter/presentation/admin/admin_stats_widgets.dart';
import 'package:eflutter/presentation/posts/post_media.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Bảng "Classrooms" chỉ xem: dữ liệu nằm sẵn trong response learning, nên tìm, lọc và
/// phân trang (20 dòng) đều làm ở client. Xếp theo điểm TB giảm dần, lớp chưa có điểm ở cuối.
class AdminStatsClassrooms extends StatefulWidget {
  const AdminStatsClassrooms({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.classrooms,
  });
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final List<ClassroomStatsRow> classrooms;

  @override
  State<AdminStatsClassrooms> createState() => _AdminStatsClassroomsState();
}

class _AdminStatsClassroomsState extends State<AdminStatsClassrooms> {
  static const pageSize = 20;
  final search = TextEditingController();
  bool? active;
  int page = 1;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<ClassroomStatsRow> get _filtered {
    final q = search.text.trim().toLowerCase();
    return widget.classrooms
        .where(
          (c) =>
              (active == null || c.active == active) &&
              (q.isEmpty ||
                  c.name.toLowerCase().contains(q) ||
                  c.code.toLowerCase().contains(q) ||
                  (c.teacher?.name.toLowerCase().contains(q) ?? false)),
        )
        .toList()
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        final x = a.averageScore, y = b.averageScore;
        if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
        return y.compareTo(x);
      });
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.classrooms;
    final activeCount = all.where((c) => c.active).length;
    final rows = _filtered;
    final pageCounts = math.max(1, (rows.length / pageSize).ceil());
    final current = page.clamp(1, pageCounts);
    final visible = rows.skip((current - 1) * pageSize).take(pageSize).toList();
    const header = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: statsMuted);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: statsBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      const Text(
                        'Classrooms',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: statsText,
                        ),
                      ),
                      Text(
                        '${all.length} ${all.length == 1 ? 'classroom' : 'classrooms'} · '
                        '$activeCount active · ${all.length - activeCount} archived · all time',
                        style: const TextStyle(fontSize: 13, color: statsMuted),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: search,
                    onChanged: (_) => setState(() => page = 1),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(SolarIconsOutline.magnifier, size: 16, color: statsMuted),
                      hintText: 'Search by name, code or teacher',
                      hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: statsBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: statsBorder),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF1F4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      for (final (value, label) in const [
                        (null, 'All'),
                        (true, 'Active'),
                        (false, 'Archived'),
                      ])
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => setState(() {
                            active = value;
                            page = 1;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: active == value ? Colors.white : null,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: active == value ? FontWeight.w500 : FontWeight.w400,
                                color: active == value ? statsPrimary : const Color(0xFF4A4A4A),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: statsStrip,
              border: Border.symmetric(horizontal: BorderSide(color: statsBorder)),
            ),
            child: const Row(
              spacing: 16,
              children: [
                Expanded(flex: 26, child: Text('CLASSROOM', style: header)),
                Expanded(flex: 17, child: Text('TEACHER', style: header)),
                Expanded(
                  flex: 8,
                  child: Text('STUDENTS', textAlign: TextAlign.right, style: header),
                ),
                Expanded(
                  flex: 9,
                  child: Text('ASSIGNMENTS', textAlign: TextAlign.right, style: header),
                ),
                Expanded(
                  flex: 9,
                  child: Text('SUBMISSIONS', textAlign: TextAlign.right, style: header),
                ),
                Expanded(flex: 20, child: Text('AVG SCORE', style: header)),
                Expanded(flex: 9, child: Text('STATUS', style: header)),
              ],
            ),
          ),
          if (widget.loading)
            const Padding(padding: EdgeInsets.all(48), child: AppLoader())
          else if (widget.error != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                spacing: 12,
                children: [
                  Text(widget.error!, style: const TextStyle(color: statsMuted)),
                  OutlinedButton(onPressed: widget.onRetry, child: const Text('Retry')),
                ],
              ),
            )
          else if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'No classrooms found',
                textAlign: TextAlign.center,
                style: TextStyle(color: statsMuted),
              ),
            )
          else
            for (final (i, c) in visible.indexed) _row(c, first: i == 0),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: statsBorder)),
            ),
            child: Row(
              spacing: 4,
              children: [
                Expanded(
                  child: Text(
                    rows.isEmpty
                        ? 'Showing 0 of 0'
                        : 'Showing ${(current - 1) * pageSize + 1}–'
                              '${(current - 1) * pageSize + visible.length} of ${rows.length}'
                              ' · sorted by average score',
                    style: const TextStyle(fontSize: 13, color: statsMuted),
                  ),
                ),
                _pageButton(
                  Icon(
                    SolarIconsOutline.altArrowLeft,
                    size: 14,
                    color: current > 1 ? statsText : statsBorder,
                  ),
                  current > 1 ? () => setState(() => page = current - 1) : null,
                ),
                for (var p = 1; p <= pageCounts; p++)
                  _pageButton(
                    Text(
                      '$p',
                      style: TextStyle(
                        fontSize: 13,
                        color: p == current ? Colors.white : statsText,
                      ),
                    ),
                    p == current ? null : () => setState(() => page = p),
                    active: p == current,
                  ),
                _pageButton(
                  Icon(
                    SolarIconsOutline.altArrowRight,
                    size: 14,
                    color: current < pageCounts ? statsText : statsBorder,
                  ),
                  current < pageCounts ? () => setState(() => page = current + 1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageButton(Widget child, VoidCallback? onTap, {bool active = false}) => SizedBox(
    width: 32,
    height: 32,
    child: Material(
      color: active ? statsPrimary : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: active ? BorderSide.none : const BorderSide(color: statsBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Center(child: child),
      ),
    ),
  );

  Widget _row(ClassroomStatsRow c, {required bool first}) {
    const number = TextStyle(fontSize: 13, color: statsText);
    final score = c.averageScore;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: statsInnerBorder)),
      ),
      child: Row(
        spacing: 16,
        children: [
          Expanded(
            flex: 26,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: statsText,
                  ),
                ),
                Text(c.code, style: const TextStyle(fontSize: 12, color: statsMuted)),
              ],
            ),
          ),
          Expanded(
            flex: 17,
            child: Row(
              spacing: 8,
              children: [
                PostAvatar(url: c.teacher?.avatar, name: c.teacher?.name, radius: 12),
                Expanded(
                  child: Text(
                    c.teacher?.name ?? 'Unknown teacher',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: number,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(formatCount(c.students), textAlign: TextAlign.right, style: number),
          ),
          Expanded(
            flex: 9,
            child: Text(formatCount(c.assignments), textAlign: TextAlign.right, style: number),
          ),
          Expanded(
            flex: 9,
            child: Text(formatCount(c.submissions), textAlign: TextAlign.right, style: number),
          ),
          Expanded(
            flex: 20,
            child: score == null
                ? const Text(
                    'No graded submissions',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                  )
                : Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (score / 10).clamp(0, 1),
                            minHeight: 8,
                            color: statsSeries1,
                            backgroundColor: const Color(0xFFEEF2F6),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          score.toStringAsFixed(2),
                          style: number.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(
            flex: 9,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.active ? statsGoodBg : const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  c.active ? 'Active' : 'Archived',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.active ? statsGood : const Color(0xFF5F6368),
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
