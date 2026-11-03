# VibeSync Kids Drawing & Creative Studio Pro

A Flutter drawing studio for children and families, published by **VibeSyncro Technologies Pvt Ltd**.

Website: https://vibesyncro.com/

## Features

- Child-friendly free drawing, fill bucket, stickers, coloring templates, undo/redo and local autosave.
- Toddler Mode with larger touch targets and multi-pointer stroke rejection.
- Parent-gated Pro Artist Mode with up to 12 editable layers, opacity, visibility, layer merge/delete, radial 4/8-way symmetry, mirror symmetry, eyedropper and advanced brushes.
- Neon glow, rainbow gradient, watercolor, pressure-simulated calligraphy and charcoal renderers.
- Double-tap canvas chrome hide/show with animated toolbars and haptic feedback.
- Optional yearly Google Play subscription using product ID `adfree_yearly`. The in-app UI displays the localized price returned by Google Play.
- Parent-controlled PNG/JPEG/PDF/SVG export, JSON backup/restore and animated GIF stroke-sequence export.
- An offline Creative Agent with 52 prompt/story language entries and device text-to-speech. It does not capture microphone audio or call a hosted LLM.

## Repository layout

- `lib/main.dart`: app shell, parent gate, subscription UI, studio controls, full-screen chrome, creative agent and export actions.
- `lib/subscriptions/ad_free_subscription_service.dart`: Google Play purchase stream, restore flow and app-private offline entitlement cache.
- `lib/drawing/drawing_controller.dart`: stroke history, layers, layer commands and symmetry transforms.
- `lib/drawing/drawing_models.dart`: drawing models, timestamps, pressure samples, layers, tools, modes and brush types.
- `lib/drawing/drawing_painters.dart`: layer painter and brush renderers.
- `lib/drawing/drawing_canvas.dart`: pointer handling, palm-touch rejection, fill bucket and canvas pixel eyedropper.
- `lib/drawing/drawing_persistence.dart`: versioned, bounded local autosave and parent-selected JSON backup/restore.
- `lib/creative/ai_creative_agent.dart`: offline prompt/story dictionary and device TTS for 52 languages.
- `lib/export/drawing_export_service.dart`: SVG stroke-path and animated GIF stroke-sequence encoders.
- `lib/l10n/app_localizations.dart`: app chrome localization (currently English, Spanish, Hindi, Chinese, German and French).

## Subscription setup

The Android app queries the Google Play subscription product ID:

```text
adfree_yearly
```

Create and activate this subscription in Play Console, add an annual auto-renewing base plan, and set the India price to **₹299 per year** (or the intended localized price in other markets). Google Play owns the displayed price, offer eligibility, billing periods and renewal terms; the app intentionally displays the price returned by the store rather than hard-coding it.

Android purchases use Google Play Billing subscriptions (not consumable purchases) through `in_app_purchase` and `in_app_purchase_android`. The product ID is `adfree_yearly` and must be configured in Play Console as an active auto-renewing subscription with the intended ₹299 annual base plan. Purchases use `buyNonConsumable`; every update marked `pendingCompletePurchase` is acknowledged with `completePurchase`.

For device binding, Android reads `Settings.Secure.ANDROID_ID` through a native Flutter platform channel and computes a SHA-256 hash using the app package name as a salt. Only that 64-character hash is sent to Google Play as the obfuscated account ID. A purchase/restore is granted only when the returned Google Play `obfuscatedAccountId` matches the current device hash. A legacy/test purchase with no obfuscated ID may be bound locally on first activation; it cannot be proven to belong to the first device after app data is removed, so this fallback is weaker than a Play record created with device binding.

The app stores the matching device hash and latest successful store confirmation in SharedPreferences for a **7-day offline grace period**. The cache is convenience state, not authoritative subscription proof, and is ignored when its device hash differs. On Android 8.0+, `ANDROID_ID` is scoped to the app signing key, Android user/profile and device; it remains stable across app updates and uninstall/reinstall while those scopes remain unchanged, but can change after a factory reset, signing-key change or user/profile change.

**There is no server-side purchase-token verification or central device-claim service in this repository.** Client-side binding blocks ordinary Google Play restores on a second device when the purchase contains its obfuscated account ID, but a modified client, identity change, or legacy purchase without a Play-side ID can bypass or weaken the limit. Enforceable cross-device controls, expiry/refund/revocation checks and abuse response require a trusted backend that verifies Play purchase tokens and atomically binds each active token to one device hash. This implementation does not claim server-grade anti-sharing or tamper resistance.

## Data handling and child safety

- Drawing state and backups remain on-device unless a parent explicitly chooses a destination through the system file/share UI.
- The Creative Agent uses local text dictionaries and the installed device text-to-speech engine. It does not record speech or send prompts/artwork to an LLM.
- The app does not request microphone or precise-location permissions.
- Parent gates are friction controls, not age verification or a substitute for verifiable parental consent.
- AdMob child-directed/non-personalized request flags are technical settings, not a Families Policy or COPPA/GDPR certification. Confirm current certified ad SDK requirements, disclosures, consent obligations, Data safety answers and Play Console declarations before publishing.

See [PRIVACY.md](PRIVACY.md) and [privacy-policy.html](privacy-policy.html). Review them whenever dependencies or SDK settings change.

## Export scope

- PNG is rendered from the canvas scene and can be shared through Android's share sheet.
- JPEG is encoded from the rendered PNG.
- SVG exports editable vector polylines for committed stroke paths and visible layer opacity. It does not vectorize raster fill images or reproduce every stamp/template primitive.
- PDF export wraps the rendered PNG on an A4 page for sharing, printing or saving.
- GIF timelapse reconstructs a bounded stroke sequence from saved stroke order/timestamps. It is not an MP4 recorder and does not replay canvas fills or every stamp/template animation.

## Build and verification

Use Flutter stable **3.44.0 or newer**, Dart **3.12 or newer** from the same Flutter SDK, Java 17 and Android SDK build-tools.

```sh
flutter pub get
dart run flutter_launcher_icons
flutter test
flutter analyze
flutter build appbundle --release
flutter build apk --release
```

GitHub Actions performs dependency resolution, launcher generation, Flutter tests, Dart analysis, signed AAB/APK builds, 16 KB App Bundle/ELF/ZIP alignment checks and artifact upload.

## Release version

Current candidate: **1.0.9 (versionCode 20261103)**, represented by:

```yaml
version: 1.0.9+20261103
```

The same values must be reflected in `android/app/build.gradle`. Verify the version code has not already been used in Play Console before uploading.

## Company

© 2026 VibeSyncro Technologies Pvt Ltd. All rights reserved.

https://vibesyncro.com/
