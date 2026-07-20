import 'package:flutter/foundation.dart';

/// ANSI escape codes for terminal color styling
class LogColor {
  static const String reset = '\x1B[0m';
  static const String black = '\x1B[30m';
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String magenta = '\x1B[35m';
  static const String cyan = '\x1B[36m';
  static const String white = '\x1B[37m';
  static const String bold = '\x1B[1m';
}

/// Custom logger supporting colored tags, groups, and debug-only execution
class AppLogger {
  AppLogger._();

  static void info(String message, {String tag = 'INFO'}) {
    _log(message, tag: tag, color: LogColor.cyan);
  }

  static void success(String message, {String tag = 'SUCCESS'}) {
    _log(message, tag: tag, color: LogColor.green);
  }

  static void warning(String message, {String tag = 'WARN'}) {
    _log(message, tag: tag, color: LogColor.yellow);
  }

  static void error(
    String message, {
    String tag = 'ERROR',
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer(message);
    if (error != null) buffer.write('\nError: $error');
    if (stackTrace != null) buffer.write('\nStackTrace:\n$stackTrace');
    _log(buffer.toString(), tag: tag, color: LogColor.red);
  }

  static void debug(String message, {String tag = 'DEBUG'}) {
    _log(message, tag: tag, color: LogColor.magenta);
  }

  static void _log(
    String message, {
    required String tag,
    required String color,
  }) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('$color[$tag] $message${LogColor.reset}');
    }
  }
}
