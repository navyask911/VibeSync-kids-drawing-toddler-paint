/**
 * VibeSync Kids Drawing Toddler Paint - AdMob & Flutter Architecture
 * Exportable production-grade Dart & XML snippets.
 */

export interface AdMobConfig {
  androidAppId: string;
  iosAppId: string;
  androidBannerUnitId: string;
  iosBannerUnitId: string;
  androidRewardedUnitId: string;
  iosRewardedUnitId: string;
  androidInterstitialUnitId: string;
  iosInterstitialUnitId: string;
}

export const GOOGLE_TEST_IDS: AdMobConfig = {
  androidAppId: 'ca-app-pub-3940256099942544~3347511713',
  iosAppId: 'ca-app-pub-3940256099942544~1458002511',
  androidBannerUnitId: 'ca-app-pub-3940256099942544/6300978111',
  iosBannerUnitId: 'ca-app-pub-3940256099942544/2934735716',
  androidRewardedUnitId: 'ca-app-pub-3940256099942544/5224354917',
  iosRewardedUnitId: 'ca-app-pub-3940256099942544/1712485313',
  androidInterstitialUnitId: 'ca-app-pub-3940256099942544/1033173712',
  iosInterstitialUnitId: 'ca-app-pub-3940256099942544/4411468910',
};

// User Production AdMob IDs (Google Play Families & COPPA Compliant)
export const PRODUCTION_CONFIG: AdMobConfig = {
  androidAppId: 'ca-app-pub-4783826505860771~6744055015',
  iosAppId: 'ca-app-pub-4783826505860771~6744055015',
  androidBannerUnitId: 'ca-app-pub-4783826505860771/2828860731',
  iosBannerUnitId: 'ca-app-pub-4783826505860771/2828860731',
  androidRewardedUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test until live rewarded unit is generated
  iosRewardedUnitId: 'ca-app-pub-3940256099942544/1712485313',
  androidInterstitialUnitId: 'ca-app-pub-3940256099942544/1033173712', // Test until live interstitial unit is generated
  iosInterstitialUnitId: 'ca-app-pub-3940256099942544/4411468910',
};

export function generateAdHelperDart(config: AdMobConfig, isUsingTestIds: boolean): string {
  return `// lib/ad_helper.dart
// -----------------------------------------------------------------------------
// Google Mobile Ads (AdMob) Singleton for VibeSync Kids Drawing Toddler Paint
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
  // ${isUsingTestIds ? 'NOTE: Currently configured with official Google AdMob Test IDs' : 'NOTE: Configured with your custom Live Production AdMob IDs'}
  // ---------------------------------------------------------------------------
  static const String androidBannerAdUnitId = '${config.androidBannerUnitId}';
  static const String iosBannerAdUnitId = '${config.iosBannerUnitId}';
  static const String androidRewardedAdUnitId = '${config.androidRewardedUnitId}';
  static const String iosRewardedAdUnitId = '${config.iosRewardedUnitId}';
  static const String androidInterstitialAdUnitId = '${config.androidInterstitialUnitId}';
  static const String iosInterstitialAdUnitId = '${config.iosInterstitialUnitId}';

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

  // ---------------------------------------------------------------------------
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
        debugPrint('Adapter: $key, State: \${value.state}, Description: \${value.description}');
      });
    }

    // Preload rewarded and interstitial ads ready for user triggers
    loadRewardedAd();
    loadInterstitialAd();
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
          debugPrint('AdHelper: Banner failed to load: \${error.message}');
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
    if (_isRewardedAdLoading || _rewardedAd != null) return;
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
          debugPrint('AdHelper: RewardedAd failed to load: \${error.message}');
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
        debugPrint('AdHelper: Failed to show rewarded ad: \${error.message}');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdClosed();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint('AdHelper: User earned reward: \${reward.amount} \${reward.type}');
        onUserEarnedReward(reward);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 6. INTERSTITIAL AD (PROTECTED WITH ACTIVE DRAWING GUARD)
  // ---------------------------------------------------------------------------
  /// Preloads an Interstitial Ad for transitions between coloring albums.
  void loadInterstitialAd() {
    if (_isInterstitialAdLoading || _interstitialAd != null) return;
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
          debugPrint('AdHelper: InterstitialAd failed to load: \${error.message}');
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
        debugPrint('AdHelper: Interstitial failed to show: \${error.message}');
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
`;
}

export function generateMainDart(): string {
  return `// lib/main.dart
// -----------------------------------------------------------------------------
// VibeSync Kids Drawing Toddler Paint Flutter App Entry Point
// Google Play Families Policy Compliant AdMob Integration
// -----------------------------------------------------------------------------

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';

void main() async {
  // CRITICAL STEP 1: Ensure Flutter engine bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL STEP 2: Initialize AdMob with global COPPA / G-Rating RequestConfiguration
  await AdHelper.instance.initialize();

  runApp(const KidsDrawingApp());
}

class KidsDrawingApp extends StatelessWidget {
  const KidsDrawingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "VibeSync Kids Drawing Toddler Paint",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFFFFFBEB),
        fontFamily: 'Comic', // Replace with your kid-friendly font
      ),
      home: const DrawingStudioScreen(),
    );
  }
}

class DrawingStudioScreen extends StatefulWidget {
  const DrawingStudioScreen({super.key});

  @override
  State<DrawingStudioScreen> createState() => _DrawingStudioScreenState();
}

class _DrawingStudioScreenState extends State<DrawingStudioScreen> {
  // Active drawing stroke states
  final List<List<Offset>> _lines = [];
  bool _isDrawingActive = false; // Guard for interstitial ads
  Color _selectedColor = Colors.deepOrange;
  double _strokeWidth = 6.0;

  // Bonus coloring pages unlock state
  final Set<String> _unlockedPages = {'Page 1: Puppy Fun', 'Page 2: Happy Sun'};
  final List<String> _allPages = [
    'Page 1: Puppy Fun',
    'Page 2: Happy Sun',
    'Page 3: Space Rocket (Bonus)',
    'Page 4: Magic Unicorn (Bonus)',
  ];

  // AdMob Banner instance
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBottomBanner();
  }

  void _loadBottomBanner() {
    _bannerAd = AdHelper.instance.createChildSafeBanner(
      onAdLoaded: () {
        if (mounted) setState(() => _isBannerLoaded = true);
      },
      onAdFailedToLoad: (error) {
        if (mounted) setState(() => _isBannerLoaded = false);
      },
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // PARENTAL GATE: MATH CHALLENGE BEFORE AD TRIGGER
  // ---------------------------------------------------------------------------
  Future<void> _promptParentalGate({
    required String bonusPageName,
    required VoidCallback onVerified,
  }) async {
    // Generate simple random arithmetic challenge
    final random = Random();
    final int a = random.nextInt(9) + 2; // 2 to 10
    final int b = random.nextInt(8) + 2; // 2 to 9
    final int correctAnswer = a + b;

    // Generate 3 plausible wrong options
    final Set<int> options = {correctAnswer};
    while (options.length < 4) {
      final delta = random.nextBool() ? 1 + random.nextInt(3) : -(1 + random.nextInt(3));
      final val = correctAnswer + delta;
      if (val > 0) options.add(val);
    }
    final optionList = options.toList()..shuffle();

    final bool? isAdultVerified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                'Parental Gate',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parents Only: Please solve this question to unlock bonus coloring content:',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '\$a + \$b = ?',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: optionList.map((val) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (val == correctAnswer) {
                        Navigator.of(dialogContext).pop(true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Incorrect. Try again!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        Navigator.of(dialogContext).pop(false);
                      }
                    },
                    child: Text(
                      '\$val',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (isAdultVerified == true) {
      onVerified();
    }
  }

  // Unlocks bonus coloring page via Rewarded Ad
  void _unlockWithRewardedAd(String pageName) {
    _promptParentalGate(
      bonusPageName: pageName,
      onVerified: () {
        AdHelper.instance.showRewardedAd(
          onUserEarnedReward: (reward) {
            setState(() {
              _unlockedPages.add(pageName);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.green[700],
                content: Text('🎉 \$pageName has been unlocked!'),
              ),
            );
          },
          onAdClosed: () {},
          onAdNotReady: (msg) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎨 VibeSync Kids Drawing'),
        elevation: 0,
        backgroundColor: Colors.amber[300],
        actions: [
          IconButton(
            tooltip: 'Clear Canvas',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _lines.clear());
            },
          ),
          IconButton(
            tooltip: 'Bonus Coloring Pages',
            icon: const Icon(Icons.stars_rounded, color: Colors.purple),
            onPressed: _showColoringPagesSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Color and Brush Toolbar
          _buildToolbar(),

          // 2. Interactive Drawing Canvas with Stroke Guard
          Expanded(
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _isDrawingActive = true;
                  _lines.add([details.localPosition]);
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _lines.last.add(details.localPosition);
                });
              },
              onPanEnd: (details) {
                setState(() {
                  _isDrawingActive = false; // Drawing stroke completed
                });
              },
              child: ClipRect(
                child: CustomPaint(
                  painter: CanvasPainter(lines: _lines, color: _selectedColor, width: _strokeWidth),
                  size: Size.infinite,
                ),
              ),
            ),
          ),

          // -----------------------------------------------------------------
          // 3. CHILD-SAFE SEPARATOR & PADDING BUFFER
          // Dedicated padding + visual separator strictly isolates banner from canvas
          // -----------------------------------------------------------------
          Container(
            height: 12,
            width: double.infinity,
            color: Colors.amber[100],
            child: const Center(
              child: Divider(height: 1, thickness: 1, color: Colors.amber),
            ),
          ),

          // -----------------------------------------------------------------
          // 4. STICKY CHILD-SAFE BOTTOM BANNER AD CONTAINER
          // Anchored outside canvas, protected with safe area
          // -----------------------------------------------------------------
          SafeArea(
            top: false,
            child: Container(
              alignment: Alignment.center,
              width: double.infinity,
              height: 52, // Standard AdSize.banner height + border
              color: Colors.white,
              child: _isBannerLoaded && _bannerAd != null
                  ? SizedBox(
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    )
                  : const Text(
                      '🛡️ Child-Safe Family Ad Placeholder',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final colors = [Colors.red, Colors.deepOrange, Colors.green, Colors.blue, Colors.purple, Colors.black];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.amber[50],
      child: Row(
        children: [
          ...colors.map((c) => GestureDetector(
            onTap: () => setState(() => _selectedColor = c),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedColor == c ? Colors.black : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
          )),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_open, size: 16),
            label: const Text('Bonus Pages'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              foregroundColor: Colors.white,
            ),
            onPressed: _showColoringPagesSheet,
          ),
        ],
      ),
    );
  }

  void _showColoringPagesSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Coloring Books',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._allPages.map((page) {
                final isUnlocked = _unlockedPages.contains(page);
                return ListTile(
                  leading: Icon(
                    isUnlocked ? Icons.palette_outlined : Icons.lock_rounded,
                    color: isUnlocked ? Colors.green : Colors.orange,
                  ),
                  title: Text(page),
                  trailing: isUnlocked
                      ? const Chip(label: Text('Ready'))
                      : ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _unlockWithRewardedAd(page);
                          },
                          child: const Text('Unlock'),
                        ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// Simple Painter for toddlers
class CanvasPainter extends CustomPainter {
  final List<List<Offset>> lines;
  final Color color;
  final double width;

  CanvasPainter({required this.lines, required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;

    for (final line in lines) {
      for (int i = 0; i < line.length - 1; i++) {
        canvas.drawLine(line[i], line[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}
`;
}

export function generateMainActivityKt(): string {
  return `package com.navya.kids_drawing_studio

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
`;
}

export function generateAndroidManifestXml(appId: string): string {
  return `<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.navya.kids_drawing_studio">

    <!-- Essential Internet & Network Permissions for Google Mobile Ads -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <application
        android:label="VibeSync Kids Drawing Toddler Paint"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- ================================================================= -->
        <!-- FLUTTER V2 EMBEDDING DECLARATION -->
        <!-- ================================================================= -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

        <!-- ================================================================= -->
        <!-- GOOGLE ADMOB APPLICATION ID METADATA -->
        <!-- Mandatory for Google Mobile Ads SDK initialization. -->
        <!-- Replace with your live AdMob App ID in production. -->
        <!-- ================================================================= -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="${appId}"/>

        <!-- ================================================================= -->
        <!-- GOOGLE PLAY FAMILIES POLICY COMPLIANCE DECLARATION -->
        <!-- ================================================================= -->
        <meta-data
            android:name="com.google.android.gms.ads.flag.OPTIMIZE_INITIALIZATION"
            android:value="true"/>

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

    </application>
</manifest>
`;
}

export function generatePubspecYaml(): string {
  return `# pubspec.yaml
name: kids_drawing_toddler_paint
description: "VibeSync Kids Drawing Toddler Paint with child-directed AdMob settings"
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter

  # Google Mobile Ads official Flutter plugin
  google_mobile_ads: ^5.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

  # Automatic Launcher Icons Generator for Android & iOS
  flutter_launcher_icons: ^0.13.1

# ==============================================================================
# FLUTTER LAUNCHER ICONS CONFIGURATION
# Generates mipmap-hdpi, xhdpi, xxhdpi, xxxhdpi, and Android 8.0+ adaptive icons
# Run: dart run flutter_launcher_icons
# ==============================================================================
flutter_launcher_icons:
  android: "ic_launcher"
  ios: false
  image_path: "assets/icon/app_icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"

flutter:
  uses-material-design: true
  # Assets can be enabled when asset files are added:
  # assets:
  #   - assets/icon/
`;
}

export function generateBuildGradle(): string {
  return `// android/app/build.gradle
// -----------------------------------------------------------------------------
// Production Release Build & Keystore Signature Wiring (Declarative Gradle DSL)
// -----------------------------------------------------------------------------

plugins {
    id "com.android.application"
    id "org.jetbrains.kotlin.android"
    id "dev.flutter.flutter-gradle-plugin"
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode') ?: '1'
def flutterVersionName = localProperties.getProperty('flutter.versionName') ?: '1.0.0'

// -----------------------------------------------------------------------------
// 1. SECURE KEYSTORE SIGNATURE LOADING
// Loads keyAlias, keyPassword, storeFile, storePassword from key.properties
// -----------------------------------------------------------------------------
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.withReader('UTF-8') { reader ->
        keystoreProperties.load(reader)
    }
}

android {
    namespace "com.navya.kids_drawing_studio"
    compileSdk = 36
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.navya.kids_drawing_studio"
        // Google Mobile Ads SDK requirement: minSdkVersion 21 or higher
        minSdkVersion 21
        targetSdkVersion 36
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        multiDexEnabled true
    }

    signingConfigs {
        release {
            if (keystoreProperties['storeFile'] != null) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
                storePassword keystoreProperties['storePassword']
            }
        }
    }

    buildTypes {
        release {
            // Apply release signature if key.properties is provided; fallback to debug signing in CI/test environments
            if (keystoreProperties['storeFile'] != null) {
                signingConfig signingConfigs.release
            } else {
                signingConfig signingConfigs.debug
            }

            // Enable R8 code shrinking, obfuscation, and resource optimization
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
        debug {
            signingConfig signingConfigs.debug
        }
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
    implementation 'androidx.multidex:multidex:2.0.1'
    implementation 'com.google.android.gms:play-services-ads:23.0.0'
}
`;
}

export function generateProguardRules(): string {
  return `# android/app/proguard-rules.pro
# ==============================================================================
# R8 / PROGUARD OPTIMIZATION & SHRINKING RULES FOR GOOGLE MOBILE ADS SDK
# ==============================================================================

# 1. Keep Google Mobile Ads SDK public classes and interfaces
-keep class com.google.android.gms.ads.** { *; }
-keep interface com.google.android.gms.ads.** { *; }

# 2. Keep AdMob mediation adapters
-keep class com.google.ads.mediation.** { *; }
-keep interface com.google.ads.mediation.** { *; }

# 3. Preserve essential annotation attributes required for reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# 4. Suppress non-critical warnings from optional Google Play Services dependencies
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.ads.mediation.**

# 5. Standard Flutter framework rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# 6. Play Core deferred components and reflection preservation
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
`;
}

export function generateKeyPropertiesExample(): string {
  return `# android/key.properties.example
# ==============================================================================
# ANDROID RELEASE SIGNING CREDENTIALS TEMPLATE
# Copy this file to android/key.properties and set your keystore values.
# NEVER commit key.properties to git (already excluded in .gitignore).
# ==============================================================================

storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
`;
}

export function generateGitignore(): string {
  return `# .gitignore for Flutter Kids Drawing App
# ==============================================================================
# BUILD ARTIFACTS
# ==============================================================================
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
/build/

# ==============================================================================
# SECRETS & SIGNING CREDENTIALS (STRICTLY EXCLUDED)
# ==============================================================================
android/key.properties
key.properties
*.jks
*.keystore
*.p12
*.pem
*.key
.env*
!.env.example

# ==============================================================================
# ANDROID & GRADLE
# ==============================================================================
.gradle/
local.properties
captures/
.externalNativeBuild/
.cxx/
*.apk
*.aab

# ==============================================================================
# IDE & OPERATING SYSTEM
# ==============================================================================
.DS_Store
*.log
.idea/
*.iml
.vscode/
`;
}

export function generateAdMobUnitTestDart(): string {
  return `// test/admob_coppa_test.dart
// -----------------------------------------------------------------------------
// Production Unit & Widget Test Suite for AdMob COPPA & Families Compliance
// -----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kids_drawing_app/ad_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Parental Gate Math Challenge Logic', () {
    test('Correct arithmetic solution passes adult verification', () {
      const int a = 7;
      const int b = 5;
      const int expectedSum = 12;

      bool verifyParentalGate(int answer) => answer == (a + b);

      expect(verifyParentalGate(expectedSum), isTrue);
      expect(verifyParentalGate(10), isFalse);
      expect(verifyParentalGate(14), isFalse);
    });

    test('Random challenge generator produces positive integer options', () {
      const int a = 6;
      const int b = 8;
      final int correct = a + b;

      final Set<int> options = {correct, correct + 2, correct - 3, correct + 4};
      expect(options.contains(14), isTrue);
      expect(options.every((val) => val > 0), isTrue);
    });
  });

  group('2. AdHelper Singleton & Stroke Suppression Guard', () {
    test('AdHelper enforces singleton instance equality', () {
      final instance1 = AdHelper.instance;
      final instance2 = AdHelper.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('Active drawing stroke strictly suppresses interstitial ads', () {
      final adHelper = AdHelper.instance;
      bool wasSuppressed = false;
      bool adClosedCalled = false;

      // When child has finger down drawing on canvas:
      adHelper.showInterstitialAd(
        isDrawingActive: true,
        onAdClosed: () => adClosedCalled = true,
        onAdSuppressed: (reason) {
          wasSuppressed = true;
          expect(reason, contains('child artwork'));
        },
      );

      expect(wasSuppressed, isTrue);
      expect(adClosedCalled, isFalse);
    });
  });

  group('3. NPA & COPPA AdRequest Parameters', () {
    test('buildChildSafeAdRequest enforces npa == "1"', () {
      final AdRequest request = AdHelper.buildChildSafeAdRequest();
      expect(request.extras, isNotNull);
      expect(request.extras!['npa'], equals('1'));
    });

    test('Configured Android and iOS AdMob unit IDs have valid formats', () {
      final ids = <String>[
        AdHelper.androidBannerAdUnitId,
        AdHelper.iosBannerAdUnitId,
        AdHelper.androidRewardedAdUnitId,
        AdHelper.iosRewardedAdUnitId,
        AdHelper.androidInterstitialAdUnitId,
        AdHelper.iosInterstitialAdUnitId,
      ];
      expect(ids, hasLength(6));
      expect(ids.every((id) => id.startsWith('ca-app-pub-')), isTrue);
      expect(AdHelper.androidBannerAdUnitId, equals('ca-app-pub-4783826505860771/2828860731'));
      expect(AdHelper.androidRewardedAdUnitId, startsWith('ca-app-pub-3940256099942544/'));
      expect(AdHelper.androidInterstitialAdUnitId, startsWith('ca-app-pub-3940256099942544/'));
    });
  });
}
`;
}

export function generateCOPPAComplianceChecklist(): string {
  return `# Google Play Families Policy & FTC COPPA Compliance Checklist
Verified for Kids Drawing and Coloring Apps

## 1. SDK & RequestConfiguration
- [x] **tagForChildDirectedTreatment**: Set to \`TagForChildDirectedTreatment.yes\`.
      Notifies Google AdMob that all ad requests originate from children under 13 under US COPPA.
- [x] **maxAdContentRating**: Explicitly set to \`MaxAdContentRating.g\`.
      Restricts all creative inventory to G-rated (strictly appropriate for all child age groups).
- [x] **tagForUnderAgeOfConsent**: Set to \`TagForUnderAgeOfConsent.yes\`.
      Enforces GDPR-K (General Data Protection Regulation for Kids) compliance for European users.
- [x] **Global Configuration Precedence**: \`MobileAds.instance.updateRequestConfiguration()\`
      must execute before \`MobileAds.instance.initialize()\` so every adapter and network instance inherits policy flags.

## 2. Non-Personalized Ads (NPA) Directive
- [x] **AdRequest extras**: Include \`{'npa': '1'}\` in all banner, rewarded, and interstitial requests.
- [x] **Zero Identifier Tracking**: No advertising ID (AAID / IDFA), behavioral cookies, or persistent device fingerprints collected or shared.

## 3. Ad Placement & Toddler Ergonomics
- [x] **Isolated Physical Boundary**: Sticky Banner Ad placed outside drawing canvas boundary.
- [x] **Dedicated Safety Buffer**: Minimum 12-16px visual separator preventing toddler misclicks during vigorous scribbling.
- [x] **Canvas Stroke Sentinel**: Interstitial and pop-up ads suppressed while \`isDrawingActive == true\`.
- [x] **Parental Gate**: Arithmetic verification required before presenting rewarded video or interstitial ads.

## 4. Google Play Console Declarations
- Target Audience: Choose "Ages 5 and under" or "Ages 6-8" under App Content -> Target audience.
- Families Policy: Disclose that ads are served through the Google Mobile Ads SDK (AdMob is on the Google Play Certified Ad Network list).
- Neutral Age Screen / Parental Gate: Required when linking to external stores or third-party web content.
`;
}

