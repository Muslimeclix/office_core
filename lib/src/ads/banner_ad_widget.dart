import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';

import '../office_core.dart';

/// Banner ad widget that respects Remote Config visibility flags and the
/// user's premium status.
///
/// If the user is premium, or if `ads.visibility.banner` is false in RC,
/// this widget renders [SizedBox.shrink] without attempting an ad load —
/// producing zero ad requests, not just hidden UI.
///
/// The ad unit ID is fetched from [OfficeAdsController.bannerUnitId] at
/// load time (which reads from Remote Config), enabling remote rotation.
///
/// Usage:
/// ```dart
/// OfficeBannerAd(adSize: AdSize.banner),
/// ```
///
/// Named constructors for common ad sizes:
/// - [OfficeBannerAd.standard] — `AdSize.banner` (320×50)
/// - [OfficeBannerAd.largeBanner] — `AdSize.largeBanner` (320×100)
/// - [OfficeBannerAd.mediumRectangle] — `AdSize.mediumRectangle` (300×250)
/// - [OfficeBannerAd.leaderboard] — `AdSize.leaderboard` (728×90)
class OfficeBannerAd extends StatefulWidget {
  /// Creates a banner ad widget with the given [adSize].
  const OfficeBannerAd({
    super.key,
    this.adSize = AdSize.banner,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.showBorder = true,
    this.borderColor,
    this.showShadow = false,
    this.showOnlyWhenLoaded = true,
    this.onAdLoaded,
    this.onAdFailedToLoad,
    this.onAdClicked,
  });

  /// Creates a banner ad widget with `AdSize.banner` (320×50).
  const OfficeBannerAd.standard({
    Key? key,
    EdgeInsets? margin,
    Color? backgroundColor,
    double? borderRadius,
    bool showBorder = false,
    bool showShadow = true,
    VoidCallback? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
    VoidCallback? onAdClicked,
  }) : this(
          key: key,
          adSize: AdSize.banner,
          margin: margin,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
          showBorder: showBorder,
          showShadow: showShadow,
          onAdLoaded: onAdLoaded,
          onAdFailedToLoad: onAdFailedToLoad,
          onAdClicked: onAdClicked,
        );

  /// Creates a banner ad widget with `AdSize.largeBanner` (320×100).
  const OfficeBannerAd.largeBanner({
    Key? key,
    EdgeInsets? margin,
    Color? backgroundColor,
    double? borderRadius,
    bool showBorder = false,
    bool showShadow = true,
    VoidCallback? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
    VoidCallback? onAdClicked,
  }) : this(
          key: key,
          adSize: AdSize.largeBanner,
          margin: margin,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
          showBorder: showBorder,
          showShadow: showShadow,
          onAdLoaded: onAdLoaded,
          onAdFailedToLoad: onAdFailedToLoad,
          onAdClicked: onAdClicked,
        );

  /// Creates a banner ad widget with `AdSize.mediumRectangle` (300×250).
  const OfficeBannerAd.mediumRectangle({
    Key? key,
    EdgeInsets? margin,
    Color? backgroundColor,
    double? borderRadius,
    bool showBorder = false,
    bool showShadow = true,
    VoidCallback? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
    VoidCallback? onAdClicked,
  }) : this(
          key: key,
          adSize: AdSize.mediumRectangle,
          margin: margin,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
          showBorder: showBorder,
          showShadow: showShadow,
          onAdLoaded: onAdLoaded,
          onAdFailedToLoad: onAdFailedToLoad,
          onAdClicked: onAdClicked,
        );

  /// Creates a banner ad widget with `AdSize.leaderboard` (728×90).
  const OfficeBannerAd.leaderboard({
    Key? key,
    EdgeInsets? margin,
    Color? backgroundColor,
    double? borderRadius,
    bool showBorder = false,
    bool showShadow = true,
    VoidCallback? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
    VoidCallback? onAdClicked,
  }) : this(
          key: key,
          adSize: AdSize.leaderboard,
          margin: margin,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
          showBorder: showBorder,
          showShadow: showShadow,
          onAdLoaded: onAdLoaded,
          onAdFailedToLoad: onAdFailedToLoad,
          onAdClicked: onAdClicked,
        );

  /// The ad size to request.
  final AdSize adSize;

  /// Margin around the ad widget.
  final EdgeInsets? margin;

  /// Padding inside the ad widget.
  final EdgeInsets? padding;

  /// Background color of the ad container.
  final Color? backgroundColor;

  /// Border radius of the ad container.
  final double? borderRadius;

  /// Whether to show a border around the ad.
  final bool showBorder;

  /// Color of the border (if [showBorder] is true).
  final Color? borderColor;

  /// Whether to show a shadow under the ad.
  final bool showShadow;

  /// If true, render a shimmer placeholder until the ad loads.
  /// If false, render a loading spinner or error widget.
  final bool showOnlyWhenLoaded;

  /// Called when the ad loads successfully.
  final VoidCallback? onAdLoaded;

  /// Called when the ad fails to load.
  final Function(LoadAdError)? onAdFailedToLoad;

  /// Called when the user clicks the ad.
  final VoidCallback? onAdClicked;

  @override
  State<OfficeBannerAd> createState() => _OfficeBannerAdState();
}

class _OfficeBannerAdState extends State<OfficeBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  String? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isAdLoading && !_isAdLoaded && _bannerAd == null) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    if (!OfficeCore.isInitialized) return;

    // Don't load if user is premium or banner is disabled in RC
    if (OfficeCore.premium.isPro || !OfficeCore.ads.shouldShowBanner) {
      return;
    }

    if (_isAdLoading) return;

    setState(() {
      _isAdLoading = true;
      _loadError = null;
    });

    final unitId = OfficeCore.ads.bannerUnitId;
    if (unitId.isEmpty) return;

    _bannerAd = BannerAd(
      size: widget.adSize,
      adUnitId: unitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _isAdLoading = false;
              _loadError = null;
            });
            widget.onAdLoaded?.call();
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _isAdLoading = false;
              _loadError = error.message;
            });
            widget.onAdFailedToLoad?.call(error);
          }
        },
        onAdClicked: (ad) => widget.onAdClicked?.call(),
      ),
      request: const AdRequest(),
    );

    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!OfficeCore.isInitialized) return const SizedBox.shrink();

    // Don't show anything if user is premium or banner is disabled
    if (OfficeCore.premium.isPro || !OfficeCore.ads.shouldShowBanner) {
      return const SizedBox.shrink();
    }

    if (_isAdLoading && !_isAdLoaded) {
      return widget.showOnlyWhenLoaded ? _buildShimmer() : _buildLoading();
    }

    if (_loadError != null && !_isAdLoaded) {
      return widget.showOnlyWhenLoaded ? _buildShimmer() : _buildError();
    }

    if (_isAdLoaded && _bannerAd != null) {
      return _buildAd();
    }

    return const SizedBox.shrink();
  }

  Widget _buildAd() {
    return Container(
      margin: widget.margin ?? const EdgeInsets.only(top: 3),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 8.0),
        border: widget.showBorder
            ? Border.all(
                color: widget.borderColor ??
                    Colors.grey.withValues(alpha: 0.3),
                width: 1.0,
              )
            : null,
        boxShadow: widget.showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _bannerAd?.size.width.toDouble(),
        height: _bannerAd?.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }

  Widget _buildLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: widget.adSize.width.toDouble(),
      height: widget.adSize.height.toDouble(),
      margin: widget.margin ?? const EdgeInsets.only(top: 3),
      decoration: BoxDecoration(
        color: widget.backgroundColor ??
            (isDark ? Colors.grey[800] : Colors.grey[200]),
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 8.0),
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Loading ad...',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: widget.adSize.width.toDouble(),
      height: widget.adSize.height.toDouble(),
      margin: widget.margin ?? const EdgeInsets.only(top: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 8.0),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 18),
            const SizedBox(height: 4),
            Text('Ad failed to load',
                style: TextStyle(fontSize: 10, color: Colors.red[400])),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.withValues(alpha: 0.1),
      highlightColor: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        width: widget.adSize.width.toDouble(),
        height: widget.adSize.height.toDouble(),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
