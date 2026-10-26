# Secure deployment

## Firebase

Enable Email/Password Authentication, create the first administrator, and assign the custom claim:

```json
{"role":"super_admin"}
```

Deploy backend resources:

```text
cd functions
npm install
cd ..
firebase functions:secrets:set PROTRACK_ACCOUNT
firebase functions:secrets:set PROTRACK_PASSWORD
firebase functions:secrets:set SEATBELT_AI_URL
firebase functions:secrets:set SEATBELT_AI_KEY
firebase deploy --only firestore:rules,firestore:indexes,functions
```

`ALLOWED_ORIGINS` is a comma-separated list when more than one custom web
domain is used. Set it as a Firebase Functions parameter when the CLI prompts
during deployment (or in the Functions environment file). Firebase Hosting
domains for the current project and local development origins are accepted
automatically.

After adding or changing a vehicle IMEI, re-save its assigned driver through
the admin UI so the backend refreshes that driver's `assignedImeis` claim.
The driver must sign out and sign in again to receive the refreshed claim.

## Release build

Android reads its public Firebase application configuration from
`android/app/google-services.json`. Web builds must supply their Firebase Web
App configuration at build time. Never pass Protrack or AI provider secrets to
Flutter.

```text
flutter build apk --release ^
  --dart-define=FIREBASE_API_KEY=PUBLIC_FIREBASE_WEB_API_KEY ^
  --dart-define=FIREBASE_APP_ID=FIREBASE_APP_ID ^
  --dart-define=FIREBASE_PROJECT_ID=FIREBASE_PROJECT_ID ^
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=SENDER_ID ^
  --dart-define=FIREBASE_STORAGE_BUCKET=BUCKET ^
  --dart-define=PROTRACK_PROXY_URL=https://REGION-PROJECT.cloudfunctions.net/protrackProxy ^
  --dart-define=ROUTING_API_URL=https://REGION-PROJECT.cloudfunctions.net/routingProxy ^
  --dart-define=FIREBASE_FUNCTIONS_URL=https://REGION-PROJECT.cloudfunctions.net/safetyApi ^
  --dart-define=FLEET_ADMIN_API_URL=https://REGION-PROJECT.cloudfunctions.net/adminApi
```

Without these values the application fails closed: it does not accept a local admin password, fabricate tracker coordinates, or approve a seatbelt photo locally.
