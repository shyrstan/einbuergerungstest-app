import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob wrapper. Uses Google's official TEST unit IDs until real ones are set
/// via --dart-define (ADMOB_INTERSTITIAL, ADMOB_REWARDED, ADMOB_BANNER).
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';

  static const _interstitialIdEnv = String.fromEnvironment('ADMOB_INTERSTITIAL');
  static String get interstitialId => _interstitialIdEnv.isEmpty ? _testInterstitial : _interstitialIdEnv;
  static const _rewardedIdEnv = String.fromEnvironment('ADMOB_REWARDED');
  static String get rewardedId => _rewardedIdEnv.isEmpty ? _testRewarded : _rewardedIdEnv;
  static const _bannerIdEnv = String.fromEnvironment('ADMOB_BANNER');
  static String get bannerId => _bannerIdEnv.isEmpty ? _testBanner : _bannerIdEnv;

  bool _initialized = false;
  bool _consentDone = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _lastInterstitialMs = 0;

  /// Minimum gap between interstitials. Never below 3 minutes – rating protection.
  static const minGap = Duration(minutes: 3);

  bool get _supported => _initialized;

  Future<void> init() async {
    if (_initialized || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    _initialized = true;
    await _requestConsent();
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
  }

  /// GDPR / UMP consent flow (required in EU). Non-blocking; falls back silently on error.
  Future<void> _requestConsent() async {
    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(params, () async {
        try {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            ConsentForm.loadAndShowConsentFormIfRequired((error) => _consentDone = true);
          } else {
            _consentDone = true;
          }
        } catch (_) {
          _consentDone = true;
        }
      }, (error) => _consentDone = true);
    } catch (_) {
      _consentDone = true;
    }
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (e) => _interstitial = null,
      ),
    );
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (e) => _rewarded = null,
      ),
    );
  }

  /// Shows an interstitial if one is loaded and the frequency cap allows it.
  /// Returns true if an ad was shown.
  Future<bool> maybeShowInterstitial({required bool premium}) async {
    if (premium || !_initialized) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastInterstitialMs < minGap.inMilliseconds) return false;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    _lastInterstitialMs = now;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadInterstitial();
      },
    );
    await ad.show();
    return true;
  }

  bool get rewardedReady => _rewarded != null;

  /// Shows a rewarded ad; calls [onReward] if the user earned the reward.
  Future<void> showRewarded({required VoidCallback onReward, VoidCallback? onUnavailable}) async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      onUnavailable?.call();
      return;
    }
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadRewarded();
        onUnavailable?.call();
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => onReward());
  }

  BannerAd createBanner({required void Function(Ad) onLoaded, required void Function(Ad, LoadAdError) onFailed}) {
    return BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(onAdLoaded: onLoaded, onAdFailedToLoad: onFailed),
    )..load();
  }

  bool get consentDone => _consentDone;

  /// True when the user must be offered a way to change ad consent (EU/UK).
  Future<bool> privacyOptionsRequired() async {
    if (!_supported) return false;
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Re-opens the consent form so the user can change their choice.
  Future<void> showPrivacyOptions() async {
    if (!_supported) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {}
  }
}
