import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'integrity.dart';
import 'progress.dart';

/// One non-consumable product: removes ads and the daily exam limit.
///
/// The Premium flag in [AppState] is only a cache for the first frames after launch.
/// It is re-checked on every start:
///  1. against Google Play's own record of the account's purchases (revokes a flag that
///     was edited on a rooted phone, and refunded purchases);
///  2. if a verification server is configured, against Google's servers via the purchase
///     token, plus a Play Integrity check of the APK (defeats billing emulators and
///     patched/re-signed APKs).
/// Network problems never revoke Premium: only a positive "not owned" / "not genuine".
class IapService {
  IapService(this.state);
  static const productId = 'premium_unlock';

  final AppState state;
  late final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? product;
  bool available = false;
  String? lastError;

  Future<void> init() async {
    try {
      available = await _iap.isAvailable();
      if (!available) return;
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (e) => lastError = '$e');
      final resp = await _iap.queryProductDetails({productId});
      if (resp.productDetails.isNotEmpty) product = resp.productDetails.first;
      await _reverify();
    } catch (e) {
      lastError = '$e';
      debugPrint('IAP init failed: $e');
    }
  }

  Future<void> buy() async {
    final p = product;
    if (p == null) return;
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  Future<void> restore() => _iap.restorePurchases();

  /// Asks Google Play which purchases this account owns right now.
  Future<void> _reverify() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      await _iap.restorePurchases();
      return;
    }
    final android = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    // ignore: deprecated_member_use
    final resp = await android.queryPastPurchases();
    if (resp.error != null) return; // Play unreachable: keep the cached flag.
    PurchaseDetails? owned;
    for (final p in resp.pastPurchases) {
      if (p.productID == productId &&
          (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored)) {
        owned = p;
      }
    }
    if (owned == null) {
      if (state.premium) await state.setPremium(false);
      return;
    }
    await _grantIfGenuine(owned);
  }

  /// Grants Premium for a purchase that Play reported, unless the verification server
  /// positively rejects the token or the app binary.
  Future<void> _grantIfGenuine(PurchaseDetails p) async {
    if (!state.premium) await state.setPremium(true);
    if (!IntegrityService.enabled) return;
    final info = await PackageInfo.fromPlatform();
    final v = await IntegrityService.verify(
      packageName: info.packageName,
      productId: productId,
      purchaseToken: p.verificationData.serverVerificationData,
    );
    if (v.purchaseValid == false || v.appRecognized == false) {
      debugPrint('Premium revoked: purchaseValid=${v.purchaseValid} appRecognized=${v.appRecognized}');
      await state.setPremium(false);
    }
  }

  void _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId) continue;
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        await _grantIfGenuine(p);
      }
    }
  }

  void dispose() => _sub?.cancel();
}
