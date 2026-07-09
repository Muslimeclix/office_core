import 'dart:async';

import 'package:flutter/widgets.dart';

/// Single [WidgetsBindingObserver] that exposes a stream of app-resume
/// events.
///
/// Replaces the duplicated `LifecycleEventHandler` classes that currently
/// exist in both `AdsController` and `NotificationController` in office
/// apps. Both subsystems subscribe to [onResumeAfterPause] instead of
/// registering their own observers.
///
/// Ignores brief resumes (under [minPauseDuration], default 1 minute) which
/// are caused by dialogs, permission prompts, image pickers, etc. Only fires
/// for real fg/bg transitions.
class OfficeLifecycleService {
  OfficeLifecycleService._() {
    WidgetsBinding.instance.addObserver(_handler);
  }

  /// Singleton instance.
  static final OfficeLifecycleService instance = OfficeLifecycleService._();

  /// Resumes shorter than this duration are ignored (dialogs, pickers, etc.).
  Duration minPauseDuration = const Duration(minutes: 1);

  final StreamController<void> _resumeController =
      StreamController<void>.broadcast();

  /// Fires when the app returns to the foreground after being paused for at
  /// least [minPauseDuration].
  Stream<void> get onResumeAfterPause => _resumeController.stream;

  late final _Handler _handler = _Handler(this);

  void _onResumed() {
    _resumeController.add(null);
  }

  /// Release resources.
  void dispose() {
    WidgetsBinding.instance.removeObserver(_handler);
    _resumeController.close();
  }
}

class _Handler extends WidgetsBindingObserver {
  _Handler(this._service);

  final OfficeLifecycleService _service;
  DateTime? _lastPausedTime;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lastPausedTime = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastPausedTime != null) {
        final diff = now.difference(_lastPausedTime!);
        if (diff >= _service.minPauseDuration) {
          _service._onResumed();
        }
      }
    }
  }
}
