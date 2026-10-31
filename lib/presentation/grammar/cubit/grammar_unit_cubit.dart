import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/grammar/grammar_unit.dart';
import 'package:eflutter/data/repositories/grammar_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'grammar_unit_cubit.freezed.dart';

@freezed
class GrammarUnitState with _$GrammarUnitState {
  const factory GrammarUnitState.initial() = _Initial;
  const factory GrammarUnitState.loading() = _Loading;
  const factory GrammarUnitState.success(UnitDetail unit) = _Success;
  const factory GrammarUnitState.error(String message) = _Error;
}

@injectable
class GrammarUnitCubit extends Cubit<GrammarUnitState> {
  final GrammarRepository _repository;

  GrammarUnitCubit(this._repository)
      : super(const GrammarUnitState.initial());

  Future<void> loadUnit(int id) async {
    emit(const GrammarUnitState.loading());
    final result = await _repository.getUnitDetail(id);
    switch (result) {
      case Success(data: final data):
        emit(GrammarUnitState.success(data));
      case Failure(message: final message):
        emit(GrammarUnitState.error(message ?? 'Failed to load unit'));
      case Cancelled():
        break;
    }
  }

  Future<void> submitProgress(int unitId) async {
    await _repository.submitProgress(unitId);
  }
}
