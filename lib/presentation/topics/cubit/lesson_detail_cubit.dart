import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/loading/loading_service.dart';
import 'package:eflutter/data/models/topic_lesson_detail.dart';
import 'package:eflutter/data/repositories/topic_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LessonDetailState {
  final TopicLessonDetail? lesson;
  final bool isLoading;
  final Failure? failure;

  const LessonDetailState({
    this.lesson,
    this.isLoading = false,
    this.failure,
  });

  LessonDetailState copyWith({
    Object? lesson = _lessonDetailSentinel,
    bool? isLoading,
    Object? failure = _lessonDetailSentinel,
  }) {
    return LessonDetailState(
      lesson: identical(lesson, _lessonDetailSentinel)
          ? this.lesson
          : lesson as TopicLessonDetail?,
      isLoading: isLoading ?? this.isLoading,
      failure: identical(failure, _lessonDetailSentinel)
          ? this.failure
          : failure as Failure?,
    );
  }
}

const _lessonDetailSentinel = Object();

class LessonDetailCubit extends Cubit<LessonDetailState> {
  final TopicRepository _topicRepository;

  LessonDetailCubit(this._topicRepository) : super(const LessonDetailState());

  Future<void> load(int lessonId) async {
    emit(state.copyWith(isLoading: true, failure: null));
    final result = await _topicRepository.getLessonById(lessonId).withLoading();
    switch (result) {
      case Success(data: final lesson):
        emit(
          state.copyWith(
            lesson: lesson,
            isLoading: false,
            failure: null,
          ),
        );
      case Failure():
        emit(state.copyWith(isLoading: false, failure: result));
        emit(state.copyWith(failure: null));
      case Cancelled():
        emit(state.copyWith(isLoading: false));
    }
  }
}
