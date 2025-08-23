import 'package:logger/logger.dart';

/// Centralized logging utility
/// WHY: Debug issues quickly, track app behavior, catch errors early
/// In production, this can send logs to crash reporting services

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      // ignore: deprecated_member_use
      printTime: true,
    ),
    level: Level.debug, // Change to Level.info in production
  );

  /// Log debug message
  static void debug(String message, [dynamic data]) {
    _logger.d('$message${data != null ? '\n$data' : ''}');
  }

  /// Log info message
  static void info(String message, [dynamic data]) {
    _logger.i('$message${data != null ? '\n$data' : ''}');
  }

  /// Log warning message
  static void warning(String message, [dynamic data]) {
    _logger.w('$message${data != null ? '\n$data' : ''}');
  }

  /// Log error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal error (app-breaking)
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
    // In production, this would trigger crash reporting
  }
}
