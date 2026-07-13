/// Root typed Remote Config model.
///
/// Mirrors the JSON stored under the Firebase Remote Config key
/// `office_config_v1`. All field names use camelCase in Dart and snake_case
/// in JSON. Deserialization is manual (no codegen dependency).
///
/// Usage:
/// ```dart
/// final raw = FirebaseRemoteConfig.instance.getString('office_config_v1');
/// final config = OfficeRemoteConfig.fromJson(jsonDecode(raw));
/// print(config.platform.ads.units.banner);
/// ```
class OfficeRemoteConfig {
  final PlatformConfig platform;

  const OfficeRemoteConfig({required this.platform});

  factory OfficeRemoteConfig.fromJson(Map<String, dynamic> json) {
    return OfficeRemoteConfig(
      platform: PlatformConfig.fromJson(
        json['platform'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {'platform': platform.toJson()};

  /// Bundled production default. Used when RC fetch fails or before the first
  /// successful fetch completes.
  static OfficeRemoteConfig get defaultProduction => OfficeRemoteConfig(
        platform: PlatformConfig.defaultProduction,
      );

  @override
  String toString() => 'OfficeRemoteConfig(platform: $platform)';
}

/// Free-tier limits read from flat RC keys `free_reminder_limit` /
/// `free_user_limit`. `-1` means unlimited.
class FreeLimitsConfig {
  const FreeLimitsConfig({
    required this.reminderLimit,
    required this.userLimit,
  });

  final int reminderLimit;
  final int userLimit;

  bool get isReminderUnlimited => reminderLimit < 0;
  bool get isUserUnlimited => userLimit < 0;

  static const FreeLimitsConfig defaultProduction =
      FreeLimitsConfig(reminderLimit: -1, userLimit: -1);
}

/// Upgrader dialog controls read from flat RC keys `show_upgrader`,
/// `show_upgrade_later`, `show_upgrade_ignore`.
class UpgraderConfig {
  const UpgraderConfig({
    required this.showUpgrader,
    required this.showLater,
    required this.showIgnore,
  });

  final bool showUpgrader;
  final bool showLater;
  final bool showIgnore;

  static const UpgraderConfig defaultProduction =
      UpgraderConfig(showUpgrader: false, showLater: false, showIgnore: false);
}

/// Top-level platform configuration container.
class PlatformConfig {
  final AdsConfig ads;
  final SplashConfig splash;
  final ResultScreenConfig resultScreen;
  final GlobalConfig global;
  final LimitsConfig limits;
  final PaywallConfig paywall;
  final AiConfig ai;
  final ProBannerConfig proBanner;
  final FreeLimitsConfig freeLimits;
  final UpgraderConfig upgrader;

  const PlatformConfig({
    required this.ads,
    required this.splash,
    required this.resultScreen,
    required this.global,
    required this.limits,
    required this.paywall,
    required this.ai,
    required this.proBanner,
    required this.freeLimits,
    required this.upgrader,
  });

  factory PlatformConfig.fromJson(Map<String, dynamic> json) {
    return PlatformConfig(
      ads: AdsConfig.fromJson(json['ads'] as Map<String, dynamic>? ?? const {}),
      splash: SplashConfig.fromJson(
          json['splash'] as Map<String, dynamic>? ?? const {}),
      resultScreen: ResultScreenConfig.fromJson(
          json['result_screen'] as Map<String, dynamic>? ?? const {}),
      // Note: JSON key is "globall" (typo in legacy config). See design doc §5.4.
      global: GlobalConfig.fromJson(
          json['globall'] as Map<String, dynamic>? ??
              json['global'] as Map<String, dynamic>? ??
              const {}),
      limits: LimitsConfig.fromJson(
          json['limits'] as Map<String, dynamic>? ?? const {}),
      paywall: PaywallConfig.fromJson(
          json['paywall'] as Map<String, dynamic>? ?? const {}),
      ai: AiConfig.fromJson(json['ai'] as Map<String, dynamic>? ?? const {}),
      proBanner: ProBannerConfig.fromJson(
          json['pro_banner'] as Map<String, dynamic>? ?? const {}),
      freeLimits: FreeLimitsConfig.defaultProduction,
      upgrader: UpgraderConfig.defaultProduction,
    );
  }

  Map<String, dynamic> toJson() => {
        'ads': ads.toJson(),
        'splash': splash.toJson(),
        'result_screen': resultScreen.toJson(),
        'globall': global.toJson(),
        'limits': limits.toJson(),
        'paywall': paywall.toJson(),
        'ai': ai.toJson(),
        'pro_banner': proBanner.toJson(),
      };

  /// Builds a [PlatformConfig] from a *resolved* (platform-suffix stripped)
  /// flat map of Remote Config values.
  ///
  /// Flat key naming:
  /// - User keys (match the office RC JSON): `show_ads`, `show_banner`,
  ///   `show_native`, `show_interstitial`, `show_open_app`,
  ///   `free_reminder_limit`, `free_user_limit`, `show_upgrader`,
  ///   `show_upgrade_later`, `show_upgrade_ignore`, `delay_paywall`.
  /// - Package-internal keys are prefixed `oc_` (e.g. `oc_limits_global_conversion`,
  ///   `oc_ai_enabled`, `oc_tool_limit_<toolId>`).
  ///
  /// [codeToolLimits] are the app-defined baseline tool limits; any
  /// `oc_tool_limit_<toolId>` entry in [r] overrides them.
  factory PlatformConfig.fromFlat(
    Map<String, dynamic> r, {
    Map<String, int> codeToolLimits = const {},
  }) {
    final toolLimits = <String, int>{...codeToolLimits};
    for (final entry in r.entries) {
      if (entry.key.startsWith('oc_tool_limit_')) {
        final toolId = entry.key.substring('oc_tool_limit_'.length);
        toolLimits[toolId] = (entry.value as num? ?? 0).toInt();
      }
    }

    return PlatformConfig(
      ads: AdsConfig(
        enabled: r['show_ads'] as bool? ?? false,
        visibility: AdsVisibility(
          banner: r['show_banner'] as bool? ?? false,
          native: r['show_native'] as bool? ?? false,
          interstitial: r['show_interstitial'] as bool? ?? false,
          nativeBanner: r['oc_ads_visibility_native_banner'] as bool? ?? false,
          appOpen: r['show_open_app'] as bool? ?? false,
          rewarded: r['oc_ads_visibility_rewarded'] as bool? ?? false,
        ),
        units: AdsUnits(
          appId: r['oc_ads_unit_app_id'] as String? ??
              'ca-app-pub-3940256099942544~3347511713',
          banner: r['oc_ads_unit_banner'] as String? ??
              'ca-app-pub-3940256099942544/6300978111',
          interstitial: r['oc_ads_unit_interstitial'] as String? ??
              'ca-app-pub-3940256099942544/1033173712',
          native: r['oc_ads_unit_native'] as String? ??
              'ca-app-pub-3940256099942544/2247696110',
          appOpen: r['oc_ads_unit_app_open'] as String? ??
              'ca-app-pub-3940256099942544/9257395921',
          rewarded: r['oc_ads_unit_rewarded'] as String? ??
              'ca-app-pub-3940256099942544/5224354917',
        ),
      ),
      splash: SplashConfig(
        showPaywallAfterSplash: r['oc_splash_show_paywall'] as bool? ?? false,
        giveFullyPremium: r['oc_splash_give_premium'] as bool? ?? false,
        showOnboardings: r['oc_splash_on_boardings'] as bool? ?? false,
        showAdAfterSplash: r['oc_splash_ad_after'] as bool? ?? false,
        onboarding: OnboardingConfig(
          subscription: SubscriptionConfig(
            required: r['oc_splash_sub_required'] as bool? ?? false,
            selectedPlanProductId:
                r['oc_splash_sub_product_id'] as String? ?? '',
            revenuecatIndex: (r['oc_splash_sub_index'] as num? ?? 0).toInt(),
            selectedPlanType: r['oc_splash_sub_type'] as String? ?? 'weekly',
            trial: TrialConfig(
              enabled: r['oc_splash_sub_trial_enabled'] as bool? ?? false,
              durationDays:
                  (r['oc_splash_sub_trial_days'] as num? ?? 0).toInt(),
            ),
          ),
          showPaywallAfterOnboarding:
              r['oc_splash_paywall_after_onboarding'] as bool? ?? false,
          buttonText: r['oc_splash_button_text'] as String? ?? 'Continue',
        ),
      ),
      resultScreen: ResultScreenConfig(
        showDiscountPopupOnBack:
            r['oc_result_discount_on_back'] as bool? ?? false,
        discountPopup: DiscountPopupConfig(
          trial: TrialConfig(
            enabled: r['oc_result_trial_enabled'] as bool? ?? false,
            durationDays: (r['oc_result_trial_days'] as num? ?? 0).toInt(),
          ),
          plan: PlanRef(
            revenuecatIndex: (r['oc_result_plan_index'] as num? ?? 0).toInt(),
            productId: r['oc_result_plan_product_id'] as String? ?? '',
            type: r['oc_result_plan_type'] as String? ?? 'weekly',
          ),
          buttonText: r['oc_result_button_text'] as String? ?? 'Start Free Trial',
        ),
      ),
      global: GlobalConfig(
        lockDownload: r['oc_lock_download'] as bool? ?? false,
        lockShare: r['oc_lock_share'] as bool? ?? false,
        lockCopy: r['oc_lock_copy'] as bool? ?? false,
      ),
      limits: LimitsConfig(
        globalConversion: (r['oc_limits_global_conversion'] as num? ?? 5).toInt(),
        otherToolsLimits: toolLimits,
        fileSize: FileSizeLimit(
          free: (r['oc_limits_file_size_free'] as num? ?? 5.0).toDouble(),
          premium: (r['oc_limits_file_size_premium'] as num? ?? 20.0).toDouble(),
        ),
        batch: BatchLimit(
          isLocked: r['oc_limits_batch_locked'] as bool? ?? false,
          limits: BatchLimits(
            free: (r['oc_limits_batch_free'] as num? ?? 5).toInt(),
            premium: (r['oc_limits_batch_premium'] as num? ?? 20).toInt(),
          ),
        ),
      ),
      paywall: PaywallConfig(
        plans: const [],
        ui: PaywallUi(
          buttonText: r['oc_paywall_button_text'] as String? ?? 'Continue',
          showBackDiscountPopup:
              r['oc_paywall_show_back_discount'] as bool? ?? false,
        ),
        crossOrContinueFree:
            r['oc_paywall_cross_or_continue'] as String? ?? 'cross',
        delaySeconds: (r['delay_paywall'] as num? ?? 0).toInt(),
      ),
      ai: AiConfig(
        enabled: r['oc_ai_enabled'] as bool? ?? false,
        provider: AiProvider(
          model: r['oc_ai_model'] as String? ?? '',
          prompt: r['oc_ai_prompt'] as String? ?? '',
        ),
        defaultProvider: r['oc_ai_provider'] as String? ?? 'gemini',
      ),
      proBanner: ProBannerConfig(
        showProBanner: r['oc_pro_banner_show'] as bool? ?? false,
        trigger: PlanRef(
          revenuecatIndex: (r['oc_pro_banner_index'] as num? ?? 0).toInt(),
          productId: r['oc_pro_banner_product_id'] as String? ?? '',
          type: r['oc_pro_banner_type'] as String? ?? 'weekly',
        ),
        showForFirstime: r['oc_pro_banner_firstime'] as bool? ?? false,
      ),
      freeLimits: FreeLimitsConfig(
        reminderLimit: (r['free_reminder_limit'] as num? ?? -1).toInt(),
        userLimit: (r['free_user_limit'] as num? ?? -1).toInt(),
      ),
      upgrader: UpgraderConfig(
        showUpgrader: r['show_upgrader'] as bool? ?? false,
        showLater: r['show_upgrade_later'] as bool? ?? false,
        showIgnore: r['show_upgrade_ignore'] as bool? ?? false,
      ),
    );
  }

  /// Resolved (platform-suffix-stripped) flat defaults for every supported
  /// key. Each key is expanded to `<key>_android`, `<key>_ios`,
  /// `<key>_macos` by the service before calling `setDefaults`.
  static const Map<String, dynamic> defaultFlat = {
    // User keys (match the office RC JSON exactly)
    'show_ads': false,
    'show_banner': false,
    'show_native': false,
    'show_interstitial': false,
    'show_open_app': false,
    'free_reminder_limit': -1,
    'free_user_limit': -1,
    'show_upgrader': false,
    'show_upgrade_later': false,
    'show_upgrade_ignore': false,
    'delay_paywall': 0,
    // Package-internal keys (prefixed oc_)
    'oc_ads_visibility_native_banner': false,
    'oc_ads_visibility_rewarded': false,
    'oc_ads_unit_app_id': 'ca-app-pub-3940256099942544~3347511713',
    'oc_ads_unit_banner': 'ca-app-pub-3940256099942544/6300978111',
    'oc_ads_unit_interstitial': 'ca-app-pub-3940256099942544/1033173712',
    'oc_ads_unit_native': 'ca-app-pub-3940256099942544/2247696110',
    'oc_ads_unit_app_open': 'ca-app-pub-3940256099942544/9257395921',
    'oc_ads_unit_rewarded': 'ca-app-pub-3940256099942544/5224354917',
    'oc_limits_global_conversion': 5,
    'oc_limits_file_size_free': 5.0,
    'oc_limits_file_size_premium': 20.0,
    'oc_limits_batch_locked': false,
    'oc_limits_batch_free': 5,
    'oc_limits_batch_premium': 20,
    'oc_lock_download': false,
    'oc_lock_share': false,
    'oc_lock_copy': false,
    'oc_ai_enabled': false,
    'oc_ai_model': '',
    'oc_ai_prompt': '',
    'oc_ai_provider': 'gemini',
    'oc_pro_banner_show': false,
    'oc_pro_banner_firstime': false,
    'oc_pro_banner_index': 0,
    'oc_pro_banner_product_id': '',
    'oc_pro_banner_type': 'weekly',
    'oc_splash_show_paywall': false,
    'oc_splash_give_premium': false,
    'oc_splash_on_boardings': false,
    'oc_splash_ad_after': false,
    'oc_splash_paywall_after_onboarding': false,
    'oc_splash_button_text': 'Continue',
    'oc_splash_sub_required': false,
    'oc_splash_sub_product_id': '',
    'oc_splash_sub_index': 0,
    'oc_splash_sub_type': 'weekly',
    'oc_splash_sub_trial_enabled': false,
    'oc_splash_sub_trial_days': 0,
    'oc_result_discount_on_back': false,
    'oc_result_trial_enabled': false,
    'oc_result_trial_days': 0,
    'oc_result_plan_index': 0,
    'oc_result_plan_product_id': '',
    'oc_result_plan_type': 'weekly',
    'oc_result_button_text': 'Start Free Trial',
    'oc_paywall_button_text': 'Continue',
    'oc_paywall_show_back_discount': false,
    'oc_paywall_cross_or_continue': 'cross',
  };

  static final PlatformConfig defaultProduction =
      PlatformConfig.fromFlat(defaultFlat);
}

// ═══════════════════════════════════════════════════════════════════════════
// ADS
// ═══════════════════════════════════════════════════════════════════════════

class AdsConfig {
  final bool enabled;
  final AdsVisibility visibility;
  final AdsUnits units;

  const AdsConfig({
    required this.enabled,
    required this.visibility,
    required this.units,
  });

  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    return AdsConfig(
      enabled: json['enabled'] as bool? ?? false,
      visibility: AdsVisibility.fromJson(
          json['visibility'] as Map<String, dynamic>? ?? const {}),
      units: AdsUnits.fromJson(
          json['units'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'visibility': visibility.toJson(),
        'units': units.toJson(),
      };

  static const AdsConfig defaultProduction = AdsConfig(
    enabled: false,
    visibility: AdsVisibility.defaultProduction,
    units: AdsUnits.defaultProduction,
  );
}

class AdsVisibility {
  final bool banner;
  final bool interstitial;
  final bool native;
  final bool nativeBanner;
  final bool appOpen;
  final bool rewarded;

  const AdsVisibility({
    required this.banner,
    required this.interstitial,
    required this.native,
    required this.nativeBanner,
    required this.appOpen,
    required this.rewarded,
  });

  factory AdsVisibility.fromJson(Map<String, dynamic> json) {
    return AdsVisibility(
      banner: json['banner'] as bool? ?? false,
      interstitial: json['interstitial'] as bool? ?? false,
      native: json['native'] as bool? ?? false,
      nativeBanner: json['native_banner'] as bool? ?? false,
      appOpen: json['app_open'] as bool? ?? false,
      rewarded: json['rewarded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'banner': banner,
        'interstitial': interstitial,
        'native': native,
        'native_banner': nativeBanner,
        'app_open': appOpen,
        'rewarded': rewarded,
      };

  bool isVisible(AdType type) {
    switch (type) {
      case AdType.banner:
        return banner;
      case AdType.interstitial:
        return interstitial;
      case AdType.native:
        return native;
      case AdType.nativeBanner:
        return nativeBanner;
      case AdType.appOpen:
        return appOpen;
      case AdType.rewarded:
        return rewarded;
    }
  }

  static const AdsVisibility defaultProduction = AdsVisibility(
    banner: false,
    interstitial: false,
    native: false,
    nativeBanner: false,
    appOpen: false,
    rewarded: false,
  );
}

class AdsUnits {
  final String appId;
  final String banner;
  final String interstitial;
  final String native;
  final String appOpen;
  final String rewarded;

  const AdsUnits({
    required this.appId,
    required this.banner,
    required this.interstitial,
    required this.native,
    required this.appOpen,
    required this.rewarded,
  });

  factory AdsUnits.fromJson(Map<String, dynamic> json) {
    return AdsUnits(
      appId: json['app_id'] as String? ?? '',
      banner: json['banner'] as String? ?? '',
      interstitial: json['interstitial'] as String? ?? '',
      native: json['native'] as String? ?? '',
      appOpen: json['app_open'] as String? ?? '',
      rewarded: json['rewarded'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'app_id': appId,
        'banner': banner,
        'interstitial': interstitial,
        'native': native,
        'app_open': appOpen,
        'rewarded': rewarded,
      };

  String unitIdFor(AdType type) {
    switch (type) {
      case AdType.banner:
        return banner;
      case AdType.interstitial:
        return interstitial;
      case AdType.native:
        return native;
      case AdType.nativeBanner:
        return banner; // native_banner reuses banner unit ID by default
      case AdType.appOpen:
        return appOpen;
      case AdType.rewarded:
        return rewarded;
    }
  }

  static const AdsUnits defaultProduction = AdsUnits(
    appId: 'ca-app-pub-3940256099942544~3347511713',
    banner: 'ca-app-pub-3940256099942544/6300978111',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    native: 'ca-app-pub-3940256099942544/2247696110',
    appOpen: 'ca-app-pub-3940256099942544/9257395921',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
  );

  /// Google test ad unit IDs — used as fallback when RC returns empty values.
  static const AdsUnits test = AdsUnits(
    appId: 'ca-app-pub-3940256099942544~3347511713',
    banner: 'ca-app-pub-3940256099942544/6300978111',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    native: 'ca-app-pub-3940256099942544/2247696110',
    appOpen: 'ca-app-pub-3940256099942544/9257395921',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
  );
}

enum AdType { banner, interstitial, native, nativeBanner, appOpen, rewarded }

// ═══════════════════════════════════════════════════════════════════════════
// SPLASH
// ═══════════════════════════════════════════════════════════════════════════

class SplashConfig {
  final bool showPaywallAfterSplash;
  final bool giveFullyPremium;
  final bool showOnboardings;
  final bool showAdAfterSplash;
  final OnboardingConfig onboarding;

  const SplashConfig({
    required this.showPaywallAfterSplash,
    required this.giveFullyPremium,
    required this.showOnboardings,
    required this.showAdAfterSplash,
    required this.onboarding,
  });

  factory SplashConfig.fromJson(Map<String, dynamic> json) {
    return SplashConfig(
      showPaywallAfterSplash: json['show_paywall_after_splash'] as bool? ?? false,
      giveFullyPremium: json['give_fully_premium'] as bool? ?? false,
      showOnboardings: json['show_on_boardings'] as bool? ?? false,
      showAdAfterSplash: json['show_ad_after_splash'] as bool? ?? false,
      onboarding: OnboardingConfig.fromJson(
          json['onboarding'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'show_paywall_after_splash': showPaywallAfterSplash,
        'give_fully_premium': giveFullyPremium,
        'show_on_boardings': showOnboardings,
        'show_ad_after_splash': showAdAfterSplash,
        'onboarding': onboarding.toJson(),
      };

  static const SplashConfig defaultProduction = SplashConfig(
    showPaywallAfterSplash: false,
    giveFullyPremium: false,
    showOnboardings: false,
    showAdAfterSplash: false,
    onboarding: OnboardingConfig.defaultProduction,
  );
}

class OnboardingConfig {
  final SubscriptionConfig subscription;
  final bool showPaywallAfterOnboarding;
  final String buttonText;

  const OnboardingConfig({
    required this.subscription,
    required this.showPaywallAfterOnboarding,
    required this.buttonText,
  });

  factory OnboardingConfig.fromJson(Map<String, dynamic> json) {
    return OnboardingConfig(
      subscription: SubscriptionConfig.fromJson(
          json['subscription'] as Map<String, dynamic>? ?? const {}),
      showPaywallAfterOnboarding:
          json['show_paywall_after_onboarding'] as bool? ?? false,
      buttonText: json['button_text'] as String? ?? 'Continue',
    );
  }

  Map<String, dynamic> toJson() => {
        'subscription': subscription.toJson(),
        'show_paywall_after_onboarding': showPaywallAfterOnboarding,
        'button_text': buttonText,
      };

  static const OnboardingConfig defaultProduction = OnboardingConfig(
    subscription: SubscriptionConfig.defaultProduction,
    showPaywallAfterOnboarding: false,
    buttonText: 'Continue',
  );
}

class SubscriptionConfig {
  final bool required;
  final String selectedPlanProductId;
  final int revenuecatIndex; // OPAQUE — consumer-consumed
  final String selectedPlanType;
  final TrialConfig trial;

  const SubscriptionConfig({
    required this.required,
    required this.selectedPlanProductId,
    required this.revenuecatIndex,
    required this.selectedPlanType,
    required this.trial,
  });

  factory SubscriptionConfig.fromJson(Map<String, dynamic> json) {
    return SubscriptionConfig(
      required: json['required'] as bool? ?? false,
      selectedPlanProductId:
          json['selected_plan_product_id'] as String? ?? '',
      revenuecatIndex: (json['revenuecat_index'] as num?)?.toInt() ?? 0,
      selectedPlanType: json['selected_plan_type'] as String? ?? 'weekly',
      trial: TrialConfig.fromJson(
          json['trial'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'required': required,
        'selected_plan_product_id': selectedPlanProductId,
        'revenuecat_index': revenuecatIndex,
        'selected_plan_type': selectedPlanType,
        'trial': trial.toJson(),
      };

  static const SubscriptionConfig defaultProduction = SubscriptionConfig(
    required: false,
    selectedPlanProductId: '',
    revenuecatIndex: 0,
    selectedPlanType: 'weekly',
    trial: TrialConfig.defaultProduction,
  );
}

class TrialConfig {
  final bool enabled;
  final int durationDays;

  const TrialConfig({required this.enabled, required this.durationDays});

  factory TrialConfig.fromJson(Map<String, dynamic> json) {
    return TrialConfig(
      enabled: json['enabled'] as bool? ?? false,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'duration_days': durationDays};

  static const TrialConfig defaultProduction =
      TrialConfig(enabled: false, durationDays: 0);
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULT SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class ResultScreenConfig {
  final bool showDiscountPopupOnBack;
  final DiscountPopupConfig discountPopup;

  const ResultScreenConfig({
    required this.showDiscountPopupOnBack,
    required this.discountPopup,
  });

  factory ResultScreenConfig.fromJson(Map<String, dynamic> json) {
    return ResultScreenConfig(
      showDiscountPopupOnBack:
          json['show_discount_popup_on_back'] as bool? ?? false,
      discountPopup: DiscountPopupConfig.fromJson(
          json['discount_popup'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'show_discount_popup_on_back': showDiscountPopupOnBack,
        'discount_popup': discountPopup.toJson(),
      };

  static const ResultScreenConfig defaultProduction = ResultScreenConfig(
    showDiscountPopupOnBack: false,
    discountPopup: DiscountPopupConfig.defaultProduction,
  );
}

class DiscountPopupConfig {
  final TrialConfig trial;
  final PlanRef plan;
  final String buttonText;

  const DiscountPopupConfig({
    required this.trial,
    required this.plan,
    required this.buttonText,
  });

  factory DiscountPopupConfig.fromJson(Map<String, dynamic> json) {
    return DiscountPopupConfig(
      trial: TrialConfig.fromJson(
          json['trial'] as Map<String, dynamic>? ?? const {}),
      plan: PlanRef.fromJson(json['plan'] as Map<String, dynamic>? ?? const {}),
      buttonText: json['button_text'] as String? ?? 'Start Free Trial',
    );
  }

  Map<String, dynamic> toJson() =>
      {'trial': trial.toJson(), 'plan': plan.toJson(), 'button_text': buttonText};

  static const DiscountPopupConfig defaultProduction = DiscountPopupConfig(
    trial: TrialConfig.defaultProduction,
    plan: PlanRef.defaultProduction,
    buttonText: 'Start Free Trial',
  );
}

/// Reused in multiple places: splash.subscription, result_screen.discount_popup.plan,
/// pro_banner.trigger.
class PlanRef {
  final int revenuecatIndex; // OPAQUE — consumer-consumed
  final String productId;
  final String type; // weekly | monthly | yearly

  const PlanRef({
    required this.revenuecatIndex,
    required this.productId,
    required this.type,
  });

  factory PlanRef.fromJson(Map<String, dynamic> json) {
    return PlanRef(
      revenuecatIndex: (json['revenuecat_index'] as num?)?.toInt() ?? 0,
      productId: json['product_id'] as String? ?? '',
      type: json['type'] as String? ?? 'weekly',
    );
  }

  Map<String, dynamic> toJson() => {
        'revenuecat_index': revenuecatIndex,
        'product_id': productId,
        'type': type,
      };

  static const PlanRef defaultProduction =
      PlanRef(revenuecatIndex: 0, productId: '', type: 'weekly');
}

// ═══════════════════════════════════════════════════════════════════════════
// GLOBAL (JSON key: "globall")
// ═══════════════════════════════════════════════════════════════════════════

class GlobalConfig {
  final bool lockDownload;
  final bool lockShare;
  final bool lockCopy;

  const GlobalConfig({
    required this.lockDownload,
    required this.lockShare,
    required this.lockCopy,
  });

  factory GlobalConfig.fromJson(Map<String, dynamic> json) {
    return GlobalConfig(
      lockDownload: json['lock_download'] as bool? ?? false,
      lockShare: json['lock_share'] as bool? ?? false,
      lockCopy: json['lock_copy'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'lock_download': lockDownload,
        'lock_share': lockShare,
        'lock_copy': lockCopy,
      };

  static const GlobalConfig defaultProduction = GlobalConfig(
    lockDownload: false,
    lockShare: false,
    lockCopy: false,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// LIMITS
// ═══════════════════════════════════════════════════════════════════════════

class LimitsConfig {
  final int globalConversion;
  final Map<String, int> otherToolsLimits;
  final FileSizeLimit fileSize;
  final BatchLimit batch;

  const LimitsConfig({
    required this.globalConversion,
    required this.otherToolsLimits,
    required this.fileSize,
    required this.batch,
  });

  factory LimitsConfig.fromJson(Map<String, dynamic> json) {
    final rawTools = json['other_tools_limits'] as Map<String, dynamic>?;
    return LimitsConfig(
      globalConversion: (json['global_conversion'] as num?)?.toInt() ?? 0,
      otherToolsLimits:
          rawTools?.map((k, v) => MapEntry(k, (v as num).toInt())) ?? const {},
      fileSize: FileSizeLimit.fromJson(
          json['file_size'] as Map<String, dynamic>? ?? const {}),
      batch: BatchLimit.fromJson(
          json['batch'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'global_conversion': globalConversion,
        'other_tools_limits': otherToolsLimits,
        'file_size': fileSize.toJson(),
        'batch': batch.toJson(),
      };

  static const LimitsConfig defaultProduction = LimitsConfig(
    globalConversion: 5,
    otherToolsLimits: {},
    fileSize: FileSizeLimit.defaultProduction,
    batch: BatchLimit.defaultProduction,
  );
}

class FileSizeLimit {
  final double free;
  final double premium;

  const FileSizeLimit({required this.free, required this.premium});

  factory FileSizeLimit.fromJson(Map<String, dynamic> json) {
    return FileSizeLimit(
      free: (json['free'] as num?)?.toDouble() ?? 0,
      premium: (json['premium'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'free': free, 'premium': premium};

  static const FileSizeLimit defaultProduction =
      FileSizeLimit(free: 5.0, premium: 20.0);
}

class BatchLimit {
  final bool isLocked;
  final BatchLimits limits;

  const BatchLimit({required this.isLocked, required this.limits});

  factory BatchLimit.fromJson(Map<String, dynamic> json) {
    return BatchLimit(
      isLocked: json['is_locked'] as bool? ?? false,
      limits: BatchLimits.fromJson(
          json['limits'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() =>
      {'is_locked': isLocked, 'limits': limits.toJson()};

  static const BatchLimit defaultProduction =
      BatchLimit(isLocked: false, limits: BatchLimits.defaultProduction);
}

class BatchLimits {
  final int free;
  final int premium;

  const BatchLimits({required this.free, required this.premium});

  factory BatchLimits.fromJson(Map<String, dynamic> json) {
    return BatchLimits(
      free: (json['free'] as num?)?.toInt() ?? 0,
      premium: (json['premium'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'free': free, 'premium': premium};

  static const BatchLimits defaultProduction =
      BatchLimits(free: 5, premium: 20);
}

// ═══════════════════════════════════════════════════════════════════════════
// PAYWALL
// ═══════════════════════════════════════════════════════════════════════════

class PaywallConfig {
  final List<PaywallPlan> plans;
  final PaywallUi ui;
  final String crossOrContinueFree;
  final int delaySeconds;

  const PaywallConfig({
    required this.plans,
    required this.ui,
    required this.crossOrContinueFree,
    required this.delaySeconds,
  });

  factory PaywallConfig.fromJson(Map<String, dynamic> json) {
    final rawPlans = json['plans'] as List?;
    return PaywallConfig(
      plans: rawPlans
              ?.map((e) => PaywallPlan.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      ui: PaywallUi.fromJson(json['ui'] as Map<String, dynamic>? ?? const {}),
      crossOrContinueFree: json['cross_or_continue_free'] as String? ?? 'cross',
      delaySeconds: (json['delay_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'plans': plans.map((e) => e.toJson()).toList(),
        'ui': ui.toJson(),
        'cross_or_continue_free': crossOrContinueFree,
        'delay_seconds': delaySeconds,
      };

  static const PaywallConfig defaultProduction = PaywallConfig(
    plans: [],
    ui: PaywallUi.defaultProduction,
    crossOrContinueFree: 'cross',
    delaySeconds: 0,
  );
}

class PaywallPlan {
  final int revenuecatIndex; // OPAQUE — consumer-consumed
  final String productId;
  final String planDuration; // weekly | monthly | yearly
  final bool hasTrial;

  const PaywallPlan({
    required this.revenuecatIndex,
    required this.productId,
    required this.planDuration,
    required this.hasTrial,
  });

  factory PaywallPlan.fromJson(Map<String, dynamic> json) {
    return PaywallPlan(
      revenuecatIndex: (json['revenuecat_index'] as num?)?.toInt() ?? 0,
      productId: json['product_id'] as String? ?? '',
      planDuration: json['plan_duration'] as String? ?? 'weekly',
      hasTrial: json['has_trial'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'revenuecat_index': revenuecatIndex,
        'product_id': productId,
        'plan_duration': planDuration,
        'has_trial': hasTrial,
      };
}

class PaywallUi {
  final String buttonText;
  final bool showBackDiscountPopup;

  const PaywallUi({
    required this.buttonText,
    required this.showBackDiscountPopup,
  });

  factory PaywallUi.fromJson(Map<String, dynamic> json) {
    return PaywallUi(
      buttonText: json['button_text'] as String? ?? 'Continue',
      showBackDiscountPopup: json['show_back_discount_popup'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'button_text': buttonText,
        'show_back_discount_popup': showBackDiscountPopup,
      };

  static const PaywallUi defaultProduction =
      PaywallUi(buttonText: 'Continue', showBackDiscountPopup: false);
}

// ═══════════════════════════════════════════════════════════════════════════
// AI
// ═══════════════════════════════════════════════════════════════════════════

class AiConfig {
  final bool enabled;
  final AiProvider provider;
  final String defaultProvider;

  const AiConfig({
    required this.enabled,
    required this.provider,
    required this.defaultProvider,
  });

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    return AiConfig(
      enabled: json['enabled'] as bool? ?? false,
      provider: AiProvider.fromJson(
          json['provider'] as Map<String, dynamic>? ?? const {}),
      defaultProvider: json['default_provider'] as String? ?? 'gemini',
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'provider': provider.toJson(),
        'default_provider': defaultProvider,
      };

  static const AiConfig defaultProduction = AiConfig(
    enabled: false,
    provider: AiProvider.defaultProduction,
    defaultProvider: 'gemini',
  );
}

class AiProvider {
  final String model;
  final String prompt;

  const AiProvider({required this.model, required this.prompt});

  factory AiProvider.fromJson(Map<String, dynamic> json) {
    return AiProvider(
      model: json['model'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'model': model, 'prompt': prompt};

  static const AiProvider defaultProduction =
      AiProvider(model: '', prompt: '');
}

// ═══════════════════════════════════════════════════════════════════════════
// PRO BANNER
// ═══════════════════════════════════════════════════════════════════════════

class ProBannerConfig {
  final bool showProBanner;
  final PlanRef trigger;
  final bool showForFirstime;

  const ProBannerConfig({
    required this.showProBanner,
    required this.trigger,
    required this.showForFirstime,
  });

  factory ProBannerConfig.fromJson(Map<String, dynamic> json) {
    return ProBannerConfig(
      showProBanner: json['show_pro_banner'] as bool? ?? false,
      trigger: PlanRef.fromJson(
          json['trigger'] as Map<String, dynamic>? ?? const {}),
      showForFirstime: json['show_for_firstime'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'show_pro_banner': showProBanner,
        'trigger': trigger.toJson(),
        'show_for_firstime': showForFirstime,
      };

  static const ProBannerConfig defaultProduction = ProBannerConfig(
    showProBanner: false,
    trigger: PlanRef.defaultProduction,
    showForFirstime: false,
  );
}
