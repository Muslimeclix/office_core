import 'dart:async';

import 'package:flutter/foundation.dart';

/// Abstract seam that decouples ads and trial gating from any specific IAP
/// or state-management solution.
///
/// A plugin cannot assume any specific state management (GetX, Provider,
/// Riverpod, etc.) or any specific IAP backend (RevenueCat, StoreKit 2,
/// Google Play Billing, custom). Any class that can report the current
/// premium status synchronously and emit changes via a stream can implement
/// this interface and be passed to [OfficeCore.initialize].
///
/// Built-in adapters ship with the plugin:
/// - [ValueNotifierPremiumProvider] — for apps using Provider, Riverpod,
///   or a simple ValueNotifier.
/// - [FakePremiumProvider] — for tests.
///
/// Custom adapters for other backends (RevenueCat, StoreKit 2, Google Play
/// Billing directly, GetX, custom server) can be written by the consumer
/// app in ~30 lines. See the README for examples.
abstract class PremiumStatusProvider {
  /// Current premium status (synchronous, for first paint).
  bool get isPro;

  /// Reactive stream that emits the new premium status on every change.
  ///
  /// Subscribers (AdsController, TrialService, ad widgets) listen to this
  /// and recompute their derived state when it changes.
  Stream<bool> get isProStream;
}

/// A [PremiumStatusProvider] backed by a [ValueNotifier<bool>].
///
/// Useful for apps that use Provider, Riverpod, or a simple ValueNotifier
/// for premium status. Also used internally by [FakePremiumProvider].
class ValueNotifierPremiumProvider
    implements PremiumStatusProvider, DisposableInterface {
  /// Creates a provider backed by [_notifier]. Adds a listener immediately
  /// so subsequent value changes are emitted on [isProStream].
  ValueNotifierPremiumProvider(this._notifier) {
    _notifier.addListener(_onChanged);
  }

  final ValueNotifier<bool> _notifier;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  void _onChanged() {
    _controller.add(_notifier.value);
  }

  @override
  bool get isPro => _notifier.value;

  @override
  Stream<bool> get isProStream => _controller.stream;

  /// Update the premium status. Subscribers are notified automatically.
  void setPro(bool value) => _notifier.value = value;

  @override
  void dispose() {
    _notifier.removeListener(_onChanged);
    _controller.close();
  }
}

/// Simple disposable interface (avoids importing Flutter foundation just
/// for the dispose pattern).
abstract class DisposableInterface {
  /// Release resources.
  void dispose();
}

/// Fake [PremiumStatusProvider] for tests.
///
/// Allows tests to toggle premium status on demand via [setPro].
class FakePremiumProvider implements PremiumStatusProvider {
  /// Creates a fake provider with an optional initial premium status.
  FakePremiumProvider({bool initialPro = false}) : _isPro = initialPro;

  bool _isPro;
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  @override
  bool get isPro => _isPro;

  @override
  Stream<bool> get isProStream => _controller.stream;

  /// Toggle premium status in tests. Emits the new value on [isProStream].
  void setPro(bool value) {
    _isPro = value;
    _controller.add(value);
  }

  /// Release resources.
  void dispose() => _controller.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// GetXPremiumProvider — adapter for existing GetX apps.
//
// This adapter is provided as a copy-paste template to avoid a hard
// dependency on package:get. Apps that use GetX should add `get` to their
// pubspec and paste this into their app:
//
//   import 'package:get/get.dart';
//   import 'package:office_core/office_core.dart';
//
//   class GetXPremiumProvider implements PremiumStatusProvider {
//     GetXPremiumProvider(this._rx);
//     final RxBool _rx;
//
//     @override
//     bool get isPro => _rx.value;
//
//     @override
//     Stream<bool> get isProStream => _rx.stream;
//   }
//
// Usage:
//   final provider = GetXPremiumProvider(Get.find<PremiumController>().isPro);
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// RevenueCatPremiumProvider — adapter for apps using RevenueCat.
//
// This adapter is provided as a copy-paste template to avoid a hard
// dependency on purchases_flutter. Apps that use RevenueCat should add
// `purchases_flutter` to their pubspec and paste this into their app:
//
//   import 'package:purchases_flutter/purchases_flutter.dart';
//   import 'package:office_core/office_core.dart';
//
//   class RevenueCatPremiumProvider implements PremiumStatusProvider {
//     RevenueCatPremiumProvider({required String apiKey}) {
//       Purchases.configure(PurchasesConfiguration(apiKey));
//       Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
//     }
//
//     bool _isPro = false;
//     final StreamController<bool> _controller =
//         StreamController<bool>.broadcast();
//
//     void _onCustomerInfoUpdated(CustomerInfo info) {
//       final pro = info.entitlements.active.isNotEmpty;
//       if (pro != _isPro) {
//         _isPro = pro;
//         _controller.add(pro);
//       }
//     }
//
//     @override
//     bool get isPro => _isPro;
//
//     @override
//     Stream<bool> get isProStream => _controller.stream;
//   }
// ─────────────────────────────────────────────────────────────────────────────
