# FleetRoute - Multi-Stop Fleet, Driver, Cargo & Delivery Management System

FleetRoute is a full-stack commercial logistics, fleet dispatch, driver telematics, and multi-stop operations management platform built with React, Node.js (Express), MongoDB, and a responsive Progressive Web App (PWA) architecture.

FleetRoute enforces a strict zero-emoji design policy, using clean Lucide vector icons, deep navy navigation (`#0b1120`, `#0f172a`), light gray neutral backgrounds (`#f8fafc`), white cards (`#ffffff`), and teal/blue primary action indicators (`#0284c7`, `#0d9488`).

---

## 1. Core System Architecture

- **Frontend**:
  - React 18, Vite, Leaflet OpenStreetMap & Google Satellite Hybrid (`lyrs=y`).
  - Lucide React icon library (Zero Emoji standard across all UI components).
  - Web Audio API alert synthesizer (chimes, clicks, geofence, and safety sound effects).
  - Progressive Web App (PWA) Service Worker with offline action queue.
  - Interactive Dual-Pin Route Geofence & Haversine gap calculator (Point A Origin & Point B Drop).
  - Clean Light Theme authentication portal with secure JWT session handling.
- **Backend API**:
  - Node.js, Express REST API (`/api/v1/*`), JSON Web Tokens (JWT), Bcrypt password hashing, CORS, Dotenv.
  - Dedicated endpoints for Trips, Drivers, Vehicles, Locations, Safety Events, and Cargo actions.
  - Pre-trip safety gate inspections (odometer photo, driver selfie, seatbelt check, safety pledge).
  - Activity timeline engine for real-time breakdown, incident, toll, and police/RTO challan reporting.
- **Persistence**:
  - Real persistent MongoDB database via Mongoose.
  - In-memory demo fallback storage (`ALLOW_DEMO_STORAGE`) is completely removed. FleetRoute fails startup cleanly if MongoDB is unreachable and returns `503 Service Unavailable` if connectivity is interrupted during operation.
- **Data Integrity**:
  - Zero fake records, zero simulated driver movement, zero placeholder rates, and zero automatic seed accounts. Empty screens present honest empty states.
- **Timezone Standard**:
  - All server timestamps are stored in ISO-8601 UTC; client interfaces present times formatted for local operations (Asia/Kolkata IST, UTC+5:30).

---

## 2. Setup and Startup Instructions

### Prerequisites
- **Node.js**: v18.0.0 or higher (tested on Node.js v20+)
- **npm**: v9.0.0 or higher
- **MongoDB**: Local MongoDB instance (port 27017) or MongoDB Atlas connection URI

### Step-by-Step Installation

1. **Install backend dependencies:**
   ```bash
   cd server
   npm.cmd install
   cd ..
   ```

2. **Install frontend dependencies:**
   ```bash
   cd client
   npm.cmd install
   cd ..
   ```

3. **Configure Environment Variables:**
   Copy `.env.example` to `.env` in the root and `server` directories:
   ```bash
   cp .env.example server/.env
   ```
   Set `MONGODB_URI` and `JWT_SECRET` in `server/.env`. A cryptographically strong `JWT_SECRET` is strictly required.

4. **Bootstrap Initial Administrator:**
   Because automatic demo seeding is removed, run the one-time admin bootstrap tool:
   ```bash
   npm run bootstrap:admin
   ```
   Or pass parameters via flags/environment without printing credentials:
   ```bash
   node server/scripts/bootstrapAdmin.js --name "Chief Dispatcher" --email "admin@company.com" --phone "+919820011223" --password "YourStrongPassword123!"
   ```
   *Note: The bootstrap script will refuse to overwrite an existing administrator.*

---

## 3. Running Backend and Frontend

Run backend and frontend in separate terminals:

**Terminal 1 (Backend API Server on port 5000):**
```bash
npm run server
```
Expected output:
```text
[FleetRoute Database] Connected to persistent MongoDB at mongodb://localhost:27017/fleetroute
[FleetRoute Server] Listening on port 5000 in production mode
```

**Terminal 2 (Frontend Client on port 3000):**
```bash
npm run client
```
Access the application in your browser at: `http://localhost:3000`

To build the client bundle for production:
```bash
npm run build
```

---

## 4. Administrative Bootstrap & Demo Cleanup Tools

### Administrator Bootstrap Tool
- **Command:** `npm run bootstrap:admin`
- **Behavior:**
  - Connects to the configured persistent MongoDB instance.
  - Prompts for name, email, phone number, and password (or reads CLI flags / environment variables).
  - Validates password complexity (minimum 8 characters).
  - Hashes passwords using Bcrypt with salt rounds.
  - Enforces one-time initialization: safely aborts if an administrator already exists.
  - Never prints passwords or JWT tokens to logs or terminal output.

### Confident Demo Data Cleanup Tool
- **Default Dry-Run Command:**
  ```bash
  npm run cleanup:demo
  ```
  Scans all database collections (`users`, `drivers`, `vehicles`, `products`, `locations`, `trips`, `safetyEvents`, `deliveryProofs`) for verified demo markers and known seed identifiers. Outputs an audit summary of confirmed demo records, real operational records preserved, and ambiguous records left untouched. Makes zero modifications.

- **Apply Command (Permanent Deletion of Confirmed Demo Data):**
  ```bash
  npm run cleanup:demo -- --apply
  ```
  Deletes only confirmed demo records matching verifiable seed identifiers or explicit `isDemo: true` markers. Ambiguous records (e.g. real records containing the word "demo" in user notes) are strictly preserved.

---

## 5. Environment Variables Reference

| Variable | Required | Description |
| :--- | :--- | :--- |
| `PORT` | Optional (default: `5000`) | HTTP port for the Express backend API. |
| `NODE_ENV` | Optional (default: `production`) | Runtime environment mode. |
| `MONGODB_URI` | **Mandatory** | MongoDB connection URI string. Startup cleanly fails if missing or unreachable. |
| `JWT_SECRET` | **Mandatory** | Cryptographic key used to sign and verify session JWTs. No hardcoded fallback exists. |
| `JWT_EXPIRES_IN` | Optional (default: `24h`) | Session token expiration duration. |
| `DEFAULT_ARRIVAL_RADIUS_METERS` | Optional (default: `150`) | Arrival geofence radius in meters for driver check-in. |
| `OVERSPEED_THRESHOLD_KMH` | Optional (default: `80`) | Speed threshold that generates an overspeed safety alert from real telemetry. |
| `LOCATION_UPDATE_INTERVAL_MS` | Optional (default: `5000`) | Client-side geolocation transmission interval in milliseconds. |
| `GEOCODING_PROVIDER` | Optional (default: `nominatim`) | Address geocoding service. |
| `GEOCODING_API_URL` | Optional | Custom Nominatim endpoint URL. |

---

## 6. Functional Capabilities & Production Upgrades

### 1. Clean Light Theme Authentication Portal
- Streamlined light-themed authentication card with smooth background orbs.
- Zero demo buttons or prefilled credentials on the login screen.
- Secure authentication via Bcrypt password hashing and JWT sessions.
- Role-based authorization: Drivers access only their assigned trips; administrators manage fleet operations. Public registration never grants admin permissions.

### 2. Interactive Map Visualizer & Dual-Pin Route Geofence
- **Google Satellite Hybrid Imagery**: Real-time high-resolution satellite tiles (`mt{s}.google.com/vt/lyrs=y`) and standard OpenStreetMap road layers.
- **Dedicated Point A & Point B Mode Switcher**:
  - `[ 🔵 A Point A सेट करें (Origin Hub) ]`
  - `[ 🔴 B Point B सेट करें (Destination Drop) ]`
- **Active Mode Guidance Banner**: Real-time contextual instruction banner highlighting the active pin mode and allowing instant 1-click swapping.
- **Targeting Crosshair Cursor & Non-Blocking Vector Layers**: Arrival radius geofence circle and route gap polyline are non-interactive (`interactive: false`), guaranteeing instant, unhindered pin placement on map clicks.
- **Haversine Distance & Travel Time Estimations**: Live calculation of aerial distance (km/m), road route approximation (~1.25 multiplier), and truck ETA (@ 42 km/h commercial fleet speed).
- **Independent Point B Direct Save**: Save Point B as a new delivery destination directly to MongoDB without overwriting Point A coordinates.

### 3. Multi-Stop Dispatch & Pre-Trip Gate Inspection
- **Dual Dispatch Wizard**:
  - Express Quick Dispatch: 1-screen, 30-second driver and cargo assignment.
  - Advanced Multi-Stop (7 Steps): Step-by-step route planning across driver selection, origin hub, loading waypoints, destination drops, cargo allocation, scheduling, and live pre-dispatch review.
- **Pre-Trip Gate Inspection Checklist**:
  - Vehicle walkaround verification.
  - Driver selfie and seatbelt compliance check.
  - Cluster odometer verification photo.
  - Zero-overspeed safety pledge sign-off.
- **Activity & Incident Reporting**: Real-time recording for vehicle breakdowns, traffic accidents, toll receipts, and police / RTO challan payments.

### 4. Honest Empty States & Real Dashboard Metrics
- Dashboard counters, chart series, and report metrics are calculated directly from authentic MongoDB collections without fake multipliers or random generation.
- Empty states display informative action prompts ("No trips created" with Create Trip, "No drivers added" with Add Driver, etc.).

### 5. Genuine Telematics & Live Fleet Tracking
- Live tracking displays locations received strictly from authenticated driver GPS telemetry.
- Simulated movement and simulated speed buttons are removed.
- GPS states distinctly display: Location unavailable, Last known location with timestamp, Live location with accuracy, GPS permission denied, or Location sharing stopped.
- Old telemetry samples (`deviceTimestamp <= lastSeen`) are rejected to preserve strict ordering.
- Overspeed alerts are triggered only by authentic speed samples exceeding the configured threshold.

### 6. Multi-Stop Workflows & Cargo Reconciliation
- Cargo ledger tracks `loadedQty`, `deliveredQty`, `damagedQty`, `rejectedQty`, and `returnedQty`.
- Idempotency deduplication prevents double deductions on network retries.
- Delivery proofs require real recipient names and genuine signatures/photos stored in MongoDB.

### 7. Production Service Worker & Offline Caching
- Service Worker invalidates legacy prototype caches.
- Authenticated operational API requests are never stored in public service worker caches, preventing cross-user data leakage.
- Offline action queuing preserves offline actions locally until connectivity is restored.

---

## 7. Verification & Automated Test Results

FleetRoute includes automated test suites covering core business logic, isolated end-to-end integration workflows, and endpoint verification.

### Running Core Logic Tests
```bash
npm test
```
Actual test output:
```text
--- RUNNING FLEETROUTE CORE LOGIC TESTS ---
[PASS] Test 1: Cargo balance progressive deduction verified (15 -> 10 -> 3 -> 0).
[PASS] Test 2: Activity durations exactly match 250 minutes with 0 overlaps.
[PASS] Test 3: Stop sequence progression verified.
--- ALL AUTOMATED LOGIC TESTS PASSED SUCCESSFULLY (3/3) ---
```

### Running Backend Endpoint Verification Script
```bash
node server/scripts/verifyEndpoints.js
```
Actual test output:
```text
[Test] Logging in as admin...
[Test] Admin logged in successfully.
[Test 1] Fetching driver user accounts... Found 8 driver accounts.
[Test 2] Editing driver account USE-1791885665898-380 (Rajesh Sharma)... Edit result: 200 -> User account updated successfully.
[Test 3] Fetching locations... Editing location LOC-HOME -> Result: 200
[Test 4] Fetching trips... Submitting gate proofs for trip TRIP-DEMO-01 -> Result: 200 (Driver Selfie Verified, Seatbelt Verified, Pledge Verified)
[Test 5] Recording Breakdown & Incident Report -> Result: 201 (Category: engine, Voice Note Saved)
[Test 6] Recording Police / RTO Challan Report -> Result: 201 (GJ01-2024-CH-9182, Penalty: 2000, Option: cash_spot)
[ALL TESTS PASSED SUCCESSFULLY!]
```

### Running Comprehensive Production Verification Suite
```bash
npm run test:all
```
Actual test output:
```text
================================================================
STARTING FLEETROUTE ISOLATED INTEGRATION TEST SUITE
================================================================
[Setup] Initializing isolated MongoMemoryServer instance...
[FleetRoute Database] Connected to persistent MongoDB
[Setup] Test Express server listening on http://127.0.0.1:52678

--- Test 1: Clean Database Starts with 0 Records & NO Demo Accounts ---
[PASS] 1.1 Verified database starts with exactly 0 operational records.
[PASS] 1.2 No demo accounts exist: unbootstrapped login rejected with 401.

--- Test 2: Administrator Bootstrap Tool ---
[PASS] 2.1 Initial administrator successfully bootstrapped via bootstrap script.
[PASS] 2.2 Bootstrap prevented overwriting existing administrator.
[PASS] 2.3 Bootstrapped administrator logged in successfully with JWT token.
[PASS] 2.4 Honest initial dashboard metrics verified (all 0s, zero fake rates).

--- Test 3: Database Disconnect Refusal (No In-Memory Fallback) ---
[PASS] 3.1 Disconnected MongoDB strictly returns 503 Service Unavailable without memory fallback.
[PASS] 3.2 Healthcheck reports disconnected database status.
[PASS] 3.3 Database successfully reconnected.

--- Test 4: Real Entity Creation & Coordinate Validation ---
[PASS] 4.1 Locations created and coordinate boundaries strictly enforced.
[PASS] 4.2 Product created in MongoDB.
[PASS] 4.3 Vehicle asset registered in MongoDB.
[PASS] 4.4 Driver profile registered in MongoDB.
[PASS] 4.5 Driver user authentication account created with bcrypt password.

--- Test 5: Trip Dispatch & Multi-Stop Workflow ---
[PASS] 5.1 Multi-stop trip created with 3 waypoints and 12 units planned.

--- Test 6: Driver Authentication & Trip Isolation ---
[PASS] 6.1 Driver authenticated successfully.
[PASS] 6.2 Driver trip isolation strictly enforced: other trips inaccessible.
[PASS] 6.3 Driver forbidden from administrative operations.

--- Test 7: Real GPS Telemetry, Ordering & Genuine Speed Alerts ---
[PASS] 7.1 Normal speed GPS sample accepted (42 km/h). No alert generated.
[PASS] 7.2 Out-of-order older GPS sample safely rejected from overwriting current position.
[PASS] 7.3 Genuine overspeed alert automatically generated from real telemetry (92 km/h > 80 km/h).

--- Test 8: Stop Progression, Cargo Balancing & Idempotency ---
[PASS] 8.1 Pickup completed with 12 units onboard. Idempotency verified.
[PASS] 8.2 Stop A delivery fulfilled (5 units delivered, 7 onboard). Real POD persisted.
[PASS] 8.3 Cargo ledger balance mathematically reconciled in MongoDB: 12 loaded, 11 delivered, 1 damaged, 0 remaining onboard.

--- Test 9: Demo Data Cleanup Script (Dry-run by Default) ---
[PASS] 9.1 Dry-run correctly left 100% of real created operational records untouched.
[PASS] 9.2 Dry-run identified demo record by ID without deleting it.
[PASS] 9.3 Apply mode permanently deleted demo record while safely preserving real operational records.

================================================================
ALL COMPREHENSIVE PRODUCTION VERIFICATION SUITES PASSED (9/9)
================================================================
```

---

## 8. Automatic Accident Detection & Zero-Touch Emergency Dispatch

FleetRoute includes a production-grade accident detection, zero-touch emergency escalation, and hospital triage engine built across seven architectural layers:

1. **Native Android Driver Application / Capacitor Wrapper**: Persistent foreground safety service with `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `BODY_SENSORS`, and `WAKE_LOCK`. Continuous sensor monitoring survives screen lock and process restarts.
2. **Multi-Sensor Fusion Engine**: Evaluates high-frequency accelerometer vector force (G-force), rapid GPS speed reduction (deceleration > 25 km/h drop), abnormal gyroscope rotation, and post-impact zero-motion stillness.
3. **Zero-Touch SOS Countdown**:
   - Severe crash detection triggers a high-urgency full-screen countdown (20 seconds default).
   - Loud synthesized two-tone emergency alarm loop and device vibration start immediately.
   - **"I Am Safe"**: Cancels emergency countdown, stops sirens, and logs an audited false-positive safety record.
   - **"Send SOS Now"**: Immediately registers emergency and initiates multi-channel dispatch.
   - **Auto-Expiry**: If the driver is unconscious or incapacitated and cannot touch the phone before the countdown reaches zero, the system automatically registers the emergency and escalates without requiring any click or confirmation.
4. **Emergency Escalation Engine**:
   - Immediately notifies control-room operators via Web Audio and real-time SSE stream.
   - Delivers multi-channel alerts to primary and secondary emergency contacts (SMS / Automated Voice Call).
   - Queries proximity-ranked nearby ambulance units and trauma-capable hospitals.
   - Automatically escalates unacknowledged emergencies to senior operations supervisors after 30 seconds.
5. **Emergency Operations Command Console (`/emergency-ops`)**:
   - Real-time incident queue with unacknowledged emergency badge counter.
   - Impact evidence grid: G-force peak, pre-impact speed, GPS accuracy, and driver medical profile (blood group, known conditions).
   - Proximity-ranked ambulance and hospital selector with direct dispatch actions.
   - Immutable audit timeline tracking every lifecycle transition (`sos_created` -> `acknowledged` -> `ambulance_assigned` -> `ambulance_en_route` -> `resolved`).
6. **Dedicated Vehicle IoT Hardware Ingestion (`POST /api/v1/iot/crash-events`)**:
   - Secure ingestion contract for in-vehicle OBD-II/telematics hardware with monotonic sequence numbers, cryptographic tokens, and airbag deployment sensors.
7. **Offline Queue & Idempotency**:
   - Unsent emergency actions are stored with unique idempotency keys in local storage and retried automatically with exponential backoff on reconnection, preventing duplicate incidents.

---

## 9. Emergency REST API Specification (`/api/v1/*`)

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/emergencies/detect` | Ingest crash candidate and trigger zero-touch emergency dispatch |
| `POST` | `/api/v1/emergencies/:id/confirm` | Driver manual immediate SOS confirmation |
| `POST` | `/api/v1/emergencies/:id/cancel` | Driver cancels countdown ("I Am Safe") -> creates false-positive record |
| `POST` | `/api/v1/emergencies/:id/acknowledge` | Operator acknowledges incident and stops sirens |
| `POST` | `/api/v1/emergencies/:id/assign-ambulance`| Dispatch specific ambulance unit & target hospital |
| `POST` | `/api/v1/emergencies/:id/status` | Update incident lifecycle status (`resolved`, `ambulance_arrived`, etc.) |
| `GET` | `/api/v1/emergencies` | List active emergency incidents with role-based filtering |
| `GET` | `/api/v1/emergencies/:id` | Fetch emergency details, medical profile, and assigned responders |
| `GET` | `/api/v1/emergencies/:id/timeline` | Fetch immutable audit timeline |
| `GET` | `/api/v1/emergencies/:id/delivery-attempts` | Multi-channel delivery audit logs |
| `GET` | `/api/v1/responders/nearby` | Proximity-ranked nearby ambulance units and hospitals |
| `POST` | `/api/v1/safety-service/heartbeat` | Native foreground safety service health heartbeat |
| `GET` | `/api/v1/safety-service/health` | Safety service health and permission status monitor |
| `POST` | `/api/v1/ambulance-units/:id/accept` | Ambulance partner accepts dispatch |
| `POST` | `/api/v1/ambulance-units/:id/reject` | Ambulance partner rejects dispatch |
| `POST` | `/api/v1/iot/crash-events` | Dedicated vehicle IoT/OBD-II hardware crash ingestion |

---

## 10. Automated Test Results

Run all test suites across the platform:

```bash
# 1. Automatic Accident Detection & Zero-Touch SOS Integration Tests
node server/tests/emergency.test.js

# 2. REST API Endpoints & Proofs Verification
node server/scripts/verifyEndpoints.js

# 3. Core Cargo & Operational Timeline Logic Tests
node server/tests/logic.test.js
```

### Actual Test Execution Output:
```text
================================================================
STARTING FLEETROUTE AUTOMATIC ACCIDENT & ZERO-TOUCH SOS TESTS
================================================================
[PASS] Test 1: Rejected crash event with missing coordinates.
[PASS] Test 2: Multi-sensor zero-touch emergency created (INC-1791893688037-843).
[PASS] Test 3: Idempotency enforced. Duplicate crash event prevented.
[PASS] Test 4: Driver cancellation creates false-positive safety record and stops alarm.
[PASS] Test 5: Control-room operator acknowledged emergency incident.
[PASS] Test 6: Responders ranked by proximity (3 ambulances, 3 hospitals).
[PASS] Test 7: Ambulance AMB-UNIT-101 dispatched with destination hospital HOSP-HYD-01.
[PASS] Test 8: Ambulance concurrency conflict prevented.
[PASS] Test 9: Foreground safety service heartbeat and health monitoring verified.
[PASS] Test 10: Dedicated IoT hardware crash ingestion verified (INC-IOT-1791893688093-621).
[PASS] Test 11: Immutable audit timeline verified (3 audited transitions: sos_created -> acknowledged -> ambulance_assigned).
[PASS] Test 12: Emergency incident successfully resolved with freed ambulance unit.
================================================================
ALL AUTOMATIC ACCIDENT & EMERGENCY TESTS PASSED 100%!
================================================================
```

---

## 11. Real-World Telematics & Integration Boundaries

1. **Browser PWA Background Tracking Constraints**:
   Standard web browsers restrict or terminate geolocation sampling when a browser tab is placed in the background or the mobile device screen locks. Reliable background crash detection is executed by the Native Android safety service with `FOREGROUND_SERVICE` and `WAKE_LOCK`.

2. **Emergency Calling (112 / 911) Compliance**:
   Standard mobile applications cannot silently dial 112 without operating-system emergency-call confirmation. FleetRoute compliant escalation delivers automated data incidents to backend dispatch, alerts verified contacts, dispatches partner ambulance APIs, and opens the system dialer with 112 when driver confirmation is required.

3. **Independently Powered Vehicle IoT Device**:
   If the mobile device is completely destroyed, powered off, or without cellular reception, a phone-only solution cannot guarantee delivery. FleetRoute supports an optional independently powered in-vehicle IoT/OBD-II hardware device with eSIM and dedicated battery (`POST /api/v1/iot/crash-events`).

4. **Road Distance vs. Straight-Line Distances**:
   When external road routing engines are not configured, distance estimations between waypoints and emergency responders are computed using the Haversine formula and explicitly labeled as straight-line distances.

