import 'package:dio/dio.dart';
import 'package:eflutter/data/models/grammar/grammar_unit.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

part 'grammar_remote_data.g.dart';

@RestApi()
@LazySingleton()
abstract class GrammarRemoteData {
  @factoryMethod
  factory GrammarRemoteData(Dio dio) = _GrammarRemoteData;

  @GET('/grammar/api/v1/units')
  Future<CurriculumResponse> getCurriculum();

  @GET('/grammar/api/v1/units/{id}')
  Future<UnitDetail> getUnitDetail(@Path('id') int id);

  @PUT('/grammar/api/v1/units/{id}/progress')
  Future<void> submitProgress(
    @Path('id') int id,
    @Body() Map<String, dynamic> body,
  );
}
