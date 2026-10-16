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
- **Node.js**: v20.11.0 or higher
- **npm**: v9.0.0 or higher
- **MongoDB**: Local MongoDB instance (port 27017) or MongoDB Atlas connection URI

### Step-by-Step Installation

1. **Install all lockfile-pinned dependencies:**
   ```bash
   npm ci
   npm --prefix server ci
   npm --prefix client ci
   ```

3. **Configure Environment Variables:**
   Copy `.env.example` to `.env` in the root and `server` directories:
   ```bash
   cp .env.example server/.env
   ```
   Set `MONGODB_URI`, a cryptographically strong `JWT_SECRET`, and exact `CORS_ORIGINS`. Android builds must also set `VITE_API_BASE_URL` to the reachable HTTPS backend `/api` URL.

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
| `NODE_ENV` | Optional (default: `development`) | Runtime environment mode. Production enables strict configuration validation. |
| `MONGODB_URI` | **Mandatory** | MongoDB connection URI string. Startup cleanly fails if missing or unreachable. |
| `LIVE_MONGODB_URI` | Optional replacement | Zero-downtime MongoDB rotation URI. When set, it takes precedence over `MONGODB_URI`. |
| `JWT_SECRET` | **Mandatory in production** | Cryptographic key of at least 32 characters used for JWTs. No hardcoded production fallback exists. |
| `CORS_ORIGINS` | **Mandatory in production** | Comma-separated exact web origins allowed to call the API. |
| `IOT_DEVICE_AUTH_SECRET` | Required to enable IoT ingestion | Distinct 32+ character key used for exact token and HMAC verification. |
| `JWT_EXPIRES_IN` | Optional (default: `24h`) | Session token expiration duration. |
| `PUBLIC_EMBEDDED_ACCESS` | Optional (default: `false`) | Enables the API's short-lived direct-open signed principal. Use only for a dedicated public presentation deployment. It inserts no placeholder records. |
| `VITE_EMBEDDED_ACCESS` | Optional (default: `false`) | Removes the client login gate and requests direct embedded access from the API. |
| `DEFAULT_ARRIVAL_RADIUS_METERS` | Optional (default: `150`) | Arrival geofence radius in meters for driver check-in. |
| `OVERSPEED_THRESHOLD_KMH` | Optional (default: `80`) | Speed threshold that generates an overspeed safety alert from real telemetry. |
| `LOCATION_UPDATE_INTERVAL_MS` | Optional (default: `5000`) | Client-side geolocation transmission interval in milliseconds. |
| `GEOCODING_PROVIDER` | Optional (default: `nominatim`) | Address geocoding service. |
| `GEOCODING_API_URL` | Optional | Custom Nominatim endpoint URL. |

---

## 6. Functional Capabilities & Production Upgrades

### 1. Direct-Open Embedded Operations Workspace
- The embedded presentation opens directly into FleetRoute without rendering a login screen.
- Access uses a short-lived signed JWT principal and is enabled independently on the client and API.
- No dummy administrator, sample trip, vehicle, driver, product, or location is inserted into MongoDB.
- Dashboard values and module records always come from the configured persistent MongoDB database; an empty database produces honest zero and empty states.
- Standard password authentication and role-based API controls remain available for non-embedded deployments.

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
- Durable trip-level idempotency keys and optimistic concurrency guards prevent cargo retry double deductions across restarts.
- Delivery proofs require real recipient names and genuine signatures/photos stored in MongoDB.

### 7. Production Service Worker & Offline Caching
- Service Worker invalidates legacy prototype caches.
- Authenticated operational API requests are never stored in public service worker caches, preventing cross-user data leakage.
- Only explicitly retry-safe operations are queued. Queues are account-scoped, carry stable operation IDs, and remain visibly `pending` until the backend acknowledges them.

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

FleetRoute includes an emergency workflow baseline across the following architectural layers. Native background-service and external-provider rollout still require real-device and provider acceptance before operational use:

1. **Android Driver Application / Capacitor Wrapper**: Android permissions and the Capacitor wrapper exist. A custom foreground safety service that is proven across screen lock and process restart remains a release requirement.
2. **Multi-Sensor Fusion Engine**: Evaluates high-frequency accelerometer vector force (G-force), rapid GPS speed reduction (deceleration > 25 km/h drop), abnormal gyroscope rotation, and post-impact zero-motion stillness.
3. **Zero-Touch SOS Countdown**:
   - Severe crash detection triggers a high-urgency full-screen countdown (20 seconds default).
   - Loud synthesized two-tone emergency alarm loop and device vibration start immediately.
   - **"I Am Safe"**: Cancels emergency countdown, stops sirens, and logs an audited false-positive safety record.
   - **"Send SOS Now"**: Immediately registers emergency and initiates multi-channel dispatch.
   - **Auto-Expiry**: If the driver is unconscious or incapacitated and cannot touch the phone before the countdown reaches zero, the system automatically registers the emergency and escalates without requiring any click or confirmation.
4. **Emergency Escalation Engine**:
   - Immediately notifies control-room operators via Web Audio and real-time SSE stream.
   - Broadcasts verified in-app control-room alerts. SMS, voice, ambulance, and hospital channels fail closed as `PROVIDER_ADAPTER_UNAVAILABLE` until real adapters and delivery receipts are implemented.
   - Queries proximity-ranked nearby ambulance units and trauma-capable hospitals.
   - Automatically escalates unacknowledged emergencies to senior operations supervisors after 30 seconds.
5. **Emergency Operations Command Console (`/emergency-ops`)**:
   - Real-time incident queue with unacknowledged emergency badge counter.
   - Impact evidence grid: G-force peak, pre-impact speed, GPS accuracy, and driver medical profile (blood group, known conditions).
   - Proximity-ranked ambulance and hospital selector with direct dispatch actions.
   - Immutable audit timeline tracking every lifecycle transition (`sos_created` -> `acknowledged` -> `ambulance_assigned` -> `ambulance_en_route` -> `resolved`).
6. **Dedicated Vehicle IoT Hardware Ingestion (`POST /api/v1/iot/crash-events`)**:
   - Fail-closed ingestion contract requiring a provisioned 32+ character secret, exact bearer token, timestamp freshness, monotonic operation identity, and HMAC-SHA256 event signature.
7. **Offline Queue & Idempotency**:
   - Retry-safe emergency detection uses account-scoped local queues and stable idempotency keys. Failed validation remains visible instead of being reported as saved.

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

Run the isolated logic, API/workflow, security-boundary, emergency, cleanup, and production-build checks:

```bash
npm run test:all
```

The integration suite starts an isolated in-memory MongoDB instance and does not depend on demo credentials, a pre-running API, or production data.

---

## 11. Real-World Telematics & Integration Boundaries

1. **Browser PWA Background Tracking Constraints**:
   Standard web browsers restrict or terminate geolocation sampling when a browser tab is backgrounded or the screen locks. Native foreground-service implementation and real-device acceptance remain mandatory before claiming reliable background crash detection.

2. **Emergency Calling (112 / 911) Compliance**:
   Standard mobile applications cannot silently dial 112 without operating-system emergency-call confirmation. FleetRoute currently records incidents and alerts the authenticated control room; telecom, partner ambulance, hospital, and government emergency delivery require separately implemented and verified provider adapters.

3. **Independently Powered Vehicle IoT Device**:
   If the mobile device is completely destroyed, powered off, or without cellular reception, a phone-only solution cannot guarantee delivery. FleetRoute supports an optional independently powered in-vehicle IoT/OBD-II hardware device with eSIM and dedicated battery (`POST /api/v1/iot/crash-events`).

4. **Road Distance vs. Straight-Line Distances**:
   When external road routing engines are not configured, distance estimations between waypoints and emergency responders are computed using the Haversine formula and explicitly labeled as straight-line distances.

