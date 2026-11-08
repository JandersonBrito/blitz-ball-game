import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pacote de ouro consumível: pode ser comprado quantas vezes o jogador quiser.
class GoldPack {
  final String id;
  final int gold;
  const GoldPack(this.id, this.gold);
}

class PurchaseService extends ChangeNotifier {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  // IDs precisam ser idênticos aos cadastrados no Google Play Console.
  static const removeAdsId = 'remove_ads';
  static const goldDoublerId = 'gold_doubler';
  static const starterPackId = 'starter_pack';

  /// Ouro entregue junto com o pacote inicial, além de remover anúncios.
  static const starterPackGold = 2500;

  static const goldPacks = [
    GoldPack('gold_pack_small', 1500),
    GoldPack('gold_pack_medium', 5000),
    GoldPack('gold_pack_large', 15000),
  ];

  static GoldPack? goldPackFor(String id) {
    for (final p in goldPacks) {
      if (p.id == id) return p;
    }
    return null;
  }

  static final Set<String> _allIds = {
    removeAdsId,
    goldDoublerId,
    starterPackId,
    ...goldPacks.map((p) => p.id),
  };

  static const _kAdsRemoved = 'purchase_ads_removed';
  static const _kGoldDoubler = 'purchase_gold_doubler';
  static const _kStarterOwned = 'purchase_starter_owned';
  static const _kPendingGold = 'purchase_pending_gold';
  static const _kProcessedIds = 'purchase_processed_ids';

  bool _adsRemoved = false;
  bool get adsRemoved => _adsRemoved;

  bool _goldDoubler = false;
  bool get goldDoubler => _goldDoubler;
  int get goldMultiplier => _goldDoubler ? 2 : 1;

  bool _starterOwned = false;
  bool get starterOwned => _starterOwned;

  /// O pacote inicial só faz sentido para quem ainda vê anúncios.
  bool get starterAvailable => !_starterOwned && !_adsRemoved;

  bool _available = false;
  bool get available => _available;

  /// ID do produto cuja compra está em andamento, ou null.
  String? _purchasingId;
  String? get purchasingId => _purchasingId;
  bool get purchasing => _purchasingId != null;

  final Map<String, ProductDetails> _products = {};
  ProductDetails? product(String id) => _products[id];

  /// Ouro comprado ainda não entregue ao [GameState]. Fica salvo para que a
  /// compra nunca se perca, mesmo se o app fechar antes da entrega.
  int _pendingGold = 0;
  int get pendingGold => _pendingGold;

  Set<String> _processedIds = {};

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool(_kAdsRemoved) ?? false;
    _goldDoubler = prefs.getBool(_kGoldDoubler) ?? false;
    _starterOwned = prefs.getBool(_kStarterOwned) ?? false;
    _pendingGold = prefs.getInt(_kPendingGold) ?? 0;
    _processedIds = (prefs.getStringList(_kProcessedIds) ?? []).toSet();
    // A loja não pode atrasar a abertura do jogo.
    unawaited(_connectStore());
  }

  Future<void> _connectStore() async {
    _available = await InAppPurchase.instance.isAvailable();
    if (!_available) return;

    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchases,
      onError: (_) {},
    );
    notifyListeners();
    unawaited(_loadProducts());
    // Recupera compras de reinstalações e confirma as interrompidas: o Google
    // estorna em 3 dias a compra que não for confirmada.
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    try {
      final response =
          await InAppPurchase.instance.queryProductDetails(_allIds);
      for (final p in response.productDetails) {
        _products[p.id] = p;
      }
      notifyListeners();
    } catch (_) {}
  }

  void _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!_allIds.contains(purchase.productID)) continue;
      final granted = purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;
      if (granted) await _deliver(purchase);
      if (purchase.status != PurchaseStatus.pending &&
          purchase.productID == _purchasingId) {
        _purchasingId = null;
        notifyListeners();
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _deliver(PurchaseDetails purchase) async {
    final prefs = await SharedPreferences.getInstance();
    final id = purchase.productID;

    final pack = goldPackFor(id);
    if (pack != null) {
      // Uma mesma compra pode chegar mais de uma vez (ex.: app fechado antes de
      // confirmar); o ID da transação impede entregar o ouro em dobro.
      final txId = purchase.purchaseID ?? '';
      if (txId.isNotEmpty && _processedIds.contains(txId)) return;
      _pendingGold += pack.gold;
      await prefs.setInt(_kPendingGold, _pendingGold);
      if (txId.isNotEmpty) {
        _processedIds.add(txId);
        await prefs.setStringList(_kProcessedIds, _processedIds.toList());
      }
    } else if (id == removeAdsId) {
      _adsRemoved = true;
      await prefs.setBool(_kAdsRemoved, true);
    } else if (id == goldDoublerId) {
      _goldDoubler = true;
      await prefs.setBool(_kGoldDoubler, true);
    } else if (id == starterPackId) {
      // Restaurar numa reinstalação devolve o benefício permanente, mas o ouro
      // só é entregue na compra original.
      if (!_starterOwned && purchase.status == PurchaseStatus.purchased) {
        _pendingGold += starterPackGold;
        await prefs.setInt(_kPendingGold, _pendingGold);
      }
      _starterOwned = true;
      _adsRemoved = true;
      await prefs.setBool(_kStarterOwned, true);
      await prefs.setBool(_kAdsRemoved, true);
    }
    notifyListeners();
  }

  /// Entrega o ouro comprado e zera o saldo pendente. Retorna quanto foi entregue.
  Future<int> claimPendingGold() async {
    final amount = _pendingGold;
    if (amount == 0) return 0;
    _pendingGold = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPendingGold, 0);
    return amount;
  }

  bool isOwned(String id) => switch (id) {
        removeAdsId => _adsRemoved,
        goldDoublerId => _goldDoubler,
        starterPackId => _starterOwned,
        _ => false,
      };

  Future<bool> buy(String id) async {
    if (!_available || purchasing || isOwned(id)) return false;
    _purchasingId = id;
    notifyListeners();

    try {
      var details = _products[id];
      if (details == null) {
        final response =
            await InAppPurchase.instance.queryProductDetails({id});
        if (response.productDetails.isEmpty) throw StateError('not found');
        details = response.productDetails.first;
        _products[id] = details;
      }
      final param = PurchaseParam(productDetails: details);
      final started = goldPackFor(id) != null
          ? await InAppPurchase.instance.buyConsumable(purchaseParam: param)
          : await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      // Se o fluxo abriu, o resultado chega pelo purchaseStream.
      if (!started) {
        _purchasingId = null;
        notifyListeners();
      }
      return started;
    } catch (_) {
      _purchasingId = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> buyRemoveAds() => buy(removeAdsId);

  Future<void> restorePurchases() async {
    if (!_available) return;
    await InAppPurchase.instance.restorePurchases();
  }

  /// Bônus de ouro por real de um pacote em relação ao menor, ex.: 0.6 = +60%.
  /// Calculado com os preços reais da loja para que o selo seja sempre verdadeiro.
  double? bonusVsSmallest(GoldPack pack) {
    final base = goldPacks.first;
    final basePrice = _products[base.id]?.rawPrice;
    final price = _products[pack.id]?.rawPrice;
    if (pack == base || basePrice == null || price == null) return null;
    if (basePrice <= 0 || price <= 0) return null;
    return (pack.gold / price) / (base.gold / basePrice) - 1;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
