import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/models/attempt_page.dart';
import 'package:eflutter/data/models/exam_attempt.dart';
import 'package:eflutter/data/models/exam_attempt_page.dart';
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
    String? search,
    int? year,
  }) => _remoteData
      .getExams(type: type, page: page, pageSize: pageSize, search: search, year: year)
      .safeResult();

  Future<Result<List<int>>> getExamYears(String type) =>
      _remoteData.getExamYears(type).safeResult();

  Future<Result<ExamDetail>> getExamById(int examId) =>
      _remoteData.getExamById(examId).safeResult();

  Future<Result<ExamAttempt>> createExamAttempt(int examId, CreateExamAttemptRequest request) =>
      _remoteData.createExamAttempt(examId, request).safeResult();

  Future<Result<ExamAttemptPage>> getAttempts({
    required String status,
    required int page,
    required int pageSize,
    String? excludeMode,
    List<String> examTypes = const [],
    String? search,
  }) => _remoteData
      .getAttempts(
        status: status,
        page: page,
        pageSize: pageSize,
        excludeMode: excludeMode,
        examTypes: examTypes,
        search: search,
      )
      .safeResult();

  Future<Result<ExamAttempt>> getAttemptQuestions(int attemptId) =>
      _remoteData.getAttemptQuestions(attemptId).safeResult();

  Future<Result<ExamAttempt>> submitAttempt(int attemptId, List<SubmitAttemptAnswer> answers) =>
      _remoteData.submitAttempt(attemptId, answers).safeResult();

  Future<Result<ExamAttempt>> cancelAttempt(int attemptId) =>
      _remoteData.cancelAttempt(attemptId).safeResult();

  Future<Result<ExamAttempt>> getAttemptHistory(int attemptId) =>
      _remoteData.getAttemptHistory(attemptId).safeResult();

  Future<Result<AttemptNavigator>> getAttemptNavigator(int attemptId) =>
      _remoteData.getAttemptNavigator(attemptId).safeResult();

  Future<Result<AttemptPage>> getAttemptPage(int attemptId, int index) =>
      _remoteData.getAttemptPage(attemptId, index).safeResult();
}
