import 'package:dio/dio.dart';

import '../error/failure.dart';

/// Maps a DioException onto the app's Failure union, reading the
/// backend's `{"success": false, "message": ..., "errors": [...]}`
/// envelope (API.md) when present so callers get a real message instead
/// of a generic one.
Failure mapDioException(DioException exception) {
  if (exception.type == DioExceptionType.connectionError ||
      exception.type == DioExceptionType.connectionTimeout ||
      exception.type == DioExceptionType.receiveTimeout) {
    return const Failure.network();
  }

  final statusCode = exception.response?.statusCode;
  final message = _extractMessage(exception.response?.data);

  if (statusCode == 401) {
    return Failure.auth(message: message);
  }
  if (statusCode == 409) {
    return Failure.conflict(message: message);
  }
  if (statusCode == 422 || statusCode == 400) {
    return Failure.validation(message: message ?? 'Validation failed', fieldErrors: null);
  }
  return Failure.server(statusCode: statusCode, message: message ?? exception.message);
}

String? _extractMessage(dynamic responseData) {
  if (responseData is Map<String, dynamic>) {
    final message = responseData['message'];
    if (message is String) return message;
  }
  return null;
}
