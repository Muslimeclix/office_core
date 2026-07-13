import 'dart:async';

import 'package:flutter_udid/flutter_udid.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';import 'ads/office_ads_controller.dart';
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
/// - [toolLimits] — app-specific tool names and their free-tier limits
/// - [notificationBackend] (if [enableNotifications] is true)
///
/// All other parameters are optional with sensible defaults.
class OfficeCoreConfig {
  const OfficeCoreConfig({
    required this.premiumProvider,
    required this.toolLimits,
    this.env = OfficeEnv.production,
    this.logLevel,
    this.remoteConfigDefaults,
    this.defaultPlanType = 'weekly',
    this.defaultPlanProductId = '',
    this.defaultTrialDays = 3,
    this.remoteConfigFetchTimeout = const Duration(seconds: 4),
    this.enableCrashlytics = true,
    this.enableAnalytics = true,
    this.enableAds = true,
    this.enableNotifications = true,
    this.notificationBackend,
    this.consentRequired = true,
  });

  /// Default plan type (e.g. 'weekly') applied to default remote config if not overridden.
  final String defaultPlanType;
  
  /// Default plan product ID applied to default remote config if not overridden.
  final String defaultPlanProductId;
  
  /// Default trial days applied to default remote config if not overridden.
  final int defaultTrialDays;

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

  /// App-specific tool names and their free-tier usage limits.
  ///
  /// Example:
  /// ```dart
  /// toolLimits: {
  ///   'pdf_translate': 5,
  ///   'image_compress': 10,
  ///   'ocr_scan': 3,
  /// }
  /// ```
  ///
  /// These serve as the baseline defaults. Each tool's limit can be overridden
  /// remotely via the `limits.other_tools_limits` key in Remote Config.
  /// Tool names defined here are guaranteed to appear in the trial service;
  /// RC can add new tools not in this map.
  final Map<String, int> toolLimits;
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
  /// Note: If `config.consentRequired` is true, this will pause initialization
  /// to show the GDPR/ATT consent form (if applicable for the user).
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

    // 1. Consent Management
    if (config.consentRequired) {
      await _requestConsent(logger);
    }

    // 2. Unified User ID
    String udid = '';
    try {
      udid = await FlutterUdid.udid;
    } catch (e) {
      logger.warning('Failed to get UDID: $e');
    }

    // 3. Initialize Remote Config
    final rc = OfficeRemoteConfigService(logger: logger);
    
    // Inject top-level app-specific defaults if no custom RC object was provided
    OfficeRemoteConfig finalDefaults = config.remoteConfigDefaults ?? OfficeRemoteConfig.defaultProduction;
    if (config.remoteConfigDefaults == null) {
      try {
        final json = finalDefaults.toJson();
        // Overrides for Onboarding
        json['platform']['splash']['onboarding']['subscription']['selected_plan_type'] = config.defaultPlanType;
        json['platform']['splash']['onboarding']['subscription']['selected_plan_product_id'] = config.defaultPlanProductId;
        json['platform']['splash']['onboarding']['subscription']['trial']['duration_days'] = config.defaultTrialDays;
        
        // Overrides for Discount Popup
        json['platform']['result_screen']['discount_popup']['plan']['type'] = config.defaultPlanType;
        json['platform']['result_screen']['discount_popup']['plan']['product_id'] = config.defaultPlanProductId;
        json['platform']['result_screen']['discount_popup']['trial']['duration_days'] = config.defaultTrialDays;
        
        // Paywall
        json['platform']['paywall']['plans'] = [
          {
            'revenuecat_index': 0, 
            'product_id': config.defaultPlanProductId, 
            'plan_duration': config.defaultPlanType, 
            'has_trial': config.defaultTrialDays > 0
          }
        ];

        // Tool limits — inject code-defined tool names as baseline defaults
        // RC can override individual values, but tool names come from code
        // to avoid generic keys like "tool1", "tool2" in the RC JSON.
        final limitsJson = json['platform']['limits'] as Map<String, dynamic>;
        final existingRcMap = limitsJson['other_tools_limits'] as Map<String, dynamic>? ?? {};
        final merged = <String, int>{...config.toolLimits};
        for (final entry in existingRcMap.entries) {
          merged[entry.key] = (entry.value as num).toInt();
        }
        limitsJson['other_tools_limits'] = merged;

        finalDefaults = OfficeRemoteConfig.fromJson(json);
      } catch (e) {
        logger.warning('Failed to inject top-level RC defaults: $e');
      }
    }

    await rc.initialize(
      defaults: finalDefaults,
      fetchTimeout: config.remoteConfigFetchTimeout,
    );

    // Initialize Crashlytics
    final crashlytics = OfficeCrashlytics(logger: logger);
    if (config.enableCrashlytics) {
      if (udid.isNotEmpty) await crashlytics.setUserIdentifier(udid);
      await crashlytics.sendUnsentReports();
    }

    // Initialize Analytics
    final analytics = OfficeAnalyticsService(logger: logger);
    if (config.enableAnalytics && udid.isNotEmpty) {
      await analytics.setUserId(udid);
    }

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
      toolLimits: config.toolLimits,
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

  /// Private helper for UMP Consent flow
  static Future<void> _requestConsent(OfficeLogger logger) async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          ConsentForm.loadAndShowConsentFormIfRequired((loadAndShowError) {
            if (loadAndShowError != null) {
              logger.warning('Consent loadAndShow error: ${loadAndShowError.message}');
            }
            completer.complete();
          });
        } else {
          completer.complete();
        }
      },
      (FormError error) {
        logger.warning('Consent request info update error: ${error.message}');
        completer.complete();
      },
    );
    return completer.future;
  }
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
