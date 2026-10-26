# Transport One

Enterprise Fleet Operations and Route Intelligence Application for Commercial Fleet Management.

---

## Overview

Transport One is a production-grade, cross-platform logistics and fleet operations system built with Flutter. It provides real-time route planning, multi-stop waypoint routing, highway traffic intelligence, driver management, and safety verification workflows for commercial transportation networks across India.

The application adapts across form factors, providing a streamlined vertical interface for mobile drivers and an expansive split-workspace console for fleet dispatchers and administrators on tablets, desktops, and web browsers.

---

## Core Features

### 1. Route Planning and Navigation
- **Interactive Map Engine:** High-performance raster and vector tile map rendering powered by FlutterMap.
- **Multiple Map Layers:** Street, Satellite, and Streetlight (night-mode) base layers with offline fallback support.
- **Multi-Stop Waypoints:** Support for arbitrary intermediate via-stops between origin pickup and final destination with dynamic stop reordering and removal.
- **Live Traffic Intelligence:** Real-time road traffic estimation based on highway density and speed profiles with color-coded road polylines (Smooth / Moderate / Heavy Congestion).
- **One-Tap Quick Presets:** Pre-configured commercial transit corridors (e.g., Bardoli - Surat - Kamrej, Surat City Loop, Mumbai Corridor).
- **Turn-by-Turn Navigation HUD:** Real-time navigation view with maneuver indicators in Hindi and English, live GPS speedometer, camera follow lock, and external Google Maps integration.

### 2. Fleet and Operations Management
- **Centralized Operations Dashboard:** Real-time fleet readiness metrics, active dispatches, driver availability, and system activity logs.
- **Driver Profiles and Roster:** Driver credential management, licensing records, assigned vehicles, contact details, and activity logs.
- **Vehicle Profiles and Payloads:** Vehicle categorization across Two-Wheelers, Light Commercial / Passenger Vehicles, and Heavy Commercial Trucks with customizable axle counts, speed governor limits, and payload capacities.
- **Trip Dispatch Management:** Trip generation, status tracking (Scheduled, In Transit, Delivered), and historical trip logging.
- **Operations Alerts:** Real-time fleet notices, speed alerts, route diversions, and regulatory compliance memos.

### 3. Driver Safety and Verification
- **Driver Seatbelt Verification:** Camera and photo attestation workflow with visual harness verification before trip departure.
- **Administrative Audit Console:** Role-gated verification history and audit review workflow for safety compliance.
- **Safety Notifications:** Context-aware audio and visual alerts during navigation.

### 4. Security and Architecture
- **Role-Based Access Control:** Separate operational contexts for Fleet Administrators and Mobile Drivers with secure role isolation.
- **Cryptographic Credential Verification:** Salted PBKDF2 credential verification with automated failed-attempt rate limiting and lockout defense.
- **Android Hardening:** Enforced `android:allowBackup="false"`, scoped XML backup and data extraction rules, `usesCleartextTraffic="false"`, and system-CA-only network security config.
- **No Embedded Plaintext Secrets:** Session token issuance and verification isolated from reverse-engineering extraction.

---

## Technology Stack

| Layer | Technologies |
|---|---|
| **Framework** | Flutter 3.x / Dart SDK (>=3.3.0 <4.0.0) |
| **Mapping Engine** | `flutter_map` (v8.3.2) with `latlong2` |
| **Geolocation** | `geolocator` (v14.1.1) with high-accuracy positioning |
| **Networking & HTTP** | `http` (v1.6.0) with custom User-Agent attribution |
| **Local Storage** | `shared_preferences` (v2.5.6) with platform interface |
| **Cryptography** | `crypto` (v3.0.6) for PBKDF2 and SHA-256 operations |
| **External Actions** | `url_launcher` (v6.3.3) for native navigation intents |

---

## Directory Structure

```text
lib/
├── main.dart                               # Application entrypoint and theme setup
└── src/
    ├── controllers/
    │   └── planner_controller.dart         # Core state management and business logic
    ├── models/
    │   └── planner_models.dart             # Vehicle, Driver, Trip, and Alert data models
    ├── pages/
    │   ├── alerts_page.dart                # Operations alerts and compliance feed
    │   ├── dashboard_page.dart             # Fleet KPI metrics and activity console
    │   ├── fleet_workspace.dart            # Multi-tab operational workspace host
    │   ├── login_page.dart                 # Universal authentication screen
    │   ├── operations_module_page.dart     # Dedicated Drivers and Vehicles management
    │   ├── route_planner_page.dart         # Responsive map and planner panel layout
    │   └── trips_page.dart                 # Trip dispatch and tracking screen
    ├── services/
    │   ├── app_security_service.dart       # PBKDF2 hashing, lockout, and encryption
    │   ├── map_tile_service.dart           # Tile URLs, subdomains, and fallback logic
    │   ├── route_traffic_service.dart      # OSRM routing, maneuvers, and road traffic
    │   └── safety_notification_service.dart# Operational alerts and sound triggers
    └── widgets/
        ├── map_workspace.dart              # Map widget, HUD, markers, and floating bars
        ├── planner_panel.dart              # Route inputs, presets, and fleet controls
        └── seatbelt_verification_dialog.dart# Driver safety photo capture and review
```

---

## Getting Started

### Prerequisites
- Flutter SDK (version 3.3.0 or higher)
- Android SDK (API level 24 minimum, API 34+ recommended)
- Google Chrome (for web evaluation)

### Installation

1. Clone or extract the project repository to your local workspace:
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

### Web
Launch the interactive web console on Chrome:
```bash
flutter run -d chrome
```

### Android Device / Emulator
Connect an Android device with USB debugging enabled or launch an Android Virtual Device (AVD):
```bash
flutter run
```

---

## Quality Assurance and Testing

The project maintains comprehensive unit, widget, and smoke tests to prevent regressions.

### Static Code Analysis
Run the static analyzer to confirm zero errors, warnings, and lints:
```bash
flutter analyze
```

### Automated Test Suite
Run the full test suite across authentication, routing, and responsive layouts:
```bash
flutter test
```

Test coverage includes:
- `test/login_page_test.dart`: Universal login rendering, credential verification, and error handling.
- `test/map_tile_service_test.dart`: Map tile URLs, subdomains, user agents, and offline fallbacks.
- `test/planner_controller_test.dart`: Waypoints management, truck payloads, and state persistence.
- `test/workspace_smoke_test.dart`: Responsive rendering without RenderFlex overflow at mobile (360x720) and desktop (1280x800) resolutions.

---

## Building for Production

### Android Release APK
Generate architecture-optimized release APKs:
```bash
flutter build apk --release --split-per-abi
```
Generated artifacts are located at:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

The primary production release binary is also packaged at the repository root:
- `TransportOne.apk` (ARM64 production release)

### Android App Bundle (Google Play)
```bash
flutter build appbundle --release
```
Artifact output:
- `build/app/outputs/bundle/release/app-release.aab`

### Web Production Bundle
Compile the optimized web distribution:
```bash
flutter build web --release
```
Artifact output directory:
- `build/web/`

---

## Security and Compliance Standards

Transport One incorporates modern Android security best practices:
- **No Cleartext Traffic:** `android:usesCleartextTraffic="false"` prevents unencrypted HTTP transmissions.
- **Scoped Backup Controls:** `android:allowBackup="false"` with XML rules prevents unauthorized ADB extraction of SharedPreferences.
- **Hardware Acceleration:** Enabled with high-performance Flutter native rendering.
- **Rate-Limited Authentication:** Defends against brute-force attacks via exponential delay and lockout thresholds.
- **Zero In-Binary Plaintext Secrets:** Authentication and session verification tokens are dynamically computed and validated.
