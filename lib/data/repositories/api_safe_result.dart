import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:talker_flutter/talker_flutter.dart';

mixin RepositorySafeCall {
  Future<Result<T>> safeCall<T>(
    Future<T> Function() action, {
    void Function(Exception e)? onError,
  }) => action().safeResult(onError: onError);
}

extension ApiSafeResult<T> on Future<T> {
  Talker get logger => getIt<Talker>();

  Future<Result<T>> safeResult({void Function(Exception e)? onError}) async {
    try {
      final response = await this;
      return Result.success(response);
    } on DioException catch (e) {
      final message = _extractDioErrorMessage(e);
      return Result.failure(code: e.response?.statusCode, message: message);
    } catch (e, st) {
      if (e is Exception) {
        onError?.call(e);
      }
      logger.error('[UnexpectedException]:', e, st);
      return Result.failure(
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  String _extractDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your internet connection.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.badResponse:
        return _extractDioBadResponseErrorMessage(e);
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      default:
        return 'Could not connect to the server.';
    }
  }

  String _extractDioBadResponseErrorMessage(DioException e) {
    final data = e.response?.data;
    final statusCode = e.response?.statusCode;

    if (statusCode != null && statusCode >= 500) {
      return 'The server is unavailable (error $statusCode). Please try again later.';
    }

    String? detail;
    if (data is Map<String, dynamic>) {
      detail = data['message'] is String ? data['message'] as String : null;
      final error = data['error'];
      detail ??= error is String ? error : null;
      if (error is Map && error['message'] is String) {
        detail ??= error['message'] as String;
      }
    } else if (data is String && data.isNotEmpty) {
      detail = data;
    }

    final normalized = detail
        ?.replaceFirst(
          RegExp(r'^\[(ERROR|FORBIDDEN|CONFLICT|UNAUTHORIZED)\]\s*'),
          '',
        )
        .trim();
    const translations = {
      'Classroom is not active': 'This classroom is no longer active.',
      'Classroom access denied': 'You cannot access this classroom.',
      'Classroom capacity is full': 'This classroom is full.',
      'Teacher cannot join own classroom as student':
          'Teachers cannot join their own classroom as students.',
      'Active attempt already exists':
          'You already have an active attempt.',
    };
    if (normalized != null && translations.containsKey(normalized)) {
      return translations[normalized]!;
    }
    if (normalized != null && !RegExp(r'[À-ỹĐđ]').hasMatch(normalized)) {
      return normalized;
    }
    return switch (statusCode) {
      400 => 'Invalid request.',
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have permission to do that.',
      404 => 'The requested item was not found.',
      409 => 'This item already exists or is in use.',
      _ => 'Could not process the request. Please try again.',
    };
  }
}
