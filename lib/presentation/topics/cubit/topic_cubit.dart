import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/data/models/topic_lesson.dart';
import 'package:eflutter/data/models/topic_section.dart';
import 'package:eflutter/data/models/topic_summary.dart';
import 'package:eflutter/data/repositories/topic_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

class TopicState {
  final List<TopicSummary> topics;
  final List<TopicSection> sections;
  final List<TopicLesson> lessons;
  final TopicSummary? selectedTopic;
  final TopicSection? selectedSection;
  final bool isLoadingTopics;
  final bool isLoadingSections;
  final bool isLoadingLessons;
  final Failure? failure;

  const TopicState({
    this.topics = const [],
    this.sections = const [],
    this.lessons = const [],
    this.selectedTopic,
    this.selectedSection,
    this.isLoadingTopics = false,
    this.isLoadingSections = false,
    this.isLoadingLessons = false,
    this.failure,
  });

  TopicState copyWith({
    List<TopicSummary>? topics,
    List<TopicSection>? sections,
    List<TopicLesson>? lessons,
    Object? selectedTopic = _topicSentinel,
    Object? selectedSection = _topicSentinel,
    bool? isLoadingTopics,
    bool? isLoadingSections,
    bool? isLoadingLessons,
    Object? failure = _topicSentinel,
  }) {
    return TopicState(
      topics: topics ?? this.topics,
      sections: sections ?? this.sections,
      lessons: lessons ?? this.lessons,
      selectedTopic: identical(selectedTopic, _topicSentinel)
          ? this.selectedTopic
          : selectedTopic as TopicSummary?,
      selectedSection: identical(selectedSection, _topicSentinel)
          ? this.selectedSection
          : selectedSection as TopicSection?,
      isLoadingTopics: isLoadingTopics ?? this.isLoadingTopics,
      isLoadingSections: isLoadingSections ?? this.isLoadingSections,
      isLoadingLessons: isLoadingLessons ?? this.isLoadingLessons,
      failure: identical(failure, _topicSentinel)
          ? this.failure
          : failure as Failure?,
    );
  }
}

const _topicSentinel = Object();

@injectable
class TopicCubit extends Cubit<TopicState> {
  final TopicRepository _topicRepository;

  TopicCubit(this._topicRepository) : super(const TopicState());

  Future<void> load() async {
    emit(state.copyWith(isLoadingTopics: true, failure: null));
    final result = await _topicRepository.getTopics().withLoading();
    switch (result) {
      case Success(data: final topics):
        emit(
          state.copyWith(
            topics: topics,
            selectedTopic: null,
            sections: const [],
            lessons: const [],
            selectedSection: null,
            isLoadingTopics: false,
          ),
        );
      case Failure():
        emit(state.copyWith(isLoadingTopics: false, failure: result));
        emit(state.copyWith(failure: null));
      case Cancelled():
        emit(state.copyWith(isLoadingTopics: false));
    }
  }

  /// Quay về danh sách topic.
  void clearTopic() {
    emit(
      state.copyWith(
        selectedTopic: null,
        selectedSection: null,
        sections: const [],
        lessons: const [],
        isLoadingSections: false,
        isLoadingLessons: false,
      ),
    );
  }

  Future<void> selectTopic(TopicSummary topic) async {
    emit(
      state.copyWith(
        selectedTopic: topic,
        selectedSection: null,
        sections: const [],
        lessons: const [],
        isLoadingSections: true,
        isLoadingLessons: false,
        failure: null,
      ),
    );

    final result = await _topicRepository
        .getSectionsByTopic(topic.id)
        .withLoading();
    switch (result) {
      case Success(data: final sections):
        emit(state.copyWith(sections: sections, isLoadingSections: false));
      case Failure(code: 404):
        // Topic không còn tồn tại (vd. dữ liệu vừa seed lại): báo lỗi rồi tải lại
        // danh sách để bỏ topic cũ khỏi màn hình.
        emit(state.copyWith(isLoadingSections: false, failure: result));
        emit(state.copyWith(failure: null));
        await load();
      case Failure():
        emit(state.copyWith(isLoadingSections: false, failure: result));
        emit(state.copyWith(failure: null));
      case Cancelled():
        emit(state.copyWith(isLoadingSections: false));
    }
  }

  /// Quay về danh sách section của topic đang chọn.
  void clearSection() {
    emit(
      state.copyWith(
        selectedSection: null,
        lessons: const [],
        isLoadingLessons: false,
      ),
    );
  }

  Future<void> selectSection(TopicSection section) async {
    emit(
      state.copyWith(
        selectedSection: section,
        lessons: const [],
        isLoadingLessons: true,
        failure: null,
      ),
    );

    final result = await _topicRepository
        .getLessonsBySection(section.id)
        .withLoading();
    switch (result) {
      case Success(data: final lessons):
        emit(state.copyWith(lessons: lessons, isLoadingLessons: false));
      case Failure():
        emit(state.copyWith(isLoadingLessons: false, failure: result));
        emit(state.copyWith(failure: null));
      case Cancelled():
        emit(state.copyWith(isLoadingLessons: false));
    }
  }
}
