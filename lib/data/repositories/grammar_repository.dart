import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/data_sources/grammar_remote_data.dart';
import 'package:eflutter/data/models/grammar/grammar_unit.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GrammarRepository with RepositorySafeCall {
  final GrammarRemoteData _remoteData;

  GrammarRepository(this._remoteData);

  Future<Result<CurriculumResponse>> getCurriculum() async {
    return safeCall(() => _remoteData.getCurriculum());
  }

  Future<Result<UnitDetail>> getUnitDetail(int id) async {
    return safeCall(() => _remoteData.getUnitDetail(id));
  }
  Future<Result<void>> submitProgress(int unitId) async {
    return safeCall(() => _remoteData.submitProgress(unitId, {
      'completed': true,
    }));
  }
}
