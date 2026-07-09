import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'models/office_remote_config.dart';
import '../util/logger.dart';

/// The RC key under which the entire JSON config document is stored.
const String kOfficeConfigKey = 'office_config_v1';

/// Service that fetches, parses, caches, and exposes the typed
/// [OfficeRemoteConfig].
///
/// Wraps [FirebaseRemoteConfig]. On initialization, sets a bundled default
/// JSON as the RC default value, configures fetch timeout, and performs an
/// initial `fetchAndActivate`. On failure, falls back to the bundled defaults.
///
/// Exposes:
/// - [current] — synchronous access to the last successfully parsed config.
/// - [changes] — broadcast stream that emits a new [OfficeRemoteConfig] on
///   every successful refresh.
/// - [refresh] — manual trigger for `fetchAndActivate`.
///
/// [refresh] is called automatically by [OfficeConnectivityService] when
/// network connectivity is restored after an outage.
class OfficeRemoteConfigService extends ChangeNotifier {
  OfficeRemoteConfigService({OfficeLogger? logger})
      : _logger = logger ?? OfficeLogger.instance;

  final OfficeLogger _logger;

  OfficeRemoteConfig _current = OfficeRemoteConfig.defaultProduction;
  bool _initialized = false;

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

  /// Initialize the service.
  ///
  /// Sets [defaults] as the Firebase RC default value, configures fetch
  /// timeout, and performs the initial `fetchAndActivate`.
  ///
  /// On any failure (network, parse, etc.), falls back to [defaults] silently.
  /// This method never throws — the host app should not crash due to an RC
  /// failure.
  Future<void> initialize({
    OfficeRemoteConfig? defaults,
    Duration fetchTimeout = const Duration(seconds: 4),
    Duration minimumFetchInterval = Duration.zero,
  }) async {
    final fallback = defaults ?? OfficeRemoteConfig.defaultProduction;
    _current = fallback;

    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setDefaults({
        kOfficeConfigKey: jsonEncode(fallback.toJson()),
      });
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: fetchTimeout,
          minimumFetchInterval: minimumFetchInterval,
        ),
      );
      await _refresh();
      _initialized = true;
      _logger.info('OfficeRemoteConfigService initialized');
    } catch (e, st) {
      _logger.warning('RC init failed, using defaults: $e\n$st');
      _initialized = true; // Still mark as initialized so consumers proceed.
    }
  }

  /// Trigger an explicit `fetchAndActivate`. Parses the result and emits on
  /// [changes] if the config changed.
  ///
  /// Safe to call at any time. Never throws.
  Future<void> refresh() async => _refresh();

  Future<void> _refresh() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      final raw = rc.getString(kOfficeConfigKey);
      if (raw.isEmpty) {
        _logger.warning('RC returned empty string for $kOfficeConfigKey');
        return;
      }
      final parsed = OfficeRemoteConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _current = parsed;
      _controller.add(parsed);
      notifyListeners();
      _logger.debug('RC refreshed successfully');
    } catch (e, st) {
      _logger.warning('RC refresh failed: $e\n$st');
    }
  }

  /// Convenience selector: `rc.get((c) => c.platform.ads.units.banner)`.
  T? get<T>(T Function(OfficeRemoteConfig) selector) {
    try {
      return selector(_current);
    } catch (_) {
      return null;
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
