import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/grammar/grammar_unit.dart';
import 'package:eflutter/data/repositories/grammar_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'grammar_curriculum_cubit.freezed.dart';

@freezed
class GrammarCurriculumState with _$GrammarCurriculumState {
  const factory GrammarCurriculumState.initial() = _Initial;
  const factory GrammarCurriculumState.loading() = _Loading;
  const factory GrammarCurriculumState.success(CurriculumResponse response) =
      _Success;
  const factory GrammarCurriculumState.error(String message) = _Error;
}

@injectable
class GrammarCurriculumCubit extends Cubit<GrammarCurriculumState> {
  final GrammarRepository _repository;

  GrammarCurriculumCubit(this._repository)
      : super(const GrammarCurriculumState.initial());

  Future<void> load() async {
    emit(const GrammarCurriculumState.loading());
    final result = await _repository.getCurriculum();
    switch (result) {
      case Success(data: final data):
        emit(GrammarCurriculumState.success(data));
      case Failure(message: final message):
        emit(GrammarCurriculumState.error(
            message ?? 'Failed to load curriculum'));
      case Cancelled():
        break;
    }
  }
}
