import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../util/lifecycle_service.dart';
import '../util/logger.dart';

/// Backend configuration for [OfficeNotificationController].
///
/// Extracts the three values that were hardcoded in the legacy
/// NotificationController:
/// - [openedApiUrl] — endpoint to call when a user opens a notification.
/// - [deviceRegistryPath] — Firebase RTDB path under which device tokens
///   are registered.
/// - [topics] — FCM topics to subscribe to.
class NotificationBackendConfig {
  const NotificationBackendConfig({
    required this.openedApiUrl,
    required this.deviceRegistryPath,
    this.topics = const ['all_users'],
  });

  /// Endpoint called when a user taps a notification. The controller POSTs
  /// a form with `notification_uid`, `package_name`, `user_token`,
  /// `status`, and `notification_reached_at`.
  final String openedApiUrl;

  /// Firebase Realtime Database path under which device tokens are
  /// registered. The controller writes to `<deviceRegistryPath>/<token>`.
  final String deviceRegistryPath;

  /// FCM topics to subscribe to on init.
  final List<String> topics;
}

/// Top-level background message handler. Must be a top-level function (not
/// a class method or closure) so it can be registered as a background
/// isolate handler.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled by the OS via flutter_local_notifications.
  // No-op here — actual display happens via the foreground handler.
}

/// Controller wrapping FCM + [FlutterLocalNotificationsPlugin].
///
/// Retains all functionality from the legacy NotificationController:
/// - FCM token management with APNS-wait on iOS.
/// - Foreground message handling via flutter_local_notifications.
/// - Background message handler registration.
/// - Topic subscription.
/// - Notification tap navigation (via [onNotificationTapped] stream).
/// - Device registration in Firebase RTDB.
/// - Notification-open API call.
/// - Translation-progress notification helper.
///
/// Three values that were hardcoded in the legacy controller are now
/// extracted into [NotificationBackendConfig] (required init param):
/// - `openedApiUrl` (was literal 'https://aso.eclixtech.com/...').
/// - `deviceRegistryPath` (was literal 'devices').
/// - `topics` (was literal 'all_users').
class OfficeNotificationController extends ChangeNotifier {
  OfficeNotificationController({
    required NotificationBackendConfig backend,
    OfficeLifecycleService? lifecycle,
    OfficeLogger? logger,
  })  : _backend = backend,
        _lifecycle = lifecycle ?? OfficeLifecycleService.instance,
        _logger = logger ?? OfficeLogger.forTag('Notifications');

  final NotificationBackendConfig _backend;
  final OfficeLifecycleService _lifecycle;
  final OfficeLogger _logger;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _fcmTokenController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationTappedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Emits the FCM token on every refresh.
  Stream<String> get onFcmTokenChanged => _fcmTokenController.stream;

  /// Emits the notification payload data when the user taps a notification.
  /// Consumers use this to navigate to the appropriate screen.
  Stream<Map<String, dynamic>> get onNotificationTapped =>
      _notificationTappedController.stream;

  String _fcmToken = '';

  /// The current FCM token (empty if not yet fetched).
  String get fcmToken => _fcmToken;

  bool _isInitialized = false;

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _isInitialized;

  String? _lastHandledNotificationId;
  StreamSubscription? _lifecycleSub;

  /// Initialize the controller. Call after [OfficeCore.initialize].
  ///
  /// If [silent] is true, permission is NOT requested (caller handles it
  /// separately via [requestPermission]).
  Future<void> initialize({bool silent = true}) async {
    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
    await _registerDevice();
    _setupLifecycleListener();

    if (!silent) {
      await requestPermission();
    }

    _isInitialized = true;
    _logger.info('NotificationController initialized');
  }

  /// Request notification permission. On iOS/macOS, requests alert, badge,
  /// and sound. On Android 13+, requests the runtime notification permission.
  Future<void> requestPermission() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        _logger.info('iOS/macOS permission: ${settings.authorizationStatus}');
        return;
      }

      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (status.isGranted) return;
        final result = await Permission.notification.request();
        _logger.info('Android permission: $result');
      }
    } catch (e) {
      _logger.warning('Permission request failed: $e');
    }
  }

  // ── Local Notifications Init ──────────────────────────────────────────────

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const macosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'general_channel',
        'High Importance Notifications',
        description: 'Used for important alerts',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // ── Firebase Messaging Init ───────────────────────────────────────────────

  Future<void> _initializeFirebaseMessaging() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      _logger.warning('setForegroundNotificationPresentationOptions failed: $e');
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    _messaging.getInitialMessage().then((message) {
      if (message != null) _handleMessageOpenedApp(message);
    });

    await _updateFCMToken();
    await _subscribeToTopics();

    _messaging.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      _fcmTokenController.add(token);
      await _registerDevice();
      _logger.info('FCM token refreshed & synced');
    });
  }

  Future<void> _subscribeToTopics() async {
    try {
      if (Platform.isIOS) {
        final apnsToken = await _waitForAPNSToken();
        if (apnsToken == null) {
          _logger.warning('APNs token not available, skipping topic subscription');
          return;
        }
      }
      
      final packageInfo = await PackageInfo.fromPlatform();
      final pkg = packageInfo.packageName.replaceAll('.', '_');
      
      final topicsToSubscribe = <String>{
        ..._backend.topics,
        'all_users_$pkg',
        'weekly_$pkg',
      };
      
      for (final topic in topicsToSubscribe) {
        await _messaging.subscribeToTopic(topic);
        _logger.info('Subscribed to topic: $topic');
      }
    } catch (e) {
      _logger.warning('Topic subscription failed: $e');
    }
  }

  Future<String?> _waitForAPNSToken({Duration maxWait = const Duration(seconds: 10)}) async {
    final endTime = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(endTime)) {
      try {
        final token = await _messaging.getAPNSToken();
        if (token != null) return token;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  Future<void> _updateFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _fcmToken = token;
        _fcmTokenController.add(token);
        _logger.info('FCM token: $token');
      }
    } catch (e) {
      _logger.warning('getToken failed: $e');
    }
  }

  // ── Message Handlers ──────────────────────────────────────────────────────

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.info('Foreground FCM: ${message.messageId}');
    await _showLocalNotification(message);
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    _logger.info('Notification tapped: ${message.messageId}');
    await _registerDevice();
    await _callNotificationOpenAPI(message.data);
    _notificationTappedController.add(message.data);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'general_channel',
      'High Importance Notifications',
      channelDescription: 'Used for important alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  // ── Notification Tap ──────────────────────────────────────────────────────

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _registerDevice();
        _callNotificationOpenAPI(data);
        _notificationTappedController.add(data);
      } catch (e) {
        _logger.warning('Failed to parse notification payload: $e');
      }
    }
  }

  // ── Device Registration ───────────────────────────────────────────────────

  Future<void> _registerDevice() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        _logger.warning('FCM token null, skipping registration');
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final udid = await FlutterUdid.udid;

      final data = {
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'language': 'en',
        'user_id': udid,
        'last_active': DateTime.now().toUtc().toIso8601String(),
      };

      final db = FirebaseDatabase.instance.ref();
      await db.child('${_backend.deviceRegistryPath}/$token').set(data);
      _logger.info('Device registered');
    } catch (e) {
      _logger.warning('Device registration failed: $e');
    }
  }

  void _setupLifecycleListener() {
    _lifecycleSub = _lifecycle.onResumeAfterPause.listen((_) => _registerDevice());
  }

  // ── Notification Open API ─────────────────────────────────────────────────

  Future<void> _callNotificationOpenAPI(Map<String, dynamic> data) async {
    final notificationUid = data['notification_uid'];
    if (notificationUid == null) return;

    if (_lastHandledNotificationId == notificationUid) {
      _logger.debug('Duplicate open ignored: $notificationUid');
      return;
    }
    _lastHandledNotificationId = notificationUid;

    try {
      final reachedAt = int.tryParse(
          data['notification_reached_at']?.toString() ?? '');
      if (reachedAt == null) {
        _logger.warning('Invalid notification payload: missing reached_at');
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final dio = Dio();

      final formData = FormData.fromMap({
        'notification_uid': notificationUid,
        'package_name': packageInfo.packageName,
        'user_token': _fcmToken,
        'status': 'opened',
        'notification_reached_at': reachedAt,
      });

      final response = await dio.post(_backend.openedApiUrl, data: formData);
      _logger.info('Open API success: ${response.statusCode}');
    } catch (e) {
      _logger.warning('Open API failed: $e');
    }
  }

  // ── Progress Notification Helper ──────────────────────────────────────────

  /// Show a progress notification (e.g., for translation/conversion tasks).
  ///
  /// Uses a fixed notification ID (888) so subsequent calls update the
  /// existing notification rather than creating new ones.
  Future<void> showProgressNotification({
    required int current,
    required int total,
    String title = 'Processing',
    String bodyTemplate = 'Processing item {current} of {total}',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'progress_channel',
      'Progress',
      channelDescription: 'Shows progress of long-running tasks',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: total,
      progress: current,
      ongoing: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: 888,
      title: title,
      body: bodyTemplate
          .replaceAll('{current}', current.toString())
          .replaceAll('{total}', total.toString()),
      notificationDetails: details,
    );
  }

  /// Cancel the progress notification shown by [showProgressNotification].
  Future<void> cancelProgressNotification() async {
    await _localNotifications.cancel(id: 888);
  }

  @override
  void dispose() {
    _lifecycleSub?.cancel();
    _fcmTokenController.close();
    _notificationTappedController.close();
    super.dispose();
  }
}
