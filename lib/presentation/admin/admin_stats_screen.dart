import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/admin_stats.dart';
import 'package:eflutter/data/repositories/admin_stats_repository.dart';
import 'package:eflutter/presentation/admin/admin_stats_classrooms.dart';
import 'package:eflutter/presentation/admin/admin_stats_widgets.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/posts/post_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

/// Kết quả tải của một service: mỗi khối trên màn tự có loading/lỗi riêng.
class _Slot<T> {
  T? data;
  String? error;
  bool loading = true;
}

const _violationLabels = {
  'AWAY_START': 'Left the exam tab',
  'COPY': 'Copy',
  'PASTE': 'Paste',
  'RELOAD': 'Reload',
  'NAVIGATION_BLOCKED': 'Blocked navigation',
  'BACK_BLOCKED': 'Blocked back button',
  'SESSION_CONFLICT': 'Session conflict',
  'SESSION_TAKEOVER': 'Session takeover',
};
const _categoryLabels = {
  'ASSIGNMENTS': 'Assignments',
  'CLASSROOMS': 'Classrooms',
  'POSTS': 'Posts',
  'ROOMS': 'Live rooms',
  'EXAMS': 'Exams',
  'OTHER': 'Other',
};
const _attachmentLabels = {'IMAGE': 'Image', 'VIDEO': 'Video', 'FILE': 'Document'};

String _bytes(int bytes) => bytes >= 1 << 30
    ? '${(bytes / (1 << 30)).toStringAsFixed(1)} GB'
    : '${(bytes / (1 << 20)).toStringAsFixed(bytes >= 10 << 20 ? 0 : 1)} MB';

/// `/admin/stats`: số liệu learning, posts, knowledge, notifications (Figma P6·1).
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  late final repository = AdminStatsRepository(getIt<Dio>());
  final learning = _Slot<LearningStats>();
  final posts = _Slot<PostStats>();
  final knowledge = _Slot<KnowledgeStats>();
  final notifications = _Slot<NotificationStats>();

  /// Số ngày của kỳ; null là toàn thời gian.
  int? rangeDays = 30;
  DateTime updatedAt = DateTime.now();
  bool toeic = false;

  static final _day = DateFormat('yyyy-MM-dd');

  DateTime get _today => DateUtils.dateOnly(DateTime.now());
  String? get _from =>
      rangeDays == null ? null : _day.format(_today.subtract(Duration(days: rangeDays! - 1)));
  String? get _to => rangeDays == null ? null : _day.format(_today);
  String get _periodLabel => rangeDays == null ? 'all time' : 'last $rangeDays days';

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  void loadAll() {
    updatedAt = DateTime.now();
    _load(learning, repository.getLearning(from: _from, to: _to));
    _load(posts, repository.getPosts(from: _from, to: _to));
    _load(knowledge, repository.getKnowledge(from: _from, to: _to));
    _load(notifications, repository.getNotifications(from: _from, to: _to));
  }

  Future<void> _load<T>(_Slot<T> slot, Future<Result<T>> request) async {
    setState(() {
      slot.loading = true;
      slot.error = null;
    });
    final result = await request;
    if (!mounted) return;
    setState(() {
      slot.loading = false;
      switch (result) {
        case Success(data: final data):
          slot.data = data;
        case Failure(message: final message):
          slot.error = message ?? 'The service did not respond.';
        case Cancelled():
          break;
      }
    });
  }

  /// Trục ngày liền mạch: theo kỳ đã chọn, hoặc từ ngày có dữ liệu sớm nhất khi xem toàn thời gian.
  List<String> _days(Iterable<String> keys) {
    var start = rangeDays == null ? null : _today.subtract(Duration(days: rangeDays! - 1));
    if (start == null) {
      final sorted = keys.toList()..sort();
      start = sorted.isEmpty
          ? _today.subtract(const Duration(days: 29))
          : DateTime.parse(sorted.first);
    }
    return [
      for (var d = start; !d.isAfter(_today); d = DateUtils.addDaysToDate(d, 1)) _day.format(d),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select<AppCubit, String?>((cubit) => cubit.state.user?.role);
    if (role != null && role.toUpperCase() != 'ADMIN') {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F9FB),
        body: Center(
          child: Text('You do not have access to this page.', style: TextStyle(color: statsMuted)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1368),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 1100;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 24,
                    children: [
                      _titleCard(),
                      _kpis(wide),
                      _learning(wide),
                      _pair(wide, [(1, _community(wide)), (1, _content())]),
                      _notifications(wide),
                      AdminStatsClassrooms(
                        loading: learning.loading,
                        error: learning.error,
                        onRetry: () =>
                            _load(learning, repository.getLearning(from: _from, to: _to)),
                        classrooms: learning.data?.classrooms ?? const [],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hai (hoặc ba) cột trên màn rộng, xếp dọc trên màn hẹp.
  Widget _pair(bool wide, List<(int, Widget)> children) => wide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [for (final (flex, child) in children) Expanded(flex: flex, child: child)],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [for (final (_, child) in children) child],
        );

  Widget _titleCard() {
    final anyLoading =
        learning.loading || posts.loading || knowledge.loading || notifications.loading;
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 22, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: statsBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(SolarIconsOutline.chart, color: statsPrimary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                const Text('Statistics', style: TextStyle(fontSize: 22, color: statsText)),
                Text(
                  'Learning, community, content and notifications · '
                  'updated ${DateFormat('HH:mm').format(updatedAt)}',
                  style: const TextStyle(fontSize: 15, color: statsMuted),
                ),
              ],
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
                  (7, '7 days'),
                  (30, '30 days'),
                  (90, '90 days'),
                  (null, 'All time'),
                ])
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      if (rangeDays == value) return;
                      setState(() => rangeDays = value);
                      loadAll();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: rangeDays == value ? Colors.white : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: rangeDays == value ? FontWeight.w500 : FontWeight.w400,
                          color: rangeDays == value ? statsPrimary : const Color(0xFF4A4A4A),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: anyLoading ? null : loadAll,
            style: IconButton.styleFrom(
              side: const BorderSide(color: statsBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(SolarIconsOutline.refresh, size: 18, color: statsText),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ KPI

  /// Mức thay đổi so với kỳ trước; null khi xem toàn thời gian hoặc kỳ trước không có dữ liệu.
  Widget? _delta(num current, num previous, {String Function(num diff)? format}) {
    if (rangeDays == null || previous == 0) return null;
    final diff = current - previous;
    final text = format != null
        ? format(diff)
        : '${diff >= 0 ? '+' : '−'}${(diff.abs() / previous * 100).round()}%';
    return DeltaPill(text: text, up: diff >= 0);
  }

  Widget _kpis(bool wide) {
    final l = learning.data;
    final p = posts.data;
    final n = notifications.data;
    String countDiff(num d) => '${d >= 0 ? '+' : '−'}${formatCount(d.abs())}';
    double rate(int read, int sent) => sent == 0 ? 0 : read / sent * 100;

    final attemptDays = l == null ? const <String>[] : _days(l.dailyAttempts.keys);
    final postDays = p == null ? const <String>[] : _days(p.daily.keys);
    final notificationDays = n == null ? const <String>[] : _days(n.daily.keys);
    final tiles = [
      (
        'Active classrooms',
        l == null ? null : formatCount(l.activeClassrooms.current),
        null,
        l == null
            ? null
            : _delta(l.activeClassrooms.current, l.activeClassrooms.previous, format: countDiff),
        const <double>[],
      ),
      (
        'Students',
        l == null ? null : formatCount(l.students.current),
        null,
        l == null ? null : _delta(l.students.current, l.students.previous),
        const <double>[],
      ),
      (
        'Attempts',
        l == null ? null : formatCount(l.attempts.current),
        null,
        l == null ? null : _delta(l.attempts.current, l.attempts.previous),
        [
          for (final d in attemptDays)
            (l!.dailyAttempts[d] ?? const [0]).fold<int>(0, (a, b) => a + b).toDouble(),
        ],
      ),
      (
        'Avg assignment score',
        l?.averageScore?.toStringAsFixed(2) ?? (l == null ? null : '—'),
        '/10',
        l?.averageScore == null || l?.previousAverageScore == null
            ? null
            : _delta(
                l!.averageScore!,
                l.previousAverageScore!,
                format: (d) => '${d >= 0 ? '+' : '−'}${d.abs().toStringAsFixed(2)}',
              ),
        const <double>[],
      ),
      (
        'Community posts',
        p == null ? null : formatCount(p.newPosts.current),
        null,
        p == null ? null : _delta(p.newPosts.current, p.newPosts.previous),
        [for (final d in postDays) (p!.daily[d]?.first ?? 0).toDouble()],
      ),
      (
        'Notification read rate',
        n == null ? null : '${rate(n.read.current, n.sent.current).round()}%',
        null,
        n == null || n.sent.previous == 0
            ? null
            : _delta(
                rate(n.read.current, n.sent.current),
                rate(n.read.previous, n.sent.previous),
                format: (d) => '${d >= 0 ? '+' : '−'}${d.abs().round()} pts',
              ),
        [
          for (final d in notificationDays)
            if ((n!.daily[d]?.first ?? 0) > 0) rate(n.daily[d]![1], n.daily[d]![0]),
        ],
      ),
    ];
    final cards = [
      for (final (label, value, suffix, delta, spark) in tiles)
        _kpiCard(label, value, suffix, delta, spark),
    ];
    return wide
        ? Row(spacing: 16, children: [for (final c in cards) Expanded(child: c)])
        : Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [for (final c in cards) SizedBox(width: 220, child: c)],
          );
  }

  Widget _kpiCard(String label, String? value, String? suffix, Widget? delta, List<double> spark) =>
      Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: statsBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: statsMuted),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: value ?? '—',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: statsText,
                      ),
                      children: [
                        if (suffix != null && value != null && value != '—')
                          TextSpan(
                            text: suffix,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: statsMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Sparkline(values: spark),
              ],
            ),
            SizedBox(
              height: 20,
              child: Row(
                spacing: 6,
                children: [
                  ?delta,
                  Flexible(
                    child: Text(
                      delta == null ? _periodLabel : 'vs previous $rangeDays days',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: statsMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ------------------------------------------------------------------ Learning

  Widget _learning(bool wide) => StatsBlock(
    title: 'Learning',
    subtitle: 'Classrooms, assignments, exams and live rooms',
    loading: learning.loading,
    error: learning.error,
    onRetry: () => _load(learning, repository.getLearning(from: _from, to: _to)),
    minHeight: 600,
    builder: (context) {
      final l = learning.data!;
      final days = _days(l.dailyAttempts.keys);
      final exams = toeic ? l.toeic : l.thpt;
      final totalSubmissions = l.onTime + l.late;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          SummaryStrip(
            items: [
              (
                'Classrooms',
                formatCount(l.activeClassrooms.current),
                'active · ${l.archivedClassrooms} archived',
              ),
              ('Teachers', formatCount(l.teachers), 'own ≥1 classroom'),
              ('Pending join requests', formatCount(l.pendingRequests), 'waiting for approval'),
              ('Assignments', formatCount(l.assignmentsTotal), '${l.assignmentsOpen} open now'),
              ('Submissions', formatCount(l.submissions.current), _periodLabel),
              (
                'Live sessions',
                formatCount(l.roomSessions),
                '${l.roomHours.toStringAsFixed(1)} h · avg ${l.avgParticipants.toStringAsFixed(1)} people',
              ),
            ],
          ),
          _pair(wide, [
            (
              2,
              ChartPanel(
                title: 'Attempts per day',
                subtitle:
                    '${formatCount(l.attempts.current)} submitted attempts · assignments, practice and mock tests',
                legend: const [
                  ('Assignment', statsSeries1),
                  ('Practice', statsSeries2),
                  ('Mock test', statsSeries3),
                ],
                child: l.attempts.current == 0
                    ? const EmptyChart(height: 240, message: 'No attempts in this period')
                    : StackedDailyColumns(
                        days: days,
                        values: [
                          for (final d in days) l.dailyAttempts[d] ?? const [0, 0, 0],
                        ],
                        series: const [
                          ('Assignment', statsSeries1),
                          ('Practice', statsSeries2),
                          ('Mock test', statsSeries3),
                        ],
                      ),
              ),
            ),
            (
              1,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  ChartPanel(
                    title: 'Assignment submissions',
                    subtitle:
                        '${formatCount(totalSubmissions)} submitted · '
                        '${l.averageScore?.toStringAsFixed(2) ?? '—'} average score',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 12,
                            child: totalSubmissions == 0
                                ? const ColoredBox(color: statsTrack)
                                : Row(
                                    spacing: 2,
                                    children: [
                                      if (l.onTime > 0)
                                        Expanded(
                                          flex: l.onTime,
                                          child: const ColoredBox(color: statsSeries1),
                                        ),
                                      if (l.late > 0)
                                        Expanded(
                                          flex: l.late,
                                          child: const ColoredBox(color: statsSeries2),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                        Row(
                          children: [
                            for (final (name, value, color) in [
                              ('On time', l.onTime, statsSeries1),
                              ('Late', l.late, statsSeries2),
                            ])
                              Expanded(
                                child: Row(
                                  spacing: 6,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    Text(
                                      name,
                                      style: const TextStyle(fontSize: 12, color: statsLabel),
                                    ),
                                    Text(
                                      '$value · ${totalSubmissions == 0 ? 0 : (value / totalSubmissions * 100).round()}%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: statsText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        Text(
                          'Not submitted yet: ${formatCount(l.notSubmitted)} (open assignments)',
                          style: const TextStyle(fontSize: 12, color: statsMuted),
                        ),
                      ],
                    ),
                  ),
                  ChartPanel(
                    title: 'Integrity violations',
                    trailing: l.terminated == 0
                        ? null
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statsBadBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${l.terminated} ${l.terminated == 1 ? 'attempt' : 'attempts'} terminated',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: statsBad,
                              ),
                            ),
                          ),
                    child: l.violations.isEmpty
                        ? const EmptyChart(height: 60, message: 'No violations in this period')
                        : HorizontalBars(
                            labelWidth: 130,
                            items: [
                              for (final v in l.violations.take(6))
                                (_violationLabels[v.key] ?? v.key, v.count.toDouble(), null),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ]),
          _pair(wide, [
            (
              1,
              ChartPanel(
                title: 'Score distribution',
                subtitle:
                    'Assignment scores on a 0–10 scale · ${formatCount(l.submissions.current)} graded'
                    '${l.averageScore == null ? '' : ' · avg ${l.averageScore!.toStringAsFixed(2)}'}',
                child: l.submissions.current == 0
                    ? const EmptyChart(height: 240, message: 'No graded submissions in this period')
                    : ScoreHistogram(buckets: l.scoreDistribution),
              ),
            ),
            (
              1,
              ChartPanel(
                title: 'Average score by exam',
                subtitle: 'Standalone practice & mock-test attempts · top 10 by attempts',
                trailing: _examToggle(),
                child: SizedBox(
                  height: 240,
                  child: exams.isEmpty
                      ? EmptyChart(
                          height: 240,
                          message: 'No ${toeic ? 'TOEIC' : 'THPT'} attempts in this period',
                        )
                      : SingleChildScrollView(
                          child: HorizontalBars(
                            labelWidth: 200,
                            track: true,
                            decimals: toeic ? 0 : 1,
                            max: toeic ? 990 : 10,
                            rowGap: 14,
                            items: [
                              for (final e in exams)
                                (e.title, e.averageScore, '${e.attempts} att.'),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ]),
        ],
      );
    },
  );

  Widget _examToggle() => Container(
    margin: const EdgeInsets.only(left: 12),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: statsTrack, borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (value, label) in const [(false, 'THPT · /10'), (true, 'TOEIC · /990')])
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => toeic = value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: toeic == value ? Colors.white : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: toeic == value ? FontWeight.w500 : FontWeight.w400,
                  color: toeic == value ? statsPrimary : statsMuted,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  // ------------------------------------------------------------------ Community / content

  Widget _community(bool wide) => StatsBlock(
    title: 'Community',
    subtitle: 'Community posts, comments and reactions',
    loading: posts.loading,
    error: posts.error,
    onRetry: () => _load(posts, repository.getPosts(from: _from, to: _to)),
    minHeight: 460,
    builder: (context) {
      final p = posts.data!;
      final days = _days(p.daily.keys);
      final attachmentCount = p.attachments.fold<int>(0, (a, b) => a + b.count);
      final attachmentBytes = p.attachments.fold<int>(0, (a, b) => a + b.bytes);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          SummaryStrip(
            items: [
              ('New posts', formatCount(p.newPosts.current), null),
              ('Comments', formatCount(p.comments.current), null),
              ('Likes', formatCount(p.likes.current), null),
              ('Attachments', formatCount(attachmentCount), _bytes(attachmentBytes)),
            ],
          ),
          ChartPanel(
            title: 'Activity per day',
            subtitle:
                '${formatCount(p.totalPosts)} visible posts · ${p.hiddenPosts} hidden · '
                '${p.classroomPosts} classroom posts in this period',
            legend: const [('Posts', statsSeries1), ('Comments', statsSeries2)],
            child: p.newPosts.current == 0 && p.comments.current == 0
                ? const EmptyChart(height: 200, message: 'No posts or comments in this period')
                : DailyLines(
                    days: days,
                    series: [
                      ('Posts', statsSeries1, [for (final d in days) p.daily[d]?[0] ?? 0]),
                      ('Comments', statsSeries2, [for (final d in days) p.daily[d]?[1] ?? 0]),
                    ],
                  ),
          ),
          _pair(wide, [
            (
              1,
              ChartPanel(
                title: 'Attachments by type',
                child: p.attachments.isEmpty
                    ? const EmptyChart(height: 100, message: 'No attachments in this period')
                    : HorizontalBars(
                        labelWidth: 76,
                        rowGap: 14,
                        items: [
                          for (final a in p.attachments)
                            (
                              _attachmentLabels[a.type] ?? a.type,
                              a.count.toDouble(),
                              _bytes(a.bytes),
                            ),
                        ],
                      ),
              ),
            ),
            (
              1,
              ChartPanel(
                title: 'Top authors',
                trailing: const Text(
                  'posts · likes',
                  style: TextStyle(fontSize: 11, color: statsMuted),
                ),
                child: p.topAuthors.isEmpty
                    ? const EmptyChart(height: 100, message: 'No posts in this period')
                    : Column(
                        spacing: 8,
                        children: [
                          for (final a in p.topAuthors)
                            Row(
                              spacing: 8,
                              children: [
                                PostAvatar(url: a.user?.avatar, name: a.user?.name, radius: 10),
                                Expanded(
                                  child: Text(
                                    a.user?.name ?? 'Unknown user',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: statsText),
                                  ),
                                ),
                                Text(
                                  '${a.posts} · ${a.likes}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: statsText,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
              ),
            ),
          ]),
        ],
      );
    },
  );

  Widget _content() => StatsBlock(
    title: 'Content library',
    subtitle: 'Seeded content and how learners use it',
    loading: knowledge.loading,
    error: knowledge.error,
    onRetry: () => _load(knowledge, repository.getKnowledge(from: _from, to: _to)),
    minHeight: 460,
    builder: (context) {
      final k = knowledge.data!;
      final inv = k.inventory;
      final days = _days(k.flashcardsDaily.keys);
      final transcripts = inv['transcripts'] ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          SummaryStrip(
            items: [
              ('Dictionary words', formatCount(inv['words'] ?? 0), null),
              (
                'Topics · lessons',
                '${inv['topics'] ?? 0} · ${formatCount(inv['lessons'] ?? 0)}',
                null,
              ),
              (
                'Transcripts',
                transcripts >= 10000
                    ? '${(transcripts / 1000).toStringAsFixed(1)}k'
                    : formatCount(transcripts),
                null,
              ),
              ('Grammar units', formatCount(inv['grammarUnits'] ?? 0), null),
            ],
          ),
          ChartPanel(
            title: 'Flashcards created per day',
            subtitle:
                '${formatCount(k.flashcardsTotal)} total · ${formatCount(k.flashcardsNew.current)} '
                'in this period · ${k.flashcardLearners} learners',
            child: k.flashcardsNew.current == 0
                ? const EmptyChart(height: 200, message: 'No flashcards created in this period')
                : DailyLines(
                    days: days,
                    series: [
                      (
                        'Flashcards',
                        statsSeries1,
                        [for (final d in days) k.flashcardsDaily[d] ?? 0],
                      ),
                    ],
                  ),
          ),
          ChartPanel(
            title: 'Most completed grammar units',
            trailing: Text(
              '${formatCount(k.grammarCompletions.current)} completions · '
              '${k.grammarLearners} learners',
              style: const TextStyle(fontSize: 11, color: statsMuted),
            ),
            child: k.topUnits.isEmpty
                ? const EmptyChart(height: 100, message: 'No units completed in this period')
                : HorizontalBars(
                    labelWidth: 220,
                    items: [
                      for (final u in k.topUnits)
                        ('Unit ${u.unit} · ${u.title}', u.count.toDouble(), null),
                    ],
                  ),
          ),
        ],
      );
    },
  );

  // ------------------------------------------------------------------ Notifications

  Widget _notifications(bool wide) => StatsBlock(
    title: 'Notifications',
    subtitle: 'In-app notifications and web push',
    loading: notifications.loading,
    error: notifications.error,
    onRetry: () => _load(notifications, repository.getNotifications(from: _from, to: _to)),
    minHeight: 280,
    builder: (context) {
      final n = notifications.data!;
      final days = _days(n.daily.keys);
      final readRate = n.sent.current == 0 ? 0.0 : n.read.current / n.sent.current;
      final maxCategory = n.categories.fold<int>(0, (a, b) => math.max(a, b.sent));
      return _pair(wide, [
        (
          3,
          ChartPanel(
            title: 'Sent per day',
            subtitle: '${formatCount(n.sent.current)} sent · ${formatCount(n.read.current)} read',
            legend: const [('Read', statsSeries1), ('Unread', statsSeries1Light)],
            child: n.sent.current == 0
                ? const EmptyChart(height: 220, message: 'No notifications in this period')
                : StackedDailyColumns(
                    height: 220,
                    days: days,
                    values: [
                      for (final d in days)
                        [n.daily[d]?[1] ?? 0, (n.daily[d]?[0] ?? 0) - (n.daily[d]?[1] ?? 0)],
                    ],
                    series: const [('Read', statsSeries1), ('Unread', statsSeries1Light)],
                  ),
          ),
        ),
        (
          2,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: statsInnerBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6,
                          children: [
                            const Text(
                              'Read rate',
                              style: TextStyle(fontSize: 12, color: statsMuted),
                            ),
                            Text(
                              '${(readRate * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: statsText,
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: readRate,
                                minHeight: 8,
                                color: statsSeries1,
                                backgroundColor: const Color(0xFFEEF2F6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 41, thickness: 1, color: statsBorder),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          const Text(
                            'Push devices',
                            style: TextStyle(fontSize: 12, color: statsMuted),
                          ),
                          Text.rich(
                            TextSpan(
                              text: formatCount(n.devices),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: statsText,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '  ${n.deviceUsers} '
                                      '${n.deviceUsers == 1 ? 'learner' : 'learners'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: statsMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ChartPanel(
                title: 'By category',
                trailing: const Text(
                  'sent · read rate',
                  style: TextStyle(fontSize: 11, color: statsMuted),
                ),
                child: n.categories.isEmpty
                    ? const EmptyChart(height: 100, message: 'No notifications in this period')
                    : HorizontalBars(
                        labelWidth: 96,
                        max: maxCategory.toDouble(),
                        items: [
                          for (final c in n.categories)
                            (
                              _categoryLabels[c.category] ?? c.category,
                              c.sent.toDouble(),
                              '${c.sent == 0 ? 0 : (c.read / c.sent * 100).round()}%',
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ]);
    },
  );
}
