# Transport One 1.2.0 Security/Tracking Remediation

## Implemented

- Removed seeded driver phone/PIN data, IMEIs, vehicle coordinates and fake LIVE telemetry.
- Replaced client-authoritative login with Firebase Authentication and role custom claims.
- Replaced unauthenticated Firestore REST writes with the authenticated Firestore SDK.
- Added restrictive owner/admin Firestore rules and delivery-proof ownership metadata.
- Moved the device encryption key from SharedPreferences to Android Keystore/iOS Keychain storage.
- Disabled client-side WhatsApp OTP proof generation and direct Protrack credential storage.
- Added Firebase Functions backends for Protrack, routing, AI verification and driver account administration.
- Added strict web CORS handling, Protrack token caching, coordinate bounds checks, and fail-closed driver IMEI authorization to Functions.
- Fixed Android Firebase startup to use `google-services.json` and enabled the Google Services Gradle plugin.
- Removed implicit first-driver/first-vehicle assignment from safety photos, reports, driver portal and new-trip creation.
- New trips now require an explicit pickup, drop, vehicle, driver, customer and cargo selection.
- Removed remaining sample customer/vehicle/driver fallbacks from production models and reports.
- Added photo-size/read-error handling to delivery proof and driver photo uploads.
- Fixed the Flutter test environment secure-storage hang and prevented signed-out GPS polling.
- Replaced undocumented Google tile scraping with OpenStreetMap/ArcGIS/Carto providers.
- Removed mixed straight-line/road routes; an incomplete road route now fails closed.
- Prevented an administrator phone GPS from being shown as the selected truck location.
- Corrected stale/demo tracker reporting and the misleading PDF export label.
- Restricted demo telemetry controls to debug builds.
- Removed the unused vendor `login_v2.js` artifact.

## Verification

- `dart analyze`: 0 issues.
- Focused security/routing regression suite: 7/7 passing.
- Android release APK: builds successfully, version `1.2.0+8`.
- APK signature: RSA 2048, APK Signature Scheme v2 verified.
- Release SHA-256: `1B197ABDBEC5354858CDFE524609F724A0FD3995F1265D3B091A6DA8E92033A8`.

## Required deployment configuration

The secure build intentionally has no embedded passwords or vendor secrets. Before production use:

1. Configure Firebase Authentication users and custom claims (`admin`, `super_admin`, or `driver`).
2. Deploy Firestore rules and Functions.
3. Add Functions secrets: `PROTRACK_ACCOUNT`, `PROTRACK_PASSWORD`, `SEATBELT_AI_URL`, `SEATBELT_AI_KEY`.
4. Set `ALLOWED_ORIGINS` for the deployed web domain and build with the deployed Function URLs described in `DEPLOYMENT.md`.
5. Rotate every password previously pasted into chat or included in an older APK.

Legacy tests that explicitly require hardcoded admin/PIN login, direct Protrack passwords, unofficial Google tiles or byte-entropy “liveness” are obsolete and intentionally fail. The replacement regression suite asserts the secure behavior.
