import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as image_codec;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'ad_helper.dart';
import 'drawing/drawing_canvas.dart';
import 'drawing/drawing_controller.dart';
import 'drawing/drawing_models.dart';
import 'drawing/drawing_persistence.dart';
import 'drawing/drawing_painters.dart';
import 'l10n/app_localizations.dart';
import 'subscriptions/ad_free_subscription_service.dart';
import 'creative/ai_creative_agent.dart';
import 'export/drawing_export_service.dart';

const String _coffeeSupportUrl = String.fromEnvironment('COFFEE_SUPPORT_URL');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw immediately. Ads/network checks initialize after the first frame so
  // a slow or disconnected network cannot prevent the canvas from opening.
  runApp(const KidsDrawingApp());
}

class KidsDrawingApp extends StatefulWidget {
  const KidsDrawingApp({super.key});

  @override
  State<KidsDrawingApp> createState() => _KidsDrawingAppState();
}

class _KidsDrawingAppState extends State<KidsDrawingApp> {
  Locale? _locale;

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeSync Kids Drawing & Creative Studio Pro',
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFFB300),
        scaffoldBackgroundColor: const Color(0xFFFFFBEB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFD54F),
          foregroundColor: Color(0xFF352713),
          elevation: 0,
        ),
      ),
      home: DrawingStudioScreen(onLocaleChanged: _setLocale),
    );
  }
}

class DrawingStudioScreen extends StatefulWidget {
  const DrawingStudioScreen({super.key, required this.onLocaleChanged});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<DrawingStudioScreen> createState() => _DrawingStudioScreenState();
}

class _DrawingStudioScreenState extends State<DrawingStudioScreen>
    with WidgetsBindingObserver {
  final DrawingController _drawing = DrawingController();
  final DrawingPersistence _persistence = DrawingPersistence();
  final AdFreeSubscriptionService _subscription = AdFreeSubscriptionService();
  final AiCreativeAgent _creativeAgent = AiCreativeAgent();
  bool _subscriptionReady = false;
  bool _chromeVisible = true;
  Timer? _autosaveTimer;
  bool _restoringDrawing = true;
  bool _autosaveInProgress = false;
  bool _autosaveAgain = false;
  final GlobalKey _canvasKey = GlobalKey();
  final Set<ColoringPage> _unlockedPages = <ColoringPage>{
    ColoringPage.puppy,
    ColoringPage.sunshine,
  };

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  bool? _isOnline;
  bool _adsInitializing = false;
  bool _checkingUpdate = false;
  bool _updateAvailable = false;
  bool _updateDownloading = false;
  bool _selectingStampOutline = false;
  AppUpdateInfo? _updateInfo;
  StreamSubscription<InternetStatus>? _internetSubscription;
  StreamSubscription<InstallStatus>? _updateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreLocalDrawing());
    _listenForInternet();
    unawaited(_initializeSubscription());
    if (defaultTargetPlatform == TargetPlatform.android) {
      _updateSubscription = InAppUpdate.installUpdateListener.listen(
        _onInstallStatus,
        onError: (Object error) =>
            debugPrint('In-app update listener unavailable: $error'),
      );
    }
  }

  Future<void> _initializeSubscription() async {
    _subscription.addListener(_onSubscriptionChanged);
    await _subscription.initialize();
    if (!mounted) return;
    setState(() => _subscriptionReady = true);
    _onSubscriptionChanged();
    if (!_subscription.isAdFree && _isOnline == true) {
      unawaited(_initializeAdsIfOnline());
    }
  }

  void _onSubscriptionChanged() {
    AdHelper.instance.setAdsEnabled(!_subscription.isAdFree);
    if (_subscription.isAdFree) {
      final banner = _bannerAd;
      _bannerAd = null;
      _bannerLoaded = false;
      banner?.dispose();
    } else {
      // Expired/revoked premium state cannot keep premium-only tools active
      // from a drawing snapshot restored on an earlier app session.
      if (_drawing.brushStyle.requiresSubscription) {
        _drawing.setBrushStyle(StrokeStyle.solid);
      }
      if (_drawing.selectedPage.requiresSubscription) {
        _drawing.setSelectedPage(ColoringPage.freeDraw);
      }
      if (_drawing.studioMode == StudioMode.proArtist) {
        _drawing.setStudioMode(StudioMode.toddler);
      }
      if (_subscriptionReady && _isOnline == true && mounted) {
        unawaited(_initializeAdsIfOnline());
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _restoreLocalDrawing() async {
    try {
      await _persistence.restore(_drawing);
    } catch (error, stackTrace) {
      // A damaged or outdated local file must never block the drawing app.
      debugPrint('Local drawing restore skipped: $error\\n$stackTrace');
    }
    if (!mounted) return;
    _drawing.addListener(_onDrawingChanged);
    setState(() => _restoringDrawing = false);
  }

  void _onDrawingChanged() {
    if (_restoringDrawing || !mounted) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () {
      unawaited(_saveDrawing());
    });
  }

  Future<void> _saveDrawing() async {
    if (_restoringDrawing) return;
    if (_autosaveInProgress) {
      _autosaveAgain = true;
      return;
    }
    _autosaveInProgress = true;
    try {
      do {
        _autosaveAgain = false;
        try {
          await _persistence.save(_drawing);
        } catch (error) {
          debugPrint('Local drawing autosave skipped: $error');
        }
      } while (_autosaveAgain && mounted);
    } finally {
      _autosaveInProgress = false;
    }
  }

  void _listenForInternet() {
    _internetSubscription = InternetConnection().onStatusChange.listen(
      (status) => _handleInternetStatus(status == InternetStatus.connected),
      onError: (Object error) {
        debugPrint('Internet status check unavailable: $error');
      },
    );
    unawaited(_refreshInternetStatus());
  }

  Future<void> _refreshInternetStatus() async {
    try {
      final online = await InternetConnection().hasInternetAccess;
      _handleInternetStatus(online);
    } catch (error) {
      debugPrint('Initial internet check unavailable: $error');
      if (mounted && _isOnline == null) {
        setState(() => _isOnline = false);
      }
    }
  }

  void _handleInternetStatus(bool online) {
    if (!mounted) return;
    final changed = _isOnline != online;
    if (changed) setState(() => _isOnline = online);
    if (online && changed) {
      if (_subscriptionReady && !_subscription.isAdFree) unawaited(_initializeAdsIfOnline());
      unawaited(_checkForUpdate());
    }
  }

  Future<void> _initializeAdsIfOnline() async {
    if (!_subscriptionReady || _subscription.isAdFree || _isOnline != true || _adsInitializing || AdHelper.instance.isInitialized) {
      return;
    }
    _adsInitializing = true;
    try {
      await AdHelper.instance
          .initialize()
          .timeout(const Duration(seconds: 12));
      if (!mounted || !AdHelper.instance.isInitialized) return;
      _loadBottomBanner();
    } catch (error) {
      debugPrint('Ad initialization deferred: $error');
      if (mounted) setState(() => _bannerLoaded = false);
    } finally {
      _adsInitializing = false;
    }
  }

  void _loadBottomBanner() {
    if (!mounted || !_subscriptionReady || _subscription.isAdFree || _isOnline != true) return;
    _bannerAd?.dispose();
    setState(() {
      _bannerLoaded = false;
      _bannerAd = null;
    });
    try {
      _bannerAd = AdHelper.instance.createChildSafeBanner(
        onAdLoaded: () {
          if (mounted) setState(() => _bannerLoaded = true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('Banner unavailable: ${error.message}');
          if (mounted) setState(() => _bannerLoaded = false);
        },
      )..load();
      setState(() {});
    } catch (error) {
      debugPrint('Banner could not be created: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _autosaveTimer?.cancel();
      unawaited(_saveDrawing());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshInternetStatus());
      unawaited(_subscription.restorePurchases());
      if (_isOnline == true) {
        unawaited(_checkForUpdate());
        if (_subscriptionReady && !_subscription.isAdFree) {
          unawaited(_initializeAdsIfOnline());
        }
      }
    }
  }

  Future<void> _checkForUpdate() async {
    if (!mounted ||
        _isOnline != true ||
        defaultTargetPlatform != TargetPlatform.android ||
        _checkingUpdate) {
      return;
    }
    _checkingUpdate = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!mounted) return;
      final available = info.updateAvailability == UpdateAvailability.updateAvailable &&
          (info.flexibleUpdateAllowed || info.immediateUpdateAllowed);
      setState(() {
        _updateInfo = info;
        _updateAvailable = available;
      });
    } catch (error) {
      // In-app updates only work for eligible Google Play installs. Sideloaded
      // APKs and local emulators commonly return API_NOT_AVAILABLE.
      debugPrint('In-app update check skipped: $error');
    } finally {
      _checkingUpdate = false;
    }
  }

  Future<void> _startUpdate() async {
    final info = _updateInfo;
    if (info == null) return;
    // Starting the Play Store update is an external action in this child-directed app.
    if (!await _promptParentalGate() || !mounted) return;
    try {
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        if (mounted) setState(() => _updateDownloading = true);
      } else if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else {
        _showMessage(AppLocalizations.of(context).translate('update_error'));
      }
    } catch (error) {
      debugPrint('Update could not start: $error');
      if (mounted) {
        _showMessage(AppLocalizations.of(context).translate('update_error'));
      }
    }
  }

  void _onInstallStatus(InstallStatus status) {
    if (!mounted) return;
    if (status == InstallStatus.downloaded) {
      setState(() => _updateDownloading = false);
      unawaited(_completeFlexibleUpdate());
    } else if (status == InstallStatus.downloading ||
        status == InstallStatus.pending) {
      setState(() => _updateDownloading = true);
    }
  }

  Future<void> _completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
      if (mounted) {
        _showMessage(AppLocalizations.of(context).translate('update_downloaded'));
      }
    } catch (error) {
      debugPrint('Flexible update completion failed: $error');
      if (mounted) {
        _showMessage(AppLocalizations.of(context).translate('update_error'));
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<int> _makeAnswerOptions(int sum, Random random) {
    final options = <int>{sum};
    while (options.length < 4) {
      final offset = random.nextInt(7) + 1;
      final value = random.nextBool() ? sum + offset : sum - offset;
      if (value > 0) options.add(value);
    }
    final result = options.toList()..shuffle(random);
    return result;
  }

  Future<bool> _promptParentalGate() async {
    final random = Random();
    var a = random.nextInt(8) + 3;
    var b = random.nextInt(7) + 2;
    var options = _makeAnswerOptions(a + b, random);
    var incorrect = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          icon: const Icon(Icons.family_restroom, size: 34),
          title: Text(AppLocalizations.of(context).translate('parent_gate_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(AppLocalizations.of(context).translate('parent_gate_desc')),
              const SizedBox(height: 14),
              Text(
                '$a + $b = ?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: options
                    .map(
                      (answer) => FilledButton.tonal(
                        onPressed: () {
                          if (answer == a + b) {
                            Navigator.of(dialogContext).pop(true);
                          } else {
                            setDialogState(() {
                              incorrect = true;
                              a = random.nextInt(8) + 3;
                              b = random.nextInt(7) + 2;
                              options = _makeAnswerOptions(a + b, random);
                            });
                          }
                        },
                        child: Text('$answer'),
                      ),
                    )
                    .toList(),
              ),
              if (incorrect) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context).translate('incorrect_answer'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppLocalizations.of(context).translate('cancel')),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _openParentsCorner() async {
    if (!await _promptParentalGate() || !mounted) return;
    final strings = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.volunteer_activism, size: 32),
        title: Text(strings.translate('parent_corner')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(strings.translate('parents_corner_help')),
              const SizedBox(height: 14),
              _buildSubscriptionControls(strings),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text('Studio mode',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(_drawing.studioMode == StudioMode.proArtist
                          ? 'Pro Artist: layers, symmetry, advanced brushes and precision tools.'
                          : 'Toddler: larger controls and simplified drawing.'),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _toggleStudioMode,
                        icon: Icon(_drawing.studioMode == StudioMode.proArtist
                            ? Icons.child_care
                            : Icons.brush),
                        label: Text(_drawing.studioMode == StudioMode.proArtist
                            ? 'Switch to Toddler Mode'
                            : 'Unlock Pro Artist Mode'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openCreativeAgent,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Creative Agent · 52 languages'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '© 2026 VibeSyncro Technologies Pvt Ltd',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      TextButton(
                        onPressed: _openCompanyWebsite,
                        child: const Text('https://vibesyncro.com/'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                strings.translate('choose_language'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              DropdownButton<Locale>(
                isExpanded: true,
                value: AppLocalizations.supportedLocales.firstWhere(
                  (locale) =>
                      locale.languageCode ==
                      Localizations.localeOf(context).languageCode,
                  orElse: () => const Locale('en'),
                ),
                items: const <DropdownMenuItem<Locale>>[
                  DropdownMenuItem(value: Locale('en'), child: Text('English')),
                  DropdownMenuItem(value: Locale('es'), child: Text('Español')),
                  DropdownMenuItem(value: Locale('hi'), child: Text('हिन्दी')),
                  DropdownMenuItem(value: Locale('zh'), child: Text('中文')),
                  DropdownMenuItem(value: Locale('de'), child: Text('Deutsch')),
                  DropdownMenuItem(value: Locale('fr'), child: Text('Français')),
                ],
                onChanged: (locale) {
                  if (locale != null) widget.onLocaleChanged(locale);
                },
              ),
              const SizedBox(height: 14),
              Text(
                strings.translate('support_title'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(strings.translate('support_message')),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _launchCoffeeSupport,
            icon: const Icon(Icons.coffee),
            label: Text(strings.translate('support_coffee')),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_checkForUpdate());
              if (_isOnline != true) {
                _showMessage(strings.translate('offline_message'));
              }
            },
            icon: const Icon(Icons.system_update_alt),
            label: Text(strings.translate('check_updates')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.translate('done')),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionControls(AppLocalizations strings) {
    return AnimatedBuilder(
      animation: _subscription,
      builder: (context, _) {
        final price = _subscription.product?.price ?? 'Price shown by Google Play';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text('VibeSync Ad-Free — yearly subscription',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(_subscription.isAdFree
                    ? 'Ad-free access is active on this device.'
                    : '$price · One year · Auto-renews unless canceled in Google Play.'),
                const SizedBox(height: 8),
                if (!_subscription.isAdFree)
                  FilledButton.icon(
                    onPressed: _subscription.product == null || _subscription.isPurchasing
                        ? null
                        : _purchaseAdFreeSubscription,
                    icon: const Icon(Icons.workspace_premium),
                    label: Text(_subscription.isPurchasing
                        ? 'Waiting for Google Play…'
                        : 'Subscribe / unlock premium'),
                  ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    TextButton(
                      onPressed: _subscription.isRestoring ? null : _restoreAdFreeSubscription,
                      child: const Text('Restore purchases'),
                    ),
                    TextButton(
                      onPressed: _manageSubscription,
                      child: const Text('Manage subscription'),
                    ),
                  ],
                ),
                if (_subscription.message != null)
                  Text(_subscription.message!, style: Theme.of(context).textTheme.bodySmall),
                const Divider(),
                const Text('Premium creative tools',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Text('Neon and rainbow brushes, extended colors, three extra templates, print-ready PDF, and artwork backup.'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _subscription.isAdFree ? _exportArtworkPng : _showPremiumOffer,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save PNG'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _subscription.isAdFree ? _exportArtworkPdf : _showPremiumOffer,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export / print PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _subscription.isAdFree ? _backupArtwork : _showPremiumOffer,
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text('Back up artwork'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _subscription.isAdFree ? _restoreArtworkBackup : _showPremiumOffer,
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore backup'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _subscription.isAdFree ? _exportArtworkJpeg : _showPremiumOffer,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('JPEG'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _subscription.isAdFree ? _exportArtworkSvg : _showPremiumOffer,
                      icon: const Icon(Icons.polyline),
                      label: const Text('SVG'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _subscription.isAdFree ? _exportTimelapseGif : _showPremiumOffer,
                      icon: const Icon(Icons.gif_box_outlined),
                      label: const Text('Timelapse GIF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _purchaseAdFreeSubscription() async {
    if (!await _promptParentalGate() || !mounted) return;
    if (_subscription.product == null) await _subscription.refreshProductDetails();
    await _subscription.purchase();
  }

  Future<void> _restoreAdFreeSubscription() async {
    if (!await _promptParentalGate() || !mounted) return;
    await _subscription.restorePurchases();
  }

  Future<void> _manageSubscription() async {
    if (!await _promptParentalGate() || !mounted) return;
    final uri = Uri.https(
      'play.google.com',
      '/store/account/subscriptions',
      <String, String>{
        'sku': AdFreeSubscriptionService.productId,
        'package': 'com.navya.kids_drawing_studio',
      },
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Could not open Google Play subscription management: $error');
      if (mounted) _showMessage('Open Google Play > Payments and subscriptions to manage this plan.');
    }
  }

  Future<void> _showPremiumOffer() async {
    if (_subscription.isAdFree || !await _promptParentalGate() || !mounted) return;
    await _subscription.refreshProductDetails();
    if (!mounted) return;
    final price = _subscription.product?.price ?? 'Price and availability shown by Google Play';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.workspace_premium, size: 34),
        title: const Text('Unlock VibeSync Premium'),
        content: Text(
          '$price for one year, billed and managed by Google Play. '
          'Unlock ad-free drawing, neon and rainbow brushes, extra colors and templates, '
          'PDF export, and parent-controlled artwork backup. '
          'The final price and renewal details are shown by Google Play before purchase.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: _subscription.product == null || _subscription.isPurchasing
                ? null
                : () {
                    Navigator.of(dialogContext).pop();
                    unawaited(_purchaseAdFreeSubscription());
                  },
            child: const Text('Continue to Google Play'),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockPremiumBrush(StrokeStyle style) async {
    await _showPremiumOffer();
    if (mounted && _subscription.isAdFree) _drawing.setBrushStyle(style);
  }

  Future<Uint8List?> _captureArtworkPng() async {
    final renderObject = _canvasKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || renderObject.size.isEmpty) {
      _showMessage('The drawing is not ready to export.');
      return null;
    }
    final logicalSize = renderObject.size;
    final logicalPixels = logicalSize.width * logicalSize.height;
    if (!logicalPixels.isFinite || logicalPixels <= 0 ||
        logicalPixels > DrawingController.maxRasterPixels) {
      _showMessage(AppLocalizations.of(context).translate('save_too_large'));
      return null;
    }
    final pixelRatio = min(
      2.0,
      sqrt(DrawingController.maxRasterPixels / logicalPixels),
    );
    final pixelWidth = (logicalSize.width * pixelRatio).ceil();
    final pixelHeight = (logicalSize.height * pixelRatio).ceil();
    if (pixelWidth <= 0 || pixelHeight <= 0 ||
        pixelWidth * pixelHeight > DrawingController.maxRasterPixels) {
      _showMessage(AppLocalizations.of(context).translate('save_too_large'));
      return null;
    }

    ui.Picture? picture;
    ui.Image? image;
    try {
      final recorder = ui.PictureRecorder();
      final exportCanvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, logicalSize.width, logicalSize.height),
      )..scale(pixelRatio);
      paintFullSceneForRaster(exportCanvas, logicalSize, _drawing);
      picture = recorder.endRecording();
      image = await picture.toImage(pixelWidth, pixelHeight);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      return Uint8List.fromList(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
    } catch (error, stackTrace) {
      debugPrint('High-resolution artwork capture failed: $error\\n$stackTrace');
      if (mounted) _showMessage(AppLocalizations.of(context).translate('save_failed'));
      return null;
    } finally {
      image?.dispose();
      picture?.dispose();
    }
  }

  Future<void> _exportArtworkPdf() async {
    if (!await _promptParentalGate() || !mounted) return;
    if (!_subscription.isAdFree) {
      await _showPremiumOffer();
      if (!_subscription.isAdFree || !mounted) return;
    }
    final png = await _captureArtworkPng();
    if (png == null || !mounted) return;

    final document = pw.Document();
    final image = pw.MemoryImage(png);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
    final pdfBytes = await document.save();
    final fileName = 'vibesync-artwork-${DateTime.now().millisecondsSinceEpoch}.pdf';
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Print-ready artwork PDF'),
        content: const Text('Choose how to use the A4 PDF sheet.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop('cancel'), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop('share'), child: const Text('Share PDF')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop('print'), child: const Text('Print')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop('save'), child: const Text('Save PDF')),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'cancel') return;
    try {
      if (choice == 'save') {
        final savedPath = await FilePicker.saveFile(
          dialogTitle: 'Save VibeSync artwork PDF',
          fileName: fileName,
          bytes: pdfBytes,
        );
        if (savedPath != null && mounted) _showMessage('PDF saved to the selected location.');
      } else if (choice == 'print') {
        await Printing.layoutPdf(
          name: fileName,
          onLayout: (format) async => pdfBytes,
        );
      } else {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      }
    } catch (error, stackTrace) {
      debugPrint('PDF export failed: $error\\n$stackTrace');
      if (mounted) _showMessage('Could not export the PDF. Please try again.');
    }
  }

  Future<void> _backupArtwork() async {
    if (!await _promptParentalGate() || !mounted) return;
    if (!_subscription.isAdFree) {
      await _showPremiumOffer();
      if (!_subscription.isAdFree || !mounted) return;
    }
    try {
      final bytes = await _persistence.exportBackup(_drawing);
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save VibeSync artwork backup',
        fileName: 'vibesync-artwork-backup-${DateTime.now().millisecondsSinceEpoch}.json',
        bytes: bytes,
      );
      if (savedPath != null && mounted) {
        _showMessage('Backup saved. Keep it in device storage or a parent-selected cloud folder.');
      }
    } catch (error, stackTrace) {
      debugPrint('Artwork backup failed: $error\\n$stackTrace');
      if (mounted) _showMessage('Could not create the backup. Please try again.');
    }
  }

  Future<void> _restoreArtworkBackup() async {
    if (!await _promptParentalGate() || !mounted) return;
    if (!_subscription.isAdFree) {
      await _showPremiumOffer();
      if (!_subscription.isAdFree || !mounted) return;
    }
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final selected = result.files.single;
      final bytes = selected.bytes ??
          (selected.path == null ? null : await File(selected.path!).readAsBytes());
      if (bytes == null) throw StateError('The selected backup could not be read.');
      await _persistence.restoreBackup(bytes, _drawing);
      await _saveDrawing();
      if (mounted) _showMessage('Artwork backup restored.');
    } catch (error, stackTrace) {
      debugPrint('Artwork restore failed: $error\\n$stackTrace');
      if (mounted) _showMessage('That backup could not be restored. The current artwork was kept when validation failed.');
    }
  }


  void _toggleStudioMode() {
    if (_drawing.studioMode == StudioMode.proArtist) {
      _drawing.setBrushStyle(StrokeStyle.solid);
      _drawing.setActiveTool(ActiveTool.brush);
      _drawing.setSymmetryMode(SymmetryMode.none);
      _drawing.setStudioMode(StudioMode.toddler);
      return;
    }
    if (!_subscription.isAdFree) {
      unawaited(_showPremiumOffer());
      return;
    }
    _drawing.setStudioMode(StudioMode.proArtist);
  }

  Future<void> _toggleChrome() async {
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    final showChrome = !_chromeVisible;
    await SystemChrome.setEnabledSystemUIMode(
      showChrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
    if (!mounted) return;
    setState(() => _chromeVisible = showChrome);
  }

  Future<void> _renameLayer(DrawingLayer layer) async {
    final textController = TextEditingController(text: layer.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename layer'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(labelText: 'Layer name'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (name != null) _drawing.renameLayer(layer.id, name);
  }

  Future<void> _showLayerManager() async {
    if (!await _promptParentalGate() || !mounted) return;
    if (!_subscription.isAdFree || _drawing.studioMode != StudioMode.proArtist) {
      await _showPremiumOffer();
      if (!_subscription.isAdFree || !mounted) return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.68,
          child: AnimatedBuilder(
            animation: _drawing,
            builder: (context, _) => Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text('Canvas layers',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      Text('${_drawing.layers.length}/12'),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _drawing.layers.length >= 12
                            ? null
                            : () => _drawing.addLayer(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add layer'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _drawing.layers.length,
                    itemBuilder: (context, index) {
                      final layer = _drawing.layers.reversed.toList()[index];
                      final isActive = layer.id == _drawing.activeLayerId;
                      final originalIndex = _drawing.layers.indexWhere((item) => item.id == layer.id);
                      return Card(
                        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(isActive ? Icons.layers : Icons.layers_outlined),
                                      title: Text(layer.name,
                                          style: TextStyle(
                                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                          )),
                                      subtitle: Text(isActive ? 'Active layer' : 'Tap to draw on this layer'),
                                      onTap: () => _drawing.selectLayer(layer.id),
                                    ),
                                  ),
                                  Switch(
                                    value: layer.visible,
                                    onChanged: (value) => _drawing.setLayerVisibility(layer.id, value),
                                  ),
                                ],
                              ),
                              Row(
                                children: <Widget>[
                                  const Text('Opacity'),
                                  Expanded(
                                    child: Slider(
                                      value: layer.opacity,
                                      min: 0,
                                      max: 1,
                                      divisions: 20,
                                      onChanged: (value) => _drawing.setLayerOpacity(layer.id, value),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 42,
                                    child: Text('${(layer.opacity * 100).round()}%'),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 6,
                                children: <Widget>[
                                  TextButton.icon(
                                    onPressed: () => _renameLayer(layer),
                                    icon: const Icon(Icons.edit_outlined, size: 17),
                                    label: const Text('Rename'),
                                  ),
                                  TextButton.icon(
                                    onPressed: originalIndex == 0
                                        ? null
                                        : () => _drawing.mergeLayerDown(layer.id),
                                    icon: const Icon(Icons.merge_type, size: 17),
                                    label: const Text('Merge down'),
                                  ),
                                  TextButton.icon(
                                    onPressed: _drawing.layers.length <= 1
                                        ? null
                                        : () => _drawing.removeLayer(layer.id),
                                    icon: const Icon(Icons.delete_outline, size: 17),
                                    label: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreativeAgent() async {
    if (!await _promptParentalGate() || !mounted) return;
    var languageCode = 'en';
    String? speechStatus;
    final tags = <String>{
      _drawing.selectedPage.name,
      ..._drawing.strokes.map((stroke) => stroke.style.name),
      ..._drawing.stamps.map((stamp) => stamp.kind.name),
    }.take(8).toList(growable: false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final language = _creativeAgent.languageFor(languageCode);
          final prompt = _creativeAgent.generateDrawingPrompt(languageCode);
          final story = _creativeAgent.generateStory(
            artworkTags: tags,
            languageCode: languageCode,
          );
          return AlertDialog(
            icon: const Icon(Icons.auto_awesome, size: 32),
            title: const Text('Creative Agent · Offline'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text('Choose a prompt language (52 available).'),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: languageCode,
                    items: AiCreativeAgent.languages.map((item) =>
                      DropdownMenuItem<String>(
                        value: item.code,
                        child: Text('${item.name} · ${item.code}'),
                      ),
                    ).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          languageCode = value;
                          speechStatus = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(prompt, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final spoken = await _creativeAgent.speakPrompt(languageCode);
                      if (dialogContext.mounted) {
                        setDialogState(() => speechStatus = spoken
                            ? 'Playing with the installed device voice.'
                            : 'This device has no voice installed for ${language.name}.');
                      }
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Speak drawing prompt'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await _creativeAgent.stopSpeaking();
                      if (dialogContext.mounted) {
                        setDialogState(() => speechStatus = 'Voice playback stopped.');
                      }
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop voice'),
                  ),
                  if (speechStatus != null)
                    Text(speechStatus!, style: Theme.of(context).textTheme.bodySmall),
                  const Divider(height: 24),
                  const Text('Your picture story',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(story),
                  const SizedBox(height: 6),
                  Text(
                    'Stories use local drawing tags only. No artwork or microphone audio is uploaded.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  final promptText = _creativeAgent.buildPrivateModelPrompt(
                    artworkTags: tags,
                    languageCode: languageCode,
                  );
                  await Clipboard.setData(ClipboardData(text: promptText));
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (mounted) _showMessage('Private creative prompt copied.');
                },
                child: const Text('Copy private prompt'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportArtworkPng() async {
    if (!await _promptParentalGate() || !mounted) return;
    if (!_subscription.isAdFree) {
      await _showPremiumOffer();
      if (!_subscription.isAdFree || !mounted) return;
    }
    final png = await _captureArtworkPng();
    if (png == null || !mounted) return;
    try {
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save VibeSync artwork PNG',
        fileName: 'vibesync-artwork-${DateTime.now().millisecondsSinceEpoch}.png',
        bytes: png,
      );
      if (saved != null && mounted) {
        _showMessage('PNG saved to the selected location. Choose Pictures to add it to your gallery.');
      }
    } catch (error) {
      debugPrint('PNG export failed: $error');
      if (mounted) _showMessage('Could not save the PNG.');
    }
  }

  Future<void> _exportArtworkJpeg() async {
    if (!await _promptParentalGate() || !mounted) return;
    if (!_subscription.isAdFree) {
      await _showPremiumOffer();
      if (!_subscription.isAdFree || !mounted) return;
    }
    final png = await _captureArtworkPng();
    if (png == null || !mounted) return;
    try {
      final decoded = image_codec.decodePng(png);
      if (decoded == null) throw const FormatException('PNG encoding could not be read.');
      final jpeg = image_codec.encodeJpg(decoded, quality: 92);
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save VibeSync artwork JPEG',
        fileName: 'vibesync-artwork-${DateTime.now().millisecondsSinceEpoch}.jpg',
        bytes: Uint8List.fromList(jpeg),
      );
      if (saved != null && mounted) _showMessage('JPEG saved to the selected location.');
    } catch (error) {
      debugPrint('JPEG export failed: $error');
      if (mounted) _showMessage('Could not export the JPEG.');
    }
  }

  Future<void> _exportArtworkSvg() async {
    if (!await _promptParentalGate() || !mounted) return;
    if (!_subscription.isAdFree) {
      await _showPremiumOffer();
      if (!_subscription.isAdFree || !mounted) return;
    }
    try {
      final size = _drawing.canvasSize;
      final svg = DrawingExportService.toSvg(
        _drawing,
        width: size.width,
        height: size.height,
      );
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save VibeSync vector SVG',
        fileName: 'vibesync-artwork-${DateTime.now().millisecondsSinceEpoch}.svg',
        bytes: Uint8List.fromList(utf8.encode(svg)),
      );
      if (saved != null && mounted) _showMessage('SVG saved to the selected location.');
    } catch (error) {
      debugPrint('SVG export failed: $error');
      if (mounted) _showMessage('Could not export the SVG.');
    }
  }

  Future<void> _exportTimelapseGif() async {
    if (!await _promptParentalGate() || !mounted) return;
    if (!_subscription.isAdFree) {
      await _showPremiumOffer();
      if (!_subscription.isAdFree || !mounted) return;
    }
    try {
      final gif = DrawingExportService.encodeTimelapseGif(_drawing);
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save VibeSync drawing timelapse',
        fileName: 'vibesync-timelapse-${DateTime.now().millisecondsSinceEpoch}.gif',
        bytes: gif,
      );
      if (saved != null && mounted) _showMessage('Animated GIF saved to the selected location.');
    } catch (error) {
      debugPrint('Timelapse export failed: $error');
      if (mounted) _showMessage(error is StateError
          ? error.message
          : 'Could not export the drawing timelapse.');
    }
  }


  Future<void> _openCompanyWebsite() async {
    if (!await _promptParentalGate() || !mounted) return;
    final uri = Uri.parse('https://vibesyncro.com/');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showMessage('Could not open the company website.');
    } catch (error) {
      debugPrint('Company website could not be opened: $error');
      if (mounted) _showMessage('Could not open the company website.');
    }
  }

  Future<void> _launchCoffeeSupport() async {
    final uri = Uri.tryParse(_coffeeSupportUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _showMessage(AppLocalizations.of(context).translate('support_link_missing'));
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage(AppLocalizations.of(context).translate('support_link_missing'));
      }
    } catch (error) {
      debugPrint('Support link could not be opened: $error');
      if (mounted) {
        _showMessage(AppLocalizations.of(context).translate('support_link_missing'));
      }
    }
  }

  Future<void> _requestColoringPage(ColoringPage page) async {
    if (page == _drawing.selectedPage) return;
    if (page.requiresSubscription) {
      if (!_subscription.isAdFree) {
        await _showPremiumOffer();
        if (!_subscription.isAdFree || !mounted) return;
      }
      _drawing.setSelectedPage(page);
      return;
    }
    if (_unlockedPages.contains(page)) {
      _drawing.setSelectedPage(page);
      return;
    }

    final strings = AppLocalizations.of(context);
    if (!await _promptParentalGate() || !mounted) return;
    if (!AdHelper.instance.hasRewardedAdConfigured) {
      // Never ship Google's test ad IDs in release. Until a production rewarded
      // unit is configured, parents can unlock the template without an ad.
      setState(() => _unlockedPages.add(page));
      _drawing.setSelectedPage(page);
      _showMessage(strings.translate('bonus_unlocked_without_ad'));
      return;
    }

    if (_isOnline != true || !AdHelper.instance.isInitialized) {
      _showMessage(strings.translate('no_ad_ready'));
      return;
    }

    try {
      AdHelper.instance.showRewardedAd(
        onUserEarnedReward: (reward) {
          if (!mounted) return;
          setState(() => _unlockedPages.add(page));
          _drawing.setSelectedPage(page);
          _showMessage('${strings.translate('done')}: ${_pageName(page, strings)}');
        },
        onAdClosed: () {},
        onAdNotReady: (_) {
          if (mounted) _showMessage(strings.translate('no_ad_ready'));
        },
      );
    } catch (error) {
      debugPrint('Rewarded ad could not be shown: $error');
      _showMessage(strings.translate('no_ad_ready'));
    }
  }

  String _pageName(ColoringPage page, AppLocalizations strings) {
    return switch (page) {
      ColoringPage.freeDraw => strings.translate('free_draw'),
      ColoringPage.puppy => strings.translate('puppy'),
      ColoringPage.sunshine => strings.translate('sunshine'),
      ColoringPage.rocket => strings.translate('rocket'),
      ColoringPage.unicorn => strings.translate('unicorn'),
      ColoringPage.dinosaur => 'Dinosaur (Premium)',
      ColoringPage.butterfly => 'Butterfly (Premium)',
      ColoringPage.castle => 'Castle (Premium)',
    };
  }


  Future<void> _saveArtwork() async {
    // Sharing artwork is an external action available only after the parent gate.
    if (!await _promptParentalGate() || !mounted) return;
    final png = await _captureArtworkPng();
    if (png == null || !mounted) {
      _showMessage(AppLocalizations.of(context).translate('save_failed'));
      return;
    }
    try {
      final directory = await getTemporaryDirectory();
      final filename = 'vibesync-drawing-${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(directory.path + Platform.pathSeparator + filename);
      await file.writeAsBytes(png, flush: true);
      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: AppLocalizations.of(context).translate('share_caption'),
        subject: AppLocalizations.of(context).translate('app_title'),
      );
    } catch (error, stackTrace) {
      debugPrint('Artwork export failed safely: $error\\n$stackTrace');
      if (mounted) _showMessage(AppLocalizations.of(context).translate('save_failed'));
    }
  }

  Future<void> _confirmClear() async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.translate('clear_canvas')),
        content: Text(strings.translate('clear_confirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.translate('clear')),
          ),
        ],
      ),
    );
    if (confirmed == true) _drawing.clearCanvas();
  }

  void _showBackgroundPalette() {
    final strings = AppLocalizations.of(context);
    final palette = <(Color, String)>[
      (Colors.white, 'color_white'),
      (const Color(0xFFFFF8E1), 'color_yellow'),
      (const Color(0xFFE1F5FE), 'color_blue'),
      (const Color(0xFFE8F5E9), 'color_green'),
      (const Color(0xFFFCE4EC), 'color_pink'),
      (const Color(0xFFF3E5F5), 'color_purple'),
      (const Color(0xFFFFE0B2), 'color_orange'),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.translate('bg_change'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: palette
                  .map(
                    (entry) => Tooltip(
                      message: strings.translate(entry.$2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          _drawing.setBackgroundColor(entry.$1);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: entry.$1,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black26, width: 2),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(AppLocalizations strings) {
    final palette = <Color>[
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFFFFD600),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
      Color(0xFFEC407A),
      Color(0xFF212121),
      if (_subscription.isAdFree) ...<Color>[
        Color(0xFF00BCD4),
        Color(0xFF7C4DFF),
        Color(0xFFAD1457),
        Color(0xFF00897B),
        Color(0xFFFF6F00),
        Color(0xFF6D4C41),
        Color(0xFF3949AB),
        Color(0xFF9E9E9E),
      ],
    ];

    return AnimatedBuilder(
      animation: _drawing,
      builder: (context, _) => Material(
        color: const Color(0xFFFFF8E1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: _drawing.studioMode == StudioMode.toddler ? 62 : 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: <Widget>[
                  ChoiceChip(
                    avatar: const Icon(Icons.brush, size: 17),
                    label: Text(strings.translate('tool_brush')),
                    selected: _drawing.activeTool == ActiveTool.brush,
                    onSelected: (_) => _drawing.setActiveTool(ActiveTool.brush),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    avatar: const Icon(Icons.format_color_fill, size: 17),
                    label: Text(strings.translate('tool_bucket')),
                    selected: _drawing.activeTool == ActiveTool.paintBucket,
                    onSelected: (_) => _drawing.setActiveTool(ActiveTool.paintBucket),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    avatar: const Icon(Icons.interests, size: 17),
                    label: Text(strings.translate('tool_stamp')),
                    selected: _drawing.activeTool == ActiveTool.stamp,
                    onSelected: (_) => _drawing.setActiveTool(ActiveTool.stamp),
                  ),
                  if (_drawing.studioMode == StudioMode.proArtist) ...<Widget>[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      avatar: const Icon(Icons.colorize, size: 17),
                      label: const Text('Eyedropper'),
                      selected: _drawing.activeTool == ActiveTool.eyedropper,
                      onSelected: (_) => _drawing.setActiveTool(ActiveTool.eyedropper),
                    ),
                  ],
                  const SizedBox(width: 8),
                  DropdownButton<StrokeStyle>(
                    value: _drawing.brushStyle,
                    underline: const SizedBox.shrink(),
                    hint: Text(strings.translate('brush_style')),
                    items: <DropdownMenuItem<StrokeStyle>>[
                      DropdownMenuItem(
                        value: StrokeStyle.solid,
                        child: Text(strings.translate('solid')),
                      ),
                      if (_drawing.studioMode == StudioMode.proArtist) ...<DropdownMenuItem<StrokeStyle>>[
                        DropdownMenuItem(
                          value: StrokeStyle.neon,
                          child: Text(strings.translate('neon')),
                        ),
                        DropdownMenuItem(
                          value: StrokeStyle.rainbow,
                          child: Text(strings.translate('rainbow')),
                        ),
                        const DropdownMenuItem(
                          value: StrokeStyle.watercolor,
                          child: Text('Watercolor'),
                        ),
                        const DropdownMenuItem(
                          value: StrokeStyle.calligraphy,
                          child: Text('Calligraphy'),
                        ),
                        const DropdownMenuItem(
                          value: StrokeStyle.charcoal,
                          child: Text('Charcoal'),
                        ),
                      ],
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      if (value.requiresSubscription && !_subscription.isAdFree) {
                        unawaited(_unlockPremiumBrush(value));
                      } else {
                        _drawing.setBrushStyle(value);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<StampKind>(
                    value: _drawing.selectedStamp,
                    underline: const SizedBox.shrink(),
                    items: <DropdownMenuItem<StampKind>>[
                      DropdownMenuItem(value: StampKind.house, child: Text(strings.translate('stamp_house'))),
                      DropdownMenuItem(value: StampKind.flower, child: Text(strings.translate('stamp_flower'))),
                      DropdownMenuItem(value: StampKind.pond, child: Text(strings.translate('stamp_pond'))),
                      DropdownMenuItem(value: StampKind.fish, child: Text(strings.translate('stamp_fish'))),
                    ],
                    onChanged: (value) {
                      if (value != null) _drawing.setSelectedStamp(value);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              height: _drawing.studioMode == StudioMode.toddler ? 56 : 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                children: <Widget>[
                  for (final color in palette)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Tooltip(
                        message: color == palette[0]
                            ? strings.translate('color_red')
                            : color == palette[1]
                                ? strings.translate('color_orange')
                                : color == palette[2]
                                    ? strings.translate('color_yellow')
                                    : color == palette[3]
                                        ? strings.translate('color_green')
                                        : color == palette[4]
                                            ? strings.translate('color_blue')
                                            : color == palette[5]
                                                ? strings.translate('color_purple')
                                                : color == palette[6]
                                                    ? strings.translate('color_pink')
                                                    : strings.translate('color_black'),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            switch (_drawing.activeTool) {
                              case ActiveTool.brush:
                                _drawing.setBrushColor(color);
                                break;
                              case ActiveTool.paintBucket:
                                _drawing.setBucketColor(color);
                                break;
                              case ActiveTool.stamp:
                                if (_selectingStampOutline) {
                                  _drawing.setStampColors(stroke: color);
                                } else {
                                  _drawing.setStampColors(fill: color);
                                }
                                break;
                              case ActiveTool.eyedropper:
                                _drawing.setBrushColor(color);
                                _drawing.setActiveTool(ActiveTool.brush);
                                break;
                            }
                          },
                          child: Container(
                            width: _drawing.studioMode == StudioMode.toddler ? 38 : 31,
                            height: _drawing.studioMode == StudioMode.toddler ? 38 : 31,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (_drawing.activeTool == ActiveTool.brush &&
                                            _drawing.brushColor == color) ||
                                        (_drawing.activeTool == ActiveTool.paintBucket &&
                                            _drawing.bucketColor == color) ||
                                        (_drawing.activeTool == ActiveTool.stamp &&
                                            (_selectingStampOutline
                                                ? _drawing.stampStrokeColor == color
                                                : _drawing.stampFillColor == color))
                                    ? Colors.black
                                    : Colors.black12,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!_subscription.isAdFree)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        avatar: const Icon(Icons.lock_outline, size: 16),
                        label: const Text('More colors'),
                        onPressed: _showPremiumOffer,
                      ),
                    ),
                  if (_drawing.activeTool == ActiveTool.stamp)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        avatar: Icon(_selectingStampOutline ? Icons.border_color : Icons.format_color_fill, size: 16),
                        label: Text(strings.translate(_selectingStampOutline ? 'stamp_outline' : 'stamp_fill')),
                        selected: _selectingStampOutline,
                        onSelected: (value) => setState(() => _selectingStampOutline = value),
                      ),
                    ),
                  if (_drawing.studioMode == StudioMode.proArtist) ...<Widget>[
                    const SizedBox(width: 8),
                    DropdownButton<SymmetryMode>(
                      value: _drawing.symmetryMode,
                      underline: const SizedBox.shrink(),
                      hint: const Text('Symmetry'),
                      items: const <DropdownMenuItem<SymmetryMode>>[
                        DropdownMenuItem(value: SymmetryMode.none, child: Text('No symmetry')),
                        DropdownMenuItem(value: SymmetryMode.mirrorHorizontal, child: Text('Mirror left/right')),
                        DropdownMenuItem(value: SymmetryMode.mirrorVertical, child: Text('Mirror top/bottom')),
                        DropdownMenuItem(value: SymmetryMode.radial4, child: Text('Radial 4')),
                        DropdownMenuItem(value: SymmetryMode.radial8, child: Text('Radial 8')),
                      ],
                      onChanged: (value) {
                        if (value != null) _drawing.setSymmetryMode(value);
                      },
                    ),
                    IconButton(
                      tooltip: 'Manage layers',
                      onPressed: _showLayerManager,
                      icon: const Icon(Icons.layers_outlined),
                    ),
                  ],
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: strings.translate('bg_change'),
                    onPressed: _showBackgroundPalette,
                    icon: const Icon(Icons.palette_outlined),
                  ),
                  SizedBox(
                    width: 112,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(strings.translate('stroke_width'), style: const TextStyle(fontSize: 10)),
                        SizedBox(
                          height: 28,
                          child: Slider(
                            value: _drawing.brushWidth,
                            min: 1,
                            max: 24,
                            onChanged: _drawing.setBrushWidth,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagePicker(AppLocalizations strings) {
    return AnimatedBuilder(
      animation: _drawing,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: <Widget>[
            const Icon(Icons.auto_awesome, size: 19),
            const SizedBox(width: 7),
            Text(strings.translate('templates')),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButton<ColoringPage>(
                isExpanded: true,
                value: _drawing.selectedPage,
                underline: const SizedBox.shrink(),
                items: ColoringPage.values
                    .map(
                      (page) => DropdownMenuItem<ColoringPage>(
                        value: page,
                        child: Text(_pageName(page, strings), overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (page) {
                  if (page != null) unawaited(_requestColoringPage(page));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(AppLocalizations strings) {
    return MaterialBanner(
      leading: const Icon(Icons.cloud_off, color: Color(0xFF7A5A00)),
      content: Text(
        '${strings.translate('offline_title')}. ${strings.translate('offline_message')}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _openParentsCorner,
          child: Text(strings.translate('parent_corner')),
        ),
      ],
    );
  }

  Widget _buildUpdateBanner(AppLocalizations strings) {
    return MaterialBanner(
      leading: const Icon(Icons.system_update_alt),
      content: Text(
        _updateDownloading
            ? strings.translate('update_downloading')
            : strings.translate('update_available'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => setState(() => _updateAvailable = false),
          child: Text(strings.translate('later')),
        ),
        FilledButton(
          onPressed: _updateDownloading ? null : _startUpdate,
          child: Text(strings.translate('update_now')),
        ),
      ],
    );
  }

  Widget _buildAdDock(AppLocalizations strings) {
    if (!_subscriptionReady || _subscription.isAdFree) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 12,
          width: double.infinity,
          color: const Color(0xFFFFF0C2),
          child: const Center(
            child: Divider(height: 1, thickness: 1, color: Color(0xFFFFD54F)),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            height: 52,
            alignment: Alignment.center,
            color: Colors.white,
            child: _isOnline == true && _bannerLoaded && _bannerAd != null
                ? SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  )
                : Text(
                    _isOnline == false
                        ? strings.translate('offline_title')
                        : strings.translate('no_ad_ready'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_chromeVisible ? kToolbarHeight : 0),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _chromeVisible
              ? AppBar(
                  title: Text(
                    strings.translate('app_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  actions: <Widget>[
                    IconButton(
                      tooltip: strings.translate('check_updates'),
                      onPressed: () {
                        if (_isOnline == true) {
                          unawaited(_checkForUpdate());
                        } else {
                          _showMessage(strings.translate('offline_message'));
                        }
                      },
                      icon: const Icon(Icons.system_update_alt),
                    ),
                    IconButton(
                      tooltip: strings.translate('parent_corner'),
                      onPressed: _openParentsCorner,
                      icon: const Icon(Icons.family_restroom),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Column(
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.12),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _chromeVisible
                      ? Column(
                          key: const ValueKey<String>('drawing-top-controls'),
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (_isOnline == false) _buildOfflineBanner(strings),
                            if (_isOnline == true && _updateAvailable)
                              _buildUpdateBanner(strings),
                            _buildToolbar(strings),
                            _buildPagePicker(strings),
                          ],
                        )
                      : const SizedBox.shrink(
                          key: ValueKey<String>('drawing-top-hidden'),
                        ),
                ),
                Expanded(
                  child: Container(
                    key: _canvasKey,
                    margin: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFE082),
                        width: 2,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: DrawingCanvas(
                      controller: _drawing,
                      onFeedback: _showMessage,
                      onDoubleTapCanvas: _toggleChrome,
                      onColorPicked: (color) {
                        _drawing.setBrushColor(color);
                        _drawing.setActiveTool(ActiveTool.brush);
                      },
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.12),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _chromeVisible
                      ? Column(
                          key: const ValueKey<String>('drawing-bottom-controls'),
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            AnimatedBuilder(
                              animation: _drawing,
                              builder: (context, _) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: strings.translate('undo'),
                                      onPressed: _drawing.canUndo ? _drawing.undo : null,
                                      icon: const Icon(Icons.undo),
                                    ),
                                    IconButton(
                                      tooltip: strings.translate('redo'),
                                      onPressed: _drawing.canRedo ? _drawing.redo : null,
                                      icon: const Icon(Icons.redo),
                                    ),
                                    IconButton(
                                      tooltip: strings.translate('save_share'),
                                      onPressed: _saveArtwork,
                                      icon: const Icon(Icons.ios_share),
                                    ),
                                    const Spacer(),
                                    FilledButton.tonalIcon(
                                      onPressed: _confirmClear,
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      label: Text(strings.translate('clear')),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_subscriptionReady && !_subscription.isAdFree)
                              _buildAdDock(strings),
                          ],
                        )
                      : const SizedBox.shrink(
                          key: ValueKey<String>('drawing-bottom-hidden'),
                        ),
                ),
              ],
            ),
            if (!_chromeVisible)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.small(
                  tooltip: 'Show drawing controls',
                  onPressed: _toggleChrome,
                  child: const Icon(Icons.tune),
                ),
              ),
            if (_restoringDrawing)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: const Color(0xCCFFFFFB),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const CircularProgressIndicator.adaptive(),
                          const SizedBox(height: 12),
                          Text(strings.translate('restoring_artwork')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _autosaveTimer?.cancel();
    _drawing.removeListener(_onDrawingChanged);
    if (!_restoringDrawing) {
      // Keep native images alive until the final local snapshot completes.
      unawaited(
        _persistence.save(_drawing).then<void>(
          (_) => _drawing.dispose(),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Final local drawing save skipped: $error');
            _drawing.dispose();
          },
        ),
      );
    } else {
      _drawing.dispose();
    }
    _internetSubscription?.cancel();
    _updateSubscription?.cancel();
    _subscription.removeListener(_onSubscriptionChanged);
    _subscription.dispose();
    unawaited(_creativeAgent.dispose());
    _bannerAd?.dispose();
    super.dispose();
  }
}
