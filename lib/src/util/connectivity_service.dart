import 'dart:async';

import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'logger.dart';

/// Wraps [InternetConnection] and exposes a stream that fires when network
/// connectivity is restored after an outage.
///
/// Used by [OfficeRemoteConfigService] to trigger a refresh on reconnect —
/// the same behavior the current office apps implement inline in
/// `AdsController`, but centralized so every subsystem benefits.
class OfficeConnectivityService {
  OfficeConnectivityService._({OfficeLogger? logger})
      : _logger = logger ?? OfficeLogger.instance;

  /// Singleton instance.
  static final OfficeConnectivityService instance =
      OfficeConnectivityService._();

  final OfficeLogger _logger;

  StreamSubscription<InternetStatus>? _subscription;
  bool _wasConnected = true;

  final StreamController<void> _reconnectController =
      StreamController<void>.broadcast();

  /// Fires when network connectivity is restored after an outage.
  Stream<void> get onReconnect => _reconnectController.stream;

  /// Whether the device currently has internet access.
  bool get isConnected => _wasConnected;

  /// Start listening to connectivity changes. Call once on app startup.
  void initialize() {
    _subscription = InternetConnection().onStatusChange.listen((status) {
      final connected = status == InternetStatus.connected;
      if (!_wasConnected && connected) {
        _logger.info('Connectivity restored — triggering reconnect');
        _reconnectController.add(null);
      }
      _wasConnected = connected;
    });
  }

  /// Release resources.
  void dispose() {
    _subscription?.cancel();
    _reconnectController.close();
  }
}
