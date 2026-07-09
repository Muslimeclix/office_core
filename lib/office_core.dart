/// OfficeCore — A federated Flutter plugin consolidating Remote Config,
/// Ads, Crashlytics, Analytics, Notifications, and Trial/Limits behind a
/// single initialize() entry point with a strongly-typed configuration model.
///
/// ## Quick Start
///
/// 1. Add `office_core` to your `pubspec.yaml`.
/// 2. Initialize Firebase in `main()`:
///
/// ```dart
/// import 'package:firebase_core/firebase_core.dart';
/// import 'package:flutter/material.dart';
/// import 'package:office_core/office_core.dart';
///
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
///
/// 3. Access subsystems anywhere via `OfficeCore.instance`:
///
/// ```dart
/// final bannerUnitId = OfficeCore.rc.current.platform.ads.units.banner;
/// final canDownload = OfficeCore.trial.canDownload;
/// OfficeCore.analytics.logEvent('my_event');
/// ```
library;

// Core singleton + config
export 'src/office_core.dart';

// Remote Config
export 'src/remote_config/office_remote_config_service.dart';
export 'src/remote_config/models/office_remote_config.dart';

// Ads
export 'src/ads/office_ads_controller.dart';
export 'src/ads/banner_ad_widget.dart';
export 'src/ads/native_ad_widget.dart';

// Crashlytics
export 'src/crashlytics/office_crashlytics.dart';

// Analytics
export 'src/analytics/office_analytics_service.dart';

// Notifications
export 'src/notifications/office_notification_controller.dart';

// Trial & Limits
export 'src/trial/office_trial_service.dart';

// Premium
export 'src/premium/premium_status_provider.dart';

// Utilities
export 'src/util/logger.dart';
export 'src/util/lifecycle_service.dart';
export 'src/util/connectivity_service.dart';
export 'src/util/prefs.dart';
