import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:office_core/office_core.dart';

/// Demonstrates the Ads subsystem: banner ads, native ads, interstitial ads.
class AdsScreen extends StatelessWidget {
  const AdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ads')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Banner Ad (will render once OfficeCore is initialized and '
              'Remote Config returns ads.enabled = true)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Banner ad — standard size
            const OfficeBannerAd.standard(),

            const SizedBox(height: 32),

            // Large banner
            const Text('Large Banner:'),
            const SizedBox(height: 8),
            const OfficeBannerAd.largeBanner(),

            const SizedBox(height: 32),

            // Medium rectangle
            const Text('Medium Rectangle:'),
            const SizedBox(height: 8),
            const OfficeBannerAd.mediumRectangle(),

            const Spacer(),

            // Interstitial trigger
            ElevatedButton.icon(
              onPressed: () => _showInterstitial(context),
              icon: const Icon(Icons.fullscreen),
              label: const Text('Show Interstitial'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showInterstitial(BuildContext context) async {
    if (OfficeCore.instance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OfficeCore not initialized')),
      );
      return;
    }
    await OfficeCore.ads.showInterstitialAd(
      onAdClosed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interstitial closed')),
        );
      },
    );
  }
}
