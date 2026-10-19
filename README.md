# VibeSync Kids Drawing Toddler Paint

A child-friendly Flutter drawing application with freehand drawing, brush styles, stickers, coloring templates, undo/redo and a bounded paint-bucket tool.

## App source

- `lib/main.dart`: app shell, AdMob lifecycle, in-app update prompt, parent-gated support and language selection.
- `lib/drawing/drawing_controller.dart`: drawing state, immutable stroke history, stamps, canvas fills and bounded undo/redo.
- `lib/drawing/drawing_models.dart`: typed strokes, stamps, layers and coloring-page types.
- `lib/drawing/drawing_painters.dart`: background/template/stamp/stroke painter layers with neon and rainbow styles.
- `lib/drawing/drawing_canvas.dart`: pointer handling, asynchronous raster fill and parent-gated PNG sharing.
- `lib/drawing/flood_fill.dart`: bounded non-recursive RGBA flood-fill algorithm that runs through Flutter's compute isolate.
- `lib/l10n/app_localizations.dart`: initial English, Spanish, Hindi, Chinese, German and French strings.
- `lib/ad_helper.dart`: existing AdMob request configuration and ad lifecycle helper.
- `src/`: separate React/Vite developer dashboard and generated-code demonstration.

## Offline behavior and optional support

The drawing screen opens before ad/network initialization completes. Drawing operations remain local to the device and usable when the internet is unavailable. Internet status is checked so the app can show a non-blocking offline banner and retry update checks when the connection returns.

The Android in-app update prompt uses Google Play's in-app update API and therefore requires an eligible Google Play install and a published update. Local APKs and ordinary emulator runs cannot fully verify that native update flow.

Parents can export artwork as a PNG through the system share sheet after passing the parent gate. The app creates a temporary local image; it does not upload artwork to a developer-operated server.

An optional coffee/support action is available only after the arithmetic parent gate. Configure a valid HTTPS support page at build time:

```sh
flutter build appbundle --release --dart-define=COFFEE_SUPPORT_URL=https://your-real-support-page.example
```

Replace the example with the actual creator-owned support URL before release. Without a configured URL, the app explains that the link has not been set and keeps all drawing features available. No support prompt is shown directly to children.

## Advertising and child safety

The app applies child-directed AdMob request settings and keeps the banner isolated from the drawing canvas. Rewarded/interstitial test IDs are used only in debug builds. Release builds do not load those formats unless production IDs are configured with `--dart-define=ADMOB_REWARDED_ANDROID=...` and/or `--dart-define=ADMOB_INTERSTITIAL_ANDROID=...` (use corresponding `_IOS` values for iOS). Without a production rewarded ID, locked coloring pages can be unlocked after parent approval without an ad. A configuration flag is not a certification: verify the current Google Play Families policies, ad SDK eligibility, app content, privacy notice and Play Console declarations before release.

## Build and verification

Use Flutter stable and Java 17.

```sh
flutter pub get
dart run flutter_launcher_icons
flutter test
flutter analyze
flutter build appbundle --release
```

GitHub Actions runs launcher generation, Flutter tests, static analysis and release AAB/APK builds. Test the drawing canvas on physical Android devices and test native Play update flows through a Play testing track before production release.
