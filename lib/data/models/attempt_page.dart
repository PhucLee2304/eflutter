/// Bảng câu hỏi của attempt (`GET /attempts/{id}/navigator`): không chứa nội dung câu.
class AttemptNavigator {
  final String flow;
  final String? stage;
  final int? currentPage;
  final DateTime? pageStartedAt;
  final DateTime serverTime;
  final DateTime? expiresAt;
  final int totalQuestions;
  final int answeredCount;
  final List<AttemptNavigatorPage> pages;

  const AttemptNavigator({
    required this.flow,
    required this.stage,
    required this.currentPage,
    required this.pageStartedAt,
    required this.serverTime,
    required this.expiresAt,
    required this.totalQuestions,
    required this.answeredCount,
    required this.pages,
  });

  factory AttemptNavigator.fromJson(Map<String, dynamic> json) {
    final pages = json['pages'] as List<dynamic>? ?? const [];
    return AttemptNavigator(
      flow: json['flow'] as String? ?? 'FREE',
      stage: json['stage'] as String?,
      currentPage: (json['currentPage'] as num?)?.toInt(),
      pageStartedAt: DateTime.tryParse(json['pageStartedAt'] as String? ?? ''),
      serverTime:
          DateTime.tryParse(json['serverTime'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      pages: pages
          .map(
            (item) =>
                AttemptNavigatorPage.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  bool get isListening => stage == 'LISTENING';

  /// Trang chứa câu [questionId], -1 nếu không có.
  int pageOfQuestion(int questionId) {
    for (final page in pages) {
      if (page.questions.any((q) => q.id == questionId)) return page.index;
    }
    return -1;
  }
}

class AttemptNavigatorPage {
  final int index;
  final String section;
  final String? part;
  final List<AttemptNavigatorQuestion> questions;

  const AttemptNavigatorPage({
    required this.index,
    required this.section,
    required this.part,
    required this.questions,
  });

  factory AttemptNavigatorPage.fromJson(Map<String, dynamic> json) {
    final questions = json['questions'] as List<dynamic>? ?? const [];
    return AttemptNavigatorPage(
      index: (json['index'] as num?)?.toInt() ?? 0,
      section: json['section'] as String? ?? '',
      part: json['part'] as String?,
      questions: questions
          .map(
            (item) =>
                AttemptNavigatorQuestion.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  bool get isListening => section == 'LISTENING';
}

class AttemptNavigatorQuestion {
  final int id;
  final int number;
  final bool answered;
  final bool locked;

  const AttemptNavigatorQuestion({
    required this.id,
    required this.number,
    required this.answered,
    required this.locked,
  });

  factory AttemptNavigatorQuestion.fromJson(Map<String, dynamic> json) {
    return AttemptNavigatorQuestion(
      id: (json['id'] as num).toInt(),
      number: (json['number'] as num?)?.toInt() ?? 0,
      answered: json['answered'] as bool? ?? false,
      locked: json['locked'] as bool? ?? false,
    );
  }
}

/// Nội dung một trang (`GET /attempts/{id}/pages/{index}`).
class AttemptPage {
  final int index;
  final String section;
  final String? part;
  final AttemptPageGroup? group;
  final List<AttemptPageQuestion> questions;
  final AttemptPageListening? listening;
  final String? nextAudioUrl;

  const AttemptPage({
    required this.index,
    required this.section,
    required this.part,
    required this.group,
    required this.questions,
    required this.listening,
    required this.nextAudioUrl,
  });

  factory AttemptPage.fromJson(Map<String, dynamic> json) {
    final questions = json['questions'] as List<dynamic>? ?? const [];
    return AttemptPage(
      index: (json['index'] as num?)?.toInt() ?? 0,
      section: json['section'] as String? ?? '',
      part: json['part'] as String?,
      group: json['group'] is Map<String, dynamic>
          ? AttemptPageGroup.fromJson(json['group'] as Map<String, dynamic>)
          : null,
      questions: questions
          .map(
            (item) =>
                AttemptPageQuestion.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      listening: json['listening'] is Map<String, dynamic>
          ? AttemptPageListening.fromJson(
              json['listening'] as Map<String, dynamic>,
            )
          : null,
      nextAudioUrl: json['nextAudioUrl'] as String?,
    );
  }

  bool get isListening => section == 'LISTENING';
}

class AttemptPageGroup {
  final String title;
  final String instruction;
  final List<String> imageUrls;
  final String? audioUrl;
  final int? audioDurationMs;

  const AttemptPageGroup({
    required this.title,
    required this.instruction,
    required this.imageUrls,
    required this.audioUrl,
    required this.audioDurationMs,
  });

  factory AttemptPageGroup.fromJson(Map<String, dynamic> json) {
    return AttemptPageGroup(
      title: json['title'] as String? ?? '',
      instruction: json['instruction'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List<dynamic>? ?? const []).cast<String>(),
      audioUrl: json['audioUrl'] as String?,
      audioDurationMs: (json['audioDurationMs'] as num?)?.toInt(),
    );
  }
}

class AttemptPageQuestion {
  final int id;
  final int number;
  final String content;
  final List<AttemptPageOption> options;
  final int? selectedOptionId;

  /// Câu không tính điểm (bài giao): hiện nhãn "Not scored".
  final bool excludedFromScore;

  const AttemptPageQuestion({
    required this.id,
    required this.number,
    required this.content,
    required this.options,
    required this.selectedOptionId,
    this.excludedFromScore = false,
  });

  factory AttemptPageQuestion.fromJson(Map<String, dynamic> json) {
    final options = json['options'] as List<dynamic>? ?? const [];
    return AttemptPageQuestion(
      id: (json['id'] as num).toInt(),
      number: (json['number'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      excludedFromScore: json['excludedFromScore'] as bool? ?? false,
      options: options
          .map(
            (item) => AttemptPageOption.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      selectedOptionId: (json['selectedOptionId'] as num?)?.toInt(),
    );
  }
}

class AttemptPageOption {
  final int id;
  final String key;
  final String? content;

  const AttemptPageOption({
    required this.id,
    required this.key,
    required this.content,
  });

  factory AttemptPageOption.fromJson(Map<String, dynamic> json) {
    return AttemptPageOption(
      id: (json['id'] as num).toInt(),
      key: json['key'] as String? ?? '',
      content: json['content'] as String?,
    );
  }
}

/// Trạng thái phát của trang nghe hiện tại: [elapsedMs] để phát tiếp sau F5,
/// [minAdvanceAt] là mốc sớm nhất server nhận ATTEMPT_LISTENING_ADVANCE.
class AttemptPageListening {
  final int elapsedMs;
  final int gapMs;
  final DateTime? minAdvanceAt;

  const AttemptPageListening({
    required this.elapsedMs,
    required this.gapMs,
    required this.minAdvanceAt,
  });

  factory AttemptPageListening.fromJson(Map<String, dynamic> json) {
    return AttemptPageListening(
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      gapMs: (json['gapMs'] as num?)?.toInt() ?? 0,
      minAdvanceAt: DateTime.tryParse(json['minAdvanceAt'] as String? ?? ''),
    );
  }
}

/// Payload ACK của ATTEMPT_LISTENING_ADVANCE.
class AttemptListeningState {
  final String stage;
  final int? currentPage;
  final DateTime? pageStartedAt;
  final DateTime? serverTime;

  const AttemptListeningState({
    required this.stage,
    required this.currentPage,
    required this.pageStartedAt,
    required this.serverTime,
  });

  factory AttemptListeningState.fromJson(Map<String, dynamic> json) {
    return AttemptListeningState(
      stage: json['stage'] as String? ?? '',
      currentPage: (json['currentPage'] as num?)?.toInt(),
      pageStartedAt: DateTime.tryParse(json['pageStartedAt'] as String? ?? ''),
      serverTime: DateTime.tryParse(json['serverTime'] as String? ?? ''),
    );
  }

  bool get isListening => stage == 'LISTENING';
}
