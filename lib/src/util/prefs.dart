import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Typed wrapper over [SharedPreferences] with a change stream.
///
/// Used by [OfficeTrialService] for usage tracking and trial-day recording.
/// Exposes typed getters so consumers don't need to remember string keys.
class OfficePrefs extends ChangeNotifier {
  OfficePrefs._();

  /// Singleton instance.
  static final OfficePrefs instance = OfficePrefs._();

  SharedPreferences? _prefs;

  /// Must be called before any getter/setter. Safe to call multiple times.
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _safe {
    final p = _prefs;
    if (p == null) {
      throw StateError(
          'OfficePrefs not initialized. Call OfficePrefs.instance.initialize() first.');
    }
    return p;
  }

  // ── Generic typed accessors ──────────────────────────────────────────────

  /// Get a string value for [key]. Returns null if not set.
  String? getString(String key) => _safe.getString(key);

  /// Set a string [value] for [key]. Notifies listeners on success.
  Future<bool> setString(String key, String value) async {
    final ok = await _safe.setString(key, value);
    notifyListeners();
    return ok;
  }

  /// Get an int value for [key]. Returns null if not set.
  int? getInt(String key) => _safe.getInt(key);

  /// Set an int [value] for [key]. Notifies listeners on success.
  Future<bool> setInt(String key, int value) async {
    final ok = await _safe.setInt(key, value);
    notifyListeners();
    return ok;
  }

  /// Get a double value for [key]. Returns null if not set.
  double? getDouble(String key) => _safe.getDouble(key);

  /// Set a double [value] for [key]. Notifies listeners on success.
  Future<bool> setDouble(String key, double value) async {
    final ok = await _safe.setDouble(key, value);
    notifyListeners();
    return ok;
  }

  /// Get a bool value for [key]. Returns null if not set.
  bool? getBool(String key) => _safe.getBool(key);

  /// Set a bool [value] for [key]. Notifies listeners on success.
  Future<bool> setBool(String key, bool value) async {
    final ok = await _safe.setBool(key, value);
    notifyListeners();
    return ok;
  }

  /// Remove the value for [key]. Notifies listeners on success.
  Future<bool> remove(String key) async {
    final ok = await _safe.remove(key);
    notifyListeners();
    return ok;
  }

  /// Clear all stored values. Notifies listeners on success.
  Future<bool> clear() async {
    final ok = await _safe.clear();
    notifyListeners();
    return ok;
  }
}
