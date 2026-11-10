import 'package:flutter/foundation.dart' show ChangeNotifier, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'consent_service.dart';
import 'purchase_service.dart';

class AdService extends ChangeNotifier {
  AdService._();
  static final AdService instance = AdService._();

  static const _gameIdAndroid = '6083796';
  static const _gameIdIos     = '6083797';

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  static String get _gameId => _isIos ? _gameIdIos : _gameIdAndroid;

  static String get _interstitialPlacement => _isIos ? 'Interstitial_iOS' : 'Interstitial_Android';
  static String get _rewardedPlacement     => _isIos ? 'Rewarded_iOS'     : 'Rewarded_Android';
  static String get _bannerPlacement       => _isIos ? 'Banner_iOS'       : 'Banner_Android';

  static const _sessionGracePeriod = Duration(minutes: 3);
  static const _interstitialCooldown = Duration(minutes: 4);

  bool _rewardedReady = false;
  bool _interstitialReady = false;
  bool _initStarted = false;
  UnityBannerAd? _bannerWidget;
  final DateTime _sessionStart = DateTime.now();
  DateTime? _lastAdShownAt;

  bool get _consented => ConsentService.instance.consented;

  /// Vale para todo intersticial; vídeos premiados também reiniciam o intervalo.
  bool get _interstitialAllowed {
    final now = DateTime.now();
    if (now.difference(_sessionStart) < _sessionGracePeriod) return false;
    final last = _lastAdShownAt;
    return last == null || now.difference(last) >= _interstitialCooldown;
  }

  Future<void> initialize() async {
    await _syncPrivacyConsent();
    if (_initStarted) {
      _loadInterstitial();
      _loadRewarded();
      return;
    }
    _initStarted = true;
    await UnityAds.init(
      gameId: _gameId,
      testMode: false,
      onComplete: () {
        _loadInterstitial();
        _loadRewarded();
      },
      onFailed: (error, message) => _initStarted = false,
    );
  }

  /// Aplica a escolha atual do [ConsentService] sem precisar reiniciar o app.
  Future<void> applyConsent() async {
    if (_consented) {
      await initialize();
      if (_bannerWidget == null) await loadBanner(notifyListeners);
    } else {
      // Sem SDK iniciado não há nada a avisar: quem recusou nunca o ativa.
      if (_initStarted) await _syncPrivacyConsent();
      _interstitialReady = false;
      _rewardedReady = false;
      _bannerWidget = null;
    }
    notifyListeners();
  }

  /// Falhas são ignoradas: os métodos abaixo já bloqueiam anúncios sem consentimento.
  Future<void> _syncPrivacyConsent() async {
    try {
      await UnityAds.setPrivacyConsent(PrivacyConsentType.gdpr, _consented);
      await UnityAds.setPrivacyConsent(PrivacyConsentType.ccpa, _consented);
    } catch (_) {}
  }

  void _loadInterstitial() {
    if (!_consented) return;
    UnityAds.load(
      placementId: _interstitialPlacement,
      onComplete: (_) => _interstitialReady = true,
      onFailed: (_, __, ___) => _interstitialReady = false,
    );
  }

  void _loadRewarded() {
    if (!_consented) return;
    UnityAds.load(
      placementId: _rewardedPlacement,
      onComplete: (_) => _rewardedReady = true,
      onFailed: (_, __, ___) => _rewardedReady = false,
    );
  }

  /// Quem comprou "Remover Anúncios" recebe a recompensa sem assistir ao vídeo.
  bool get isRewardedReady => _adsRemoved || (_consented && _rewardedReady);

  bool get _adsRemoved => PurchaseService.instance.adsRemoved;

  void showInterstitial() {
    if (_adsRemoved || !_consented || !_interstitialAllowed || !_interstitialReady) return;
    _interstitialReady = false;
    UnityAds.showVideoAd(
      placementId: _interstitialPlacement,
      onStart: (_) => _lastAdShownAt = DateTime.now(),
      onComplete: (_) => _loadInterstitial(),
      onFailed: (_, __, ___) => _loadInterstitial(),
      onSkipped: (_) => _loadInterstitial(),
    );
  }

  void showRewarded(void Function() onRewarded) {
    if (_adsRemoved) {
      onRewarded();
      return;
    }
    if (!_consented || !_rewardedReady) return;
    _rewardedReady = false;
    UnityAds.showVideoAd(
      placementId: _rewardedPlacement,
      onStart: (_) => _lastAdShownAt = DateTime.now(),
      onComplete: (_) {
        onRewarded();
        _loadRewarded();
      },
      onFailed: (_, __, ___) => _loadRewarded(),
      onSkipped: (_) => _loadRewarded(),
    );
  }

  Future<void> loadBanner(VoidCallback onLoaded) async {
    if (_adsRemoved || !_consented) return;
    _bannerWidget = UnityBannerAd(
      placementId: _bannerPlacement,
      size: BannerSize.standard,
      onLoad: (_) => onLoaded(),
      // Sem anúncio, libera o espaço reservado em vez de deixar uma faixa vazia.
      onFailed: (_, __, ___) {
        _bannerWidget = null;
        notifyListeners();
      },
    );
    // Widget precisa estar na árvore para carregar; notifica para montar o widget
    onLoaded();
  }

  Widget? get bannerWidget => _adsRemoved ? null : _bannerWidget;

  double? get bannerWidth => BannerSize.standard.width.toDouble();

  double? get bannerHeight => BannerSize.standard.height.toDouble();

  void disposeBanner() {
    _bannerWidget = null;
  }
}
