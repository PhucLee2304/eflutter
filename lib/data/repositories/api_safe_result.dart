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
      return Result.failure(message: message);
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
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.badResponse:
        return _extractDioBadResponseErrorMessage(e);
      case DioExceptionType.cancel:
        return 'The request has been canceled.';
      default:
        return 'Undefined connection error.';
    }
  }

  String _extractDioBadResponseErrorMessage(DioException e) {
    final data = e.response?.data;
    final statusCode = e.response?.statusCode;

    if (statusCode != null && statusCode >= 500) {
      return 'Server is experiencing issues (Error $statusCode). Please try again later.';
    }

    if (data == null) {
      return e.message ?? 'An unexpected error occurred. Please try again.';
    }

    if (data is Map<String, dynamic>) {
      if (data.containsKey('message')) {
        return data['message'];
      }
      if (data.containsKey('error')) {
        final error = data['error'];
        if (error is String) {
          return error;
        }
        if (error is Map && error.containsKey('message')) {
          return error['message'];
        }
      }
    }

    if (data is String && data.isNotEmpty) {
      return data;
    }

    return 'An unexpected error occurred while processing the request.';
  }
}
