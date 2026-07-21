import 'package:logger/logger.dart';

/// Structured logging wrapper, per SPRINT0.md §12.
///
/// A thin wrapper (rather than calling `package:logger` directly at every
/// call site) so a Sentry breadcrumb sink can be added in a later sprint
/// without touching every caller.
class AppLogger {
  AppLogger(this._name);

  final String _name;

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      colors: false,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  void debug(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.d('[$_name] $message', error: error, stackTrace: stackTrace);

  void info(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.i('[$_name] $message', error: error, stackTrace: stackTrace);

  void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.w('[$_name] $message', error: error, stackTrace: stackTrace);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e('[$_name] $message', error: error, stackTrace: stackTrace);
}
