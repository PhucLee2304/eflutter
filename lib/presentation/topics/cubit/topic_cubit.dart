import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/data/models/topic_lesson.dart';
import 'package:eflutter/data/models/topic_section.dart';
import 'package:eflutter/data/models/topic_summary.dart';
import 'package:eflutter/data/repositories/topic_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Dữ liệu Topics lưu theo id để mỗi route (/topic, /topic/:topicId,
/// .../sections/:sectionId, .../lessons/:lessonId) tự đọc phần của mình, kể cả
/// khi mở thẳng URL hay bấm Back của trình duyệt.
class TopicState {
  /// null: chưa tải xong.
  final List<TopicSummary>? topics;

  /// Section theo topicId; chưa có key là đang tải.
  final Map<int, List<TopicSection>> sections;

  /// Lesson theo sectionId; chưa có key là đang tải.
  final Map<int, List<TopicLesson>> lessons;
  final Failure? failure;

  const TopicState({
    this.topics,
    this.sections = const {},
    this.lessons = const {},
    this.failure,
  });

  TopicSummary? topic(int id) =>
      topics?.where((topic) => topic.id == id).firstOrNull;

  TopicSection? section(int topicId, int sectionId) => sections[topicId]
      ?.where((section) => section.id == sectionId)
      .firstOrNull;

  TopicState copyWith({
    List<TopicSummary>? topics,
    Map<int, List<TopicSection>>? sections,
    Map<int, List<TopicLesson>>? lessons,
    Failure? failure,
  }) {
    return TopicState(
      topics: topics ?? this.topics,
      sections: sections ?? this.sections,
      lessons: lessons ?? this.lessons,
      failure: failure,
    );
  }
}

@injectable
class TopicCubit extends Cubit<TopicState> {
  final TopicRepository _topicRepository;

  TopicCubit(this._topicRepository) : super(const TopicState());

  // Các trang trong stack route (vd. /topic/1 nằm dưới /topic/1/sections/2) cùng
  // gọi tải một lúc: chỉ gửi một request cho mỗi id.
  bool _pendingTopics = false;
  final _pendingSections = <int>{};
  final _pendingLessons = <int>{};

  /// [refresh]: tải lại cả khi đã có (màn danh sách topic), để dữ liệu vừa seed
  /// lại hiện ra mà không phải reload trang.
  Future<void> loadTopics({bool refresh = false}) async {
    if ((state.topics != null && !refresh) || _pendingTopics) return;
    _pendingTopics = true;
    final result = await _topicRepository.getTopics().withLoading();
    _pendingTopics = false;
    switch (result) {
      case Success(data: final topics):
        emit(state.copyWith(topics: topics));
      case Failure():
        emit(state.copyWith(topics: state.topics ?? const [], failure: result));
        emit(state.copyWith());
      case Cancelled():
        break;
    }
  }

  Future<void> loadSections(int topicId) async {
    if (state.sections.containsKey(topicId) || !_pendingSections.add(topicId)) {
      return;
    }
    final result = await _topicRepository
        .getSectionsByTopic(topicId)
        .withLoading();
    _pendingSections.remove(topicId);
    switch (result) {
      case Success(data: final sections):
        emit(state.copyWith(sections: {...state.sections, topicId: sections}));
      case Failure():
        // Lỗi (vd. topic không còn tồn tại): để danh sách rỗng thay vì quay mãi.
        emit(
          state.copyWith(
            sections: {...state.sections, topicId: const <TopicSection>[]},
            failure: result,
          ),
        );
        emit(state.copyWith());
      case Cancelled():
        break;
    }
  }

  Future<void> loadLessons(int sectionId) async {
    if (state.lessons.containsKey(sectionId) ||
        !_pendingLessons.add(sectionId)) {
      return;
    }
    final result = await _topicRepository
        .getLessonsBySection(sectionId)
        .withLoading();
    _pendingLessons.remove(sectionId);
    switch (result) {
      case Success(data: final lessons):
        emit(state.copyWith(lessons: {...state.lessons, sectionId: lessons}));
      case Failure():
        // Lỗi (vd. section không còn tồn tại): để danh sách rỗng thay vì quay mãi.
        emit(
          state.copyWith(
            lessons: {...state.lessons, sectionId: const <TopicLesson>[]},
            failure: result,
          ),
        );
        emit(state.copyWith());
      case Cancelled():
        break;
    }
  }
}
