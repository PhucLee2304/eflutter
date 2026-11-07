/// Số liệu cho màn Admin › Statistics, mỗi service một response (`GET /admin/stats`).
library;

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
double _double(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _doubleOrNull(dynamic v) => (v as num?)?.toDouble();
List<Map<String, dynamic>> _list(dynamic v) =>
    (v as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
Map<String, dynamic> _map(dynamic v) => v as Map<String, dynamic>? ?? const {};

/// Số của kỳ đang xem và kỳ trước cùng độ dài.
class PeriodCount {
  const PeriodCount({this.current = 0, this.previous = 0});
  factory PeriodCount.fromJson(dynamic json) {
    final m = _map(json);
    return PeriodCount(current: _int(m['current']), previous: _int(m['previous']));
  }
  final int current;
  final int previous;
}

class LabeledCount {
  const LabeledCount(this.key, this.count);
  factory LabeledCount.fromJson(Map<String, dynamic> m) =>
      LabeledCount(m['key'] as String? ?? '', _int(m['count']));
  final String key;
  final int count;
}

class StatsUser {
  const StatsUser({required this.name, this.avatar});
  static StatsUser? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final avatar = json['avatar'] as String?;
    return StatsUser(
      name: json['name'] as String? ?? '',
      avatar: avatar == null || avatar.isEmpty ? null : avatar,
    );
  }

  final String name;
  final String? avatar;
}

// ---------------------------------------------------------------- learning

class LearningStats {
  const LearningStats({
    required this.activeClassrooms,
    required this.archivedClassrooms,
    required this.teachers,
    required this.students,
    required this.pendingRequests,
    required this.assignmentsTotal,
    required this.assignmentsOpen,
    required this.submissions,
    required this.onTime,
    required this.late,
    required this.notSubmitted,
    required this.averageScore,
    required this.previousAverageScore,
    required this.scoreDistribution,
    required this.attempts,
    required this.dailyAttempts,
    required this.thpt,
    required this.toeic,
    required this.violations,
    required this.terminated,
    required this.roomSessions,
    required this.roomHours,
    required this.avgParticipants,
    required this.classrooms,
  });

  factory LearningStats.fromJson(Map<String, dynamic> json) {
    final c = _map(json['classrooms']);
    final a = _map(json['assignments']);
    final at = _map(json['attempts']);
    final i = _map(json['integrity']);
    final r = _map(json['rooms']);
    final score = _map(a['averageScore']);
    return LearningStats(
      activeClassrooms: PeriodCount.fromJson(c['active']),
      archivedClassrooms: _int(c['archived']),
      teachers: _int(c['teachers']),
      students: PeriodCount.fromJson(c['students']),
      pendingRequests: _int(c['pendingRequests']),
      assignmentsTotal: _int(a['total']),
      assignmentsOpen: _int(a['open']),
      submissions: PeriodCount.fromJson(a['submissions']),
      onTime: _int(a['onTime']),
      late: _int(a['late']),
      notSubmitted: _int(a['notSubmitted']),
      averageScore: _doubleOrNull(score['current']),
      previousAverageScore: _doubleOrNull(score['previous']),
      scoreDistribution: [
        for (final v in a['scoreDistribution'] as List<dynamic>? ?? const []) _int(v),
      ],
      attempts: PeriodCount.fromJson(at['total']),
      dailyAttempts: {
        for (final d in _list(at['daily']))
          d['date'] as String: [_int(d['assignment']), _int(d['practice']), _int(d['test'])],
      },
      thpt: [for (final e in _list(at['thpt'])) ExamAverage.fromJson(e)],
      toeic: [for (final e in _list(at['toeic'])) ExamAverage.fromJson(e)],
      violations: [for (final e in _list(i['byType'])) LabeledCount.fromJson(e)],
      terminated: _int(i['terminated']),
      roomSessions: _int(r['sessions']),
      roomHours: _double(r['hours']),
      avgParticipants: _double(r['avgParticipants']),
      classrooms: [for (final e in _list(json['list'])) ClassroomStatsRow.fromJson(e)],
    );
  }

  final PeriodCount activeClassrooms;
  final int archivedClassrooms;
  final int teachers;
  final PeriodCount students;
  final int pendingRequests;
  final int assignmentsTotal;
  final int assignmentsOpen;
  final PeriodCount submissions;
  final int onTime;
  final int late;
  final int notSubmitted;
  final double? averageScore;
  final double? previousAverageScore;
  final List<int> scoreDistribution;
  final PeriodCount attempts;

  /// Ngày (YYYY-MM-DD) → [bài tập lớp, luyện tập, thi thử].
  final Map<String, List<int>> dailyAttempts;
  final List<ExamAverage> thpt;
  final List<ExamAverage> toeic;
  final List<LabeledCount> violations;
  final int terminated;
  final int roomSessions;
  final double roomHours;
  final double avgParticipants;
  final List<ClassroomStatsRow> classrooms;
}

class ExamAverage {
  const ExamAverage({required this.title, required this.attempts, required this.averageScore});
  factory ExamAverage.fromJson(Map<String, dynamic> m) => ExamAverage(
    title: m['title'] as String? ?? '',
    attempts: _int(m['attempts']),
    averageScore: _double(m['averageScore']),
  );
  final String title;
  final int attempts;
  final double averageScore;
}

class ClassroomStatsRow {
  const ClassroomStatsRow({
    required this.id,
    required this.name,
    required this.code,
    required this.teacher,
    required this.students,
    required this.assignments,
    required this.submissions,
    required this.averageScore,
    required this.active,
  });
  factory ClassroomStatsRow.fromJson(Map<String, dynamic> m) => ClassroomStatsRow(
    id: _int(m['id']),
    name: m['name'] as String? ?? '',
    code: m['code'] as String? ?? '',
    teacher: StatsUser.fromJson(m['teacher']),
    students: _int(m['students']),
    assignments: _int(m['assignments']),
    submissions: _int(m['submissions']),
    averageScore: _doubleOrNull(m['averageScore']),
    active: m['active'] as bool? ?? false,
  );
  final int id;
  final String name;
  final String code;
  final StatsUser? teacher;
  final int students;
  final int assignments;
  final int submissions;
  final double? averageScore;
  final bool active;
}

// ---------------------------------------------------------------- posts

class PostStats {
  const PostStats({
    required this.totalPosts,
    required this.newPosts,
    required this.hiddenPosts,
    required this.classroomPosts,
    required this.comments,
    required this.likes,
    required this.daily,
    required this.attachments,
    required this.topAuthors,
  });
  factory PostStats.fromJson(Map<String, dynamic> json) => PostStats(
    totalPosts: _int(json['totalPosts']),
    newPosts: PeriodCount.fromJson(json['newPosts']),
    hiddenPosts: _int(json['hiddenPosts']),
    classroomPosts: _int(json['classroomPosts']),
    comments: PeriodCount.fromJson(json['comments']),
    likes: PeriodCount.fromJson(json['likes']),
    daily: {
      for (final d in _list(json['daily']))
        d['date'] as String: [_int(d['posts']), _int(d['comments'])],
    },
    attachments: [
      for (final a in _list(json['attachments']))
        (type: a['type'] as String? ?? '', count: _int(a['count']), bytes: _int(a['bytes'])),
    ],
    topAuthors: [
      for (final a in _list(json['topAuthors']))
        (user: StatsUser.fromJson(a['user']), posts: _int(a['posts']), likes: _int(a['likes'])),
    ],
  );
  final int totalPosts;
  final PeriodCount newPosts;
  final int hiddenPosts;
  final int classroomPosts;
  final PeriodCount comments;
  final PeriodCount likes;

  /// Ngày → [bài mới, bình luận].
  final Map<String, List<int>> daily;
  final List<({String type, int count, int bytes})> attachments;
  final List<({StatsUser? user, int posts, int likes})> topAuthors;
}

// ---------------------------------------------------------------- knowledge

class KnowledgeStats {
  const KnowledgeStats({
    required this.inventory,
    required this.flashcardsTotal,
    required this.flashcardsNew,
    required this.flashcardLearners,
    required this.flashcardsDaily,
    required this.grammarCompletions,
    required this.grammarLearners,
    required this.topUnits,
  });
  factory KnowledgeStats.fromJson(Map<String, dynamic> json) {
    final f = _map(json['flashcards']);
    final g = _map(json['grammar']);
    return KnowledgeStats(
      inventory: {for (final e in _map(json['inventory']).entries) e.key: _int(e.value)},
      flashcardsTotal: _int(f['total']),
      flashcardsNew: PeriodCount.fromJson(f['new']),
      flashcardLearners: _int(f['learners']),
      flashcardsDaily: {for (final d in _list(f['daily'])) d['date'] as String: _int(d['count'])},
      grammarCompletions: PeriodCount.fromJson(g['completions']),
      grammarLearners: _int(g['learners']),
      topUnits: [
        for (final u in _list(g['topUnits']))
          (
            unit: _int(u['unit']),
            title: u['title'] as String? ?? '',
            count: _int(u['completions']),
          ),
      ],
    );
  }

  /// topics, sections, lessons, transcripts, words, themes, grammarUnits.
  final Map<String, int> inventory;
  final int flashcardsTotal;
  final PeriodCount flashcardsNew;
  final int flashcardLearners;
  final Map<String, int> flashcardsDaily;
  final PeriodCount grammarCompletions;
  final int grammarLearners;
  final List<({int unit, String title, int count})> topUnits;
}

// ---------------------------------------------------------------- notifications

class NotificationStats {
  const NotificationStats({
    required this.sent,
    required this.read,
    required this.daily,
    required this.categories,
    required this.devices,
    required this.deviceUsers,
  });
  factory NotificationStats.fromJson(Map<String, dynamic> json) => NotificationStats(
    sent: PeriodCount.fromJson(json['sent']),
    read: PeriodCount.fromJson(json['read']),
    daily: {
      for (final d in _list(json['daily'])) d['date'] as String: [_int(d['sent']), _int(d['read'])],
    },
    categories: [
      for (final c in _list(json['categories']))
        (category: c['category'] as String? ?? '', sent: _int(c['sent']), read: _int(c['read'])),
    ],
    devices: _int(json['devices']),
    deviceUsers: _int(json['deviceUsers']),
  );
  final PeriodCount sent;
  final PeriodCount read;

  /// Ngày → [đã gửi, đã đọc].
  final Map<String, List<int>> daily;
  final List<({String category, int sent, int read})> categories;
  final int devices;
  final int deviceUsers;
}

// ---------------------------------------------------------------- users (identity)

class UserStats {
  const UserStats({
    this.total = 0,
    this.admins = 0,
    this.clients = 0,
    this.blocked = 0,
    this.signups = const PeriodCount(),
    this.blockedInPeriod = 0,
    this.usersBefore = 0,
    this.daily = const {},
    this.heatmap = const {},
  });
  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    total: _int(json['total']),
    admins: _int(json['admins']),
    clients: _int(json['clients']),
    blocked: _int(json['blocked']),
    signups: PeriodCount.fromJson(json['signups']),
    blockedInPeriod: _int(json['blockedInPeriod']),
    usersBefore: _int(json['usersBefore']),
    daily: {for (final d in _list(json['daily'])) d['date'] as String: _int(d['count'])},
    heatmap: {
      for (final c in _list(json['heatmap']))
        (weekday: _int(c['weekday']), hour: _int(c['hour'])): _int(c['count']),
    },
  );

  /// Số hiện tại, không phụ thuộc kỳ.
  final int total;
  final int admins;
  final int clients;
  final int blocked;
  final PeriodCount signups;

  /// Tài khoản đang khoá có thời điểm khoá trong kỳ.
  final int blockedInPeriod;

  /// Tài khoản tạo trước đầu kỳ: mốc của đường tăng trưởng tích luỹ.
  final int usersBefore;

  /// Ngày → số đăng ký.
  final Map<String, int> daily;

  /// (thứ 1 = thứ Hai … 7 = Chủ nhật, giờ 0–23) → số đăng ký trong kỳ.
  final Map<({int weekday, int hour}), int> heatmap;
}
