// lib/main.dart
// -----------------------------------------------------------------------------
// Flutter Kids Drawing & Coloring App Entry Point
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
  final double _strokeWidth = 6.0;

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
    final random = Random();
    final int a = random.nextInt(8) + 2; // 2 to 9
    final int b = random.nextInt(7) + 2; // 2 to 8
    final int correctAnswer = a + b;

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
                  '$a + $b = ?',
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
                      '$val',
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
                content: Text('🎉 $pageName has been unlocked!'),
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
