import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pacote de ouro consumível: pode ser comprado quantas vezes o jogador quiser.
class GoldPack {
  final String id;
  final int gold;
  const GoldPack(this.id, this.gold);
}

/// Resultado da última tentativa de compra de um produto, mostrado na loja.
enum PurchaseOutcome { success, pending, canceled, error, notFound }

/// Resultado do botão "Restaurar compras".
enum RestoreOutcome { restored, nothingFound, failed }

/// Resultado do resgate de um código promocional do Google Play.
class RedeemResult {
  /// IDs dos produtos liberados pelo código (vazio = nada novo encontrado).
  final List<String> grantedIds;
  const RedeemResult(this.grantedIds);
  bool get found => grantedIds.isNotEmpty;
}

class PurchaseService extends ChangeNotifier with WidgetsBindingObserver {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  // IDs precisam ser idênticos aos cadastrados no Google Play Console.
  static const removeAdsId = 'remove_ads';
  static const goldDoublerId = 'gold_doubler';
  /// Pacote Iniciante: +3 bolas iniciais em toda fase e a skin Prisma.
  static const starterPackId = 'starter_pack_3_balls';
  static const starterBonusBalls = 3;

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

  /// Compras permanentes; as demais são consumíveis.
  static const _nonConsumableIds = {removeAdsId, goldDoublerId, starterPackId};

  static final Set<String> _allIds = {
    removeAdsId,
    goldDoublerId,
    starterPackId,
    ...goldPacks.map((p) => p.id),
  };

  static const _kAdsRemoved = 'purchase_ads_removed';
  static const _kGoldDoubler = 'purchase_gold_doubler';
  static const _kStarterOwned = 'purchase_starter_3_balls';
  static const _kPendingGold = 'purchase_pending_gold';
  static const _kProcessedIds = 'purchase_processed_ids';

  bool _adsRemoved = false;
  bool get adsRemoved => _adsRemoved;

  bool _goldDoubler = false;
  bool get goldDoubler => _goldDoubler;
  int get goldMultiplier => _goldDoubler ? 2 : 1;

  bool _starterOwned = false;
  bool get starterOwned => _starterOwned;
  bool get starterAvailable => !_starterOwned;

  bool _available = false;
  bool get available => _available;

  /// ID do produto cuja compra está em andamento, ou null.
  String? _purchasingId;
  String? get purchasingId => _purchasingId;
  bool get purchasing => _purchasingId != null;

  final Map<String, PurchaseOutcome> _outcomes = {};
  PurchaseOutcome? outcome(String id) => _outcomes[id];

  final Map<String, ProductDetails> _products = {};
  ProductDetails? product(String id) => _products[id];

  /// Ouro comprado ainda não entregue ao [GameState]. Fica salvo para que a
  /// compra nunca se perca, mesmo se o app fechar antes da entrega.
  int _pendingGold = 0;
  int get pendingGold => _pendingGold;

  Set<String> _processedIds = {};

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Produtos liberados durante a verificação atual (ver [refreshPurchases]).
  List<String>? _grantsInRefresh;
  bool _refreshing = false;

  /// O jogador saiu para resgatar um código e ainda não voltou ao app.
  bool _redeemPending = false;
  bool get redeemPending => _redeemPending;

  bool _checkingRedeem = false;
  bool get checkingRedeem => _checkingRedeem;

  RedeemResult? _redeemResult;
  RedeemResult? get redeemResult => _redeemResult;
  void clearRedeemResult() {
    _redeemResult = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool(_kAdsRemoved) ?? false;
    _goldDoubler = prefs.getBool(_kGoldDoubler) ?? false;
    _starterOwned = prefs.getBool(_kStarterOwned) ?? false;
    _pendingGold = prefs.getInt(_kPendingGold) ?? 0;
    _processedIds = (prefs.getStringList(_kProcessedIds) ?? []).toSet();
    WidgetsBinding.instance.addObserver(this);
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
    await _revalidate();
  }

  /// Confere no Google Play quais compras permanentes o usuário possui. Também
  /// revoga as reembolsadas, que o restorePurchases() simplesmente não devolve.
  /// Sem resposta confiável da loja (ex.: offline), mantém o que está salvo.
  /// Retorna quantas compras permanentes foram encontradas, ou null se falhou.
  Future<int?> _revalidate() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final addition = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error != null) return null;
      final owned = response.pastPurchases
          .where((p) => p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored)
          .map((p) => p.productID)
          .toSet();
      final prefs = await SharedPreferences.getInstance();
      for (final id in _nonConsumableIds) {
        if (owned.contains(id) && !isOwned(id)) _grantsInRefresh?.add(id);
      }
      _adsRemoved = owned.contains(removeAdsId);
      _goldDoubler = owned.contains(goldDoublerId);
      _starterOwned = owned.contains(starterPackId);
      await prefs.setBool(_kAdsRemoved, _adsRemoved);
      await prefs.setBool(_kGoldDoubler, _goldDoubler);
      await prefs.setBool(_kStarterOwned, _starterOwned);
      notifyListeners();
      return owned.intersection(_nonConsumableIds).length;
    } catch (_) {
      return null;
    }
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
      if (purchase.productID.isEmpty) {
        // Cancelamento/erro sem compra: o Google Play não informa o produto,
        // então o resultado vale para a compra em andamento.
        _resolveOrphan(purchase.status);
        continue;
      }
      if (!_allIds.contains(purchase.productID)) continue;
      final granted = purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;
      if (granted) await _deliver(purchase);
      // Restaurações silenciosas não devem gerar aviso de "compra concluída".
      final outcome = switch (purchase.status) {
        PurchaseStatus.purchased => PurchaseOutcome.success,
        PurchaseStatus.pending => PurchaseOutcome.pending,
        PurchaseStatus.canceled => PurchaseOutcome.canceled,
        PurchaseStatus.error => PurchaseOutcome.error,
        PurchaseStatus.restored => null,
      };
      if (outcome != null) _outcomes[purchase.productID] = outcome;
      // Pendente (ex.: boleto) libera a tela; o item chega quando for pago.
      final boughtInApp = purchase.productID == _purchasingId;
      if (boughtInApp) _purchasingId = null;
      notifyListeners();
      if (granted && goldPackFor(purchase.productID) != null &&
          !(boughtInApp && purchase.status == PurchaseStatus.purchased)) {
        // Ouro que não veio do buyConsumable (código promocional, compra
        // interrompida) não é consumido pelo plugin; sem consumir, o pacote
        // fica "possuído" e não pode ser comprado de novo. Consumir já confirma.
        await _consume(purchase);
      } else if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  void _resolveOrphan(PurchaseStatus status) {
    final id = _purchasingId;
    if (id == null) return;
    _outcomes[id] = switch (status) {
      PurchaseStatus.canceled => PurchaseOutcome.canceled,
      PurchaseStatus.pending => PurchaseOutcome.pending,
      _ => PurchaseOutcome.error,
    };
    _purchasingId = null;
    notifyListeners();
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
      _grantsInRefresh?.add(id);
      _pendingGold += pack.gold;
      await prefs.setInt(_kPendingGold, _pendingGold);
      if (txId.isNotEmpty) {
        _processedIds.add(txId);
        await prefs.setStringList(_kProcessedIds, _processedIds.toList());
      }
    } else if (_nonConsumableIds.contains(id) && !isOwned(id)) {
      _grantsInRefresh?.add(id);
    }
    if (id == removeAdsId) {
      _adsRemoved = true;
      await prefs.setBool(_kAdsRemoved, true);
    } else if (id == goldDoublerId) {
      _goldDoubler = true;
      await prefs.setBool(_kGoldDoubler, true);
    } else if (id == starterPackId) {
      _starterOwned = true;
      await prefs.setBool(_kStarterOwned, true);
    }
    notifyListeners();
  }

  Future<void> _consume(PurchaseDetails purchase) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
      return;
    }
    try {
      await InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .consumePurchase(purchase);
    } catch (_) {}
  }

  /// Busca na loja compras feitas fora do app (ex.: código promocional
  /// resgatado no Play Store) e as entrega. Retorna os produtos liberados.
  Future<List<String>> refreshPurchases() async {
    if (!_available || _refreshing) return const [];
    _refreshing = true;
    final grants = <String>[];
    _grantsInRefresh = grants;
    try {
      await InAppPurchase.instance.restorePurchases();
      await _revalidate();
      // As compras restauradas são entregues de forma assíncrona pelo stream.
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {
    } finally {
      _grantsInRefresh = null;
      _refreshing = false;
    }
    return grants;
  }

  /// Abre a tela de resgate do Google Play com o código preenchido. O item é
  /// detectado quando o jogador volta ao app.
  Future<bool> redeemCode(String code) async {
    final clean = code.replaceAll(RegExp(r'\s'), '').toUpperCase();
    final uri = Uri.https('play.google.com', '/redeem',
        clean.isEmpty ? null : {'code': clean});
    _redeemResult = null;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      _redeemPending = ok;
      notifyListeners();
      return ok;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_available) return;
    unawaited(_onResumed());
  }

  Future<void> _onResumed() async {
    // Rede de segurança: se a tela do Google Play fechou e nenhum resultado
    // chegou, libera o botão em vez de deixá-lo carregando para sempre.
    final buying = _purchasingId;
    if (buying != null) {
      unawaited(Future.delayed(const Duration(seconds: 3), () {
        if (_purchasingId == buying) _resolveOrphan(PurchaseStatus.canceled);
      }));
    }
    final fromRedeem = _redeemPending;
    if (fromRedeem) {
      _redeemPending = false;
      _checkingRedeem = true;
      notifyListeners();
    }
    final grants = await refreshPurchases();
    if (fromRedeem) {
      _checkingRedeem = false;
      _redeemResult = RedeemResult(grants.toSet().toList());
      notifyListeners();
    }
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
    _outcomes.remove(id);
    notifyListeners();

    try {
      var details = _products[id];
      if (details == null) {
        final response =
            await InAppPurchase.instance.queryProductDetails({id});
        if (response.productDetails.isEmpty) {
          _outcomes[id] = PurchaseOutcome.notFound;
          _purchasingId = null;
          notifyListeners();
          return false;
        }
        details = response.productDetails.first;
        _products[id] = details;
      }
      final param = PurchaseParam(productDetails: details);
      final started = goldPackFor(id) != null
          ? await InAppPurchase.instance.buyConsumable(purchaseParam: param)
          : await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      // Se o fluxo abriu, o resultado chega pelo purchaseStream.
      if (!started) {
        _outcomes[id] = PurchaseOutcome.error;
        _purchasingId = null;
        notifyListeners();
      }
      return started;
    } catch (_) {
      _outcomes[id] = PurchaseOutcome.error;
      _purchasingId = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> buyRemoveAds() => buy(removeAdsId);

  Future<void> restorePurchases() async {
    await restore();
  }

  bool _restoring = false;
  bool get restoring => _restoring;

  Future<RestoreOutcome> restore() async {
    if (!_available || _restoring) return RestoreOutcome.failed;
    _restoring = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.restorePurchases();
      final found = await _revalidate();
      if (found == null) {
        // Fora do Android não há como contar; o resultado chega pelo stream.
        return defaultTargetPlatform == TargetPlatform.android
            ? RestoreOutcome.failed
            : RestoreOutcome.restored;
      }
      return found > 0 ? RestoreOutcome.restored : RestoreOutcome.nothingFound;
    } catch (_) {
      return RestoreOutcome.failed;
    } finally {
      _restoring = false;
      notifyListeners();
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }
}
