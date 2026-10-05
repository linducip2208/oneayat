// AdMob abstraction: test IDs by default, disabled for premium.
// Never shows interstitial on ayat open.
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  bool initialized = false;
  bool premium = false;

  // Official Google test IDs — replace with real IDs in release config.
  static const String bannerTestId = 'ca-app-pub-3940256099942544/6300978111';

  String get bannerId => bannerTestId;

  Future<void> init({required bool premiumUser}) async {
    premium = premiumUser;
    if (premium) return;
    try {
      await MobileAds.instance.initialize();
      initialized = true;
    } catch (e) {
      debugPrint('Ads init failed (offline ok): $e');
    }
  }

  bool get bannerEnabled => initialized && !premium;
}
