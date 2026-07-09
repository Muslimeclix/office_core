import 'package:shared_preferences/shared_preferences.dart';

import 'ads/office_ads_controller.dart';
import 'analytics/office_analytics_service.dart';
import 'crashlytics/office_crashlytics.dart';
import 'notifications/office_notification_controller.dart';
import 'premium/premium_status_provider.dart';
import 'remote_config/models/office_remote_config.dart';
import 'remote_config/office_remote_config_service.dart';
import 'trial/office_trial_service.dart';
import 'util/connectivity_service.dart';
import 'util/lifecycle_service.dart';
import 'util/logger.dart';

/// Environment selector for [OfficeCore.initialize].
enum OfficeEnv { development, staging, production }

/// Configuration object for [OfficeCore.initialize].
///
/// Required (app-specific) parameters:
/// - [premiumProvider]
/// - [notificationBackend] (if [enableNotifications] is true)
///
/// All other parameters are optional with sensible defaults.
class OfficeCoreConfig {
  const OfficeCoreConfig({
    required this.premiumProvider,
    this.env = OfficeEnv.production,
    this.logLevel,
    this.remoteConfigDefaults,
    this.remoteConfigFetchTimeout = const Duration(seconds: 4),
    this.enableCrashlytics = true,
    this.enableAnalytics = true,
    this.enableAds = true,
    this.enableNotifications = true,
    this.notificationBackend,
    this.consentRequired = true,
  });

  /// Premium status provider. The plugin cannot know how the app tracks
  /// premium (RevenueCat, StoreKit, custom, GetX). Pass any class that
  /// implements [PremiumStatusProvider].
  final PremiumStatusProvider premiumProvider;

  /// Environment (affects log verbosity and crash reporting destination).
  final OfficeEnv env;

  /// Override the default log level. If null, defaults to [OfficeLogLevel.debug]
  /// in dev and [OfficeLogLevel.warning] in release.
  final OfficeLogLevel? logLevel;

  /// Bundled default [OfficeRemoteConfig] used when RC fetch fails or before
  /// the first successful fetch completes. Defaults to
  /// [OfficeRemoteConfig.defaultProduction].
  final OfficeRemoteConfig? remoteConfigDefaults;

  /// RC fetch timeout. Default: 4 seconds.
  final Duration remoteConfigFetchTimeout;

  /// Enable/disable the Crashlytics subsystem. Disabled subsystems return
  /// no-op implementations.
  final bool enableCrashlytics;

  /// Enable/disable the Analytics subsystem.
  final bool enableAnalytics;

  /// Enable/disable the Ads subsystem.
  final bool enableAds;

  /// Enable/disable the Notifications subsystem.
  final bool enableNotifications;

  /// Backend config for notifications. Required if [enableNotifications] is
  /// true.
  final NotificationBackendConfig? notificationBackend;

  /// Whether consent (ATT/GDPR) is required before ads/analytics activate.
  /// Default: true.
  final bool consentRequired;
}

/// Singleton that exposes every OfficeCore subsystem.
///
/// Initialized via [initialize]. After initialization, access subsystems via
/// the static [instance] getter:
///
/// ```dart
/// OfficeCore.instance?.ads.shouldShowBanner
/// OfficeCore.instance?.rc.current.platform.ads.units.banner
/// OfficeCore.instance?.crashlytics.record(error, stack)
/// OfficeCore.instance?.analytics.logEvent('my_event')
/// OfficeCore.instance?.trial.canDownload
/// OfficeCore.instance?.notifications.fcmToken
/// ```
class OfficeCore {
  OfficeCore._(this._config, this._services);

  final OfficeCoreConfig _config;
  final _Services _services;

  static OfficeCore? _instance;

  /// The initialized [OfficeCore] instance, or null if [initialize] has not
  /// been called.
  static OfficeCore? get instance => _instance;

  /// The config passed to [initialize].
  static OfficeCoreConfig get config => _instance!._config;

  // ── Subsystem accessors ───────────────────────────────────────────────────

  /// Remote Config service.
  static OfficeRemoteConfigService get rc => _instance!._services.rc;

  /// Premium status provider.
  static PremiumStatusProvider get premium => _instance!._config.premiumProvider;

  /// Ads controller.
  static OfficeAdsController get ads => _instance!._services.ads;

  /// Crashlytics.
  static OfficeCrashlytics get crashlytics => _instance!._services.crashlytics;

  /// Analytics service.
  static OfficeAnalyticsService get analytics =>
      _instance!._services.analytics;

  /// Notifications controller.
  static OfficeNotificationController? get notifications =>
      _instance!._services.notifications;

  /// Trial & limits service.
  static OfficeTrialService get trial => _instance!._services.trial;

  /// Lifecycle service.
  static OfficeLifecycleService get lifecycle =>
      _instance!._services.lifecycle;

  /// Connectivity service.
  static OfficeConnectivityService get connectivity =>
      _instance!._services.connectivity;

  /// Logger.
  static OfficeLogger get logger => _instance!._services.logger;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Initialize OfficeCore. Must be called once in `main()` before
  /// `runApp()`.
  ///
  /// This method never throws — every subsystem catches its own init errors
  /// and degrades gracefully. The host app should not crash due to an
  /// OfficeCore failure.
  ///
  /// Example:
  /// ```dart
  /// Future<void> main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  ///
  ///   await OfficeCore.initialize(OfficeCoreConfig(
  ///     premiumProvider: ValueNotifierPremiumProvider(ValueNotifier(false)),
  ///     notificationBackend: NotificationBackendConfig(
  ///       openedApiUrl: 'https://api.example.com/notification/opened',
  ///       deviceRegistryPath: 'devices',
  ///       topics: ['all_users'],
  ///     ),
  ///   ));
  ///
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> initialize(OfficeCoreConfig config) async {
    if (_instance != null) {
      throw StateError('OfficeCore already initialized. Call OfficeCore.dispose() first.');
    }

    // Set up logger
    final logger = OfficeLogger.instance;
    logger.level = config.logLevel ??
        (config.env == OfficeEnv.production
            ? OfficeLogLevel.warning
            : OfficeLogLevel.debug);

    // Initialize utilities
    final lifecycle = OfficeLifecycleService.instance;
    final connectivity = OfficeConnectivityService.instance;
    connectivity.initialize();

    // Initialize Remote Config
    final rc = OfficeRemoteConfigService(logger: logger);
    await rc.initialize(
      defaults: config.remoteConfigDefaults,
      fetchTimeout: config.remoteConfigFetchTimeout,
    );

    // Initialize Crashlytics
    final crashlytics = OfficeCrashlytics(logger: logger);
    if (config.enableCrashlytics) {
      await crashlytics.sendUnsentReports();
    }

    // Initialize Analytics
    final analytics = OfficeAnalyticsService(logger: logger);

    // Initialize Ads
    final ads = OfficeAdsController(
      rc: rc,
      premium: config.premiumProvider,
      connectivity: connectivity,
      lifecycle: lifecycle,
      logger: logger,
    );
    if (config.enableAds) {
      ads.initialize();
    }

    // Initialize Notifications
    OfficeNotificationController? notifications;
    if (config.enableNotifications && config.notificationBackend != null) {
      notifications = OfficeNotificationController(
        backend: config.notificationBackend!,
        lifecycle: lifecycle,
        logger: logger,
      );
      await notifications.initialize();
    }

    // Initialize Trial
    final prefs = await SharedPreferences.getInstance();
    final trial = OfficeTrialService(
      rc: rc,
      premium: config.premiumProvider,
      prefs: prefs,
    );

    _instance = OfficeCore._(
      config,
      _Services(
        rc: rc,
        ads: ads,
        crashlytics: crashlytics,
        analytics: analytics,
        notifications: notifications,
        trial: trial,
        lifecycle: lifecycle,
        connectivity: connectivity,
        logger: logger,
      ),
    );

    logger.info('OfficeCore initialized (env: ${config.env.name})');
  }

  /// Tear down all subsystems. Call in `dispose()` if you need to
  /// re-initialize (e.g., in tests).
  static void dispose() {
    _instance?._services.dispose();
    _instance = null;
  }

  /// Whether [initialize] has been called and completed.
  static bool get isInitialized => _instance != null;
}

class _Services {
  _Services({
    required this.rc,
    required this.ads,
    required this.crashlytics,
    required this.analytics,
    required this.notifications,
    required this.trial,
    required this.lifecycle,
    required this.connectivity,
    required this.logger,
  });

  final OfficeRemoteConfigService rc;
  final OfficeAdsController ads;
  final OfficeCrashlytics crashlytics;
  final OfficeAnalyticsService analytics;
  final OfficeNotificationController? notifications;
  final OfficeTrialService trial;
  final OfficeLifecycleService lifecycle;
  final OfficeConnectivityService connectivity;
  final OfficeLogger logger;

  void dispose() {
    ads.dispose();
    rc.dispose();
    notifications?.dispose();
    trial.dispose();
    connectivity.dispose();
    lifecycle.dispose();
  }
}
