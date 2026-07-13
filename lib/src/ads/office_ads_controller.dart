import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../premium/premium_status_provider.dart';
import '../remote_config/models/office_remote_config.dart';
import '../remote_config/office_remote_config_service.dart';
import '../util/connectivity_service.dart';
import '../util/lifecycle_service.dart';
import '../util/logger.dart';

/// Controller that manages ad visibility flags and the lifecycle of
/// app-open and interstitial ads.
///
/// Retains the same reactive visibility flags as the legacy AdsController
/// ([shouldShowBanner], [shouldShowNative], [shouldShowInterstitial],
/// [shouldShowOpenApp]) but with four key differences:
///
/// 1. Drops `Get.find<PremiumController>()` — receives a
///    [PremiumStatusProvider] via constructor injection instead.
/// 2. Reads every value from [OfficeRemoteConfigService] instead of
///    flat-keyed getters.
/// 3. Listens to `rc.changes` and `premium.isProStream` and recomputes
///    visibility flags on either change.
/// 4. Ad unit IDs come from Remote Config (`ads.units.{...}`) rather than
///    compile-time `AdsHelper` constants — enabling remote rotation.
///
/// Visibility flags are exposed as plain `bool` getters. Consumers can also
/// call [addListener] (inherited from [ChangeNotifier]) to rebuild UI when
/// flags change.
class OfficeAdsController extends ChangeNotifier {
  OfficeAdsController({
    required OfficeRemoteConfigService rc,
    required PremiumStatusProvider premium,
    OfficeConnectivityService? connectivity,
    OfficeLifecycleService? lifecycle,
    OfficeLogger? logger,
  })  : _rc = rc,
        _premium = premium,
        _connectivity = connectivity ?? OfficeConnectivityService.instance,
        _lifecycle = lifecycle ?? OfficeLifecycleService.instance,
        _logger = logger ?? OfficeLogger.forTag('Ads');

  final OfficeRemoteConfigService _rc;
  final PremiumStatusProvider _premium;
  final OfficeConnectivityService _connectivity;
  final OfficeLifecycleService _lifecycle;
  final OfficeLogger _logger;

  // Visibility flags
  bool _shouldShowBanner = false;
  bool _shouldShowNative = false;
  bool _shouldShowInterstitial = false;
  bool _shouldShowOpenApp = false;

  /// Whether banner ads should be shown (RC + premium-aware).
  bool get shouldShowBanner => _shouldShowBanner;

  /// Whether native ads should be shown (RC + premium-aware).
  bool get shouldShowNative => _shouldShowNative;

  /// Whether interstitial ads should be shown (RC + premium-aware).
  bool get shouldShowInterstitial => _shouldShowInterstitial;

  /// Whether app-open ads should be shown (RC + premium-aware).
  bool get shouldShowOpenApp => _shouldShowOpenApp;

  // App open ad state
  AppOpenAd? _appOpenAd;
  bool _isAppOpenLoading = false;
  bool _isShowingAppOpen = false;

  // Interstitial ad state
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  bool _isInterstitialLoading = false;

  StreamSubscription? _rcSub;
  StreamSubscription? _premiumSub;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _lifecycleSub;

  /// Initialize the controller. Safe to call once after
  /// [OfficeCore.initialize].
  void initialize() {
    _recompute();

    _premiumSub = _premium.isProStream.listen((_) => _recompute());
    _rcSub = _rc.changes.listen((_) => _recompute());
    _connectivitySub = _connectivity.onReconnect.listen((_) => _rc.refresh());
    _lifecycleSub = _lifecycle.onResumeAfterPause.listen((_) => _onAppResumed());

    if (_shouldShowOpenApp) _loadAppOpenAd();
    if (_shouldShowInterstitial) _loadInterstitialAd();
  }

  void _recompute() {
    final isPro = _premium.isPro;
    final ads = _rc.current.platform.ads;
    final showAds = ads.enabled && !isPro;

    final newBanner = showAds && ads.visibility.banner;
    final newNative = showAds && ads.visibility.native;
    final newInterstitial = showAds && ads.visibility.interstitial;
    final newAppOpen = showAds && ads.visibility.appOpen;

    if (newBanner != _shouldShowBanner ||
        newNative != _shouldShowNative ||
        newInterstitial != _shouldShowInterstitial ||
        newAppOpen != _shouldShowOpenApp) {
      _shouldShowBanner = newBanner;
      _shouldShowNative = newNative;
      _shouldShowInterstitial = newInterstitial;
      _shouldShowOpenApp = newAppOpen;
      notifyListeners();
      _logger.debug('Visibility recomputed: banner=$newBanner, '
          'native=$newNative, interstitial=$newInterstitial, appOpen=$newAppOpen');
    }

    // Dispose ads that are no longer needed
    if (!_shouldShowOpenApp) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
    }
    if (!_shouldShowInterstitial) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialReady = false;
    }

    // Preload ads that became needed
    if (_shouldShowOpenApp && _appOpenAd == null && !_isAppOpenLoading) {
      _loadAppOpenAd();
    }
    if (_shouldShowInterstitial &&
        _interstitialAd == null &&
        !_isInterstitialLoading) {
      _loadInterstitialAd();
    }
  }

  // ── App Open Ad ──────────────────────────────────────────────────────────

  void _loadAppOpenAd() {
    if (!_shouldShowOpenApp || _isAppOpenLoading || _appOpenAd != null) return;

    final unitId = _rc.current.platform.ads.units.appOpen;
    if (unitId.isEmpty) {
      _logger.warning('App open ad unit ID is empty');
      return;
    }

    _isAppOpenLoading = true;
    AppOpenAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenLoading = false;
          _setAppOpenCallbacks(ad);
          _logger.debug('App open ad loaded');
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          _isAppOpenLoading = false;
          _logger.warning('App open ad failed to load: $error');
        },
      ),
    );
  }

  void _showAppOpenAd() {
    if (_isShowingAppOpen) return;
    if (_appOpenAd == null) {
      _loadAppOpenAd();
      return;
    }
    _isShowingAppOpen = true;
    _appOpenAd!.show();
  }

  void _setAppOpenCallbacks(AppOpenAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAppOpen = false;
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAppOpen = false;
        ad.dispose();
        _appOpenAd = null;
        _logger.warning('App open ad failed to show: $error');
      },
    );
  }

  void _onAppResumed() {
    if (_shouldShowOpenApp) {
      _showAppOpenAd();
    }
  }

  // ── Interstitial Ad ──────────────────────────────────────────────────────

  void _loadInterstitialAd() {
    if (!_shouldShowInterstitial || _isInterstitialLoading) return;
    if (_interstitialAd != null) return;

    final unitId = _rc.current.platform.ads.units.interstitial;
    if (unitId.isEmpty) {
      _logger.warning('Interstitial ad unit ID is empty');
      return;
    }

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          _isInterstitialLoading = false;
          _logger.debug('Interstitial ad loaded');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialReady = false;
          _isInterstitialLoading = false;
          _logger.warning('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  /// Show the interstitial ad if ready. Calls [onAdClosed] after the ad is
  /// dismissed (or immediately if no ad is ready).
  Future<void> showInterstitialAd({VoidCallback? onAdClosed}) async {
    if (_isInterstitialReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isInterstitialReady = false;
          _interstitialAd = null;
          _loadInterstitialAd();
          onAdClosed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isInterstitialReady = false;
          _interstitialAd = null;
          _loadInterstitialAd();
          _logger.warning('Interstitial failed to show: $error');
          onAdClosed?.call();
        },
      );
      await _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      // No ad ready — preload and continue
      _loadInterstitialAd();
      onAdClosed?.call();
    }
  }

  // ── Unit ID accessors (for widgets) ──────────────────────────────────────

  /// Banner ad unit ID (from RC `ads.units.banner`). Falls back to test ID if empty.
  String get bannerUnitId {
    final id = _rc.current.platform.ads.units.banner;
    return id.isNotEmpty ? id : AdsUnits.test.banner;
  }

  /// Native ad unit ID (from RC `ads.units.native`). Falls back to test ID if empty.
  String get nativeUnitId {
    final id = _rc.current.platform.ads.units.native;
    return id.isNotEmpty ? id : AdsUnits.test.native;
  }

  /// Interstitial ad unit ID (from RC `ads.units.interstitial`). Falls back to test ID if empty.
  String get interstitialUnitId {
    final id = _rc.current.platform.ads.units.interstitial;
    return id.isNotEmpty ? id : AdsUnits.test.interstitial;
  }

  /// App-open ad unit ID (from RC `ads.units.app_open`). Falls back to test ID if empty.
  String get appOpenUnitId {
    final id = _rc.current.platform.ads.units.appOpen;
    return id.isNotEmpty ? id : AdsUnits.test.appOpen;
  }

  /// Rewarded ad unit ID (from RC `ads.units.rewarded`). Falls back to test ID if empty.
  String get rewardedUnitId {
    final id = _rc.current.platform.ads.units.rewarded;
    return id.isNotEmpty ? id : AdsUnits.test.rewarded;
  }

  @override
  void dispose() {
    _rcSub?.cancel();
    _premiumSub?.cancel();
    _connectivitySub?.cancel();
    _lifecycleSub?.cancel();
    _appOpenAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
