import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const _interstitialId = 'ca-app-pub-4052319139037863/6112867456';
  static const _rewardedId     = 'ca-app-pub-4052319139037863/9135352704';
  static const bannerId        = 'ca-app-pub-4052319139037863/5203110463';

  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;
  BannerAd?       _bannerAd;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  bool get isRewardedReady => _rewardedAd != null;

  void showInterstitial() {
    _interstitialAd?.show();
    _interstitialAd = null;
    _loadInterstitial();
  }

  void showRewarded(void Function() onRewarded) {
    if (_rewardedAd == null) return;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
      },
    );
    _rewardedAd!.show(onUserEarnedReward: (_, __) => onRewarded());
    _rewardedAd = null;
  }

  Future<void> loadBanner(VoidCallback onLoaded) async {
    final banner = BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    );
    _bannerAd = banner;
    await banner.load();
  }

  Widget? get bannerWidget =>
      _bannerAd != null ? AdWidget(ad: _bannerAd!) : null;

  double? get bannerWidth => _bannerAd?.size.width.toDouble();

  double? get bannerHeight => _bannerAd?.size.height.toDouble();

  void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }
}
