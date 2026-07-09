import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

import '../util/logger.dart';

/// Analytics service wrapping [FirebaseAnalytics] with a drop-in
/// [RouteObserver] for automatic screen-view tracking.
///
/// On Windows (where Firebase Analytics is not available), this class
/// degrades to a no-op — calls succeed silently without recording anything.
///
/// Usage:
/// ```dart
/// // In MaterialApp:
/// MaterialApp(
///   navigatorObservers: [OfficeCore.analytics.routeObserver],
/// );
///
/// // Anywhere:
/// OfficeCore.analytics.logEvent('conversion_started', {'tool': 'pdf_translate'});
/// OfficeCore.analytics.logScreenView('HomeScreen', normalize: true);
/// ```
class OfficeAnalyticsService {
  OfficeAnalyticsService({OfficeLogger? logger})
      : _logger = logger ?? OfficeLogger.forTag('Analytics');

  final OfficeLogger _logger;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Drop-in [NavigatorObserver] for [MaterialApp.navigatorObservers].
  ///
  /// Automatically logs a screen view when a new route is pushed, replaced,
  /// or popped to. Screen name is derived from `route.settings.name`, with
  /// a fallback to `route.settings.arguments.toString()` or the route's
  /// runtime type.
  late final NavigatorObserver routeObserver = _RouteObserver(this);

  /// Log a custom event with optional parameters.
  ///
  /// [eventName] is lowercased automatically (Firebase Analytics requires
  /// lowercase event names).
  Future<void> logEvent(
    String eventName, [
    Map<String, Object>? parameters,
  ]) async {
    try {
      await _analytics.logEvent(
        name: eventName.toLowerCase(),
        parameters: parameters ?? const <String, Object>{},
      );
      _logger.debug('Analytics event: $eventName | Params: $parameters');
    } catch (e) {
      _logger.warning('Analytics logEvent failed: $e');
    }
  }

  /// Log a screen view.
  ///
  /// [normalize] (default true) lowercases the screen name and strips
  /// leading/trailing slashes for consistency with Firebase Analytics
  /// conventions. Pass `normalize: false` to preserve the original case.
  Future<void> logScreenView(String screenName, {bool normalize = true}) async {
    try {
      String name = screenName;
      if (normalize) {
        name = name.replaceAll('/', '').toLowerCase();
      }
      await _analytics.logScreenView(screenName: name);
      _logger.debug('Analytics screen view: $name');
    } catch (e) {
      _logger.warning('Analytics logScreenView failed: $e');
    }
  }

  /// Set a user property that will be attached to all subsequent events.
  Future<void> setUserProperty({required String name, String? value}) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      _logger.warning('Analytics setUserProperty failed: $e');
    }
  }

  /// Set the user ID for analytics.
  Future<void> setUserId(String? id) async {
    try {
      await _analytics.setUserId(id: id);
    } catch (e) {
      _logger.warning('Analytics setUserId failed: $e');
    }
  }

  /// Reset analytics data for the current user (e.g., on logout).
  Future<void> resetAnalyticsData() async {
    try {
      await _analytics.resetAnalyticsData();
    } catch (e) {
      _logger.warning('Analytics resetAnalyticsData failed: $e');
    }
  }
}

class _RouteObserver extends RouteObserver<PageRoute<dynamic>> {
  _RouteObserver(this._service);

  final OfficeAnalyticsService _service;

  void _sendScreenView(PageRoute<dynamic> route) {
    String? screenName = route.settings.name;
    screenName ??=
        route.settings.arguments?.toString() ?? route.runtimeType.toString();
    if (screenName.isNotEmpty) {
      _service.logScreenView(screenName);
    }
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PageRoute) _sendScreenView(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute is PageRoute) _sendScreenView(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute is PageRoute) _sendScreenView(previousRoute);
    super.didPop(route, previousRoute);
  }
}
