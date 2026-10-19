import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ad_helper.dart';
import 'drawing/drawing_canvas.dart';
import 'drawing/drawing_controller.dart';
import 'drawing/drawing_models.dart';
import 'l10n/app_localizations.dart';

/// Configure a verified parent-facing support page at build time with:
/// --dart-define=VIBESYNC_SUPPORT_URL=https://your-real-support-page
const String _supportUrl = String.fromEnvironment('VIBESYNC_SUPPORT_URL', defaultValue: '');
const String _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.navya.kids_drawing_studio';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Do not wait for ad/network services before drawing the first frame.
  runApp(const KidsDrawingApp());
}

class KidsDrawingApp extends StatefulWidget {
  const KidsDrawingApp({super.key});
  @override
  State<KidsDrawingApp> createState() => _KidsDrawingAppState();
}

class _KidsDrawingAppState extends State<KidsDrawingApp> {
  Locale _locale = const Locale('en');

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VibeSync Kids Drawing Toddler Paint',
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.amber,
          scaffoldBackgroundColor: const Color(0xFFFFFBEB),
        ),
        home: DrawingStudioScreen(
          onLocaleChanged: (locale) => setState(() => _locale = locale),
        ),
      );
}

class DrawingStudioScreen extends StatefulWidget {
  const DrawingStudioScreen({required this.onLocaleChanged, super.key});
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<DrawingStudioScreen> createState() => _DrawingStudioScreenState();
}

class _DrawingStudioScreenState extends State<DrawingStudioScreen>
    with WidgetsBindingObserver {
  late final DrawingController _drawing;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _isDrawingActive = false;
  bool _isRestoringDrawing = true;
  bool? _hasNetwork;
  bool _parentGateOpen = false;
  bool _updateDialogOpen = false;
  bool _flexibleUpdateInProgress = false;
  bool _checkingFlexibleUpdate = false;
  bool _unlockedPagesChanged = false;
  Timer? _updatePollTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final Set<String> _unlockedPages = {'puppy', 'sunshine'};
  final List<StampKind> _coloringPages = const [
    StampKind.puppy, StampKind.sunshine, StampKind.rocket, StampKind.unicorn,
  ];
  final List<StampKind> _quickStickers = const [
    StampKind.flower, StampKind.house, StampKind.pond, StampKind.fish,
  ];
  StampKind? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drawing = DrawingController();
    unawaited(_restoreDrawing());
    unawaited(_restoreUnlockedPages());
    _listenForConnectivity();
    unawaited(_initializeAdsWithoutBlocking());
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_checkForUpdate()));
  }

  Future<void> _restoreDrawing() async {
    try {
      await _drawing.restore();
    } finally {
      if (mounted) setState(() => _isRestoringDrawing = false);
    }
  }

  Future<void> _restoreUnlockedPages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('vibesync_unlocked_pages_v1');
      if (saved != null && mounted && !_unlockedPagesChanged) {
        setState(() {
          _unlockedPages
            ..clear()
            ..addAll(saved)
            ..add('puppy')
            ..add('sunshine');
        });
      }
    } catch (error) {
      debugPrint('Unlocked-page restore skipped: $error');
    }
  }

  Future<void> _saveUnlockedPages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('vibesync_unlocked_pages_v1', _unlockedPages.toList());
    } catch (error) {
      debugPrint('Unlocked-page save skipped: $error');
    }
  }

  Future<void> _initializeAdsWithoutBlocking() async {
    try {
      await AdHelper.instance.initialize();
      if (mounted) _loadBottomBanner();
    } catch (error) {
      debugPrint('AdMob unavailable; drawing remains usable: $error');
    }
  }

  void _loadBottomBanner() {
    if (!mounted) return;
    _bannerAd = AdHelper.instance.createChildSafeBanner(
      onAdLoaded: () {
        if (mounted) setState(() => _isBannerLoaded = true);
      },
      onAdFailedToLoad: (_) {
        if (mounted) setState(() => _isBannerLoaded = false);
      },
    )..load();
  }

  void _listenForConnectivity() {
    final connectivity = Connectivity();
    unawaited(connectivity.checkConnectivity().then(_applyConnectivity).catchError((Object error) {
      debugPrint('Network status unavailable: $error');
    }));
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      _applyConnectivity,
      onError: (Object error) => debugPrint('Network listener error: $error'),
    );
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;
    final connected = results.any((result) => result != ConnectivityResult.none);
    if (_hasNetwork != connected) setState(() => _hasNetwork = connected);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _flexibleUpdateInProgress) {
      unawaited(_completeFlexibleUpdateIfReady());
    }
  }

  Future<void> _checkForUpdate({bool userInitiated = false}) async {
    if (!Platform.isAndroid) {
      if (userInitiated && mounted) {
        _showMessage(AppLocalizations.of(context).translate('update_check_failed'));
      }
      return;
    }
    if (_updateDialogOpen) return;
    try {
      final info = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (_flexibleUpdateInProgress && info.installStatus == InstallStatus.downloaded) {
        await _completeFlexibleUpdateIfReady();
        return;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        if (userInitiated) _showMessage(AppLocalizations.of(context).translate('no_update'));
        return;
      }

      _updateDialogOpen = true;
      final l10n = AppLocalizations.of(context);
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.system_update_alt, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.translate('update'))),
          ]),
          content: Text(l10n.translate('update_available')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.translate('update_later')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.translate('update_now')),
            ),
          ],
        ),
      );
      _updateDialogOpen = false;
      if (proceed != true || !mounted) return;
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        _flexibleUpdateInProgress = true;
        _startFlexibleUpdatePolling();
        _showMessage(l10n.translate('update_started'));
      } else {
        await launchUrl(Uri.parse(_playStoreUrl), mode: LaunchMode.externalApplication);
      }
    } catch (error) {
      _updateDialogOpen = false;
      debugPrint('In-app update check unavailable: $error');
      if (userInitiated && mounted) {
        _showMessage(AppLocalizations.of(context).translate('update_check_failed'));
      }
    }
  }

  void _startFlexibleUpdatePolling() {
    _updatePollTimer?.cancel();
    var attempts = 0;
    _updatePollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted || !_flexibleUpdateInProgress || attempts++ > 90) {
        timer.cancel();
        return;
      }
      await _completeFlexibleUpdateIfReady();
    });
  }

  Future<void> _completeFlexibleUpdateIfReady() async {
    if (_checkingFlexibleUpdate || !_flexibleUpdateInProgress || !Platform.isAndroid) return;
    _checkingFlexibleUpdate = true;
    try {
      final info = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 6));
      if (info.installStatus == InstallStatus.downloaded) {
        _updatePollTimer?.cancel();
        final l10n = AppLocalizations.of(context);
        if (!mounted) return;
        final install = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.translate('update_ready')),
            content: Text(l10n.translate('update_available')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.translate('update_later')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.translate('update_install')),
              ),
            ],
          ),
        );
        if (install == true) {
          await InAppUpdate.completeFlexibleUpdate();
          _flexibleUpdateInProgress = false;
        } else {
          _startFlexibleUpdatePolling();
        }
      }
    } catch (error) {
      debugPrint('Flexible update status unavailable: $error');
    } finally {
      _checkingFlexibleUpdate = false;
    }
  }

  Future<bool> _showParentalGate() async {
    if (_parentGateOpen || !mounted) return false;
    _parentGateOpen = true;
    final random = Random();
    int a = random.nextInt(8) + 5;
    int b = random.nextInt(7) + 3;
    bool hasError = false;
    List<int> options = _gateOptions(a + b, random);
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.shield_outlined, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.translate('parent_gate_title'))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.translate('parent_gate_desc')),
              const SizedBox(height: 16),
              Text('$a + $b = ?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((value) => ElevatedButton(
                  onPressed: () {
                    if (value == a + b) {
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      setDialogState(() {
                        a = random.nextInt(8) + 5;
                        b = random.nextInt(7) + 3;
                        options = _gateOptions(a + b, random);
                        hasError = true;
                      });
                    }
                  },
                  child: Text('$value'),
                )).toList(),
              ),
              if (hasError) ...[
                const SizedBox(height: 8),
                Text(l10n.translate('incorrect_answer'), style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.translate('cancel')),
            ),
          ],
        ),
      ),
    );
    _parentGateOpen = false;
    return result == true;
  }

  List<int> _gateOptions(int answer, Random random) {
    final values = <int>{answer};
    while (values.length < 4) {
      final offset = random.nextInt(7) + 1;
      values.add(max(1, answer + (random.nextBool() ? offset : -offset)));
    }
    return values.toList()..shuffle(random);
  }

  Future<void> _openSupportPage() async {
    if (!await _showParentalGate() || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final supportUri = Uri.tryParse(_supportUrl);
    if (_supportUrl.isEmpty || supportUri == null || supportUri.scheme != 'https') {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.translate('support_title')),
          content: Text(l10n.translate('support_not_configured')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('cancel')),
            ),
          ],
        ),
      );
      return;
    }
    try {
      final launched = await launchUrl(supportUri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) _showMessage(l10n.translate('support_failed'));
    } catch (error) {
      debugPrint('Support page could not be opened: $error');
      if (mounted) _showMessage(l10n.translate('support_failed'));
    }
  }

  Future<void> _clearCanvas() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.translate('clear')),
        content: Text(l10n.translate('clear_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.translate('clear_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.translate('clear_confirm_button')),
          ),
        ],
      ),
    );
    if (confirmed == true) setState(_drawing.clearCanvas);
  }

  void _unlockWithRewardedAd(StampKind kind) {
    unawaited(_showParentalGate().then((verified) {
      if (!verified || !mounted) return;
      AdHelper.instance.showRewardedAd(
        onUserEarnedReward: (_) {
          if (!mounted) return;
          setState(() {
            _unlockedPages.add(kind.name);
            _selectedTemplate = kind;
            _unlockedPagesChanged = true;
          });
          unawaited(_saveUnlockedPages());
          _showMessage('🎉 ' + AppLocalizations.of(context).translate(_stampKey(kind)));
        },
        onAdClosed: () {},
        onAdNotReady: (message) {
          if (mounted) _showMessage(message);
        },
      );
    }));
  }

  void _showColoringPagesSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.translate('bonus_pages'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._coloringPages.map((kind) {
                final unlocked = _unlockedPages.contains(kind.name);
                return ListTile(
                  leading: Icon(
                    unlocked ? Icons.palette_outlined : Icons.lock_rounded,
                    color: unlocked ? Colors.green : Colors.orange,
                  ),
                  title: Text(l10n.translate(_stampKey(kind))),
                  subtitle: unlocked ? Text(l10n.translate('ready')) : null,
                  trailing: unlocked
                      ? TextButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            setState(() {
                              _selectedTemplate = kind;
                              _drawing.selectTool(ActiveTool.brush);
                            });
                          },
                          child: Text(l10n.translate('use')),
                        )
                      : FilledButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _unlockWithRewardedAd(kind);
                          },
                          child: Text(l10n.translate('unlock')),
                        ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _stampKey(StampKind kind) => 'stamp_' + kind.name;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updatePollTimer?.cancel();
    _connectivitySubscription?.cancel();
    _bannerAd?.dispose();
    _drawing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brushColors = <Color>[
      Colors.red, Colors.deepOrange, Colors.amber, Colors.green,
      Colors.blue, Colors.purple, Colors.pink, Colors.brown, Colors.black,
    ];
    final backgrounds = <Color>[
      Colors.white, const Color(0xFFFFFBEB), const Color(0xFFE0F2FE),
      const Color(0xFFFCE7F3), const Color(0xFFDCFCE7), const Color(0xFFEDE9FE),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('app_title'), maxLines: 1, overflow: TextOverflow.ellipsis),
        elevation: 0,
        backgroundColor: Colors.amber[300],
        actions: [
          IconButton(
            tooltip: l10n.translate('update'),
            onPressed: () => unawaited(_checkForUpdate(userInitiated: true)),
            icon: const Icon(Icons.system_update_alt),
          ),
          PopupMenuButton<Locale>(
            tooltip: 'Language / Idioma / भाषा / 语言',
            onSelected: widget.onLocaleChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(value: Locale('en'), child: Text('English')),
              PopupMenuItem(value: Locale('es'), child: Text('Español')),
              PopupMenuItem(value: Locale('hi'), child: Text('हिन्दी')),
              PopupMenuItem(value: Locale('zh'), child: Text('中文')),
              PopupMenuItem(value: Locale('de'), child: Text('Deutsch')),
              PopupMenuItem(value: Locale('fr'), child: Text('Français')),
            ],
            icon: const Icon(Icons.translate),
          ),
          IconButton(
            tooltip: l10n.translate('support_coffee'),
            onPressed: _openSupportPage,
            icon: const Icon(Icons.coffee_outlined),
          ),
          IconButton(
            tooltip: l10n.translate('bonus_pages'),
            icon: const Icon(Icons.auto_awesome, color: Colors.purple),
            onPressed: _showColoringPagesSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hasNetwork == false)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFFFF3CD),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.brown),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate('offline_message'),
                      style: const TextStyle(fontSize: 12, color: Colors.brown),
                    ),
                  ),
                  TextButton(
                    onPressed: _openSupportPage,
                    child: Text(l10n.translate('support'), maxLines: 1),
                  ),
                ],
              ),
            ),
          _buildActions(l10n),
          _buildBrushStyles(l10n),
          _buildBrushColors(l10n, brushColors),
          _buildBackgroundColors(l10n, backgrounds),
          _buildStickers(l10n),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DrawingCanvas(
                  controller: _drawing,
                  guideTemplate: _selectedTemplate,
                  onDrawingStateChanged: (active) => setState(() => _isDrawingActive = active),
                ),
                if (_isRestoringDrawing)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(l10n.translate('restoring'), style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                if (_drawing.strokes.isEmpty && _drawing.stamps.isEmpty &&
                    _selectedTemplate == null && !_isRestoringDrawing)
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          l10n.translate('draw_here'),
                          style: TextStyle(color: Colors.blueGrey.withOpacity(0.50), fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: 10,
            width: double.infinity,
            color: Colors.amber[100],
            child: const Center(child: Divider(height: 1, thickness: 1, color: Colors.amber)),
          ),
          SafeArea(
            top: false,
            child: Container(
              alignment: Alignment.center,
              width: double.infinity,
              height: 52,
              color: Colors.white,
              child: _isBannerLoaded && _bannerAd != null
                  ? SizedBox(
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    )
                  : Text(
                      l10n.translate('ad_area'),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(AppLocalizations l10n) => SizedBox(
        height: 52,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.translate('undo'),
                onPressed: _drawing.canUndo && !_isDrawingActive ? () => setState(_drawing.undo) : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: l10n.translate('redo'),
                onPressed: _drawing.canRedo && !_isDrawingActive ? () => setState(_drawing.redo) : null,
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                tooltip: l10n.translate('clear'),
                onPressed: _isDrawingActive ? null : _clearCanvas,
                icon: const Icon(Icons.delete_outline),
              ),
              const VerticalDivider(indent: 10, endIndent: 10),
              ChoiceChip(
                selected: _drawing.activeTool == ActiveTool.brush,
                avatar: const Icon(Icons.brush, size: 17),
                label: Text(l10n.translate('brush')),
                onSelected: _isDrawingActive ? null : (_) => setState(() => _drawing.selectTool(ActiveTool.brush)),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                selected: _drawing.activeTool == ActiveTool.stamp,
                avatar: const Icon(Icons.auto_awesome, size: 17),
                label: Text(l10n.translate('stickers')),
                onSelected: _isDrawingActive ? null : (_) => setState(() => _drawing.selectTool(ActiveTool.stamp)),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: l10n.translate('bucket_unavailable'),
                child: Chip(
                  avatar: const Icon(Icons.format_color_fill, size: 17),
                  label: const Text('Bucket'),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildBrushStyles(AppLocalizations l10n) => SizedBox(
        height: 44,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(l10n.translate('brush_style'), style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              for (final style in StrokeStyle.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(l10n.translate(style.name)),
                    selected: _drawing.brushStyle == style,
                    onSelected: _isDrawingActive ? null : (_) => setState(() => _drawing.selectBrushStyle(style)),
                  ),
                ),
              const SizedBox(width: 6),
              Text(l10n.translate('brush_size'), style: const TextStyle(fontSize: 12)),
              SizedBox(
                width: 110,
                child: Slider(
                  min: 2, max: 20, divisions: 9,
                  value: _drawing.brushWidth.clamp(2, 20).toDouble(),
                  onChanged: _isDrawingActive ? null : (value) => setState(() => _drawing.selectBrushWidth(value)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildBrushColors(AppLocalizations l10n, List<Color> colors) => SizedBox(
        height: 42,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Text(l10n.translate('colors'), style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                itemCount: colors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 5),
                itemBuilder: (context, index) => _colorButton(
                  colors[index],
                  selected: _drawing.brushColor == colors[index],
                  onPressed: () => setState(() => _drawing.selectBrushColor(colors[index])),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildBackgroundColors(AppLocalizations l10n, List<Color> colors) => SizedBox(
        height: 40,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Text(l10n.translate('background'), style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                itemCount: colors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _colorButton(
                  colors[index],
                  selected: _drawing.backgroundColor == colors[index],
                  onPressed: () => setState(() => _drawing.setBackgroundColor(colors[index])),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _colorButton(Color color, {required bool selected, required VoidCallback onPressed}) =>
      Semantics(
        button: true,
        selected: selected,
        label: 'Color ' + color.value.toRadixString(16),
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.black87 : Colors.black12,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        ),
      );

  Widget _buildStickers(AppLocalizations l10n) => SizedBox(
        height: 50,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Text(l10n.translate('stickers'), style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _quickStickers.map((kind) {
                  final selected = _drawing.activeTool == ActiveTool.stamp && _drawing.selectedStamp == kind;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                    child: ChoiceChip(
                      avatar: Icon(_stampIcon(kind), size: 16),
                      label: Text(l10n.translate(_stampKey(kind))),
                      selected: selected,
                      onSelected: _isDrawingActive ? null : (_) => setState(() => _drawing.selectStamp(kind)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );

  IconData _stampIcon(StampKind kind) => switch (kind) {
        StampKind.puppy => Icons.pets,
        StampKind.sunshine => Icons.wb_sunny_outlined,
        StampKind.rocket => Icons.rocket_launch_outlined,
        StampKind.unicorn => Icons.auto_awesome,
        StampKind.house => Icons.house_outlined,
        StampKind.flower => Icons.local_florist_outlined,
        StampKind.pond => Icons.water,
        StampKind.fish => Icons.set_meal_outlined,
      };
}