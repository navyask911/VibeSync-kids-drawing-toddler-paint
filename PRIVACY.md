# Privacy Notice

**App:** VibeSync Kids Drawing & Creative Studio Pro  
**Publisher:** VibeSyncro Technologies Pvt Ltd  
**Website:** https://vibesyncro.com/  
**Last reviewed:** November 1, 2026

This notice describes the current repository implementation. It is not legal advice, a certification of compliance, or a substitute for the privacy disclosures and declarations required by Google Play, advertising providers, or applicable law.

## Children and parent controls

This is a child-oriented drawing application. Settings, purchase actions, subscription management, optional support links, and artwork export/backup actions are placed behind an arithmetic parent gate. The gate is a user-interface control; it is not identity verification, age assurance, or verifiable parental consent.

Parents and guardians should review the Play Store listing, Data safety form, service-provider terms and this notice before enabling the app for a child.

## Artwork and local storage

Drawing strokes, templates, stamps, fill layers, brush settings and layer settings are autosaved to app-private device storage. The app does not implement a developer-operated account system, cloud sync backend, or automatic upload of artwork.

A parent can explicitly export/share images, PDF files, SVG stroke paths, GIF stroke sequences, or JSON backups. Those operations create files locally and open a platform file picker, print service or share sheet. When a parent selects another app or cloud-storage destination, that recipient processes the selected file under its own terms and privacy policy.

Local files may be removed when app data is cleared, the application is uninstalled, or the device is reset. Parents should keep their own backups where needed.

## Creative Agent and voice

The Creative Agent builds prompt text and short story starters from non-identifying drawing tags stored in the current canvas. Its language dictionary is on-device. Text-to-speech uses the installed Android speech engine.

The app does not request microphone permission, record a child's voice, or send prompt text, canvas coordinates, artwork or voice recordings to a hosted LLM as part of this implementation. Some device text-to-speech providers may have their own system-level behavior; review the provider settings on the device.

## Advertising, billing and other SDKs

The Android application integrates Google Mobile Ads, Google Play Billing through Flutter's `in_app_purchase` package, connectivity checks, in-app updates, file selection, PDF/printing, image encoding and text-to-speech dependencies.

The AdMob helper applies child-directed treatment, a G-rated content ceiling and a non-personalized request extra. These settings do not by themselves establish that every serving ad SDK/mediation adapter is currently certified for children or that every legal requirement has been met. Before release, verify the currently applicable Google Play Families Policy requirements, SDK self-certification status, ad mediation partners, privacy settings, regional consent requirements, Data safety answers and ad disclosures.

Google Play processes purchases and may receive purchase-account, transaction, device and diagnostic data under its own policies. The current app receives purchase updates/restores and persists a 24-hour app-private entitlement cache for offline convenience. This repository does not include server-side purchase-token validation. The local cache is not authoritative proof of subscription validity, expiry, refunds, chargebacks or cross-device ownership.

Connectivity and update APIs may contact their respective network endpoints. The app does not operate a server receiving these checks.

## Permissions

The app uses Android Internet and network-state permissions for advertising, billing, connectivity and update services. It does not request microphone or precise-location permission. It uses app-private storage and parent-initiated file picker/share/print flows rather than broad shared-storage access.

## Data sharing and retention

The publisher does not operate an artwork-upload or user-account backend in this repository. Data sent to Google Mobile Ads, Google Play, Android services, selected file/share/printing recipients, device speech engines, or connectivity/update providers is governed by those providers' terms and notices. Parents control files they explicitly export.

## Parental requests and contact

For questions about this notice or a privacy request, contact the publisher through:

https://vibesyncro.com/

Please do not send a child's artwork or personal information unless it is necessary for your request.

## Updates

This notice should be reviewed and updated when the app adds network services, analytics, cloud sync, account functionality, new SDKs, or changes to advertising/billing behavior. The effective policy shown in Google Play and on the publisher's website should match the policy shipped with the app.
