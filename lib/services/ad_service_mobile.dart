import 'package:flutter/widgets.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'purchase_service.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const _gameIdAndroid = '6083796';
  static const _gameIdIos     = '6083797';

  static const _interstitialPlacement = 'Interstitial_Android';
  static const _rewardedPlacement     = 'Rewarded_Android';
  static const _bannerPlacement       = 'Banner_Android';

  bool _rewardedReady = false;
  bool _interstitialReady = false;
  UnityBannerAd? _bannerWidget;

  Future<void> initialize() async {
    await UnityAds.init(
      gameId: _gameIdAndroid,
      testMode: false,
      onComplete: () {
        _loadInterstitial();
        _loadRewarded();
      },
      onFailed: (error, message) {},
    );
  }

  void _loadInterstitial() {
    UnityAds.load(
      placementId: _interstitialPlacement,
      onComplete: (_) => _interstitialReady = true,
      onFailed: (_, __, ___) => _interstitialReady = false,
    );
  }

  void _loadRewarded() {
    UnityAds.load(
      placementId: _rewardedPlacement,
      onComplete: (_) => _rewardedReady = true,
      onFailed: (_, __, ___) => _rewardedReady = false,
    );
  }

  bool get isRewardedReady => _rewardedReady;

  bool get _adsRemoved => PurchaseService.instance.adsRemoved;

  void showInterstitial() {
    if (_adsRemoved || !_interstitialReady) return;
    _interstitialReady = false;
    UnityAds.showVideoAd(
      placementId: _interstitialPlacement,
      onComplete: (_) => _loadInterstitial(),
      onFailed: (_, __, ___) => _loadInterstitial(),
      onSkipped: (_) => _loadInterstitial(),
    );
  }

  void showRewarded(void Function() onRewarded) {
    if (_adsRemoved || !_rewardedReady) return;
    _rewardedReady = false;
    UnityAds.showVideoAd(
      placementId: _rewardedPlacement,
      onComplete: (_) {
        onRewarded();
        _loadRewarded();
      },
      onFailed: (_, __, ___) => _loadRewarded(),
      onSkipped: (_) => _loadRewarded(),
    );
  }

  Future<void> loadBanner(VoidCallback onLoaded) async {
    if (_adsRemoved) return;
    _bannerWidget = UnityBannerAd(
      placementId: _bannerPlacement,
      size: BannerSize.standard,
      onLoad: (_) => onLoaded(),
      onFailed: (_, __, ___) => _bannerWidget = null,
    );
    // Widget precisa estar na árvore para carregar; notifica para montar o widget
    onLoaded();
  }

  Widget? get bannerWidget => _bannerWidget;

  double? get bannerWidth => BannerSize.standard.width.toDouble();

  double? get bannerHeight => BannerSize.standard.height.toDouble();

  void disposeBanner() {
    _bannerWidget = null;
  }
}
