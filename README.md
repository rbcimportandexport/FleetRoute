# Transport One (FleetRoute)

Enterprise Fleet Operations, Protrack GPS Live Tracking, Fastag Integration, AI Cargo Intelligence, and Route Navigation Application for Commercial Fleet Management across India.

---

## Overview

**Transport One** is a production-grade, cross-platform logistics and fleet operations system built with Flutter and Firebase. It provides real-time route planning, multi-stop waypoint routing, OSRM road highway traffic intelligence, Protrack GPS hardware tracking, Fastag toll integration, driver duty/attendance management, AI cargo weight estimation, and safety verification workflows for commercial transportation networks across India.

The application adapts seamlessly across form factors:
- **Mobile Driver Desk & Navigation:** Clean, touch-optimized HUD with turn-by-turn guidance in Hindi & English, live GPS speedometer, Sunday vehicle cleaning attestation, duty punch-in/out, and POD (Proof of Delivery) upload.
- **Admin & Fleet Dispatch Console:** Split-workspace console for fleet dispatchers and administrators on tablets, desktops, and web browsers with real-time multi-truck GPS tracking, expense audits, billing/invoicing, and customer dispatching.

---

## Core Features & Modules

### 1. Route Planning & Turn-by-Turn Live Navigation
- **Interactive Map Engine:** High-performance raster and vector tile map rendering powered by FlutterMap with Google Maps fallback options.
- **Multiple Map Layers:** Street, Satellite, and Streetlight (night-mode) base layers with offline cache support.
- **Multi-Stop Waypoints & Pin Modes:** Instant tap-to-set for **Pickup (Green Pin)**, **Drop (Red Pin)**, and multiple **Via Stops (Orange Pins)** with real-time reverse geocoding.
- **Continuous Pickup & Drop Visibility:** Both Pickup and Drop markers remain clearly showcase on the map throughout the live trip navigation.
- **Accurate Distance & Road Maneuver Engine:**
  - Real-time road distance calculation (`Geolocator.distanceBetween`) along exact OSRM highway coordinates.
  - Turn indicators formatted dynamically: distances under 1,000 meters in `m`, and above 1,000 meters in `km`.
  - Far-horizon road instructions (e.g. `685 km तक सीधे चलें / Continue straight`) avoiding confusing premature turn alerts.

### 2. Protrack GPS & Live Telemetry
- **Hardware Integration:** Real-time Protrack GPS tracker integration (`api.protrack365.com`) for tracking truck ignition, real speed, course bearing, and stale signal detection.
- **Fallback Phone GPS Tracking:** Automatic fallback to device GPS with stationary drift suppression.
- **Live Vehicle Telematics:** Instant popup detailing battery voltage, ignition status, speed governor alerts, and trip history.

### 3. Fastag & Toll Tracking
- **Automatic Toll Deductions:** Integration with NPCI NETC Fastag API for real-time FASTag balance, transaction history, toll plaza passages, and expense audits.
- **Fleet Expense Auto-Matching:** Direct linking of Fastag toll records to active trips.

### 4. Cargo Intelligence & Product Catalog
- **Automated Weight Calculation:** Intelligent category-based cargo weighting:
  - Beds / Furniture: 45 KG – 50 KG / unit
  - Chairs / Stools: 25 KG – 28 KG / unit
  - Shampoos / Liquids: 35 KG – 40 KG / box
  - Trolleys / Accessories: 15 KG – 20 KG / unit
- **Custom Cargo Items:** Dynamic piece/quantity counter with instant total payload summary and overload protection against truck payload limits.

### 5. Driver Duty, Safety & Weekly Cleaning
- **Attendance & Duty Management:** Start Duty / End Duty with date-guarded attendance records ensuring past shifts are never falsely marked active.
- **Seatbelt & Cabin Verification:** AI image verification and camera attestation ensuring safety compliance before departure.
- **Weekly Sunday Vehicle Cleaning:** Automated Sunday cleaning reminder and photo upload verification with deduplication guards.
- **Police / RTO Memo Reporting:** Instant photo submission for on-road challans and compliance reviews.

### 6. Billing, Invoicing & POD (Proof of Delivery)
- **Trip Dispatches:** Structured trip numbers (e.g., `TRIP-2026-082` for admin orders, `LIVE-GJ19Y2720` for driver live routes).
- **Proof of Delivery (POD):** Photo capture, customer recipient name, and signature proof sync.
- **Invoicing & PDF Exports:** Comprehensive report generation for fleet expenses, tolls, diesel, and profit margins.

---

## Technology Stack

| Layer | Technologies |
|---|---|
| **Framework** | Flutter 3.x / Dart SDK (>=3.3.0 <4.0.0) |
| **Backend & Cloud** | Firebase Firestore, Firebase Authentication, Cloud Storage |
| **Mapping Engine** | `flutter_map` (v8.3.2) with `latlong2` & `google_maps_flutter` |
| **Geolocation & GPS** | `geolocator` (v14.1.1) with high-accuracy positioning |
| **External Telematics** | Protrack API (`api.protrack365.com`) & Fastag NETC APIs |
| **Local Persistence** | `shared_preferences` (v2.5.6) |
| **Security & Crypto** | PBKDF2 with SHA-256 password hashing & rate limiting |

---

## Directory Structure

```text
lib/
├── main.dart                               # Application entrypoint & theme setup
└── src/
    ├── controllers/
    │   └── planner_controller.dart         # Core state management and fleet business logic
    ├── models/
    │   └── planner_models.dart             # Vehicle, Driver, Trip, Cargo, and Telemetry models
    ├── pages/
    │   ├── alerts_page.dart                # Operations alerts and compliance notices
    │   ├── billing_page.dart               # Invoices, freight billing, and rate calculation
    │   ├── dashboard_page.dart             # Real-time fleet KPI metrics and fleet overview
    │   ├── driver_portal_page.dart         # Driver mobile desk, duty, cleaning & trip sheet
    │   ├── expenses_page.dart              # Diesel, toll, maintenance & driver allowance ledger
    │   ├── fastag_history_page.dart        # Real Fastag toll transaction logs
    │   ├── login_page.dart                 # Universal authentication screen
    │   ├── reports_page.dart               # Fleet analytics and CSV/PDF export console
    │   └── trips_page.dart                 # Trip dispatch, cargo loading, and status tracker
    ├── services/
    │   ├── firebase_backend_service.dart   # Firestore sync and cloud backup
    │   ├── protrack_gps_service.dart       # Protrack GPS telematics service
    │   ├── real_fastag_service.dart        # Fastag toll sync
    │   ├── route_traffic_service.dart      # OSRM road routing, maneuvers, and road traffic
    │   └── safety_notification_service.dart# Operational alerts, sound triggers & push notices
    └── widgets/
        ├── map_workspace.dart              # Map widget, live HUD, navigation & markers
        ├── planner_panel.dart              # Route inputs, presets, and fleet controls
        └── seatbelt_verification_dialog.dart# Driver safety photo capture and review
```

---

## Getting Started

### Prerequisites
- Flutter SDK (version 3.3.0 or higher)
- Android SDK (API level 24 minimum, API 34+ recommended)
- Google Chrome (for web console evaluation)

### Installation

1. Clone or extract the project repository:
   ```bash
   cd "d:/TRANSPORT 1"
   ```

2. Retrieve project dependencies:
   ```bash
   flutter pub get
   ```

3. Verify development environment:
   ```bash
   flutter doctor
   ```

---

## Running the Application

### Web Console
Launch the interactive web console:
```bash
flutter run -d chrome
```

### Android Device / Emulator
Connect an Android device with USB debugging enabled:
```bash
flutter run
```

---

## Quality Assurance & Testing

Run static analysis to confirm zero errors or lints:
```bash
flutter analyze
```

Run automated tests:
```bash
flutter test
```

---

## Building for Production

### Android Release APK
Generate the release APK:
```bash
flutter build apk --release
```
The production APK is copied to the repository root:
- `TRANSPORT_ONE.apk`

### Web Production Bundle
Compile the optimized web distribution:
```bash
flutter build web --release
```
Artifact output directory:
- `build/web/` (deployed to `client/public/`)

---

## Production Security & Deployment

- **Scoped Backup Controls:** `android:allowBackup="false"` with scoped extraction rules.
- **Hardware Acceleration:** Native Skia / Impeller Flutter GPU rendering.
- **Encrypted Local Storage:** Passwords hashed with PBKDF2 and rate-limited against brute-force attacks.
- **Real-Time Cloud Synchronization:** Multi-device synchronization across Web and Mobile via Firebase Firestore.
