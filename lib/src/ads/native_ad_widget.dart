import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';

import '../office_core.dart';

/// Native ad widget that respects Remote Config visibility flags and the
/// user's premium status.
///
/// If the user is premium, or if `ads.visibility.native` is false in RC,
/// this widget renders [SizedBox.shrink] without attempting an ad load.
///
/// Supports two template types: [TemplateType.small] (95px height) and
/// [TemplateType.medium] (350px height). Adapts colors to the current
/// theme (light/dark) automatically.
///
/// Usage:
/// ```dart
/// OfficeNativeAd(templateType: TemplateType.medium),
/// ```
class OfficeNativeAd extends StatefulWidget {
  const OfficeNativeAd({
    super.key,
    this.templateType = TemplateType.medium,
    this.margin,
    this.backgroundColor,
    this.primaryTextColor,
    this.secondaryTextColor,
    this.ctaBackgroundColor,
    this.ctaTextColor,
    this.showOnlyWhenLoaded = true,
  });

  /// The template type (small = 95px, medium = 350px).
  final TemplateType templateType;

  /// Margin around the ad widget.
  final EdgeInsets? margin;

  /// Background color of the ad container. Defaults to theme-adaptive.
  final Color? backgroundColor;

  /// Color of the primary text (ad title). Defaults to theme-adaptive.
  final Color? primaryTextColor;

  /// Color of the secondary text (ad body). Defaults to theme-adaptive.
  final Color? secondaryTextColor;

  /// Background color of the call-to-action button. Defaults to theme primary.
  final Color? ctaBackgroundColor;

  /// Text color of the call-to-action button. Defaults to white.
  final Color? ctaTextColor;

  /// If true, render a shimmer placeholder until the ad loads.
  final bool showOnlyWhenLoaded;

  @override
  State<OfficeNativeAd> createState() => _OfficeNativeAdState();
}

class _OfficeNativeAdState extends State<OfficeNativeAd> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  String? _loadError;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
  }

  void _loadAd() {
    if (!OfficeCore.isInitialized) return;

    if (OfficeCore.premium.isPro || !OfficeCore.ads.shouldShowNative) return;
    if (_isAdLoading) return;

    setState(() {
      _isAdLoading = true;
      _loadError = null;
    });

    final unitId = OfficeCore.ads.nativeUnitId;
    if (unitId.isEmpty) return;

    _nativeAd = NativeAd(
      adUnitId: unitId,
      nativeTemplateStyle: _buildNativeTemplateStyle(),
      nativeAdOptions: _buildNativeAdOptions(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _isAdLoading = false;
              _loadError = null;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (_retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _loadAd();
            });
          }
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _isAdLoading = false;
              _loadError = error.message;
            });
          }
        },
      ),
      request: const AdRequest(),
    );

    _nativeAd!.load();
  }

  NativeTemplateStyle _buildNativeTemplateStyle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NativeTemplateStyle(
      templateType: widget.templateType,
      mainBackgroundColor: widget.backgroundColor ??
          (isDark ? const Color(0xFF1E1E1E) : Colors.white),
      cornerRadius: 12.0,
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: widget.ctaTextColor ?? Colors.white,
        backgroundColor:
            widget.ctaBackgroundColor ?? Theme.of(context).colorScheme.primary,
        style: NativeTemplateFontStyle.bold,
        size: 14.0,
      ),
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: widget.primaryTextColor ??
            (isDark ? Colors.white : Colors.black),
        backgroundColor: Colors.transparent,
        style: NativeTemplateFontStyle.bold,
        size: 16.0,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: widget.secondaryTextColor ??
            (isDark ? Colors.grey[300] : Colors.grey[600]),
        backgroundColor: Colors.transparent,
        style: NativeTemplateFontStyle.normal,
        size: 14.0,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: widget.secondaryTextColor ??
            (isDark ? Colors.grey[400] : Colors.grey[500]),
        backgroundColor: Colors.transparent,
        style: NativeTemplateFontStyle.normal,
        size: 12.0,
      ),
    );
  }

  NativeAdOptions _buildNativeAdOptions() {
    return NativeAdOptions(
      shouldRequestMultipleImages: widget.templateType != TemplateType.small,
      adChoicesPlacement: AdChoicesPlacement.topRightCorner,
      mediaAspectRatio: MediaAspectRatio.landscape,
      videoOptions: VideoOptions(
        startMuted: true,
        customControlsRequested: true,
        clickToExpandRequested: widget.templateType == TemplateType.medium,
      ),
    );
  }

  double _getAdHeight() {
    switch (widget.templateType) {
      case TemplateType.small:
        return 95.0;
      case TemplateType.medium:
        return 350.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!OfficeCore.isInitialized) return const SizedBox.shrink();

    if (OfficeCore.premium.isPro || !OfficeCore.ads.shouldShowNative) {
      return const SizedBox.shrink();
    }

    if (_isAdLoading && !_isAdLoaded) {
      return widget.showOnlyWhenLoaded ? _buildShimmer() : _buildLoading();
    }

    if (_loadError != null && !_isAdLoaded) {
      return widget.showOnlyWhenLoaded ? _buildShimmer() : _buildError();
    }

    if (_isAdLoaded && _nativeAd != null) {
      return _buildAd();
    }

    return const SizedBox.shrink();
  }

  Widget _buildAd() {
    return Container(
      height: _getAdHeight(),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AdWidget(ad: _nativeAd!),
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
        height: _getAdHeight(),
      ),
    );
  }

  Widget _buildLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: _getAdHeight(),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Loading ad...',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      height: _getAdHeight(),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 20),
            const SizedBox(height: 4),
            Text('Ad failed to load',
                style: TextStyle(fontSize: 10, color: Colors.red[400])),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }
}
