import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Wraps RevenueCat (`purchases_flutter`) with a safe debug fallback
/// when API keys are placeholders.
class MonetizationService {
  MonetizationService({
    this.androidApiKey = _placeholderAndroidKey,
    this.iosApiKey = _placeholderIosKey,
    this.proEntitlementId = 'pro',
  });

  static const String _placeholderAndroidKey = 'goog_PLACEHOLDER_API_KEY';
  static const String _placeholderIosKey = 'appl_PLACEHOLDER_API_KEY';

  final String androidApiKey;
  final String iosApiKey;
  final String proEntitlementId;

  bool _initialized = false;
  bool _isDebugFallback = true;
  bool _debugProEnabled = false;

  bool get isInitialized => _initialized;
  bool get isDebugFallback => _isDebugFallback;

  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String get _activeApiKey {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return androidApiKey;
    if (Platform.isIOS) return iosApiKey;
    return '';
  }

  bool _isPlaceholderKey(String key) {
    return key.isEmpty ||
        key.contains('PLACEHOLDER') ||
        key == _placeholderAndroidKey ||
        key == _placeholderIosKey;
  }

  /// Initializes RevenueCat safely. Falls back to local debug mode
  /// if running on desktop/web or if API keys are placeholders.
  Future<void> initialize() async {
    if (_initialized) return;

    final apiKey = _activeApiKey;
    if (!_isMobilePlatform || _isPlaceholderKey(apiKey)) {
      _isDebugFallback = true;
      _initialized = true;
      debugPrint(
        'MonetizationService running in safe debug fallback mode '
        '(placeholder API key or non-mobile platform).',
      );
      return;
    }

    try {
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _isDebugFallback = false;
      _initialized = true;
    } catch (e) {
      _isDebugFallback = true;
      _initialized = true;
      debugPrint('Purchases.configure failed, using debug fallback: $e');
    }
  }

  /// Returns whether the user currently holds the Pro entitlement.
  Future<bool> checkProStatus() async {
    if (!_initialized) {
      await initialize();
    }
    if (_isDebugFallback) {
      return _debugProEnabled;
    }
    final info = await Purchases.getCustomerInfo();
    return _hasProEntitlement(info);
  }

  /// Fetches RevenueCat offerings, or `null` in debug fallback mode.
  Future<Offerings?> getOfferings() async {
    if (!_initialized) {
      await initialize();
    }
    if (_isDebugFallback) {
      return null;
    }
    return Purchases.getOfferings();
  }

  /// Purchases a RevenueCat [package] and returns the updated Pro status.
  Future<bool> purchasePackage(Package package) async {
    if (!_initialized) {
      await initialize();
    }
    if (_isDebugFallback) {
      _debugProEnabled = true;
      return true;
    }
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return _hasProEntitlement(result.customerInfo);
  }

  /// Simulates a Pro purchase when running in debug fallback mode.
  Future<bool> purchaseDebugFallback() async {
    _debugProEnabled = true;
    return true;
  }

  /// Restores previous store purchases and returns the updated Pro status.
  Future<bool> restorePurchases() async {
    if (!_initialized) {
      await initialize();
    }
    if (_isDebugFallback) {
      return _debugProEnabled;
    }
    final info = await Purchases.restorePurchases();
    return _hasProEntitlement(info);
  }

  /// Allows toggling Pro entitlement in debug builds when API keys are placeholders.
  void setDebugPro(bool value) {
    if (_isDebugFallback) {
      _debugProEnabled = value;
    }
  }

  bool _hasProEntitlement(CustomerInfo info) {
    return info.entitlements.all[proEntitlementId]?.isActive ?? false;
  }
}
