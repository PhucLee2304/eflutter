import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  setUpAll(() {
    if (!getIt.isRegistered<Talker>()) {
      getIt.registerSingleton<Talker>(Talker());
    }
  });

  test('translates known classroom error', () async {
    final request = RequestOptions(path: '/classrooms');
    final result = await Future<String>.error(
      DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 400,
          data: {'error': '[ERROR] Classroom capacity is full'},
        ),
        type: DioExceptionType.badResponse,
      ),
    ).safeResult();
    expect(result, isA<Failure>());
    expect((result as Failure).message, 'This classroom is full.');
  });

  test('keeps unknown English backend details readable', () async {
    final request = RequestOptions(path: '/classrooms');
    final result = await Future<String>.error(
      DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 403,
          data: {'error': '[FORBIDDEN] Some English backend detail'},
        ),
        type: DioExceptionType.badResponse,
      ),
    ).safeResult();
    expect(
      (result as Failure).message,
      'Some English backend detail',
    );
  });
}
