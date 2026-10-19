import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ad_helper.dart';
import 'drawing/drawing_canvas.dart';
import 'drawing/drawing_controller.dart';
import 'drawing/drawing_models.dart';
import 'l10n/app_localizations.dart';

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
      title: 'VibeSync Kids Drawing Toddler Paint',
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
  AppUpdateInfo? _updateInfo;
  StreamSubscription<InternetStatus>? _internetSubscription;
  StreamSubscription<InstallStatus>? _updateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForInternet();
    if (defaultTargetPlatform == TargetPlatform.android) {
      _updateSubscription = InAppUpdate.installUpdateListener.listen(
        _onInstallStatus,
        onError: (Object error) =>
            debugPrint('In-app update listener unavailable: $error'),
      );
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
      unawaited(_initializeAdsIfOnline());
      unawaited(_checkForUpdate());
    }
  }

  Future<void> _initializeAdsIfOnline() async {
    if (_isOnline != true || _adsInitializing || AdHelper.instance.isInitialized) {
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
    if (!mounted || _isOnline != true) return;
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
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshInternetStatus());
      if (_isOnline == true) unawaited(_checkForUpdate());
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
    if (_unlockedPages.contains(page)) {
      _drawing.setSelectedPage(page);
      return;
    }

    final strings = AppLocalizations.of(context);
    if (!await _promptParentalGate() || !mounted) return;
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
    };
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
    const palette = <Color>[
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFFFFD600),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
      Color(0xFFEC407A),
      Color(0xFF212121),
    ];

    return AnimatedBuilder(
      animation: _drawing,
      builder: (context, _) => Material(
        color: const Color(0xFFFFF8E1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 54,
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
                  const SizedBox(width: 8),
                  DropdownButton<StrokeStyle>(
                    value: _drawing.brushStyle,
                    underline: const SizedBox.shrink(),
                    hint: Text(strings.translate('brush_style')),
                    items: <DropdownMenuItem<StrokeStyle>>[
                      DropdownMenuItem(value: StrokeStyle.solid, child: Text(strings.translate('solid'))),
                      DropdownMenuItem(value: StrokeStyle.neon, child: Text(strings.translate('neon'))),
                      DropdownMenuItem(value: StrokeStyle.rainbow, child: Text(strings.translate('rainbow'))),
                    ],
                    onChanged: (value) {
                      if (value != null) _drawing.setBrushStyle(value);
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
              height: 50,
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
                                                    : strings.translate('color_white'),
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
                                _drawing.setStampColors(fill: color);
                                break;
                            }
                          },
                          child: Container(
                            width: 31,
                            height: 31,
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
                                            _drawing.stampFillColor == color)
                                    ? Colors.black
                                    : Colors.black12,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
      appBar: AppBar(
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
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (_isOnline == false) _buildOfflineBanner(strings),
            if (_isOnline == true && _updateAvailable) _buildUpdateBanner(strings),
            _buildToolbar(strings),
            _buildPagePicker(strings),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE082), width: 2),
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
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _drawing,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
            _buildAdDock(strings),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _internetSubscription?.cancel();
    _updateSubscription?.cancel();
    _bannerAd?.dispose();
    _drawing.dispose();
    super.dispose();
  }
}
