
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
