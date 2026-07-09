import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../util/logger.dart';

/// Wraps [FirebaseCrashlytics] with breadcrumb logging, custom keys, and
/// a zone-guarded error capture helper.
///
/// On Windows (where Firebase Crashlytics is not available), this class
/// degrades to a no-op — calls succeed silently without recording anything.
///
/// Usage:
/// ```dart
/// OfficeCore.crashlytics.setCustomKey('current_screen', 'HomeScreen');
/// OfficeCore.crashlytics.log('User tapped Export button');
/// OfficeCore.crashlytics.record(error, stack, reason: 'pdf_parse_failed');
/// ```
class OfficeCrashlytics {
  OfficeCrashlytics({OfficeLogger? logger})
      : _logger = logger ?? OfficeLogger.forTag('Crashlytics');

  final OfficeLogger _logger;

  /// Record an error with optional stack trace and reason.
  ///
  /// Safe to call on all platforms — on Windows this is a no-op.
  Future<void> record(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    Map<String, String>? keys,
  }) async {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      if (reason != null) {
        await crashlytics.log(reason);
      }
      if (keys != null) {
        for (final entry in keys.entries) {
          await crashlytics.setCustomKey(entry.key, entry.value);
        }
      }
      await crashlytics.recordError(error, stackTrace, reason: reason);
    } catch (e) {
      _logger.warning('Crashlytics record failed: $e');
    }
  }

  /// Set a custom key that will appear in future crash reports.
  Future<void> setCustomKey(String key, String value) async {
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (e) {
      _logger.warning('Crashlytics setCustomKey failed: $e');
    }
  }

  /// Set a custom key with an int value.
  Future<void> setCustomKeyInt(String key, int value) async {
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (e) {
      _logger.warning('Crashlytics setCustomKey failed: $e');
    }
  }

  /// Set a custom key with a bool value.
  Future<void> setCustomKeyBool(String key, bool value) async {
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (e) {
      _logger.warning('Crashlytics setCustomKey failed: $e');
    }
  }

  /// Record a breadcrumb that appears in the crash report.
  ///
  /// Use this to log user actions leading up to a potential crash, e.g.
  /// `OfficeCore.crashlytics.log('User tapped Export button')`.
  Future<void> log(String message) async {
    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      _logger.warning('Crashlytics log failed: $e');
    }
  }

  /// Set the user identifier for crash reports.
  Future<void> setUserIdentifier(String identifier) async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(identifier);
    } catch (e) {
      _logger.warning('Crashlytics setUserIdentifier failed: $e');
    }
  }

  /// Send any unsent crash reports. Called automatically on app start by
  /// [OfficeCore.initialize].
  Future<void> sendUnsentReports() async {
    try {
      await FirebaseCrashlytics.instance.sendUnsentReports();
    } catch (e) {
      _logger.warning('Crashlytics sendUnsentReports failed: $e');
    }
  }
}
