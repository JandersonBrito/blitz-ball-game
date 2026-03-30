import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const _interstitialId = 'ca-app-pub-4052319139037863/6112867456';
  static const _rewardedId     = 'ca-app-pub-4052319139037863/9135352704';
  static const bannerId        = 'ca-app-pub-4052319139037863/5203110463';

  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    loadInterstitial();
    loadRewarded();
  }

  void loadInterstitial() {
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

  void loadRewarded() {
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
    loadInterstitial();
  }

  /// Exibe o anúncio premiado. Chama [onRewarded] se o usuário assistir até o fim.
  void showRewarded(void Function() onRewarded) {
    if (_rewardedAd == null) return;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        loadRewarded();
      },
    );
    _rewardedAd!.show(onUserEarnedReward: (_, __) => onRewarded());
    _rewardedAd = null;
  }
}
