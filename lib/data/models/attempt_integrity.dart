/// Một dòng log giám sát giáo viên xem (PLAN_ATTEMPT_INTEGRITY.md mục 1.3, 1.9).
class IntegrityEventRecord {
  const IntegrityEventRecord({
    required this.eventId,
    required this.attemptId,
    required this.studentId,
    required this.type,
    required this.level,
    required this.receivedAt,
    this.violationNo,
    this.serverDurationMs,
    this.replayed = false,
    this.stale = false,
    this.detail,
    this.review,
  });

  final String eventId;
  final int attemptId;
  final String studentId;
  final String type;

  /// LOG | WARNING | VIOLATION.
  final String level;
  final DateTime receivedAt;
  final int? violationNo;
  final int? serverDurationMs;
  final bool replayed;
  final bool stale;
  final String? detail;

  /// CONTINUE_ALLOWED | BANNED; null là chưa xử lý.
  final String? review;

  bool get isViolation => level == IntegrityLevel.violation;
  bool get isPending => isViolation && review == null;

  factory IntegrityEventRecord.fromJson(Map<String, dynamic> json) =>
      IntegrityEventRecord(
        eventId: json['eventId'] as String? ?? '',
        attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
        studentId: json['studentId'] as String? ?? '',
        type: json['type'] as String? ?? '',
        level: json['level'] as String? ?? IntegrityLevel.log,
        receivedAt:
            DateTime.tryParse(
              json['receivedAt'] as String? ?? json['at'] as String? ?? '',
            )?.toLocal() ??
            DateTime.now(),
        violationNo: (json['violationNo'] as num?)?.toInt(),
        serverDurationMs: (json['serverDurationMs'] as num?)?.toInt(),
        replayed: json['replayed'] as bool? ?? false,
        stale: json['stale'] as bool? ?? false,
        detail: json['detail'] as String?,
        review: json['review'] as String?,
      );
}

abstract final class IntegrityLevel {
  static const log = 'LOG';
  static const warning = 'WARNING';
  static const violation = 'VIOLATION';
}

abstract final class IntegrityReviewAction {
  static const allowContinue = 'CONTINUE';
  static const ban = 'BAN';
}

class IntegrityEventPage {
  const IntegrityEventPage({required this.items, required this.pageCounts});
  final List<IntegrityEventRecord> items;
  final int pageCounts;

  factory IntegrityEventPage.fromJson(Map<String, dynamic> json) =>
      IntegrityEventPage(
        items: (json['data'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  IntegrityEventRecord.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        pageCounts: (json['pageCounts'] as num?)?.toInt() ?? 1,
      );
}

/// Push ATTEMPT_INTEGRITY_UPDATED trên /ws/classrooms.
class IntegrityUpdate {
  const IntegrityUpdate({
    required this.studentId,
    required this.attemptId,
    required this.violationCount,
    required this.maxViolations,
    required this.status,
    required this.outcome,
    required this.away,
    this.event,
  });

  final String studentId;
  final int attemptId;
  final int violationCount;
  final int maxViolations;
  final String status;
  final String outcome;

  /// Học sinh đang rời màn thi.
  final bool away;
  final IntegrityEventRecord? event;

  factory IntegrityUpdate.fromJson(Map<String, dynamic> json) {
    final event = json['event'];
    return IntegrityUpdate(
      studentId: json['studentId'] as String? ?? '',
      attemptId: (json['attemptId'] as num?)?.toInt() ?? 0,
      violationCount: (json['violationCount'] as num?)?.toInt() ?? 0,
      maxViolations: (json['maxViolations'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      outcome: json['outcome'] as String? ?? 'NONE',
      away: json['away'] as bool? ?? false,
      event: event is Map<String, dynamic>
          ? IntegrityEventRecord.fromJson({
              ...event,
              'studentId': json['studentId'],
              'attemptId': json['attemptId'],
            })
          : null,
    );
  }
}
