import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'progress.dart';

/// One non-consumable product: removes ads and unlocks explanations in all languages.
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
      await _iap.restorePurchases();
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

  void _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId) continue;
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        await state.setPremium(true);
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  void dispose() => _sub?.cancel();
}
