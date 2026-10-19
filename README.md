# VibeSync Kids Drawing Toddler Paint

A small Flutter drawing app for toddlers. The Android application lives in `lib/` and `android/`; `src/` is a separate React/Vite developer dashboard and source-code generator.

## Current app features

- Freehand finger drawing on a canvas.
- Six selectable brush colors and a clear-canvas action.
- Bottom banner ad integration with a visual spacer separating the ad area from the canvas.
- A randomized arithmetic parental gate before a rewarded-ad bonus-unlock attempt.
- Child-directed AdMob request configuration, a G-rated content ceiling, under-age-of-consent flag and a non-personalized-ad request extra.

## Important current limitations

- The four bonus entries are currently labels and unlock states, not finished coloring-page illustrations.
- Brush color is currently applied by the painter to all stored strokes, so changing color can recolor previous strokes. Per-stroke color storage is still needed.
- Drawings are held in memory only. Save/export, undo/redo, persistence and sharing are not implemented.
- A wrong answer in the Flutter parental gate closes the dialog instead of offering another attempt.
- The banner uses the configured app's banner ad unit. Rewarded and interstitial IDs in `lib/ad_helper.dart` are Google's test IDs; the interstitial helper is not currently called by the Flutter UI.
- The ad settings are technical safeguards, not a certification or guarantee of COPPA, GDPR-K or Google Play Families Policy compliance. Verify the app's audience, consent/privacy disclosures, ad-network setup and ad placement in Play Console and AdMob before release.

## Repository map

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Flutter drawing screen and parental gate |
| `lib/ad_helper.dart` | AdMob initialization, request flags and ad lifecycle helpers |
| `android/` | Android manifest, launcher resources and release configuration |
| `test/admob_coppa_test.dart` | Flutter unit tests for selected ad/request invariants |
| `src/` | React/Vite developer dashboard, simulator and generated Flutter templates |
| `.github/workflows/build-aab.yml` | Android App Bundle/APK build workflow |

The web dashboard contains simulated ad playback and illustrative test-status UI. It does not execute Flutter tests or inspect a built APK.

## Build and test

Use a Flutter stable SDK and Java 17.

```sh
flutter pub get
dart run flutter_launcher_icons
flutter test
flutter analyze
flutter build appbundle --release
```

The GitHub Actions workflow builds a release AAB and APK and uploads them as workflow artifacts. Release signing must use the intended upload keystore; do not publish an artifact that was signed with the debug key.
