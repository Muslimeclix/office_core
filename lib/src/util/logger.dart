import 'package:flutter/foundation.dart';

/// Severity levels for [OfficeLogger].
enum OfficeLogLevel { debug, info, warning, error, none }

/// Tagged logger that respects [OfficeLogLevel] set at init time.
///
/// All log messages are prefixed with `[OfficeCore:<tag>]` so they're easy
/// to filter in log viewers. In release builds, the default level is
/// [OfficeLogLevel.warning] (only warnings and errors are emitted).
///
/// Usage:
/// ```dart
/// OfficeLogger.instance.info('Something happened');
/// OfficeLogger.instance.warning('Something concerning');
/// OfficeLogger.instance.error('Something broke: $e');
/// ```
class OfficeLogger {
  OfficeLogger._()
      : _level = kReleaseMode
            ? OfficeLogLevel.warning
            : OfficeLogLevel.debug;

  static final OfficeLogger instance = OfficeLogger._();

  OfficeLogLevel _level;
  String _tag = 'Core';


  /// Set the minimum log level.
  set level(OfficeLogLevel value) => _level = value;

  /// Set the tag prefix.
  set tag(String value) => _tag = value;

  /// Log a debug message. Silently dropped if [level] is above debug.
  void debug(Object? message) => _log(OfficeLogLevel.debug, message);

  /// Log an info message. Silently dropped if [level] is above info.
  void info(Object? message) => _log(OfficeLogLevel.info, message);

  /// Log a warning message. Silently dropped if [level] is above warning.
  void warning(Object? message) => _log(OfficeLogLevel.warning, message);

  /// Log an error message with optional error and stack trace.
  void error(Object? message, [Object? error, StackTrace? stack]) {
    _log(OfficeLogLevel.error, message);
    if (error != null) _log(OfficeLogLevel.error, error);
    if (stack != null) _log(OfficeLogLevel.error, stack);
  }

  void _log(OfficeLogLevel level, Object? message) {
    if (level.index < _level.index) return;
    // ignore: avoid_print
    print('[OfficeCore:$_tag] ${_levelLabel(level)} $message');
  }

  String _levelLabel(OfficeLogLevel level) {
    switch (level) {
      case OfficeLogLevel.debug:
        return 'DEBUG';
      case OfficeLogLevel.info:
        return 'INFO';
      case OfficeLogLevel.warning:
        return 'WARN';
      case OfficeLogLevel.error:
        return 'ERROR';
      case OfficeLogLevel.none:
        return '';
    }
  }

  /// Create a child logger with a fixed tag. Subsystems use this so their
  /// logs are easily identifiable.
  factory OfficeLogger.forTag(String tag) {
    final logger = OfficeLogger._();
    logger._tag = tag;
    return logger;
  }
}