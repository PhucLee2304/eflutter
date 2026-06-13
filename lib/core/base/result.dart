import 'package:flutter/foundation.dart';

/// Base class for all results.
///
/// [T] is the type of the result.
///
/// Get result data:
/// ```dart
/// switch (result) {
///   case Success(data: var data):
///     print(data);
///   case Failure(code: var code, message: var message):
///     print(message);
/// }
/// ```
///
/// Use result data in a widget:
/// ```dart
/// Widget build(BuildContext context) {
///   return switch (result) {
///     Success(data: var data) => Text(data.toString()),
///     Failure(code: var code, message: var message) => Text(message),
///   };
/// }
/// ```
@immutable
sealed class Result<T> {
  const Result();

  /// Get the data of the result if it is a success, otherwise null.
  T? get dataOrNull => switch (this) {
    Success(data: var data) => data,
    Cancelled() => null,
    Failure() => null,
  };

  const factory Result.success(T data) = Success;
  const factory Result.cancelled() = Cancelled;
  const factory Result.failure({int? code, String? message}) = Failure;
}

/// A success result.
class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);
}

/// A cancelled result.
class Cancelled<T> extends Result<T> {
  const Cancelled();
}

/// A failure result
class Failure<T> extends Result<T> {
  final int? code;
  final String? message;

  const Failure({this.code, this.message = 'Something went wrong!'});

  @override
  String toString() => 'Failure(code: $code, message: $message)';
}
