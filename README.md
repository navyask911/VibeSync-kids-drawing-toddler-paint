# VibeSync Kids Drawing Toddler Paint

Flutter drawing and sticker app for young children. Android app code is under \`lib/\` and \`android/\`; \`src/\` is a separate React/Vite developer dashboard and source generator.

## Implemented in this branch

- Isolated canvas painter/controller with a repaint boundary.
- Immutable strokes preserving original color, width and brush style.
- Solid, neon and rainbow brush styles.
- Vector sticker stamps for puppy, sunshine, rocket, unicorn, house, flower, pond and fish.
- Undo/redo for strokes, stamps, background changes and clear operations.
- Debounced local-only drawing auto-save and best-effort restore.
- Six-language initial UI localization (English, Spanish, Hindi, Chinese, German and French).
- Network availability notice while keeping the canvas usable offline.
- Android Play in-app update check with graceful fallback when the Play API is unavailable.
- Parent arithmetic gate before opening an optional support URL.

## Current limitations

- The paint bucket is deliberately disabled until a real raster-backed, bounded flood-fill engine and its undo/redo tests are implemented.
- Raster checkpointing and offscreen image-cache compaction are not yet implemented; vectors remain the document source of truth.
- Coloring-page stencils are lightweight guides, not a paint-inside-the-lines system.
- Auto-saved drawings are stored only on-device by this app code and are not uploaded to a developer server.
- Coffee support requires a verified HTTPS page provided as \`--dart-define=VIBESYNC_SUPPORT_URL=https://your-real-support-page\`. No payment URL is guessed.
- Rewarded/interstitial ad IDs are still Google test IDs in \`lib/ad_helper.dart\`; set up production units and verify child-directed ad/network policy before release.
- Technical safeguards do not certify compliance with COPPA, GDPR-K or Google Play Families Policy.

## Build and test

Use Flutter stable and Java 17.

\`\`\`sh
flutter pub get
dart run flutter_launcher_icons
flutter test
flutter analyze
flutter build appbundle --release --dart-define=VIBESYNC_SUPPORT_URL=https://your-verified-support-page
\`\`\`

GitHub Actions builds an AAB and APK, runs tests and static analysis, and uploads artifacts. Verify release signing, install on real devices, and test Play Store in-app updates through a Play testing track before publishing.

## Android release versioning

This release candidate uses version name `1.0.1` and build/version code `20261019` (from `version: 1.0.1+20261019` in `pubspec.yaml`). The AAB and APK from the same release use the same version code. Before preparing a later Play Store release, increment both the version name as appropriate and the numeric value after `+`. GitHub Actions verifies that a release candidate's code is higher than the code on its base revision and blocks accidental reuse of an old code.
