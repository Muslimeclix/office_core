
## 1.1.1

- **Drastically improved initialization time**: Converted sequential async initializations to concurrent operations using `Future.wait`. This fixes the issue of prolonged blank screens (15-20 seconds) when the package is initialized in `main()`.
- **Early instantiation of `_instance`**: The core `OfficeCore` singleton is now populated immediately after resolving its fast dependencies. This ensures that `OfficeCore.crashlytics` and other subsystems do not throw `NullThrownError` while secondary subsystems (like Ads or Notifications) are still booting up.

## 1.1.0

- **Remote Config rewritten to flat, per-platform keys** (e.g. `show_banner_android`, `free_reminder_limit_ios`). No more single `office_config_v1` JSON blob. Consumers can keep their existing RC JSON (parameter groups) unchanged.
- **Never crashes on no internet.** If Remote Config can't be fetched (offline / Firebase unavailable), the app launches immediately on bundled defaults and keeps running.
- **Auto-sync on reconnect.** When connectivity is restored, OfficeCore automatically re-fetches Remote Config and emits `OfficeCore.rc.changes` — no extra code needed.
- **Package defaults fill gaps.** Any RC key not provided by the developer (or provided as `null`/empty string) falls back to the package's built-in defaults. `remoteConfigDefaults` is now a `Map<String, dynamic>?` of per-platform flat overrides.
- **Generic accessors added**: `OfficeCore.rc.boolValue`, `intValue`, `doubleValue`, `stringValue` resolve the current platform suffix automatically for app-specific keys.
- **New typed fields**: `platform.freeLimits` (`reminderLimit`, `userLimit`, `-1` = unlimited) and `platform.upgrader` (`showUpgrader`, `showLater`, `showIgnore`).
- **Ad unit IDs default to Google test IDs** when not set in RC — ads work in development with zero setup.

## 1.0.1

- **Tool limits now code-defined**: Added required `toolLimits` map to `OfficeCoreConfig`. Tool names come from app code (no more generic `tool1`/`tool2` keys). RC overrides individual limit values.
- **Test ad IDs as fallback**: Google's test ad unit IDs are now the default. If RC returns empty IDs, test IDs are used automatically — no setup needed during development.
- **Notification app info overrides**: Added optional `packageName`, `appVersion`, `buildNumber` to `NotificationBackendConfig` so developers can provide these explicitly instead of relying on auto-detection.
- **UMP consent flow**: Automatic GDPR/ATT consent request via Google UMP SDK before initializing ads and analytics.
- **Unified UDID tracking**: All subsystems now share a single device fingerprint (`flutter_udid`), synced to Crashlytics, Analytics, and notification device registration.
- **Dynamic FCM topics**: Automatically subscribes to `all_users_{package_name}` and `weekly_{package_name}` based on the app's package name, enabling targeted campaigns without hardcoding.
- **Project URLs updated**: `pubspec.yaml` now points to the correct repository.
- **`.pubignore` added**: Excludes docs, tests, examples, and IDE files from the published package.

## 1.0.0

Initial release of OfficeCore.

### Subsystems

- **Remote Config**: Strongly-typed JSON config model with versioned schema,
  automatic refresh on connectivity restore, broadcast change stream.
- **Ads**: `OfficeAdsController` with banner, native, interstitial, and app-open
  ad support. Ad unit IDs and visibility flags fetched from Remote Config.
  `BannerAdWidget` and `NativeAdWidget` with shimmer loading states.
- **Crashlytics**: `OfficeCrashlytics` wrapping Firebase Crashlytics with
  breadcrumb logging, custom keys, and zone-guarded error capture.
- **Analytics**: `OfficeAnalyticsService` with drop-in `RouteObserver` for
  automatic screen-view tracking and `logEvent` for custom events.
- **Notifications**: `OfficeNotificationController` wrapping FCM +
  `flutter_local_notifications`. Device registration, topic subscription,
  tap navigation, translation-progress notification helper.
- **Trial & Limits**: `OfficeTrialService` consolidating conversion limits,
  file-size limits, batch limits, feature locks (download/share/copy), and
  local usage tracking with `hasRemainingQuota`.

### Abstractions

- `PremiumStatusProvider` interface decoupling ads and trial gating from any
  specific IAP or state-management solution. Built-in adapters:
  - `RevenueCatPremiumProvider`
  - `GetXPremiumProvider` (zero-rewrite migration from existing GetX apps)
  - `FakePremiumProvider` (for tests)

### Utilities

- `OfficeLifecycleService` — single `WidgetsBindingObserver` with
  `onResumeAfterPause` stream (replaces duplicated `LifecycleEventHandler`).
- `OfficeConnectivityService` — wraps `internet_connection_checker_plus`,
  exposes `onReconnect` stream.
- `OfficeLogger` — tagged logger respecting `logLevel`.
- `OfficePackageInfo` / `OfficeDeviceInfo` — cached `PackageInfo.fromPlatform()`
  and `flutter_udid` results.
- `OfficeConsentGate` — ATT (iOS) + GDPR (EU) consent widget.
- `OfficeShimmer` — extracted shimmer loading widget.
- `OfficeZoneGuard` — `runZonedGuarded` wrapper with crashlytics integration.

### Platform Support

| Platform | Status |
|----------|--------|
| Android  | Full Firebase-backed support |
| iOS      | Full Firebase-backed support |
| macOS    | Full Firebase-backed support |
| Windows  | No-op stubs (v2 will add Sentry + custom HTTP RC) |
