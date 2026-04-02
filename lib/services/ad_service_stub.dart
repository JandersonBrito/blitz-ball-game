import 'package:flutter/widgets.dart';

/// Web stub — all ad calls are no-ops.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const bannerId = '';

  Future<void> initialize() async {}

  bool get isRewardedReady => false;

  void showInterstitial() {}

  void showRewarded(void Function() onRewarded) {}

  Future<void> loadBanner(VoidCallback onLoaded) async {}

  Widget? get bannerWidget => null;

  double? get bannerWidth => null;

  double? get bannerHeight => null;

  void disposeBanner() {}
}
