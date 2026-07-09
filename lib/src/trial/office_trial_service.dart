import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../premium/premium_status_provider.dart';
import '../remote_config/office_remote_config_service.dart';

/// Net-new subsystem that consolidates limits, feature locks, and trial-day
/// tracking into a single API.
///
/// Reads from [OfficeRemoteConfigService] (limits.globalConversion,
/// limits.otherToolsLimits, limits.fileSize, limits.batch, global.lock{Download,
/// Share,Copy}) and combines them with [PremiumStatusProvider] to determine
/// whether features are unlocked for the current user.
///
/// Usage tracking is persisted locally via [SharedPreferences]. Trial day
/// tracking is also local-only in v1 — bypassable by reinstall. v2 will
/// move trial validation server-side, keyed on a device fingerprint.
class OfficeTrialService extends ChangeNotifier {
  /// Creates a trial service. Usually called by [OfficeCore.initialize],
  /// not directly by consumers.
  OfficeTrialService({
    required OfficeRemoteConfigService rc,
    required PremiumStatusProvider premium,
    required SharedPreferences prefs,
  })  : _rc = rc,
        _premium = premium,
        _prefs = prefs;

  final OfficeRemoteConfigService _rc;
  final PremiumStatusProvider _premium;
  final SharedPreferences _prefs;

  static const _kInstallDateKey = 'office_core_install_date';
  static const _kUsagePrefix = 'office_core_usage_';

  // ── Limits ────────────────────────────────────────────────────────────────

  /// Global conversion limit (per RC `limits.global_conversion`).
  int get globalConversionLimit =>
      _rc.current.platform.limits.globalConversion;

  /// Per-tool free limit (per RC `limits.other_tools_limits[toolId]`).
  /// Returns 0 if the tool is not configured.
  int toolLimit(String toolId) =>
      _rc.current.platform.limits.otherToolsLimits[toolId] ?? 0;

  /// File size limit in MB. Returns the premium value if the user is premium,
  /// otherwise the free value.
  double get fileSizeLimit => _premium.isPro
      ? _rc.current.platform.limits.fileSize.premium
      : _rc.current.platform.limits.fileSize.free;

  /// Batch processing limit. Returns the premium value if the user is premium.
  int get batchLimit => _premium.isPro
      ? _rc.current.platform.limits.batch.limits.premium
      : _rc.current.platform.limits.batch.limits.free;

  /// Whether batch processing is locked for the current user.
  /// True only if `limits.batch.is_locked` is true AND the user is not premium.
  bool get isBatchLocked =>
      _rc.current.platform.limits.batch.isLocked && !_premium.isPro;

  // ── Feature Locks ─────────────────────────────────────────────────────────

  /// Whether the user can download. Unlocked if `global.lock_download` is
  /// false OR the user is premium.
  bool get canDownload =>
      !_rc.current.platform.global.lockDownload || _premium.isPro;

  /// Whether the user can share. Unlocked if `global.lock_share` is false
  /// OR the user is premium.
  bool get canShare =>
      !_rc.current.platform.global.lockShare || _premium.isPro;

  /// Whether the user can copy. Unlocked if `global.lock_copy` is false
  /// OR the user is premium.
  bool get canCopy =>
      !_rc.current.platform.global.lockCopy || _premium.isPro;

  // ── Trial Day Tracking ────────────────────────────────────────────────────

  /// The trial duration in days, per RC `splash.onboarding.subscription.trial.duration_days`.
  int get trialDurationDays =>
      _rc.current.platform.splash.onboarding.subscription.trial.durationDays;

  /// Whether trial is enabled per RC.
  bool get isTrialEnabled =>
      _rc.current.platform.splash.onboarding.subscription.trial.enabled;

  /// The install date (when the app was first launched). Stored in prefs.
  DateTime get installDate {
    final epoch = _prefs.getInt(_kInstallDateKey);
    if (epoch == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _prefs.setInt(_kInstallDateKey, now);
      return DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }

  /// Number of days remaining in the trial. Returns 0 if the trial has
  /// expired or is not enabled.
  int get trialDaysRemaining {
    if (!isTrialEnabled) return 0;
    if (_premium.isPro) return 0;
    final elapsed = DateTime.now().difference(installDate).inDays;
    final remaining = trialDurationDays - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Whether the trial is currently active (enabled in RC, not expired, user
  /// is not premium).
  bool get isTrialActive =>
      isTrialEnabled && !_premium.isPro && trialDaysRemaining > 0;

  // ── Usage Tracking ────────────────────────────────────────────────────────

  /// Get the current usage count for [toolId]. Persisted in prefs.
  int getUsage(String toolId) {
    return _prefs.getInt('$_kUsagePrefix$toolId') ?? 0;
  }

  /// Increment the usage count for [toolId] by 1. Persists immediately.
  Future<void> incrementUsage(String toolId) async {
    final current = getUsage(toolId);
    await _prefs.setInt('$_kUsagePrefix$toolId', current + 1);
    notifyListeners();
  }

  /// Reset the usage count for [toolId] to 0.
  Future<void> resetUsage(String toolId) async {
    await _prefs.remove('$_kUsagePrefix$toolId');
    notifyListeners();
  }

  /// Whether the user has remaining quota for [toolId]. Premium users always
  /// have quota (returns true). Free users are limited by
  /// [toolLimit].
  bool hasRemainingQuota(String toolId) {
    if (_premium.isPro) return true;
    return getUsage(toolId) < toolLimit(toolId);
  }

  /// Whether the user has remaining global conversion quota. Premium users
  /// always have quota.
  bool hasRemainingGlobalConversion() {
    if (_premium.isPro) return true;
    final totalUsage = _rc.current.platform.limits.otherToolsLimits.keys
        .fold(0, (sum, toolId) => sum + getUsage(toolId));
    return totalUsage < globalConversionLimit;
  }
}
