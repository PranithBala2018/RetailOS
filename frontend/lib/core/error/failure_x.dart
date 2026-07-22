import 'failure.dart';

/// Turns a [Failure] into a short, user-facing sentence. Kept separate
/// from `failure.dart` (a generated-pair source file) so every screen
/// across every module can render a consistent message instead of the
/// Freezed default `toString()`.
extension FailureMessage on Failure {
  String get userMessage => when(
    network: (message) =>
        message ?? 'No internet connection. Please check your network.',
    server: (message, statusCode) =>
        message ?? 'Something went wrong on the server. Please try again.',
    cache: (message) => message ?? 'Could not read local data.',
    validation: (message, fieldErrors) => message,
    conflict: (message) =>
        message ??
        'This record was changed by someone else. Reload and try again.',
    auth: (message) =>
        message ?? 'Your session has expired. Please sign in again.',
    unexpected: (message) => message ?? 'An unexpected error occurred.',
  );
}
