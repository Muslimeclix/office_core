import 'dart:async';
import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'models/office_remote_config.dart';
import '../util/connectivity_service.dart';
import '../util/logger.dart';

/// The RC key under which the entire legacy JSON config document was stored.
/// Retained only for backwards compatibility; the new model reads flat,
/// per-platform keys (e.g. `show_banner_android`).
const String kOfficeConfigKey = 'office_config_v1';

/// Service that fetches, parses, caches, and exposes the typed
/// [OfficeRemoteConfig].
///
/// Unlike the legacy single-JSON approach, this service uses **flat,
/// per-platform Remote Config keys** (e.g. `show_banner_android`,
/// `free_reminder_limit_ios`). All keys are suffixed with the running
/// platform: `_android`, `_ios`, or `_macos`.
///
/// Key behaviors:
/// - **Never crashes.** Initialization and refresh are fully guarded. If
///   there is no internet (or Firebase RC is unavailable), the service
///   proceeds with the bundled defaults and simply never updates until a
///   connection is available.
/// - **Auto-sync.** When connectivity is restored, the service
///   automatically re-fetches and re-emits the updated config.
/// - **Graceful defaults.** Package defaults are always present. A
///   consumer may supply additional defaults via [userDefaults]; any value
///   that is `null` or an empty string is ignored so the package default
///   is used instead.
class OfficeRemoteConfigService extends ChangeNotifier {
  OfficeRemoteConfigService({OfficeLogger? logger})
      : _logger = logger ?? OfficeLogger.instance;

  final OfficeLogger _logger;

  OfficeRemoteConfig _current = OfficeRemoteConfig.defaultProduction;
  bool _initialized = false;
  FirebaseRemoteConfig? _rc;
  Map<String, dynamic> _resolved = Map.from(PlatformConfig.defaultFlat);
  Map<String, int> _toolLimits = const {};

  /// The most recently fetched (or default) config.
  OfficeRemoteConfig get current => _current;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _initialized;

  /// Stream that emits a new [OfficeRemoteConfig] on every successful refresh.
  final StreamController<OfficeRemoteConfig> _controller =
      StreamController<OfficeRemoteConfig>.broadcast();

  /// Broadcast stream that emits a new [OfficeRemoteConfig] on every
  /// successful refresh.
  Stream<OfficeRemoteConfig> get changes => _controller.stream;

  /// Suffix used for per-platform RC keys on the current platform.
  String get _suffix {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return 'android'; // Windows has no Firebase RC; fall back to android keys
  }

  /// Whether Firebase Remote Config is actually usable on this platform.
  bool get _rcAvailable => !Platform.isWindows;

  /// Initialize the service.
  ///
  /// [userDefaults] is an optional per-platform flat map (e.g.
  /// `{'show_banner_android': false, ...}`) merged on top of the package
  /// defaults. [toolLimits] are the app-defined baseline tool limits.
  ///
  /// This method **never throws.** On any failure it silently proceeds with
  /// the bundled defaults so the host app keeps running.
  Future<void> initialize({
    Map<String, dynamic>? userDefaults,
    Map<String, int> toolLimits = const {},
    String defaultPlanType = 'weekly',
    String defaultPlanProductId = '',
    int defaultTrialDays = 3,
    Duration fetchTimeout = const Duration(seconds: 4),
    Duration minimumFetchInterval = Duration.zero,
  }) async {
    _toolLimits = toolLimits;

    final merged = _mergeDefaults(userDefaults);

    // Build the resolved map (platform suffix stripped) from the merged
    // defaults. This is what we expose immediately, even before any fetch.
    _resolved = _resolveFromDefaults(merged);

    // Apply top-level app config overrides (plan type / product / trial).
    _resolved['oc_splash_sub_type'] = defaultPlanType;
    _resolved['oc_splash_sub_product_id'] = defaultPlanProductId;
    _resolved['oc_splash_sub_trial_days'] = defaultTrialDays;
    _resolved['oc_result_plan_type'] = defaultPlanType;
    _resolved['oc_result_plan_product_id'] = defaultPlanProductId;
    _resolved['oc_result_trial_days'] = defaultTrialDays;

    _rebuild();

    if (!_rcAvailable) {
      _initialized = true;
      _logger.info('RC unavailable on this platform — using defaults');
      return;
    }

    try {
      _rc = FirebaseRemoteConfig.instance;
      await _rc!.setDefaults(merged);
      await _rc!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: fetchTimeout,
          minimumFetchInterval: minimumFetchInterval,
        ),
      );
      await _rc!.fetchAndActivate().timeout(fetchTimeout);
      _refreshResolved();
      _rebuild();
      _logger.info('OfficeRemoteConfigService initialized');
    } catch (e, st) {
      // No internet or any other failure — keep using defaults. Never crash.
      _logger.warning('RC init failed, using defaults: $e\n$st');
    }

    _initialized = true;
  }

  /// Trigger an explicit `fetchAndActivate` and rebuild. Safe to call any
  /// time. Never throws.
  Future<void> refresh() async => _refresh();

  Future<void> _refresh() async {
    if (!_rcAvailable || _rc == null) return;
    try {
      await _rc!.fetchAndActivate().timeout(const Duration(seconds: 4));
      _refreshResolved();
      _rebuild();
      _logger.debug('RC refreshed successfully');
    } catch (e, st) {
      _logger.warning('RC refresh failed (keeping current): $e\n$st');
    }
  }

  void _refreshResolved() {
    if (_rc == null) return;
    for (final entry in PlatformConfig.defaultFlat.entries) {
      final key = entry.key;
      final perKey = '${key}_$_suffix';
      final val = entry.value;
      if (val is bool) {
        _resolved[key] = _rc!.getBool(perKey);
      } else if (val is int) {
        _resolved[key] = _rc!.getInt(perKey);
      } else if (val is double) {
        _resolved[key] = _rc!.getDouble(perKey);
      } else {
        _resolved[key] = _rc!.getString(perKey);
      }
    }
  }

  void _rebuild() {
    _current = OfficeRemoteConfig(
      platform: PlatformConfig.fromFlat(_resolved, codeToolLimits: _toolLimits),
    );
    _controller.add(_current);
    notifyListeners();
  }

  // ── Generic accessors for app-specific keys ───────────────────────────────
  // These resolve the current platform suffix automatically so consumers can
  // read `free_reminder_limit`, `free_user_limit`, etc. directly.

  /// Read a boolean RC value for the current platform.
  bool boolValue(String baseKey) =>
      (_resolved[baseKey] as bool?) ?? false;

  /// Read an int RC value for the current platform.
  int intValue(String baseKey) =>
      (_resolved[baseKey] as num?)?.toInt() ?? 0;

  /// Read a double RC value for the current platform.
  double doubleValue(String baseKey) =>
      (_resolved[baseKey] as num?)?.toDouble() ?? 0.0;

  /// Read a string RC value for the current platform.
  String stringValue(String baseKey) =>
      (_resolved[baseKey] as String?) ?? '';

  /// Convenience selector: `rc.get((c) => c.platform.ads.units.banner)`.
  T? get<T>(T Function(OfficeRemoteConfig) selector) {
    try {
      return selector(_current);
    } catch (_) {
      return null;
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Merge package defaults (expanded per-platform) with [userDefaults].
  /// User values win, except when null or empty string (then package default).
  Map<String, dynamic> _mergeDefaults(Map<String, dynamic>? userDefaults) {
    final merged = <String, dynamic>{};
    // Expand package flat defaults to per-platform keys.
    for (final entry in PlatformConfig.defaultFlat.entries) {
      for (final p in const ['android', 'ios', 'macos']) {
        merged['${entry.key}_$p'] = entry.value;
      }
    }
    if (userDefaults != null) {
      for (final entry in userDefaults.entries) {
        final v = entry.value;
        if (v == null) continue;
        if (v is String && v.isEmpty) continue;
        merged[entry.key] = v;
      }
    }
    return merged;
  }

  /// Build the resolved (suffix-stripped) map from a per-platform defaults map.
  Map<String, dynamic> _resolveFromDefaults(Map<String, dynamic> perPlatform) {
    final resolved = <String, dynamic>{};
    for (final entry in PlatformConfig.defaultFlat.entries) {
      final key = entry.key;
      final perKey = '${key}_$_suffix';
      final v = perPlatform[perKey] ?? perPlatform[key] ?? entry.value;
      resolved[key] = v;
    }
    return resolved;
  }

  /// Subscribe to connectivity restores so RC auto-syncs when back online.
  void watchConnectivity(OfficeConnectivityService connectivity) {
    connectivity.onReconnect.listen((_) => _refresh());
  }

  @override
  @mustCallSuper
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
