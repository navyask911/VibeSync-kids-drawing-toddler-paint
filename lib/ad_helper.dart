// lib/ad_helper.dart
// -----------------------------------------------------------------------------
// Google Mobile Ads (AdMob) Singleton for Flutter Kids Drawing App
// Strict COPPA, GDPR-K, and Google Play Families Policy Compliance
// -----------------------------------------------------------------------------

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // Private constructor for Singleton pattern
  AdHelper._internal();
  static final AdHelper instance = AdHelper._internal();

  // Initialization flag
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Active ad instances
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;

  // ---------------------------------------------------------------------------
  // 1. ADMOB UNIT IDENTIFIERS
  // Rewarded/interstitial currently use official Google test units.
  static const String androidBannerAdUnitId = 'ca-app-pub-4783826505860771/2828860731';
  static const String iosBannerAdUnitId = 'ca-app-pub-4783826505860771/2828860731';
  // Official test units are used only in debug builds. Configure the production
  // units through --dart-define before enabling ads for those formats in release.
  static const String androidRewardedTestAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String iosRewardedTestAdUnitId = 'ca-app-pub-3940256099942544/1712485313';
  static const String androidInterstitialTestAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String iosInterstitialTestAdUnitId = 'ca-app-pub-3940256099942544/4411468910';

  static const String _androidRewardedProductionAdUnitId =
      String.fromEnvironment('ADMOB_REWARDED_ANDROID');
  static const String _iosRewardedProductionAdUnitId =
      String.fromEnvironment('ADMOB_REWARDED_IOS');
  static const String _androidInterstitialProductionAdUnitId =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID');
  static const String _iosInterstitialProductionAdUnitId =
      String.fromEnvironment('ADMOB_INTERSTITIAL_IOS');

  static String get androidRewardedAdUnitId =>
      kDebugMode ? androidRewardedTestAdUnitId : _androidRewardedProductionAdUnitId;
  static String get iosRewardedAdUnitId =>
      kDebugMode ? iosRewardedTestAdUnitId : _iosRewardedProductionAdUnitId;
  static String get androidInterstitialAdUnitId =>
      kDebugMode ? androidInterstitialTestAdUnitId : _androidInterstitialProductionAdUnitId;
  static String get iosInterstitialAdUnitId =>
      kDebugMode ? iosInterstitialTestAdUnitId : _iosInterstitialProductionAdUnitId;

  static String get bannerAdUnitId {
    if (Platform.isAndroid) return androidBannerAdUnitId;
    if (Platform.isIOS) return iosBannerAdUnitId;
    throw UnsupportedError('Unsupported mobile platform for AdMob');
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) return androidRewardedAdUnitId;
    if (Platform.isIOS) return iosRewardedAdUnitId;
    throw UnsupportedError('Unsupported mobile platform for AdMob');
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) return androidInterstitialAdUnitId;
    if (Platform.isIOS) return iosInterstitialAdUnitId;
    throw UnsupportedError('Unsupported mobile platform for AdMob');
  }

  bool get hasRewardedAdConfigured => rewardedAdUnitId.isNotEmpty;
  bool get hasInterstitialAdConfigured => interstitialAdUnitId.isNotEmpty;

  // 2. COPPA & GOOGLE PLAY FAMILIES GLOBAL INITIALIZATION
  // ---------------------------------------------------------------------------
  /// Initializes the Google Mobile Ads SDK with strict Families Policy settings.
  /// Must be called after WidgetsFlutterBinding.ensureInitialized() in main().
  Future<void> initialize() async {
    if (_isInitialized) return;

    // MANDATORY FAMILIES POLICY & COPPA CONFIGURATION
    // 1. tagForChildDirectedTreatment: Child-directed ad network treatment (COPPA)
    // 2. maxAdContentRating: Only G-rated ads (all ages appropriate)
    // 3. tagForUnderAgeOfConsent: Under-age user protection (GDPR-K / European Union)
    final RequestConfiguration requestConfiguration = RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      maxAdContentRating: MaxAdContentRating.g,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
      testDeviceIds: <String>[
        // Add your real test device hashes here during development:
        // 'YOUR_TEST_DEVICE_HASH_ID',
      ],
    );

    // Apply global request configuration BEFORE initializing the SDK
    await MobileAds.instance.updateRequestConfiguration(requestConfiguration);

    // Initialize MobileAds SDK
    final InitializationStatus status = await MobileAds.instance.initialize();
    _isInitialized = true;

    if (kDebugMode) {
      debugPrint('AdHelper: MobileAds initialized with COPPA G-Rating.');
      status.adapterStatuses.forEach((key, value) {
        debugPrint('Adapter: $key, State: ${value.state}, Description: ${value.description}');
      });
    }

    // Preload only formats with a configured unit ID. In release builds, test
    // IDs are deliberately not substituted for missing production credentials.
    if (hasRewardedAdConfigured) loadRewardedAd();
    if (hasInterstitialAdConfigured) loadInterstitialAd();
  }

  // ---------------------------------------------------------------------------
  // 3. CHILD-SAFE NON-PERSONALIZED AD (NPA) REQUEST BUILDER
  // ---------------------------------------------------------------------------
  /// Returns an AdRequest strictly marked with NPA (Non-Personalized Ads).
  /// Google Play Families Policy strictly forbids behavioral targeting or
  /// device identifiers for advertising tracking on child users.
  static AdRequest buildChildSafeAdRequest() {
    return const AdRequest(
      extras: <String, String>{
        'npa': '1', // Signals Non-Personalized Ads to Google AdMob network
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. CHILD-SAFE BANNER AD FACTORY
  // ---------------------------------------------------------------------------
  /// Creates a BannerAd configured with NPA and error handling.
  /// IMPORTANT: Always place the returned BannerAd in a dedicated layout widget
  /// outside the drawing canvas with sufficient padding to prevent toddler misclicks.
  BannerAd createChildSafeBanner({
    required void Function() onAdLoaded,
    required void Function(LoadAdError error) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: buildChildSafeAdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('AdHelper: Child-safe banner loaded successfully.');
          onAdLoaded();
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('AdHelper: Banner failed to load: ${error.message}');
          ad.dispose();
          onAdFailedToLoad(error);
        },
        onAdOpened: (Ad ad) => debugPrint('AdHelper: Banner ad opened.'),
        onAdClosed: (Ad ad) => debugPrint('AdHelper: Banner ad closed.'),
        onAdImpression: (Ad ad) => debugPrint('AdHelper: Banner ad impression recorded.'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. REWARDED AD (BONUS COLORING PAGE UNLOCK)
  // ---------------------------------------------------------------------------
  /// Preloads a Rewarded Ad for unlocking bonus coloring sheets.
  void loadRewardedAd() {
    if (!hasRewardedAdConfigured || _isRewardedAdLoading || _rewardedAd != null) return;
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: buildChildSafeAdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('AdHelper: Child-safe RewardedAd preloaded.');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdHelper: RewardedAd failed to load: ${error.message}');
          _rewardedAd = null;
          _isRewardedAdLoading = false;
        },
      ),
    );
  }

  /// Displays the rewarded ad to unlock bonus content.
  /// [onUserEarnedReward] is triggered when the adult/kid finishes watching the ad.
  /// Gated by Parental Gate prior to invoking this method.
  void showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
    required void Function() onAdClosed,
    void Function(String message)? onAdNotReady,
  }) {
    if (_rewardedAd == null) {
      debugPrint('AdHelper: Rewarded ad not ready. Reloading...');
      loadRewardedAd();
      onAdNotReady?.call('Ad is currently loading. Please try again in a few moments.');
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        debugPrint('AdHelper: Rewarded ad displayed on screen.');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        debugPrint('AdHelper: Rewarded ad dismissed by user.');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload next instance
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint('AdHelper: Failed to show rewarded ad: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdClosed();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint('AdHelper: User earned reward: ${reward.amount} ${reward.type}');
        onUserEarnedReward(reward);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 6. INTERSTITIAL AD (PROTECTED WITH ACTIVE DRAWING GUARD)
  // ---------------------------------------------------------------------------
  /// Preloads an Interstitial Ad for transitions between coloring albums.
  void loadInterstitialAd() {
    if (!hasInterstitialAdConfigured ||
        _isInterstitialAdLoading ||
        _interstitialAd != null) {
      return;
    }
    _isInterstitialAdLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: buildChildSafeAdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('AdHelper: Child-safe InterstitialAd preloaded.');
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdHelper: InterstitialAd failed to load: ${error.message}');
          _interstitialAd = null;
          _isInterstitialAdLoading = false;
        },
      ),
    );
  }

  /// Displays the interstitial ad ONLY if the child is NOT actively drawing.
  /// [isDrawingActive] MUST be passed from the canvas state.
  /// Never interrupt an active toddler drawing session.
  void showInterstitialAd({
    required bool isDrawingActive,
    required void Function() onAdClosed,
    void Function(String reason)? onAdSuppressed,
  }) {
    // CRITICAL TODDLER SAFETY RULE:
    // Never show an interstitial ad while child has finger down or mid-stroke
    if (isDrawingActive) {
      debugPrint('AdHelper: Interstitial SUPPRESSED because child is actively drawing.');
      onAdSuppressed?.call('Suppressed to avoid interrupting child artwork.');
      return;
    }

    if (_interstitialAd == null) {
      debugPrint('AdHelper: Interstitial ad not ready.');
      loadInterstitialAd();
      onAdClosed();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        debugPrint('AdHelper: Interstitial displayed.');
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        debugPrint('AdHelper: Interstitial dismissed.');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload next
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('AdHelper: Interstitial failed to show: ${error.message}');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdClosed();
      },
    );

    _interstitialAd!.show();
  }

  // ---------------------------------------------------------------------------
  // 7. CLEANUP
  // ---------------------------------------------------------------------------
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}
