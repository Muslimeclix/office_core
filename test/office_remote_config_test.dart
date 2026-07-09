import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:office_core/src/remote_config/models/office_remote_config.dart';

void main() {
  group('OfficeRemoteConfig', () {
    test('defaultProduction has correct shape', () {
      final config = OfficeRemoteConfig.defaultProduction;
      expect(config.platform.ads.enabled, false);
      expect(config.platform.limits.globalConversion, 5);
      expect(config.platform.limits.fileSize.free, 5.0);
      expect(config.platform.limits.fileSize.premium, 20.0);
      expect(config.platform.global.lockDownload, false);
    });

    test('fromJson parses full JSON correctly', () {
      final json = {
        'platform': {
          'ads': {
            'enabled': true,
            'visibility': {
              'banner': true,
              'interstitial': false,
              'native': true,
              'native_banner': false,
              'app_open': true,
              'rewarded': false,
            },
            'units': {
              'app_id': 'ca-app-pub-1234',
              'banner': 'banner-unit-id',
              'interstitial': 'interstitial-unit-id',
              'native': 'native-unit-id',
              'app_open': 'appopen-unit-id',
              'rewarded': 'rewarded-unit-id',
            },
          },
          'splash': {
            'show_paywall_after_splash': true,
            'give_fully_premium': false,
            'show_on_boardings': true,
            'show_ad_after_splash': false,
            'onboarding': {
              'subscription': {
                'required': true,
                'selected_plan_product_id': 'com.weekly.pro',
                'revenuecat_index': 4,
                'selected_plan_type': 'weekly',
                'trial': {'enabled': true, 'duration_days': 3},
              },
              'show_paywall_after_onboarding': true,
              'button_text': 'Continue',
            },
          },
          'result_screen': {
            'show_discount_popup_on_back': true,
            'discount_popup': {
              'trial': {'enabled': true, 'duration_days': 7},
              'plan': {
                'revenuecat_index': 0,
                'product_id': 'com.monthly.pro',
                'type': 'weekly',
              },
              'button_text': 'Start Free Trial',
            },
          },
          'globall': {
            'lock_download': true,
            'lock_share': false,
            'lock_copy': true,
          },
          'limits': {
            'global_conversion': 5,
            'other_tools_limits': {'tool1': 1, 'tool2': 4, 'tool3': 5},
            'file_size': {'free': 5.0, 'premium': 20.0},
            'batch': {
              'is_locked': true,
              'limits': {'free': 5, 'premium': 20},
            },
          },
          'paywall': {
            'plans': [
              {
                'revenuecat_index': 0,
                'product_id': 'com.weekly.pro',
                'plan_duration': 'weekly',
                'has_trial': true,
              },
              {
                'revenuecat_index': 1,
                'product_id': 'com.monthly.pro',
                'plan_duration': 'monthly',
                'has_trial': false,
              },
            ],
            'ui': {
              'button_text': 'continue/free',
              'show_back_discount_popup': true,
            },
            'cross_or_continue_free': 'cross',
            'delay_seconds': 3,
          },
          'ai': {
            'enabled': true,
            'provider': {
              'model': 'gemini-2.5-flash-lite',
              'prompt': 'Your System Prompt Here',
            },
            'default_provider': 'gemini',
          },
          'pro_banner': {
            'show_pro_banner': true,
            'trigger': {
              'paywall_or_plan': 'paywall/plan',
              'revenuecat_index': 0,
              'product_id': 'com.monthly.pro',
              'type': 'weekly',
            },
            'show_for_firstime': true,
          },
        },
      };

      final config = OfficeRemoteConfig.fromJson(json);

      // Ads
      expect(config.platform.ads.enabled, true);
      expect(config.platform.ads.visibility.banner, true);
      expect(config.platform.ads.visibility.interstitial, false);
      expect(config.platform.ads.units.appId, 'ca-app-pub-1234');
      expect(config.platform.ads.units.banner, 'banner-unit-id');

      // Splash
      expect(config.platform.splash.showPaywallAfterSplash, true);
      expect(
          config.platform.splash.onboarding.subscription.revenuecatIndex, 4);
      expect(config.platform.splash.onboarding.subscription.trial.durationDays,
          3);

      // Global (note: JSON key is "globall")
      expect(config.platform.global.lockDownload, true);
      expect(config.platform.global.lockShare, false);
      expect(config.platform.global.lockCopy, true);

      // Limits
      expect(config.platform.limits.globalConversion, 5);
      expect(config.platform.limits.otherToolsLimits['tool1'], 1);
      expect(config.platform.limits.otherToolsLimits['tool2'], 4);
      expect(config.platform.limits.fileSize.free, 5.0);
      expect(config.platform.limits.fileSize.premium, 20.0);
      expect(config.platform.limits.batch.isLocked, true);
      expect(config.platform.limits.batch.limits.free, 5);
      expect(config.platform.limits.batch.limits.premium, 20);

      // Paywall
      expect(config.platform.paywall.plans.length, 2);
      expect(config.platform.paywall.plans[0].productId, 'com.weekly.pro');
      expect(config.platform.paywall.plans[0].hasTrial, true);
      expect(config.platform.paywall.ui.buttonText, 'continue/free');
      expect(config.platform.paywall.delaySeconds, 3);

      // AI
      expect(config.platform.ai.enabled, true);
      expect(config.platform.ai.provider.model, 'gemini-2.5-flash-lite');

      // ProBanner
      expect(config.platform.proBanner.showProBanner, true);
      expect(config.platform.proBanner.trigger.productId, 'com.monthly.pro');
    });

    test('fromJson handles missing keys gracefully with defaults', () {
      final config = OfficeRemoteConfig.fromJson({});

      expect(config.platform.ads.enabled, false);
      expect(config.platform.ads.visibility.banner, false);
      expect(config.platform.ads.units.banner, '');
      expect(config.platform.limits.globalConversion, 0); // empty JSON default
      expect(config.platform.global.lockDownload, false);
      expect(config.platform.paywall.plans, isEmpty);
    });

    test('fromJson accepts both "globall" and "global" keys', () {
      // Legacy typo
      final legacy = OfficeRemoteConfig.fromJson({
        'platform': {
          'globall': {'lock_download': true},
        },
      });
      expect(legacy.platform.global.lockDownload, true);

      // Fixed
      final fixed = OfficeRemoteConfig.fromJson({
        'platform': {
          'global': {'lock_download': true},
        },
      });
      expect(fixed.platform.global.lockDownload, true);
    });

    test('toJson round-trips correctly', () {
      final original = OfficeRemoteConfig.fromJson({
        'platform': {
          'ads': {
            'enabled': true,
            'visibility': {'banner': true},
            'units': {'banner': 'test-id'},
          },
          'limits': {
            'global_conversion': 10,
            'other_tools_limits': {'t1': 2},
          },
        },
      });

      final json = original.toJson();
      final roundTripped = OfficeRemoteConfig.fromJson(json);

      expect(roundTripped.platform.ads.enabled, true);
      expect(roundTripped.platform.ads.visibility.banner, true);
      expect(roundTripped.platform.ads.units.banner, 'test-id');
      expect(roundTripped.platform.limits.globalConversion, 10);
      expect(roundTripped.platform.limits.otherToolsLimits['t1'], 2);
    });

    test('JSON encode/decode round-trip via string', () {
      final original = OfficeRemoteConfig.defaultProduction;
      final encoded = jsonEncode(original.toJson());
      final decoded =
          OfficeRemoteConfig.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
      expect(decoded.platform.ads.enabled, original.platform.ads.enabled);
      expect(decoded.platform.limits.globalConversion,
          original.platform.limits.globalConversion);
    });

    test('AdsVisibility.isVisible works for all AdType values', () {
      const visibility = AdsVisibility(
        banner: true,
        interstitial: false,
        native: true,
        nativeBanner: false,
        appOpen: true,
        rewarded: false,
      );

      expect(visibility.isVisible(AdType.banner), true);
      expect(visibility.isVisible(AdType.interstitial), false);
      expect(visibility.isVisible(AdType.native), true);
      expect(visibility.isVisible(AdType.nativeBanner), false);
      expect(visibility.isVisible(AdType.appOpen), true);
      expect(visibility.isVisible(AdType.rewarded), false);
    });

    test('AdsUnits.unitIdFor returns correct ID per AdType', () {
      const units = AdsUnits(
        appId: 'app',
        banner: 'banner-id',
        interstitial: 'interstitial-id',
        native: 'native-id',
        appOpen: 'appopen-id',
        rewarded: 'rewarded-id',
      );

      expect(units.unitIdFor(AdType.banner), 'banner-id');
      expect(units.unitIdFor(AdType.interstitial), 'interstitial-id');
      expect(units.unitIdFor(AdType.native), 'native-id');
      expect(units.unitIdFor(AdType.nativeBanner), 'banner-id'); // reuses banner
      expect(units.unitIdFor(AdType.appOpen), 'appopen-id');
      expect(units.unitIdFor(AdType.rewarded), 'rewarded-id');
    });
  });
}
