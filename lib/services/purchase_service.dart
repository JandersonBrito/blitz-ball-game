import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService extends ChangeNotifier {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  /// Product ID must match exactly what's registered in Google Play Console.
  static const productId = 'remove_ads';
  static const _kAdsRemoved = 'purchase_ads_removed';

  bool _adsRemoved = false;
  bool get adsRemoved => _adsRemoved;

  bool _available = false;
  bool get available => _available;

  bool _purchasing = false;
  bool get purchasing => _purchasing;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool(_kAdsRemoved) ?? false;

    _available = await InAppPurchase.instance.isAvailable();
    if (!_available) return;

    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchases,
      onError: (_) {},
    );
  }

  void _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == productId) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await _markAdsRemoved();
        }
        if (purchase.status != PurchaseStatus.pending) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _markAdsRemoved() async {
    _adsRemoved = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdsRemoved, true);
    notifyListeners();
  }

  Future<bool> buyRemoveAds() async {
    if (!_available || _adsRemoved || _purchasing) return false;
    _purchasing = true;
    notifyListeners();

    try {
      final response = await InAppPurchase.instance
          .queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        _purchasing = false;
        notifyListeners();
        return false;
      }
      final param = PurchaseParam(productDetails: response.productDetails.first);
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      _purchasing = false;
      notifyListeners();
      return true;
    } catch (_) {
      _purchasing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_available) return;
    await InAppPurchase.instance.restorePurchases();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
