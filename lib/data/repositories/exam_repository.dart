import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/exam_detail.dart';
import 'package:eflutter/data/models/exam_page.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';

class ExamRepository {
  final RemoteDataBase _remoteData;

  ExamRepository(this._remoteData);

  Future<Result<ExamPage>> getExams({
    required String type,
    required int page,
    required int pageSize,
  }) => _remoteData
      .getExams(type: type, page: page, pageSize: pageSize)
      .safeResult();

  Future<Result<ExamDetail>> getExamById(int examId) =>
      _remoteData.getExamById(examId).safeResult();
}
