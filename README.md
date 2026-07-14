# OfficeCore

[![pub package](https://img.shields.io/pub/v/office_core.svg)](https://pub.dev/packages/office_core)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows-blue)](https://flutter.dev)

A Flutter plugin that consolidates **Remote Config**, **Ads**, **Crashlytics**,
**Analytics**, **Notifications**, and **Trial/Limits** behind a single
`initialize()` entry point with a strongly-typed configuration model.

> Stop re-implementing the same cross-cutting concerns in every app.
> Add one dependency, call one init method, ship faster.

---

## 📑 Table of Contents

1. [Features](#-features)
2. [Platform Support](#-platform-support)
3. [Installation](#-installation)
4. [Prerequisites Setup](#-prerequisites-setup) ← **Start here**
   - [Firebase Setup](#1-firebase-setup)
   - [AdMob Setup (where to get ad unit IDs)](#2-admob-setup--where-to-get-ad-unit-ids)
   - [Remote Config Setup (where to put ad unit IDs)](#3-remote-config-setup--where-to-put-ad-unit-ids)
   - [Platform Configuration](#4-platform-configuration)
5. [Initialization](#-initialization)
6. [Usage](#-usage)
   - [Ads](#-ads-usage)
   - [Remote Config](#-remote-config-usage)
   - [Trial & Limits](#-trial--limits-usage)
   - [Crashlytics](#-crashlytics-usage)
   - [Analytics](#-analytics-usage)
   - [Notifications](#-notifications-usage)
7. [Premium Status Adapters](#-premium-status-adapters)
8. [Remote Config JSON Schema (Full Reference)](#-remote-config-json-schema-full-reference)
9. [Configuration Reference](#-configuration-reference)
10. [Graceful Degradation](#-graceful-degradation)
11. [Testing](#-testing)
12. [Example App](#-example-app)
13. [Migration Guide](#-migration-guide)
14. [FAQ](#-faq)
15. [Troubleshooting](#-troubleshooting)
16. [Contributing](#-contributing)
17. [License](#-license)

---

## ✨ Features

| Subsystem | What it does |
|-----------|-------------|
| **Remote Config** | Strongly-typed JSON config model with versioned schema, automatic refresh on connectivity restore, broadcast change stream. |
| **Ads** | Banner, native, interstitial, and app-open ad support. Ad unit IDs and visibility flags fetched from Remote Config. `OfficeBannerAd` and `OfficeNativeAd` widgets with shimmer loading states. |
| **Crashlytics** | Wraps Firebase Crashlytics with breadcrumb logging, custom keys, and zone-guarded error capture. Auto-syncs unified UDID. |
| **Analytics** | Drop-in `RouteObserver` for automatic screen-view tracking and `logEvent` for custom events. Auto-syncs unified UDID. |
| **Notifications** | FCM + `flutter_local_notifications`. Device registration, dynamic topic subscription (package-specific), tap navigation, progress notification helper. |
| **Trial & Limits** | Conversion limits, file-size limits, batch limits, feature locks (download/share/copy), and local usage tracking. |
| **Consent (UMP)** | Automatically requests GDPR/ATT consent via Google UMP SDK before initializing ads and analytics. |

### Abstractions

- **`PremiumStatusProvider`** — decouples ads and trial gating from any specific IAP or state-management solution. Built-in adapters for `ValueNotifier`, fake (for tests), plus templates for GetX and RevenueCat.

### Utilities

- `OfficeLifecycleService` — single `WidgetsBindingObserver` with `onResumeAfterPause` stream.
- `OfficeConnectivityService` — wraps `internet_connection_checker_plus`.
- `OfficeLogger` — tagged logger respecting `logLevel`.
- `OfficePrefs` — typed `SharedPreferences` wrapper with change stream.

---

## 📱 Platform Support

| Platform | Remote Config | Ads | Crashlytics | Analytics | Notifications | Trial & Limits |
|----------|:---:|:---:|:---:|:---:|:---:|:---:|
| **Android** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **iOS** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **macOS** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Windows** | ⚠️ no-op | ⚠️ no-op | ⚠️ no-op | ⚠️ no-op | ⚠️ no-op | ✅ |

> Windows ships with no-op stubs in v1. v2 will add Sentry for crashlytics and a custom HTTP-based Remote Config fallback.

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  office_core: ^1.1.1
```

Then run:

```bash
flutter pub get
```

---

## 🔧 Prerequisites Setup

**This is the most important section.** OfficeCore is a wrapper around Firebase — before it can do anything, you need Firebase + AdMob + Remote Config configured.

### 1. Firebase Setup

OfficeCore depends on these Firebase services:
- **Firebase Remote Config** — stores your config JSON
- **Firebase Crashlytics** — crash reporting
- **Firebase Analytics** — event tracking
- **Firebase Cloud Messaging (FCM)** — push notifications
- **Firebase Realtime Database** — device registration

#### Step 1.1: Create a Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → name it (e.g., "MyApp-Prod")
3. (Optional) Enable Google Analytics for the project

#### Step 1.2: Add Android app

1. In the Firebase console, click the Android icon ("Add app → Android")
2. Enter your **Android package name** (e.g., `com.yourcompany.myapp`) — must match `applicationId` in `android/app/build.gradle`
3. Download `google-services.json`
4. Place it at: `android/app/google-services.json`

#### Step 1.3: Add iOS app

1. Click the iOS icon ("Add app → iOS")
2. Enter your **iOS bundle ID** (e.g., `com.yourcompany.myApp`) — must match `CFBundleIdentifier` in `ios/Runner.xcodeproj/project.pbxproj`
3. Download `GoogleService-Info.plist`
4. Place it at: `ios/Runner/GoogleService-Info.plist`
5. Open `ios/Runner.xcworkspace` in Xcode → add the plist to the Runner target (right-click Runner → Add Files to "Runner")

#### Step 1.4: Add macOS app (optional)

Same as iOS but for `macos/Runner/`.

#### Step 1.5: Enable Firebase services in console

In the Firebase console, enable each service in the left sidebar:
- **Remote Config** → click "Create your first parameter" (we'll add the JSON in step 3)
- **Crashlytics** → enable (may require building once to register)
- **Analytics** → enabled by default if you enabled Google Analytics
- **Cloud Messaging** → enabled by default
- **Realtime Database** → click "Create Database" → choose region → start in test mode (lock down rules before production)

#### Step 1.6: Add Firebase SDK to your Flutter app

Add to `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^latest
```

Add `firebase_options.dart` by running:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This auto-detects your Firebase project and generates `lib/firebase_options.dart`.

#### Step 1.7: Initialize Firebase in `main()`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}
```

✅ **Verify:** Run the app. If it launches without errors, Firebase is set up correctly.

---

### 2. AdMob Setup — Where to Get Ad Unit IDs

OfficeCore uses Google Mobile Ads (AdMob). You need an AdMob account and ad unit IDs.

#### Step 2.1: Create an AdMob account

1. Go to [apps.admob.com](https://apps.admob.com)
2. Sign in with your Google account
3. Complete account setup (select your country, accept terms)

#### Step 2.2: Add your app to AdMob

1. Click **Apps → Add app**
2. Select platform (Android or iOS)
3. Search for your app on Google Play / App Store, or click "No" to add manually
4. Add the other platform as well if cross-platform

#### Step 2.3: Create ad units

For each app, click **Ad units → Add ad unit**. Create one ad unit for each format you want:

| Ad Format | AdMob Option | Use Case |
|-----------|--------------|----------|
| Banner | "Banner" | Top/bottom of screen |
| Interstitial | "Interstitial" | Full-screen between actions |
| Native | "Native advanced" or "Native" | In-feed custom layout |
| App Open | "App open" | Shows on app launch/resume |
| Rewarded | "Rewarded" | User earns reward for watching |

**Create at least these 4 ad units** (per platform):
1. Banner ad unit → copy the **Ad unit ID** (looks like `ca-app-pub-1234567890123456/1234567890`)
2. Interstitial ad unit → copy the Ad unit ID
3. Native ad unit → copy the Ad unit ID
4. App Open ad unit → copy the Ad unit ID

> 💡 **Tip:** You'll have **different ad unit IDs for Android and iOS**. OfficeCore's Remote Config JSON has just ONE field per format — pick one (typically Android) as the default and use Firebase Remote Config conditions if you need per-platform IDs.

#### Step 2.4: Find your App ID

In AdMob → Apps → your app → **App settings**, you'll see the **App ID**:
- Android: `ca-app-pub-1234567890123456~1234567890` (note the `~`)
- iOS: `ca-app-pub-1234567890123456~1234567890`

You'll need this for the AndroidManifest.xml and Info.plist updates below.

#### Step 2.5: Update AndroidManifest.xml

Open `android/app/src/main/AndroidManifest.xml`. Add the AdMob App ID inside `<application>`:

```xml
<manifest>
    <application>
        <!-- AdMob App ID — replace with your own -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-1234567890123456~1234567890"/>
        <!-- ... other activities ... -->
    </application>
</manifest>
```

#### Step 2.6: Update iOS Info.plist

Open `ios/Runner/Info.plist`. Add the `GADApplicationIdentifier` key:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-1234567890123456~1234567890</string>
```

#### Step 2.7: Update macOS Info.plist (if supporting macOS)

Same as iOS, but for `macos/Runner/Info.plist`. Also add an entitlement for network access in `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

#### Step 2.8: Initialize Google Mobile Ads

In your `main()` function, before `runApp()`:

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Mobile Ads SDK
  await MobileAds.instance.initialize();

  runApp(MyApp());
}
```

✅ **Verify:** Use AdMob's **test ad unit IDs** (see [Google's docs](https://developers.google.com/admob/flutter/test-ads)) to test before going live. Never use real ad unit IDs during development — it can get your AdMob account banned.

---

### 3. Remote Config Setup — Where to Put Ad Unit IDs

OfficeCore reads Remote Config from **flat, per-platform keys** (one key per value, suffixed with the platform: `_android`, `_ios`, `_macos`). This is more robust than a single JSON blob — and crucially, **if there is no internet, the app keeps running on bundled defaults and auto-syncs the moment a connection returns.** No crash, ever.

You can organize these keys into **parameter groups** (e.g. `ADS`, `FREE_LIMITS`, `UPGRADER`, `PAYWALL`) in the Firebase console — they're just regular parameters.

#### Step 3.1: Open Remote Config in Firebase console

Firebase console → your project → **Remote Config** (left sidebar) → **Create your first parameter**.

#### Step 3.2: Create parameters (flat, per-platform)

Create one parameter per value, per platform. Example — for the `ADS` group:

| Parameter key | Type | Default (android) | Default (ios) | Default (macos) |
|---------------|------|-------------------|---------------|-----------------|
| `show_ads_android` | Boolean | `true` | — | — |
| `show_ads_ios` | Boolean | — | `true` | — |
| `show_ads_macos` | Boolean | — | — | `false` |
| `show_banner_android` | Boolean | `true` | — | — |
| `show_banner_ios` | Boolean | — | `true` | — |
| `show_banner_macos` | Boolean | — | — | `false` |
| `show_native_android` | Boolean | `true` | — | — |
| `show_interstitial_android` | Boolean | `true` | — | — |
| `show_open_app_android` | Boolean | `true` | — | — |

> Tip: You don't have to create the `_macos` keys unless you ship macOS. OfficeCore falls back to its package defaults for any missing key.

#### Step 3.3: Minimal example — the office RC JSON

This is a complete, ready-to-import Remote Config structure (parameter groups + parameters). You can paste it into your Firebase project — OfficeCore works with it out of the box:

```json
{
  "parameterGroups": {
    "PAYWALL": {
      "description": "Paywall delay settings",
      "parameters": {
        "delay_paywall_android": { "defaultValue": { "value": "3" }, "valueType": "NUMBER" },
        "delay_paywall_ios":   { "defaultValue": { "value": "0" }, "valueType": "NUMBER" },
        "delay_paywall_macos": { "defaultValue": { "value": "0" }, "valueType": "NUMBER" }
      }
    },
    "FREE_LIMITS": {
      "description": "Free usage limits",
      "parameters": {
        "free_reminder_limit_android": { "defaultValue": { "value": "1" }, "description": "-1 for unlimited", "valueType": "NUMBER" },
        "free_reminder_limit_ios":   { "defaultValue": { "value": "1" }, "description": "-1 for unlimited", "valueType": "NUMBER" },
        "free_reminder_limit_macos": { "defaultValue": { "value": "3" }, "description": "-1 for unlimited", "valueType": "NUMBER" },
        "free_user_limit_android": { "defaultValue": { "value": "1" }, "description": "-1 for unlimited", "valueType": "NUMBER" },
        "free_user_limit_ios":   { "defaultValue": { "value": "1" }, "description": "-1 for unlimited", "valueType": "NUMBER" },
        "free_user_limit_macos": { "defaultValue": { "value": "1" }, "description": "-1 for unlimited", "valueType": "NUMBER" }
      }
    },
    "ADS": {
      "description": "Ads control flags",
      "parameters": {
        "show_banner_android": { "defaultValue": { "value": "true" }, "valueType": "BOOLEAN" },
        "show_banner_ios":   { "defaultValue": { "value": "true" }, "valueType": "BOOLEAN" },
        "show_banner_macos": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_native_android": { "defaultValue": { "value": "true" }, "valueType": "BOOLEAN" },
        "show_native_ios":   { "defaultValue": { "value": "true" }, "valueType": "BOOLEAN" },
        "show_native_macos": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_interstitial_android": { "defaultValue": { "value": "true" }, "valueType": "BOOLEAN" },
        "show_interstitial_ios":   { "defaultValue": { "value": "true" }, "valueType": "BOOLEAN" },
        "show_interstitial_macos": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_open_app_android": { "defaultValue": { "value": "true" }, "valueType": "BOOLEAN" },
        "show_open_app_ios":   { "defaultValue": { "value": "true" }, "valueType": "BOOLEAN" },
        "show_open_app_macos": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_ads_android": { "defaultValue": { "value": "true" }, "valueType": "BOOLEAN" },
        "show_ads_ios":   { "defaultValue": { "value": "true" }, "valueType": "BOOLEAN" },
        "show_ads_macos": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" }
      }
    },
    "UPGRADER": {
      "description": "Upgrade dialog controls",
      "parameters": {
        "show_upgrader_android": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_upgrade_later_android": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_upgrade_ignore_android": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_upgrader_ios": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_upgrade_later_ios": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_upgrade_ignore_ios": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_upgrader_macos": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_upgrade_later_macos": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" },
        "show_upgrade_ignore_macos": { "defaultValue": { "value": "false" }, "valueType": "BOOLEAN" }
      }
    }
  }
}
```

#### Step 3.4: Ad unit IDs

Ad unit IDs live under package-internal keys (prefixed `oc_`). The defaults are Google's **test ad IDs**, so ads work in development with zero setup. To use real ads, set the `oc_ads_unit_*` parameters in Remote Config (per platform):

| Parameter | Example value |
|-----------|---------------|
| `oc_ads_unit_app_id_android` | `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` |
| `oc_ads_unit_banner_android` | `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY` |
| `oc_ads_unit_interstitial_android` | `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY` |
| `oc_ads_unit_native_android` | `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY` |
| `oc_ads_unit_app_open_android` | `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY` |
| `oc_ads_unit_rewarded_android` | `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY` |

(Repeat with `_ios` / `_macos` suffixes as needed.)

#### Step 3.5: Publish changes

Click **Publish changes** at the top right. Without this, the config is not live.

#### Step 3.6: Configure visibility flags

Set the `show_*` boolean flags:
- `true` = this ad format is enabled (will load when not premium)
- `false` = this ad format is killed globally (no ad requests, even for free users)

You can change these at any time without an app release — that's the whole point of Remote Config.

#### Step 3.7: Test ad unit IDs during development

For development, use AdMob's official test ad unit IDs (these always return test ads):

```json
{
  "platform": {
    "ads": {
      "enabled": true,
      "units": {
        "app_id": "ca-app-pub-3940256099942544~3347511713",
        "banner": "ca-app-pub-3940256099942544/6300978111",
        "interstitial": "ca-app-pub-3940256099942544/1033173712",
        "native": "ca-app-pub-3940256099942544/2247696110",
        "app_open": "ca-app-pub-3940256099942544/9257395921",
        "rewarded": "ca-app-pub-3940256099942544/5224354917"
      }
    }
  }
}
```

> ⚠️ **Never click your own live ads.** Always use test ad unit IDs in development. Clicking your own live ads is a policy violation that can get your AdMob account banned.

#### Step 3.8: (Optional) Use per-platform ad unit IDs

If you want different ad unit IDs for Android vs iOS, create a **Remote Config condition**:
1. In the parameter, click the default value → **Add condition**
2. Create a condition "Platform is Android" using the built-in `app.platform` condition
3. Create a condition "Platform is iOS"
4. Provide different JSON for each condition

---

### 4. Platform Configuration

#### Android — add permissions and config

**`android/app/src/main/AndroidManifest.xml`:**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Required for FCM + Remote Config + ads -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <!-- Required for notifications on Android 13+ -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <!-- (Optional) Required if you support AdMob -->
    <uses-permission android:name="com.google.android.gms.permission.AD_ID"/>

    <application>
        <!-- AdMob App ID -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>

        <!-- ... your activities ... -->
    </application>
</manifest>
```

**`android/app/build.gradle`** — set min SDK to 21+:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
        // ...
    }
}
```

#### iOS — add capabilities and Info.plist keys

**`ios/Runner/Info.plist`:**

```xml
<!-- AdMob App ID -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>

<!-- Background mode for FCM -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>

<!-- (Optional) Request App Tracking Transparency on first launch -->
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>
```

**Capabilities** (open `ios/Runner.xcworkspace` in Xcode → Runner target → Signing & Capabilities):
- ✅ Push Notifications
- ✅ Background Modes → Remote notifications

#### macOS — add entitlements

**`macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>aps-environment</key>
    <string>development</string>  <!-- or "production" in Release.entitlements -->
</dict>
</plist>
```

---

## 🚀 Initialization

Once the prerequisites above are done, you have two options for initializing `OfficeCore`.

### Option A: Initialize in Splash Screen (Recommended)

Because `OfficeCore` fetches Remote Config and may show a UMP Consent dialog (which requires an active UI), **it is highly recommended to call `OfficeCore.initialize(...)` inside your `SplashController` or Splash screen** rather than in `main()`. This prevents the app from displaying a prolonged blank screen while waiting for network requests.

**Important:** If you move initialization to your Splash screen, you must initialize `FirebaseCrashlytics` manually in your `main()` function if you want to capture extremely early startup crashes. (You can then disable Crashlytics inside `OfficeCoreConfig` or leave it enabled — it safely wraps the native instance).

**1. `main.dart` (Fast boot):**
```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Crashlytics natively to catch early errors
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(MyApp());
}
```

**2. `splash_controller.dart` (Heavy initialization):**
```dart
class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _initApp();
  }

  Future<void> _initApp() async {
    await MobileAds.instance.initialize();

    await OfficeCore.initialize(OfficeCoreConfig(
      premiumProvider: ValueNotifierPremiumProvider(ValueNotifier(false)),
      toolLimits: {'pdf_translate': 5, 'image_compress': 10},
      env: OfficeEnv.production,
      
      // We set this to false because we handled Crashlytics in main() manually
      enableCrashlytics: false, 
      
      enableAds: true,
      enableAnalytics: true,
      consentRequired: true,
    ));

    Get.offAll(() => HomeScreen());
  }
}
```

### Option B: Initialize in `main()`

If you prefer to initialize everything in `main()`, you can still do so. As of `1.1.1`, the internal operations run concurrently, greatly reducing the blank screen duration.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MobileAds.instance.initialize();

  // Initialize OfficeCore
  await OfficeCore.initialize(OfficeCoreConfig(
    premiumProvider: ValueNotifierPremiumProvider(ValueNotifier(false)),
    toolLimits: {'pdf_translate': 5},
    env: OfficeEnv.production,
  ));

  // Now you can safely use OfficeCore.crashlytics
  FlutterError.onError = (details) => OfficeCore.crashlytics.record(details.exception, details.stack);

  runApp(MyApp());
}
```

---

## 📖 Usage

### 📺 Ads Usage

#### Show banner ads

Add `OfficeBannerAd` to any widget tree. It auto-respects premium status and RC visibility flags:

```dart
Scaffold(
  appBar: AppBar(title: Text('Home')),
  body: Column(
    children: [
      Expanded(child: YourContent()),
      OfficeBannerAd.standard(),  // 320×50 banner at the bottom
    ],
  ),
)
```

Available named constructors for common ad sizes:

| Constructor | AdSize | Dimensions |
|-------------|--------|------------|
| `OfficeBannerAd.standard()` | `AdSize.banner` | 320×50 |
| `OfficeBannerAd.largeBanner()` | `AdSize.largeBanner` | 320×100 |
| `OfficeBannerAd.mediumRectangle()` | `AdSize.mediumRectangle` | 300×250 |
| `OfficeBannerAd.leaderboard()` | `AdSize.leaderboard` | 728×90 |

Custom size:

```dart
OfficeBannerAd(adSize: AdSize(width: 320, height: 100))
```

#### Show native ads

```dart
OfficeNativeAd(templateType: TemplateType.medium)  // 350px height
OfficeNativeAd(templateType: TemplateType.small)   // 95px height
```
> **AdMob Safety:** `OfficeNativeAd` automatically handles loading retries, but safely halts retries on `NO_FILL` (error code 3) to strictly comply with AdMob spam policies and prevent bans.

> **Test IDs by default:** If Remote Config returns empty ad unit IDs (e.g., during development), OfficeCore falls back to Google's official test ad unit IDs automatically. No setup needed — ads just work with test ads until real IDs are put in Remote Config.

#### Show interstitial ads

Triggered manually (e.g., between actions):

```dart
ElevatedButton(
  onPressed: () async {
    await OfficeCore.ads.showInterstitialAd(
      onAdClosed: () {
        // Navigate to next screen or continue action
      },
    );
  },
  child: Text('Continue'),
)
```

If no ad is ready, `showInterstitialAd` calls `onAdClosed` immediately (no waiting).

#### App open ads

App open ads are **automatic** — they fire when the app returns to the foreground after being backgrounded for at least 1 minute. No code needed beyond `OfficeCore.initialize`.

To disable app open ads at runtime:
```dart
// Set visibility.app_open = false in Remote Config — applies on next refresh.
```

#### Check ad visibility flags

```dart
if (OfficeCore.ads.shouldShowBanner) {
  // Show banner somewhere
}
if (OfficeCore.ads.shouldShowInterstitial) {
  // Maybe show a "Watch ad for reward" button
}
```

These flags recompute automatically when:
- Remote Config refreshes (network restored, manual `OfficeCore.rc.refresh()`)
- Premium status changes (user subscribes / cancels)

#### Listen to ad visibility changes

```dart
OfficeCore.ads.addListener(() {
  // Re-render your UI — ads may have appeared/disappeared
  setState(() {});
});
```

---

### ⚙️ Remote Config Usage

#### Read typed values

```dart
// Ad config
final adsEnabled = OfficeCore.rc.current.platform.ads.enabled;
final bannerUnitId = OfficeCore.rc.current.platform.ads.units.banner;
final bannerVisible = OfficeCore.rc.current.platform.ads.visibility.banner;

// Trial config
final trialEnabled = OfficeCore.rc.current.platform.splash.onboarding.subscription.trial.enabled;
final trialDays = OfficeCore.rc.current.platform.splash.onboarding.subscription.trial.durationDays;

// Paywall plans
final plans = OfficeCore.rc.current.platform.paywall.plans;
for (final plan in plans) {
  print('${plan.planDuration} — ${plan.productId} — trial: ${plan.hasTrial}');
}

// AI config
final aiModel = OfficeCore.rc.current.platform.ai.provider.model;
final aiPrompt = OfficeCore.rc.current.platform.ai.provider.prompt;

// Limits
final globalConversion = OfficeCore.rc.current.platform.limits.globalConversion;
final toolLimits = OfficeCore.rc.current.platform.limits.otherToolsLimits;

// Free limits + upgrader (app-specific flat keys)
final reminderLimit = OfficeCore.rc.current.platform.freeLimits.reminderLimit; // -1 = unlimited
final isReminderUnlimited = OfficeCore.rc.current.platform.freeLimits.isReminderUnlimited;
final userLimit = OfficeCore.rc.current.platform.freeLimits.userLimit;
final showUpgrader = OfficeCore.rc.current.platform.upgrader.showUpgrader;
```

#### Read app-specific flat keys directly

If your Remote Config has custom per-platform keys (e.g. `free_reminder_limit_android`),
you don't need them in the typed model — read them straight off the service. The
platform suffix is resolved automatically:

```dart
final reminderLimit = OfficeCore.rc.intValue('free_reminder_limit'); // resolves _android/_ios/_macos
final showUpgrader  = OfficeCore.rc.boolValue('show_upgrader');
final customStr     = OfficeCore.rc.stringValue('my_custom_key');
final customDouble  = OfficeCore.rc.doubleValue('my_custom_double');
```

#### Listen for config changes

When you update Remote Config in the Firebase console, the plugin auto-fetches on network reconnect. Subscribe to changes:

```dart
OfficeCore.rc.changes.listen((config) {
  // Re-render paywall, update feature gates, etc.
  setState(() {});
});
```

#### Manually trigger a refresh

```dart
await OfficeCore.rc.refresh();
```

Useful after a user takes an action that should refresh config (e.g., subscribes to premium).

---

### 🔒 Trial & Limits Usage

#### Check feature locks

```dart
if (OfficeCore.trial.canDownload) {
  // allow download
} else {
  // show paywall or upgrade prompt
}

if (OfficeCore.trial.canShare) { ... }
if (OfficeCore.trial.canCopy) { ... }
```

#### Check trial status

```dart
if (OfficeCore.trial.isTrialActive) {
  final daysLeft = OfficeCore.trial.trialDaysRemaining;
  Text('Trial: $daysLeft days remaining');
}
```

#### Check limits

```dart
// Global conversion limit (per RC)
final globalLimit = OfficeCore.trial.globalConversionLimit;

// Per-tool limit — tool names come from your code (OfficeCoreConfig.toolLimits),
// individual limit values can be overridden remotely via RC.
final toolLimit = OfficeCore.trial.toolLimit('pdf_translate');

// File size limit (premium-aware — returns premium limit if user is pro)
final maxFileSizeMb = OfficeCore.trial.fileSizeLimit;

// Batch processing limit (premium-aware)
final batchLimit = OfficeCore.trial.batchLimit;
final isBatchLocked = OfficeCore.trial.isBatchLocked;
```

#### Track usage

```dart
// Before a conversion/check, verify quota
if (OfficeCore.trial.hasRemainingQuota('pdf_translate')) {
  // Allow the action
  await performConversion();

  // Increment usage count (persisted in SharedPreferences)
  await OfficeCore.trial.incrementUsage('pdf_translate');
} else {
  // Show paywall or "limit reached" message
}

// Read current usage
final usage = OfficeCore.trial.getUsage('pdf_translate'); // int
print('Used $usage / ${OfficeCore.trial.toolLimit("pdf_translate")}');

// Reset usage (e.g., daily/weekly reset)
await OfficeCore.trial.resetUsage('pdf_translate');
```

---

### 💥 Crashlytics Usage

#### Record errors manually

```dart
try {
  riskyOperation();
} catch (e, st) {
  await OfficeCore.crashlytics.record(e, st, reason: 'risky_operation_failed');
}
```

#### Log breadcrumbs

Breadcrumbs appear in crash reports, helping you understand what the user did before a crash:

```dart
OfficeCore.crashlytics.log('User opened PDF: $fileName');
OfficeCore.crashlytics.log('Started conversion to ${outputFormat}');
// ... if a crash happens here, both log lines appear in the report
```

#### Set custom keys

Custom keys appear in crash reports as metadata:

```dart
await OfficeCore.crashlytics.setCustomKey('current_screen', 'HomeScreen');
await OfficeCore.crashlytics.setCustomKey('file_size_mb', fileSize.toString());
await OfficeCore.crashlytics.setCustomKeyInt('page_count', 42);
await OfficeCore.crashlytics.setCustomKeyBool('is_premium', isPro);
```

#### Set user identifier

```dart
await OfficeCore.crashlytics.setUserIdentifier(userId);
```

#### Automatic capture with zone guard

Wrap `runApp` to catch all uncaught async errors:

```dart
runZonedGuarded(() {
  runApp(MyApp());
}, (error, stack) {
  OfficeCore.crashlytics.record(error, stack);
});
```

---

### 📊 Analytics Usage

#### Automatic screen tracking

Add the route observer to `MaterialApp`:

```dart
MaterialApp(
  navigatorObservers: [
    OfficeCore.analytics.routeObserver,  // ← automatic screen views
  ],
  routes: {
    '/home': (ctx) => HomeScreen(),
    '/settings': (ctx) => SettingsScreen(),
  },
)
```

Screen names are derived from `route.settings.name`. They are lowercased and slashes are stripped by default (e.g., `/HomeScreen` → `homescreen`).

#### Manual screen tracking

```dart
OfficeCore.analytics.logScreenView('HomeScreen', normalize: true);
```

Pass `normalize: false` to preserve the original case.

#### Log custom events

```dart
await OfficeCore.analytics.logEvent('conversion_started', {
  'tool': 'pdf_translate',
  'file_size_mb': 5.2,
  'output_format': 'docx',
});

await OfficeCore.analytics.logEvent('paywall_shown');
await OfficeCore.analytics.logEvent('subscription_purchased', {
  'plan': 'yearly',
  'price': 49.99,
});
```

Event names are lowercased automatically (Firebase requirement).

#### Set user properties

```dart
await OfficeCore.analytics.setUserProperty(name: 'subscription_plan', value: 'yearly');
await OfficeCore.analytics.setUserProperty(name: 'account_type', value: 'premium');
```

#### Set user ID

```dart
await OfficeCore.analytics.setUserId(user.id);
```

#### Reset on logout

```dart
await OfficeCore.analytics.resetAnalyticsData();
```

---

### 🔔 Notifications Usage

#### Request permission

By default, OfficeCore initializes notifications silently without prompting the user on first launch (`silent: true` is the default). You should request permission manually later in the user journey.

```dart
// On iOS/macOS: shows system permission dialog
// On Android 13+: shows runtime permission dialog
await OfficeCore.notifications?.requestPermission();
```

Best practice: call this after explaining to the user why you want notifications (e.g., behind an "Enable notifications" button), not immediately on startup.

#### Topic Subscription (Automatic & Dynamic)

OfficeCore automatically subscribes the user to any topics defined in `NotificationBackendConfig.topics`.
Additionally, it dynamically fetches the app's package name and subscribes to `all_users_{package_name}` and `weekly_{package_name}` to make targeted campaigns effortless without needing to hardcode package names.

#### Get FCM token

```dart
final token = OfficeCore.notifications?.fcmToken;
// Send this token to your backend to send targeted push notifications
```

#### Listen for token refresh

```dart
OfficeCore.notifications?.onFcmTokenChanged.listen((token) {
  // Send updated token to your backend
  api.updateDeviceToken(token);
});
```

#### Handle notification taps

```dart
OfficeCore.notifications?.onNotificationTapped.listen((data) {
  // data is the FCM payload's `data` map
  final route = data['route'];
  final params = data['params'];

  if (route != null) {
    Navigator.pushNamed(context, route, arguments: params);
  }
});
```

Configure your FCM payload from the backend:

```json
{
  "notification": {
    "title": "New feature available!",
    "body": "Tap to check out our new PDF translator."
  },
  "data": {
    "route": "/feature_showcase",
    "params": { "feature_id": "pdf_translate" },
    "notification_uid": "abc-123",
    "notification_reached_at": "1700000000"
  }
}
```

#### Show progress notifications

For long-running tasks (translation, conversion, upload):

```dart
// Update progress as the task runs
for (var i = 0; i < totalPages; i++) {
  await translatePage(i);
  await OfficeCore.notifications?.showProgressNotification(
    current: i + 1,
    total: totalPages,
    title: 'Translating PDF',
  );
}

// Cancel when done
await OfficeCore.notifications?.cancelProgressNotification();
```

#### Device registration (automatic)

OfficeCore automatically registers the device in Firebase Realtime Database under the path you configured (`deviceRegistryPath`). The registration includes:

- FCM token
- Platform (android/ios)
- App version + build number
- Language
- Device ID (UDID)
- Last active timestamp

No code needed. To verify, check your Firebase Realtime Database — you should see entries under `devices/<token>`.

---

## 🔌 Premium Status Adapters

OfficeCore doesn't assume how your app tracks premium status. Implement `PremiumStatusProvider` and pass it to `initialize()`.

### Using ValueNotifier (built-in adapter)

Simplest option — works with Provider, Riverpod, or plain Flutter:

```dart
import 'package:flutter/foundation.dart';

final isProNotifier = ValueNotifier<bool>(false);
final provider = ValueNotifierPremiumProvider(isProNotifier);

await OfficeCore.initialize(OfficeCoreConfig(
  premiumProvider: provider,
  // ...
));

// Update premium status later (e.g., after IAP purchase)
isProNotifier.value = true;
```

### Using GetX (copy-paste template)

```dart
import 'package:get/get.dart';
import 'package:office_core/office_core.dart';

class GetXPremiumProvider implements PremiumStatusProvider {
  GetXPremiumProvider(this._rx);
  final RxBool _rx;

  @override
  bool get isPro => _rx.value;

  @override
  Stream<bool> get isProStream => _rx.stream;
}

// Usage:
final provider = GetXPremiumProvider(Get.find<PremiumController>().isPro);
```

### Using RevenueCat (copy-paste template)

```dart
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:office_core/office_core.dart';

class RevenueCatPremiumProvider implements PremiumStatusProvider {
  RevenueCatPremiumProvider({required String apiKey}) {
    Purchases.configure(PurchasesConfiguration(apiKey));
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
  }

  bool _isPro = false;
  final _controller = StreamController<bool>.broadcast();

  void _onCustomerInfoUpdated(CustomerInfo info) {
    final pro = info.entitlements.active.isNotEmpty;
    if (pro != _isPro) {
      _isPro = pro;
      _controller.add(pro);
    }
  }

  @override
  bool get isPro => _isPro;

  @override
  Stream<bool> get isProStream => _controller.stream;
}
```

### Using FakePremiumProvider (for tests)

```dart
final premium = FakePremiumProvider(initialPro: false);
// ... use premium in tests ...
premium.setPro(true);  // toggle mid-test
premium.dispose();
```

---

## 📋 Remote Config JSON Schema (Full Reference)

> **Note:** OfficeCore v1.1+ reads **flat, per-platform keys** (suffixed `_android` / `_ios` / `_macos`), not the legacy single `office_config_v1` JSON blob. The example JSON in [Step 3.3](#step-33-minimal-example--the-office-rc-json) is the canonical schema. The legacy nested structure below is retained only for reference.

### Flat key reference (per platform suffix)

| Flat key (add `_android` / `_ios` / `_macos`) | Type | Meaning |
|-----------------------------------------------|------|---------|
| `show_ads` | bool | Master ads switch |
| `show_banner` | bool | Banner ads |
| `show_native` | bool | Native ads |
| `show_interstitial` | bool | Interstitial ads |
| `show_open_app` | bool | App-open ads |
| `free_reminder_limit` | int | Free reminder limit (`-1` = unlimited) |
| `free_user_limit` | int | Free user limit (`-1` = unlimited) |
| `show_upgrader` | bool | Force-update dialog |
| `show_upgrade_later` | bool | Show "later" button |
| `show_upgrade_ignore` | bool | Show "ignore" button |
| `delay_paywall` | int | Paywall delay (seconds) |
| `oc_ads_unit_app_id` | string | AdMob App ID |
| `oc_ads_unit_banner` | string | Banner unit ID |
| `oc_ads_unit_interstitial` | string | Interstitial unit ID |
| `oc_ads_unit_native` | string | Native unit ID |
| `oc_ads_unit_app_open` | string | App-open unit ID |
| `oc_ads_unit_rewarded` | string | Rewarded unit ID |
| `oc_ads_visibility_native_banner` | bool | Native-banner visibility |
| `oc_ads_visibility_rewarded` | bool | Rewarded visibility |
| `oc_limits_global_conversion` | int | Global conversion limit |
| `oc_limits_file_size_free` | double | File-size limit (free) |
| `oc_limits_file_size_premium` | double | File-size limit (premium) |
| `oc_limits_batch_locked` | bool | Batch locked |
| `oc_limits_batch_free` | int | Batch limit (free) |
| `oc_limits_batch_premium` | int | Batch limit (premium) |
| `oc_tool_limit_<toolId>` | int | Per-tool limit override |
| `oc_lock_download` / `oc_lock_share` / `oc_lock_copy` | bool | Feature locks |
| `oc_ai_enabled` / `oc_ai_model` / `oc_ai_prompt` / `oc_ai_provider` | mixed | AI config |
| `oc_pro_banner_show` / `oc_pro_banner_firstime` | bool | Pro banner |
| `oc_splash_*` / `oc_result_*` / `oc_paywall_*` | mixed | Splash / result / paywall config |

> Any key **not** provided (or provided as `null`/empty) falls back to the package default.

<details><summary>Legacy single-JSON schema (retained for reference)</summary>

The full JSON document stored under the Firebase Remote Config key `office_config_v1`:

```json
{
  "platform": {
    "ads": {
      "enabled": true,
      "visibility": {
        "banner": true, "interstitial": true, "native": true,
        "native_banner": true, "app_open": true, "rewarded": true
      },
      "units": {
        "app_id": "ca-app-pub-XXXX~YYYY",
        "banner": "ca-app-pub-XXXX/YYYY",
        "interstitial": "ca-app-pub-XXXX/YYYY",
        "native": "ca-app-pub-XXXX/YYYY",
        "app_open": "ca-app-pub-XXXX/YYYY",
        "rewarded": "ca-app-pub-XXXX/YYYY"
      }
    },
    "splash": {
      "show_paywall_after_splash": true,
      "give_fully_premium": false,
      "show_on_boardings": false,
      "show_ad_after_splash": false,
      "onboarding": {
        "subscription": {
          "required": true,
          "selected_plan_product_id": "com.weekly.pro",
          "revenuecat_index": 4,
          "selected_plan_type": "weekly",
          "trial": { "enabled": true, "duration_days": 3 }
        },
        "show_paywall_after_onboarding": true,
        "button_text": "Continue"
      }
    },
    "result_screen": {
      "show_discount_popup_on_back": true,
      "discount_popup": {
        "trial": { "enabled": true, "duration_days": 7 },
        "plan": {
          "revenuecat_index": 0,
          "product_id": "com.monthly.pro",
          "type": "weekly"
        },
        "button_text": "Start Free Trial"
      }
    },
    "globall": {
      "lock_download": true,
      "lock_share": true,
      "lock_copy": true
    },
    "limits": {
      "global_conversion": 5,
      "other_tools_limits": { "tool1": 1, "tool2": 4, "tool3": 5 },
      "file_size": { "free": 5.0, "premium": 20.0 },
      "batch": { "is_locked": true, "limits": { "free": 5, "premium": 20 } }
    },
    "paywall": {
      "plans": [
        { "revenuecat_index": 0, "product_id": "com.weekly.pro",
          "plan_duration": "weekly", "has_trial": true },
        { "revenuecat_index": 1, "product_id": "com.monthly.pro",
          "plan_duration": "monthly", "has_trial": false },
        { "revenuecat_index": 2, "product_id": "com.yearly.pro",
          "plan_duration": "yearly", "has_trial": false }
      ],
      "ui": { "button_text": "continue/free", "show_back_discount_popup": true },
      "cross_or_continue_free": "cross",
      "delay_seconds": 3
    },
    "ai": {
      "enabled": true,
      "provider": { "model": "gemini-2.5-flash-lite", "prompt": "Your System Prompt Here" },
      "default_provider": "gemini"
    },
    "pro_banner": {
      "show_pro_banner": true,
      "trigger": { "paywall_or_plan": "paywall/plan", "revenuecat_index": 0,
                   "product_id": "com.monthly.pro", "type": "weekly" },
      "show_for_firstime": true
    }
  }
}
```

</details>

### Field Reference

#### `ads` — Ad configuration

| Field | Type | Description |
|-------|------|-------------|
| `ads.enabled` | bool | Master switch for all ads. Set false to kill all ads globally. |
| `ads.visibility.banner` | bool | Show banner ads to free users. |
| `ads.visibility.interstitial` | bool | Show interstitial ads. |
| `ads.visibility.native` | bool | Show native ads. |
| `ads.visibility.native_banner` | bool | Show native banner ads (v2 — scaffolded in v1). |
| `ads.visibility.app_open` | bool | Show app open ads on resume. |
| `ads.visibility.rewarded` | bool | Show rewarded ads (v2 — scaffolded in v1). |
| `ads.units.app_id` | string | AdMob App ID (with `~`). |
| `ads.units.banner` | string | AdMob Banner ad unit ID (with `/`). |
| `ads.units.interstitial` | string | AdMob Interstitial ad unit ID. |
| `ads.units.native` | string | AdMob Native ad unit ID. |
| `ads.units.app_open` | string | AdMob App Open ad unit ID. |
| `ads.units.rewarded` | string | AdMob Rewarded ad unit ID. |

#### `splash` — Splash + onboarding flow

| Field | Type | Description |
|-------|------|-------------|
| `splash.show_paywall_after_splash` | bool | Show paywall immediately after splash. |
| `splash.give_fully_premium` | bool | Give all users premium (for testing or special promos). |
| `splash.show_on_boardings` | bool | Show onboarding screens. |
| `splash.show_ad_after_splash` | bool | Show an interstitial after splash. |
| `splash.onboarding.subscription.required` | bool | Subscription required during onboarding. |
| `splash.onboarding.subscription.selected_plan_product_id` | string | Default plan to highlight (your app's IAP product ID). |
| `splash.onboarding.subscription.revenuecat_index` | int | OPAQUE — passed through to your IAP solution. |
| `splash.onboarding.subscription.selected_plan_type` | string | weekly \| monthly \| yearly. |
| `splash.onboarding.subscription.trial.enabled` | bool | Trial enabled. |
| `splash.onboarding.subscription.trial.duration_days` | int | Trial duration in days. |

#### `result_screen` — Post-action discount popup

| Field | Type | Description |
|-------|------|-------------|
| `result_screen.show_discount_popup_on_back` | bool | Show discount popup when user taps back from result. |
| `result_screen.discount_popup.trial.enabled` | bool | Trial enabled in discount popup. |
| `result_screen.discount_popup.trial.duration_days` | int | Trial days offered in discount popup. |
| `result_screen.discount_popup.plan.revenuecat_index` | int | OPAQUE — passed to your IAP. |
| `result_screen.discount_popup.plan.product_id` | string | IAP product ID. |
| `result_screen.discount_popup.plan.type` | string | weekly \| monthly \| yearly. |
| `result_screen.discount_popup.button_text` | string | CTA button text. |

#### `globall` — Global feature locks

> Note: the JSON key is `globall` (with two Ls) — a legacy typo. The plugin accepts both `globall` and `global`.

| Field | Type | Description |
|-------|------|-------------|
| `globall.lock_download` | bool | If true, free users can't download. |
| `globall.lock_share` | bool | If true, free users can't share. |
| `globall.lock_copy` | bool | If true, free users can't copy. |

#### `limits` — Usage limits

| Field | Type | Description |
|-------|------|-------------|
| `limits.global_conversion` | int | Max conversions per period for free users. |
| `limits.other_tools_limits` | map | Per-tool limit overrides. Tool names must also be defined in code (`OfficeCoreConfig.toolLimits`) — RC values override the code baseline. New tool names should be added in code, not RC. |
| `limits.file_size.free` | double | Max file size (MB) for free users. |
| `limits.file_size.premium` | double | Max file size (MB) for premium users. |
| `limits.batch.is_locked` | bool | If true, batch processing requires premium. |
| `limits.batch.limits.free` | int | Max batch size for free users. |
| `limits.batch.limits.premium` | int | Max batch size for premium users. |

#### `paywall` — Paywall configuration

| Field | Type | Description |
|-------|------|-------------|
| `paywall.plans` | array | List of plans to show on paywall. |
| `paywall.plans[].revenuecat_index` | int | OPAQUE — index in your RevenueCat offering. |
| `paywall.plans[].product_id` | string | IAP product ID. |
| `paywall.plans[].plan_duration` | string | weekly \| monthly \| yearly. |
| `paywall.plans[].has_trial` | bool | Plan offers a free trial. |
| `paywall.ui.button_text` | string | CTA button text. |
| `paywall.ui.show_back_discount_popup` | bool | Show discount popup when user taps back from paywall. |
| `paywall.cross_or_continue_free` | string | `"cross"` (X button) or `"continue_free"` (continue without subscribing). |
| `paywall.delay_seconds` | int | Delay before showing paywall (seconds). |

#### `ai` — AI provider configuration

| Field | Type | Description |
|-------|------|-------------|
| `ai.enabled` | bool | AI features enabled. |
| `ai.provider.model` | string | Model name (e.g., `gemini-2.5-flash-lite`). |
| `ai.provider.prompt` | string | System prompt. |
| `ai.default_provider` | string | Default AI provider name. |

#### `pro_banner` — In-app upgrade banner

| Field | Type | Description |
|-------|------|-------------|
| `pro_banner.show_pro_banner` | bool | Show in-app upgrade banner. |
| `pro_banner.trigger.revenuecat_index` | int | OPAQUE — plan to upgrade to. |
| `pro_banner.trigger.product_id` | string | IAP product ID. |
| `pro_banner.trigger.type` | string | weekly \| monthly \| yearly. |
| `pro_banner.show_for_firstime` | bool | Show only for first-time users. |

### Opaque Fields — What They Mean

Fields labeled **OPAQUE** (like `revenuecat_index`, `product_id`, `has_trial`) are **not interpreted by OfficeCore**. The plugin just exposes them as typed values. Your app reads them and wires them into your own IAP solution (RevenueCat, StoreKit 2, Google Play Billing, custom backend).

This keeps the plugin IAP-agnostic — you choose your own IAP solution.

### Schema Versioning

When you need to make a breaking schema change:

1. Create a new RC key: `office_config_v2`
2. Update the plugin to read `office_config_v2` (or support both during migration)
3. Old apps continue reading `office_config_v1` unchanged
4. Once the last v1 consumer is retired, delete the v1 key

---

## 🔧 Configuration Reference

### `OfficeCoreConfig`

| Parameter | Type | Required | Default | Description |
|-----------|------|:--------:|:-------:|-------------|
| `premiumProvider` | `PremiumStatusProvider` | ✅ | — | How your app tracks premium status |
| `toolLimits` | `Map<String, int>` | ✅ | — | App-specific tool names + free-tier limits. Tool names are code-defined (never generic like `tool1`). RC can override individual values. |
| `notificationBackend` | `NotificationBackendConfig?` | ✅* | — | Notification endpoint, DB path, topics (*required if `enableNotifications` is true) |
| `env` | `OfficeEnv` | ❌ | `production` | Environment (affects log verbosity) |
| `logLevel` | `OfficeLogLevel?` | ❌ | dev: `debug`, release: `warning` | Override log level |
| `remoteConfigDefaults` | `Map<String, dynamic>?` | ❌ | `null` | Optional per-platform flat RC defaults merged on top of package defaults (e.g. `{'show_banner_android': false}`). `null`/empty-string values fall back to package defaults. |
| `remoteConfigFetchTimeout` | `Duration` | ❌ | `4s` | RC fetch timeout |
| `enableCrashlytics` | `bool` | ❌ | `true` | Enable/disable crashlytics |
| `enableAnalytics` | `bool` | ❌ | `true` | Enable/disable analytics |
| `enableAds` | `bool` | ❌ | `true` | Enable/disable ads |
| `enableNotifications` | `bool` | ❌ | `true` | Enable/disable notifications |
| `consentRequired` | `bool` | ❌ | `true` | Require GDPR/ATT consent via UMP SDK before ads/analytics init |
| `defaultPlanType` | `String` | ❌ | `'weekly'` | Overrides the default plan type for paywalls in the fallback config |
| `defaultPlanProductId` | `String` | ❌ | `''` | Overrides the default product ID for paywalls in the fallback config |
| `defaultTrialDays` | `int` | ❌ | `3` | Overrides the default trial days in the fallback config |

### `NotificationBackendConfig`

| Parameter | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `openedApiUrl` | `String` | ✅ | Endpoint called when a user opens a notification. The plugin POSTs `notification_uid`, `package_name`, `user_token`, `status`, `notification_reached_at`. |
| `deviceRegistryPath` | `String` | ✅ | Firebase RTDB path under which device tokens are registered. |
| `topics` | `List<String>` | ❌ | FCM topics to subscribe to. Default: `['all_users']`. |
| `packageName` | `String?` | ❌ | Package name override (e.g. `com.mycompany.myapp`). Auto-detected if omitted. |
| `appVersion` | `String?` | ❌ | App version override (e.g. `1.2.3`). Auto-detected if omitted. |
| `buildNumber` | `String?` | ❌ | Build number override (e.g. `42`). Auto-detected if omitted. |

---

## 🛡️ Graceful Degradation

Every subsystem catches its own initialization errors and degrades to a no-op. The host app **never crashes** due to an OfficeCore failure.

- **No internet / RC unavailable** → the app launches immediately on the **bundled defaults** and keeps running. The moment connectivity is restored, OfficeCore **automatically re-fetches** Remote Config and emits the updated `OfficeCore.rc.changes` — no code needed.
- **RC fetch fails** → falls back to bundled defaults (`OfficeRemoteConfig.defaultProduction`).
- **Crashlytics init fails** → `record()` and `log()` become no-ops.
- **Ads init fails** → ad widgets render `SizedBox.shrink()`.
- **Notifications init fails** → `fcmToken` is empty, streams emit nothing.
- **Windows** → all Firebase-backed subsystems are no-op stubs (v1).

---

## 🧪 Testing

The plugin ships with `FakePremiumProvider` for testing:

```dart
import 'package:office_core/office_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium users see no ads', () {
    final premium = FakePremiumProvider(initialPro: true);
    expect(premium.isPro, true);
    // ... test your widgets with this provider
    premium.dispose();
  });

  test('free users have quota limits', () {
    final premium = FakePremiumProvider(initialPro: false);
    // ... test trial service behavior
    premium.setPro(true); // toggle mid-test
    premium.dispose();
  });
}
```

Run the plugin's own tests:

```bash
flutter test
```

---

## 📦 Example App

The `example/` directory contains a full demo app with 5 screens:

- **Home** — Premium status toggle + subsystem status overview
- **Ads** — Banner ads (standard, large, medium rectangle) + interstitial trigger
- **Trial** — Trial status, limits, feature locks, usage tracking demo
- **Notifications** — Permission request, FCM token display, progress notification
- **Config** — Typed Remote Config values + raw JSON view

Run it:

```bash
cd example
flutter pub get
flutter run
```

To fully run the example, you need to:
1. Create a Firebase project and add config files (see [Prerequisites Setup](#-prerequisites-setup))
2. Add AdMob App ID to `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`
3. Set up the flat Remote Config parameters (use the test ad unit IDs from [Step 3.7](#step-37-test-ad-unit-ids-during-development))
4. Uncomment the `Firebase.initializeApp()` and `OfficeCore.initialize()` lines in `example/lib/main.dart`

---

## 🔄 Migration Guide

If you have existing ad controllers, notification controllers, or RC services copied into individual apps, migrate in 10 phases (each independently shippable):

1. **Scaffold plugin repo** — add `office_core` dependency
2. **Port typed RC model** — set up flat per-platform RC parameters in Firebase
3. **Migrate one app to new RC model** (ads/notifications unchanged) — validates JSON schema
4. **Introduce `PremiumStatusProvider`** — wrap existing PremiumController
5. **Move ads widgets + controller into plugin** — remove local copies
6. **Move notifications into plugin** — extract endpoint/DB-path/topics into `NotificationBackendConfig`
7. **Move crashlytics + analytics** — wrap `runApp` in `runZonedGuarded`
8. **Build Trial/Limits subsystem** (net-new) — feature-gated UI reads from `OfficeCore.trial`
9. **Bundle common utilities** — replace duplicated LifecycleEventHandler, connectivity listeners
10. **Onboard second app** — this is where API rough edges surface; iterate

---

## ❓ FAQ

### Q: Where do I put my ad unit IDs?

**In Firebase Remote Config, not in code.** Create flat, per-platform parameters (e.g. `oc_ads_unit_banner_android`, `show_banner_ios`) as described in [Prerequisites Setup → Step 3](#3-remote-config-setup--where-to-put-ad-unit-ids). OfficeCore auto-resolves the current platform suffix. See that section for the complete walkthrough.

### Q: Can I use different ad unit IDs for Android and iOS?

Yes — use Firebase Remote Config **conditions**. In the parameter, click the default value → Add condition → create "Platform is Android" and "Platform is iOS" conditions, then provide different JSON for each.

### Q: How do I disable an ad format without an app release?

Set `ads.visibility.<format> = false` in Remote Config. The plugin auto-refreshes on network reconnect. Setting visibility to false produces **zero ad requests**, not just hidden UI.

### Q: How do I disable all ads for premium users?

You don't need to — OfficeCore does it automatically. When `PremiumStatusProvider.isPro` is true, all ad visibility flags become false. Just make sure your `PremiumStatusProvider` reports `true` when the user is premium.

### Q: Can I use OfficeCore without Firebase?

No. OfficeCore wraps Firebase Remote Config, Crashlytics, Analytics, and Cloud Messaging. You need a Firebase project. (v2 may add a non-Firebase fallback for Windows.)

### Q: Does OfficeCore call RevenueCat or StoreKit?

No. OfficeCore is IAP-agnostic. Fields like `revenuecat_index` and `product_id` are **opaque** — OfficeCore exposes them as typed values, your app reads them and passes them to whatever IAP solution you use. See [Premium Status Adapters](#-premium-status-adapters) for adapter templates.

### Q: How do I test ads without getting my AdMob account banned?

Always use AdMob's test ad unit IDs during development. OfficeCore uses them as the default fallback — if Remote Config returns empty IDs, test IDs are used automatically. See [Step 3.7](#step-37-test-ad-unit-ids-during-development) for the test IDs list. Never click your own live ads.

### Q: How do I define tool-specific limits?

Pass a `Map<String, int>` as `toolLimits` in `OfficeCoreConfig`. The keys are your app's tool names (e.g. `'pdf_translate'`, `'image_compress'`), and the values are the free-tier limits. These serve as the baseline — RC can override individual values via `limits.other_tools_limits`, but tool names come from code to avoid generic keys like `"tool1"`, `"tool2"`.

### Q: Why is the JSON key `globall` (with two Ls)?

It's a legacy typo from the original office apps. The plugin accepts both `globall` and `global` for forward compatibility. New configs should use `global`.

### Q: How do I handle Windows in v1?

All Firebase-backed subsystems are no-op stubs on Windows in v1. The plugin won't crash — it just won't do anything. The Trial & Limits subsystem works on Windows (it's pure Dart). v2 will add Sentry for crashlytics and a custom HTTP-based RC fallback.

### Q: How do I know if OfficeCore initialized correctly?

```dart
if (OfficeCore.isInitialized) {
  // OK to use OfficeCore.rc, OfficeCore.ads, etc.
} else {
  // Initialize() not called yet, or it threw an error
}
```

The `OfficeLogger` logs init progress at the info level. In debug mode, you'll see `[OfficeCore:Core] INFO OfficeCore initialized (env: production)`.

### Q: My Remote Config changes aren't showing up. Why?

Check:
1. Did you click **Publish changes** in the Firebase console?
2. Is `minimumFetchInterval` set to `Duration.zero`? (default in OfficeCore)
3. Try calling `OfficeCore.rc.refresh()` manually.
4. Check that your per-platform parameter keys exist (e.g. `show_banner_android`, `oc_ads_unit_banner_ios`) and are published.
5. Check that the JSON is valid (no trailing commas, properly escaped strings).

---

## 🛠️ Troubleshooting

### Ads not showing

1. **Check RC visibility flags:** `ads.enabled` must be true, `ads.visibility.<format>` must be true.
2. **Check premium status:** If `OfficeCore.premium.isPro` is true, ads won't show.
3. **Check ad unit IDs:** Are they non-empty in `OfficeCore.rc.current.platform.ads.units`?
4. **Check AdMob App ID:** Is it in `AndroidManifest.xml` and `Info.plist`?
5. **Use test ad unit IDs:** See [Step 3.7](#step-37-test-ad-unit-ids-during-development).
6. **Check logs:** `[OfficeCore:Ads]` logs ad load failures.

### Crashlytics not reporting crashes

1. Crashes are uploaded on the **next app launch**, not when the crash happens.
2. In debug mode, crashes may not be uploaded. Test in release mode: `flutter run --release`.
3. Call `OfficeCore.crashlytics.sendUnsentReports()` on app start (OfficeCore does this automatically).

### Notifications not arriving

1. **Check permission:** `OfficeCore.notifications?.isInitialized` should be true.
2. **Check FCM token:** `OfficeCore.notifications?.fcmToken` should be non-empty.
3. **iOS:** Did you upload your APNs auth key to Firebase? (Project Settings → Cloud Messaging → iOS)
4. **Android:** Did you add the `POST_NOTIFICATIONS` permission for Android 13+?
5. **Check Firebase console:** Messaging → send a test message to your device token.

### Remote Config not updating

1. Did you click **Publish changes** in the Firebase console?
2. Try `await OfficeCore.rc.refresh()`.
3. Check `minimumFetchInterval` — Firebase throttles fetches. In debug, OfficeCore sets this to zero.
4. Check your network connection.

### Build errors

1. Run `flutter clean && flutter pub get`.
2. Make sure `minSdkVersion` is 21+ in `android/app/build.gradle`.
3. Make sure `firebase_core` is in your `pubspec.yaml`.
4. Run `flutterfire configure` to regenerate `firebase_options.dart`.

---

## 🤝 Contributing

Contributions are welcome! Please read the [contribution guidelines](CONTRIBUTING.md) first.

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

MIT — see [LICENSE](LICENSE).

---

## 🙏 Acknowledgments

Built on top of excellent Firebase and Google Mobile Ads Flutter plugins.
