// server/tests/comprehensive.test.js
// Isolated Automated Test Suite for FleetRoute Production
// STRICTLY ZERO EMOJIS.

const assert = require('assert');
const http = require('http');
const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');

// Configure isolated test environment variables before loading server modules
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'isolated-test-jwt-secret-fleetroute-2026-audit';
process.env.PUBLIC_EMBEDDED_ACCESS = 'true';

let mongoServer;
let server;
let baseUrl;
let app;
let db;
let models;

async function apiRequest(endpoint, { method = 'GET', body = null, token = null } = {}) {
  const url = `${baseUrl}${endpoint}`;
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined
  });

  const status = res.status;
  let data = null;
  try {
    data = await res.json();
  } catch {
    data = null;
  }
  return { status, data, ok: res.ok };
}

async function runComprehensiveTests() {
  console.log('================================================================');
  console.log('STARTING FLEETROUTE ISOLATED INTEGRATION TEST SUITE');
  console.log('================================================================');

  // Step 0: Spin up isolated in-process MongoDB Memory Server
  console.log('[Setup] Initializing isolated MongoMemoryServer instance...');
  mongoServer = await MongoMemoryServer.create({
    instance: { dbName: 'fleetroute_test_isolated' }
  });
  const testMongoUri = mongoServer.getUri() + 'fleetroute_test_isolated';
  process.env.MONGODB_URI = testMongoUri;
  console.log(`[Setup] Isolated MongoDB running at: ${testMongoUri}`);

  // Now load db and server with MONGODB_URI set to isolated instance
  db = require('../db');
  models = require('../models');
  app = require('../server');

  await db.connect(testMongoUri);
  console.log('[Setup] Mongoose connected to isolated test database.');

  // Start Express on ephemeral port
  await new Promise((resolve) => {
    server = http.createServer(app);
    server.listen(0, '127.0.0.1', () => {
      const port = server.address().port;
      baseUrl = `http://127.0.0.1:${port}`;
      console.log(`[Setup] Test Express server listening on ${baseUrl}`);
      resolve();
    });
  });

  try {
    // -------------------------------------------------------------------------
    // TEST 1: Clean Database Starts with 0 Records and NO Demo Accounts
    // -------------------------------------------------------------------------
    console.log('\n--- Test 1: Clean Database Starts with 0 Records & NO Demo Accounts ---');

    const [userCount, driverCount, vehicleCount, locationCount, productCount, tripCount] = await Promise.all([
      models.User.countDocuments(),
      models.Driver.countDocuments(),
      models.Vehicle.countDocuments(),
      models.Location.countDocuments(),
      models.Product.countDocuments(),
      models.Trip.countDocuments()
    ]);

    assert.strictEqual(userCount, 0, 'Clean database must have 0 users');
    assert.strictEqual(driverCount, 0, 'Clean database must have 0 drivers');
    assert.strictEqual(vehicleCount, 0, 'Clean database must have 0 vehicles');
    assert.strictEqual(locationCount, 0, 'Clean database must have 0 locations');
    assert.strictEqual(productCount, 0, 'Clean database must have 0 products');
    assert.strictEqual(tripCount, 0, 'Clean database must have 0 trips');
    console.log('[PASS] 1.1 Verified database starts with exactly 0 operational records.');

    // Verify former demo credentials fail authentication
    const fakeDemoLogin = await apiRequest('/api/auth/login', {
      method: 'POST',
      body: { identifier: 'admin@fleetroute.com', password: 'AdminPassword123!' }
    });
    assert.strictEqual(fakeDemoLogin.status, 401, 'Former demo accounts must return 401 on clean database');
    console.log('[PASS] 1.2 No demo accounts exist: unbootstrapped login rejected with 401.');

    // Direct-open access must use a signed transient principal and must not
    // insert a placeholder administrator or any operational data.
    const embeddedSession = await apiRequest('/api/auth/embedded-session', { method: 'POST' });
    assert.strictEqual(embeddedSession.status, 200, 'Embedded session must be issued when explicitly enabled');
    assert(embeddedSession.data.token, 'Embedded session must return a signed JWT');
    assert.strictEqual(embeddedSession.data.user.accessMode, 'embedded');
    assert.strictEqual(await models.User.countDocuments(), 0, 'Embedded access must not create a dummy user');
    const embeddedDashboard = await apiRequest('/api/dashboard', { token: embeddedSession.data.token });
    assert.strictEqual(embeddedDashboard.status, 200, 'Embedded principal must access the real dashboard');
    assert.strictEqual(embeddedDashboard.data.activeTrips, 0, 'Embedded dashboard must report authentic empty state');
    console.log('[PASS] 1.3 Direct-open session uses real storage and creates zero placeholder records.');

    // -------------------------------------------------------------------------
    // TEST 2: Administrator Bootstrap Tool
    // -------------------------------------------------------------------------
    console.log('\n--- Test 2: Administrator Bootstrap Tool ---');

    const { bootstrapAdmin } = require('../scripts/bootstrapAdmin');

    const bootstrapResult = await bootstrapAdmin({
      name: 'System Administrator',
      email: 'sysadmin@company.com',
      phone: '+91 98111 22233',
      password: 'ProductionSecureAdminPass2026!',
      role: 'admin'
    });

    assert.strictEqual(bootstrapResult.success, true, 'Admin bootstrap must succeed');
    assert.strictEqual(bootstrapResult.user.email, 'sysadmin@company.com', 'Admin email must match');
    assert.strictEqual(bootstrapResult.user.role, 'admin', 'Admin role must be admin');
    console.log('[PASS] 2.1 Initial administrator successfully bootstrapped via bootstrap script.');

    // Verify existing administrator cannot be overwritten by bootstrap
    const overwriteAttempt = await bootstrapAdmin({
      name: 'Duplicate Admin',
      email: 'sysadmin@company.com',
      password: 'AnotherPassword123!'
    });
    assert.strictEqual(overwriteAttempt.success, false, 'Bootstrap must refuse to overwrite existing admin');
    console.log('[PASS] 2.2 Bootstrap prevented overwriting existing administrator.');

    // Admin login with real credentials
    const adminLoginRes = await apiRequest('/api/auth/login', {
      method: 'POST',
      body: { identifier: 'sysadmin@company.com', password: 'ProductionSecureAdminPass2026!' }
    });
    assert.strictEqual(adminLoginRes.status, 200, 'Admin login must succeed with 200');
    assert(adminLoginRes.data.token, 'Admin login must return a JWT token');
    const adminToken = adminLoginRes.data.token;
    console.log('[PASS] 2.3 Bootstrapped administrator logged in successfully with JWT token.');

    // Verify initial dashboard stats show honest zeros
    const emptyDash = await apiRequest('/api/dashboard', { token: adminToken });
    assert.strictEqual(emptyDash.status, 200);
    assert.strictEqual(emptyDash.data.activeTrips, 0, 'Active trips must be 0 on clean database');
    assert.strictEqual(emptyDash.data.driversOnDuty, 0, 'Drivers on duty must be 0 on clean database');
    assert.strictEqual(emptyDash.data.completedDeliveriesToday, 0, 'Completed deliveries must be 0');
    console.log('[PASS] 2.4 Honest initial dashboard metrics verified (all 0s, zero fake rates).');

    // -------------------------------------------------------------------------
    // TEST 3: Database Disconnect & 503 Refusal (No In-Memory Fallback)
    // -------------------------------------------------------------------------
    console.log('\n--- Test 3: Database Disconnect Refusal (No In-Memory Fallback) ---');

    await mongoose.connection.close();
    assert.strictEqual(db.isConnected(), false, 'Database must be disconnected');

    const offlineReq = await apiRequest('/api/trips', { token: adminToken });
    assert.strictEqual(offlineReq.status, 503, 'API must return 503 when MongoDB is offline');
    assert(offlineReq.data.message.includes('Database connection offline'), 'Must explain database offline');
    console.log('[PASS] 3.1 Disconnected MongoDB strictly returns 503 Service Unavailable without memory fallback.');

    // Health endpoint reports disconnected status
    const healthReq = await apiRequest('/api/health');
    assert.strictEqual(healthReq.status, 503);
    assert.strictEqual(healthReq.data.database, 'disconnected');
    console.log('[PASS] 3.2 Healthcheck reports disconnected database status.');

    // Reconnect database for remaining tests
    await db.connect(testMongoUri);
    assert.strictEqual(db.isConnected(), true, 'Database reconnected');
    console.log('[PASS] 3.3 Database successfully reconnected.');

    // -------------------------------------------------------------------------
    // TEST 4: Real Entity Creation & Coordinate Boundary Validation
    // -------------------------------------------------------------------------
    console.log('\n--- Test 4: Real Entity Creation & Coordinate Validation ---');

    // 4.1 Create Locations
    const locWh = await apiRequest('/api/locations', {
      method: 'POST',
      token: adminToken,
      body: { name: 'Mumbai Central Depot', type: 'warehouse', address: 'Bandra Kurla Complex', lat: 19.0657, lng: 72.8688, arrivalRadiusMeters: 150 }
    });
    assert.strictEqual(locWh.status, 201, 'Warehouse location created');

    const locA = await apiRequest('/api/locations', {
      method: 'POST',
      token: adminToken,
      body: { name: 'Customer Hub Andheri', type: 'customer', address: 'Andheri East', lat: 19.1136, lng: 72.8697, arrivalRadiusMeters: 100 }
    });
    assert.strictEqual(locA.status, 201, 'Customer Hub A created');

    const locB = await apiRequest('/api/locations', {
      method: 'POST',
      token: adminToken,
      body: { name: 'Customer Hub Powai', type: 'customer', address: 'Hiranandani Powai', lat: 19.1197, lng: 72.9051, arrivalRadiusMeters: 100 }
    });
    assert.strictEqual(locB.status, 201, 'Customer Hub B created');

    // Coordinate boundary validation
    const invalidLat = await apiRequest('/api/locations', {
      method: 'POST',
      token: adminToken,
      body: { name: 'Invalid Lat', address: 'Somewhere', lat: 99.9, lng: 72.0 }
    });
    assert.strictEqual(invalidLat.status, 400, 'Latitude > 90 must be rejected');

    const invalidLng = await apiRequest('/api/locations', {
      method: 'POST',
      token: adminToken,
      body: { name: 'Invalid Lng', address: 'Somewhere', lat: 19.0, lng: -195.0 }
    });
    assert.strictEqual(invalidLng.status, 400, 'Longitude < -180 must be rejected');
    console.log('[PASS] 4.1 Locations created and coordinate boundaries strictly enforced.');

    // 4.2 Create Product
    const prodRes = await apiRequest('/api/products', {
      method: 'POST',
      token: adminToken,
      body: { name: 'Industrial Water Filters', sku: 'SKU-FLT-01', category: 'Filters', unit: 'boxes', weightKg: 8.5 }
    });
    assert.strictEqual(prodRes.status, 201);
    const product = prodRes.data.product;
    console.log('[PASS] 4.2 Product created in MongoDB.');

    // 4.3 Create Vehicle
    const vehRes = await apiRequest('/api/vehicles', {
      method: 'POST',
      token: adminToken,
      body: { registrationNumber: 'MH-02-AB-9921', model: 'Tata Ultra T.7', capacityKg: 4000, maxVolumeCbm: 18, fuelType: 'diesel' }
    });
    assert.strictEqual(vehRes.status, 201);
    const vehicle = vehRes.data.vehicle;
    console.log('[PASS] 4.3 Vehicle asset registered in MongoDB.');

    // 4.4 Create Driver
    const drvRes = await apiRequest('/api/drivers', {
      method: 'POST',
      token: adminToken,
      body: {
        name: 'Vikram Shinde',
        phone: '+91 98200 44556',
        licenseNumber: 'MH-02-2021-9988',
        licenseExpiry: '2030-12-31',
        assignedVehicleId: vehicle.id
      }
    });
    assert.strictEqual(drvRes.status, 201);
    const driver = drvRes.data.driver;
    console.log('[PASS] 4.4 Driver profile registered in MongoDB.');

    // 4.5 Create Driver User Account with secure password
    const drvUserRes = await apiRequest('/api/auth/users', {
      method: 'POST',
      token: adminToken,
      body: {
        name: driver.name,
        email: 'vikram.driver@fleetroute.com',
        phone: driver.phone,
        password: 'DriverSecurePass2026!',
        role: 'driver',
        driverId: driver.id
      }
    });
    assert.strictEqual(drvUserRes.status, 201);
    console.log('[PASS] 4.5 Driver user authentication account created with bcrypt password.');

    // -------------------------------------------------------------------------
    // TEST 5: Trip Dispatch & Multi-Stop Workflow
    // -------------------------------------------------------------------------
    console.log('\n--- Test 5: Trip Dispatch & Multi-Stop Workflow ---');

    const tripRes = await apiRequest('/api/trips', {
      method: 'POST',
      token: adminToken,
      body: {
        driverId: driver.id,
        driverName: driver.name,
        vehicleId: vehicle.id,
        vehicleRegistration: vehicle.registrationNumber,
        stops: [
          { type: 'pickup', locationId: locWh.data.location.id, name: 'Mumbai Central Depot', address: 'BKC', lat: 19.0657, lng: 72.8688, status: 'pending' },
          { type: 'delivery', locationId: locA.data.location.id, name: 'Customer Hub Andheri', address: 'Andheri East', lat: 19.1136, lng: 72.8697, recipientName: 'Amit Shah', status: 'pending' },
          { type: 'delivery', locationId: locB.data.location.id, name: 'Customer Hub Powai', address: 'Powai', lat: 19.1197, lng: 72.9051, recipientName: 'Pooja Mehta', status: 'pending' }
        ],
        cargo: [
          { productId: product.id, productName: product.name, plannedQty: 12, loadedQty: 12, deliveredQty: 0, damagedQty: 0, rejectedQty: 0, returnedQty: 0, unit: 'boxes' }
        ]
      }
    });
    assert.strictEqual(tripRes.status, 201);
    const trip = tripRes.data.trip;
    console.log(`[PASS] 5.1 Multi-stop trip created: ${trip.id} with 3 waypoints and 12 units planned.`);

    // -------------------------------------------------------------------------
    // TEST 6: Driver Authentication & Trip Isolation
    // -------------------------------------------------------------------------
    console.log('\n--- Test 6: Driver Authentication & Trip Isolation ---');

    const driverLogin = await apiRequest('/api/auth/login', {
      method: 'POST',
      body: { identifier: 'vikram.driver@fleetroute.com', password: 'DriverSecurePass2026!' }
    });
    assert.strictEqual(driverLogin.status, 200);
    assert.strictEqual(driverLogin.data.user.mustChangePassword, true, 'New account must require initial password rotation');
    const passwordRotation = await apiRequest('/api/auth/change-password', {
      method: 'POST',
      token: driverLogin.data.token,
      body: { currentPassword: 'DriverSecurePass2026!', newPassword: 'DriverRotatedSecurePass2026!' }
    });
    assert.strictEqual(passwordRotation.status, 200);
    assert.strictEqual(passwordRotation.data.reauthRequired, true);
    const rotatedDriverLogin = await apiRequest('/api/auth/login', {
      method: 'POST',
      body: { identifier: 'vikram.driver@fleetroute.com', password: 'DriverRotatedSecurePass2026!' }
    });
    assert.strictEqual(rotatedDriverLogin.status, 200);
    assert.strictEqual(rotatedDriverLogin.data.user.mustChangePassword, false);
    const driverToken = rotatedDriverLogin.data.token;
    assert.strictEqual(driverLogin.data.user.role, 'driver');
    console.log('[PASS] 6.1 Driver authenticated successfully.');

    const lockedDeparture = await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { action: 'start_trip' }
    });
    assert.strictEqual(lockedDeparture.status, 409, 'Departure must remain locked before gate evidence');
    assert.strictEqual(lockedDeparture.data.code, 'GATE_INTERLOCK_LOCKED');

    const gateProof = await apiRequest(`/api/trips/${trip.id}/gate-proofs`, {
      method: 'POST',
      token: driverToken,
      body: {
        odometerPhoto: 'data:image/jpeg;base64,TEST_ODOMETER',
        walkaroundPhoto: 'data:image/jpeg;base64,TEST_WALKAROUND',
        driverSeatbeltPhoto: 'data:image/jpeg;base64,TEST_SELFIE',
        seatbeltVerified: true,
        overspeedingPledge: true,
        depotLocationName: 'Mumbai Central Depot'
      }
    });
    assert.strictEqual(gateProof.status, 200);
    assert(gateProof.data.gateProofs.gateClearedAt, 'Complete gate evidence must clear interlock');

    const startTrip = await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { action: 'start_trip' }
    });
    assert.strictEqual(startTrip.status, 200, 'Verified driver can start the trip once');

    // Fetch trips as driver: must see ONLY assigned trip
    const driverTripsRes = await apiRequest('/api/trips', { token: driverToken });
    assert.strictEqual(driverTripsRes.status, 200);
    assert.strictEqual(driverTripsRes.data.length, 1, 'Driver must receive exactly 1 assigned trip');
    assert.strictEqual(driverTripsRes.data[0].id, trip.id, 'Driver receives only their assigned trip');
    console.log('[PASS] 6.2 Driver trip isolation strictly enforced: other trips inaccessible.');

    // Driver cannot perform admin actions
    const driverForbidden = await apiRequest('/api/drivers', {
      method: 'POST',
      token: driverToken,
      body: { name: 'Hacker', phone: '+919999999999' }
    });
    assert.strictEqual(driverForbidden.status, 403, 'Driver access to admin routes forbidden');
    console.log('[PASS] 6.3 Driver forbidden from administrative operations.');

    // A second driver must not mutate the first driver's trip or inspect their incident.
    const otherDriverRes = await apiRequest('/api/drivers', {
      method: 'POST',
      token: adminToken,
      body: { name: 'Unauthorized Driver', phone: '+91 98200 40000', licenseNumber: 'MH-02-2022-4000' }
    });
    assert.strictEqual(otherDriverRes.status, 201);
    const otherDriver = otherDriverRes.data.driver;
    const otherUserRes = await apiRequest('/api/auth/users', {
      method: 'POST',
      token: adminToken,
      body: {
        name: otherDriver.name,
        email: 'other.driver@fleetroute.com',
        phone: otherDriver.phone,
        password: 'OtherDriverSecurePass2026!',
        role: 'driver',
        driverId: otherDriver.id
      }
    });
    assert.strictEqual(otherUserRes.status, 201);
    const otherLogin = await apiRequest('/api/auth/login', {
      method: 'POST',
      body: { identifier: 'other.driver@fleetroute.com', password: 'OtherDriverSecurePass2026!' }
    });
    assert.strictEqual(otherLogin.status, 200);
    const otherPasswordRotation = await apiRequest('/api/auth/change-password', {
      method: 'POST',
      token: otherLogin.data.token,
      body: { currentPassword: 'OtherDriverSecurePass2026!', newPassword: 'OtherDriverRotatedPass2026!' }
    });
    assert.strictEqual(otherPasswordRotation.status, 200);
    const otherRotatedLogin = await apiRequest('/api/auth/login', {
      method: 'POST',
      body: { identifier: 'other.driver@fleetroute.com', password: 'OtherDriverRotatedPass2026!' }
    });
    assert.strictEqual(otherRotatedLogin.status, 200);

    const crossDriverCargo = await apiRequest(`/api/trips/${trip.id}/cargo-action`, {
      method: 'POST',
      token: otherRotatedLogin.data.token,
      body: { action: 'load', productId: product.id, quantity: 1, idempotencyKey: 'CROSS-DRIVER-DENIED' }
    });
    assert.strictEqual(crossDriverCargo.status, 403, 'Other driver must not mutate this trip cargo');

    const crossDriverTelemetry = await apiRequest('/api/driver/location', {
      method: 'POST',
      token: otherRotatedLogin.data.token,
      body: {
        tripId: trip.id,
        lat: 19.07,
        lng: 72.87,
        accuracy: 10,
        speed: 20,
        heading: 90,
        deviceTimestamp: new Date().toISOString()
      }
    });
    assert.strictEqual(crossDriverTelemetry.status, 403, 'Other driver must not update this trip telemetry');

    await models.EmergencyIncident.create({
      id: 'INC-ROLE-ISOLATION',
      incidentId: 'INC-ROLE-ISOLATION',
      driverId: driver.id,
      status: 'sos_created',
      coordinates: { lat: 19.07, lng: 72.87 },
      locationPoint: { type: 'Point', coordinates: [72.87, 19.07] },
      detectedAtDevice: new Date().toISOString(),
      detectedAtServer: new Date().toISOString()
    });
    const crossDriverIncident = await apiRequest('/api/v1/emergencies/INC-ROLE-ISOLATION', {
      token: otherRotatedLogin.data.token
    });
    assert.strictEqual(crossDriverIncident.status, 403, 'Other driver must not inspect this incident');
    const ownDriverIncident = await apiRequest('/api/v1/emergencies/INC-ROLE-ISOLATION', { token: driverToken });
    assert.strictEqual(ownDriverIncident.status, 200, 'Assigned driver can inspect their own incident');

    const emergencyKey = `EMERGENCY-IDEMPOTENCY-${Date.now()}`;
    const detectedEmergency = await apiRequest('/api/v1/emergencies/detect', {
      method: 'POST',
      token: driverToken,
      body: {
        idempotencyKey: emergencyKey,
        tripId: trip.id,
        coordinates: { lat: 19.071, lng: 72.871 },
        locationAccuracy: 8,
        speedBeforeImpact: 54,
        estimatedImpactForce: 4.8,
        confidenceScore: 0.94,
        severity: 'CRITICAL',
        detectionSource: 'INTEGRATION_TEST_SENSOR'
      }
    });
    assert.strictEqual(detectedEmergency.status, 201, 'Valid driver emergency must be persisted');
    const detectedIncidentId = detectedEmergency.data.incident.incidentId;
    const duplicateEmergency = await apiRequest('/api/v1/emergencies/detect', {
      method: 'POST',
      token: driverToken,
      body: { idempotencyKey: emergencyKey, coordinates: { lat: 19.071, lng: 72.871 } }
    });
    assert.strictEqual(duplicateEmergency.status, 200);
    assert.strictEqual(duplicateEmergency.data.isDuplicate, true, 'Emergency retry must be idempotent');
    assert.strictEqual(duplicateEmergency.data.incident.incidentId, detectedIncidentId);

    const unauthorizedEmergencyRead = await apiRequest(`/api/v1/emergencies/${detectedIncidentId}`, {
      token: otherRotatedLogin.data.token
    });
    assert.strictEqual(unauthorizedEmergencyRead.status, 403, 'Other driver must not inspect detected emergency');
    const cancelEmergency = await apiRequest(`/api/v1/emergencies/${detectedIncidentId}/cancel`, {
      method: 'POST',
      token: driverToken,
      body: { reason: 'Integration test false-positive confirmation.' }
    });
    assert.strictEqual(cancelEmergency.status, 200);
    const cancelledEmergency = await apiRequest(`/api/v1/emergencies/${detectedIncidentId}`, { token: driverToken });
    assert.strictEqual(cancelledEmergency.data.status, 'cancelled_by_driver');

    const heartbeat = await apiRequest('/api/v1/safety-service/heartbeat', {
      method: 'POST',
      token: driverToken,
      body: {
        deviceId: 'INTEGRATION-DEVICE-1',
        activeTripId: trip.id,
        serviceRunning: true,
        locationPermission: 'granted_fine',
        notificationPermission: 'granted',
        batteryOptimizationExempt: true,
        sensorAvailability: { accelerometer: true, gyroscope: true, gps: true, obd2: false },
        batteryLevel: 90
      }
    });
    assert.strictEqual(heartbeat.status, 200, 'Authenticated driver heartbeat must be accepted');
    const heartbeatHealth = await apiRequest('/api/v1/safety-service/health', { token: driverToken });
    assert.strictEqual(heartbeatHealth.status, 200);
    assert.strictEqual(heartbeatHealth.data.driverId, driver.id);

    const unconfiguredIot = await apiRequest('/api/v1/iot/crash-events', {
      method: 'POST',
      body: {}
    });
    assert.strictEqual(unconfiguredIot.status, 503, 'Unconfigured IoT ingestion must fail closed');
    assert.strictEqual(unconfiguredIot.data.code, 'IOT_NOT_CONFIGURED');

    const unknownRoute = await apiRequest('/api/does-not-exist', { token: adminToken });
    assert.strictEqual(unknownRoute.status, 404);
    assert.strictEqual(unknownRoute.data.code, 'ROUTE_NOT_FOUND');
    assert(unknownRoute.data.requestId, 'Structured errors must include a request ID');
    console.log('[PASS] 6.4 Cross-driver access, emergency idempotency/cancellation, heartbeat, IoT and errors verified.');

    // -------------------------------------------------------------------------
    // TEST 7: Real GPS Telemetry, Out-of-Order Rejection & Speed Alerts
    // -------------------------------------------------------------------------
    console.log('\n--- Test 7: Real GPS Telemetry, Ordering & Genuine Speed Alerts ---');

    const now = Date.now();
    const tNewer = new Date(now).toISOString();
    const tOlder = new Date(now - 60000).toISOString();

    // 7.1 Send fresh normal speed telemetry (speed = 42 km/h)
    const normTel = await apiRequest('/api/driver/location', {
      method: 'POST',
      token: driverToken,
      body: {
        tripId: trip.id,
        lat: 19.0700,
        lng: 72.8700,
        accuracy: 10,
        speed: 42,
        heading: 90,
        deviceTimestamp: tNewer
      }
    });
    assert.strictEqual(normTel.status, 200);
    assert.strictEqual(normTel.data.lastLocation.speed, 42);
    console.log('[PASS] 7.1 Normal speed GPS sample accepted (42 km/h). No alert generated.');

    // Verify no safety event was created for normal speed
    const safetyEvents1 = await models.SafetyEvent.find({ tripId: trip.id, type: 'overspeed' });
    assert.strictEqual(safetyEvents1.length, 0, 'No alert must be generated for normal speed');

    // 7.2 Send out-of-order older sample: must not overwrite newer position
    const oldTel = await apiRequest('/api/driver/location', {
      method: 'POST',
      token: driverToken,
      body: {
        tripId: trip.id,
        lat: 19.0100,
        lng: 72.8100,
        accuracy: 20,
        speed: 15,
        heading: 0,
        deviceTimestamp: tOlder
      }
    });
    assert.strictEqual(oldTel.status, 200);
    assert.strictEqual(oldTel.data.lastLocation.lat, 19.0700, 'Newer position must not be overwritten');
    console.log('[PASS] 7.2 Out-of-order older GPS sample safely rejected from overwriting current position.');

    // 7.3 Send real overspeed telemetry (speed = 92 km/h > 80 km/h threshold)
    const overspeedTel = await apiRequest('/api/driver/location', {
      method: 'POST',
      token: driverToken,
      body: {
        tripId: trip.id,
        lat: 19.0800,
        lng: 72.8750,
        accuracy: 8,
        speed: 92,
        heading: 120,
        deviceTimestamp: new Date(now + 10000).toISOString()
      }
    });
    assert.strictEqual(overspeedTel.status, 200);

    // Verify speed alert was generated ONLY because of genuine GPS telemetry exceeding threshold
    const safetyEvents2 = await models.SafetyEvent.find({ tripId: trip.id, type: 'overspeed' });
    assert.strictEqual(safetyEvents2.length, 1, 'Genuine speed violation alert logged');
    assert.strictEqual(safetyEvents2[0].recordedSpeed, 92);
    assert.strictEqual(safetyEvents2[0].type, 'overspeed');
    console.log('[PASS] 7.3 Genuine overspeed alert automatically generated from real telemetry (92 km/h > 80 km/h).');

    // -------------------------------------------------------------------------
    // TEST 8: Stop Progression, Cargo Balancing & Idempotency
    // -------------------------------------------------------------------------
    console.log('\n--- Test 8: Stop Progression, Cargo Balancing & Idempotency ---');

    // Step 1: Arrive at Pickup & Load 12 boxes
    await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { stopIndex: 0, status: 'arrived' }
    });
    await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { stopIndex: 0, status: 'loading' }
    });

    const loadIdempKey = `LOAD-IDEMP-${Date.now()}`;
    const loadAction = await apiRequest(`/api/trips/${trip.id}/cargo-action`, {
      method: 'POST',
      token: driverToken,
      body: { action: 'load', productId: product.id, quantity: 12, idempotencyKey: loadIdempKey }
    });
    assert.strictEqual(loadAction.status, 200);

    // Idempotent duplicate call must not duplicate cargo
    const duplicateLoad = await apiRequest(`/api/trips/${trip.id}/cargo-action`, {
      method: 'POST',
      token: driverToken,
      body: { action: 'load', productId: product.id, quantity: 12, idempotencyKey: loadIdempKey }
    });
    assert.strictEqual(duplicateLoad.status, 200);
    assert.strictEqual(duplicateLoad.data.isDuplicate, true, 'Duplicate cargo action flagged');

    // Complete pickup stop
    await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { stopIndex: 0, status: 'completed' }
    });
    await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { action: 'next_stop' }
    });
    console.log('[PASS] 8.1 Pickup completed with 12 units onboard. Idempotency verified.');

    // Step 2: Deliver 5 units at Stop A (with real POD evidence)
    await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { stopIndex: 1, status: 'arrived' }
    });
    await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { stopIndex: 1, status: 'unloading' }
    });

    await apiRequest(`/api/trips/${trip.id}/cargo-action`, {
      method: 'POST',
      token: driverToken,
      body: { action: 'deliver', productId: product.id, quantity: 5, idempotencyKey: `DELIV-A-${Date.now()}` }
    });

    const podFinishA = await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: {
        stopIndex: 1,
        status: 'completed',
        pod: {
          recipientName: 'Amit Shah',
          notes: 'Received 5 boxes in perfect condition',
          deliveredQty: 5,
          damagedQty: 0,
          rejectedQty: 0,
          signature: 'data:image/png;base64,TEST_SIGNATURE_A',
          photoData: 'data:image/jpeg;base64,TEST_DELIVERY_A'
        }
      }
    });
    assert.strictEqual(podFinishA.status, 200);

    // Verify delivery proof was saved in MongoDB DeliveryProof collection
    const savedPodsA = await models.DeliveryProof.find({ tripId: trip.id, stopIndex: 1 });
    assert.strictEqual(savedPodsA.length, 1, 'DeliveryProof record must be persisted in MongoDB');
    assert.strictEqual(savedPodsA[0].recipientName, 'Amit Shah');
    console.log('[PASS] 8.2 Stop A delivery fulfilled (5 units delivered, 7 onboard). Real POD persisted.');

    await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { action: 'next_stop' }
    });

    // Step 3: Deliver 6 units at Stop B, with 1 damaged in transit
    await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { stopIndex: 2, status: 'arrived' }
    });
    await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: { stopIndex: 2, status: 'unloading' }
    });

    await apiRequest(`/api/trips/${trip.id}/cargo-action`, {
      method: 'POST',
      token: driverToken,
      body: { action: 'deliver', productId: product.id, quantity: 6, idempotencyKey: `DELIV-B-${Date.now()}` }
    });

    await apiRequest(`/api/trips/${trip.id}/advance-stop`, {
      method: 'POST',
      token: driverToken,
      body: {
        stopIndex: 2,
        status: 'completed',
        pod: {
          recipientName: 'Pooja Mehta',
          notes: '6 boxes delivered, 1 box damaged outer carton',
          deliveredQty: 6,
          damagedQty: 1,
          rejectedQty: 0,
          signature: 'data:image/png;base64,TEST_SIGNATURE_B',
          photoData: 'data:image/jpeg;base64,TEST_DELIVERY_B'
        }
      }
    });

    // Check final trip cargo totals in MongoDB
    const finalTrip = await models.Trip.findOne({ id: trip.id });
    const finalCargo = finalTrip.cargo.find(c => c.productId === product.id);
    assert.strictEqual(finalCargo.loadedQty, 12, '12 loaded');
    assert.strictEqual(finalCargo.deliveredQty, 11, '11 delivered (5 + 6)');
    assert.strictEqual(finalCargo.damagedQty, 1, '1 damaged');
    const remainingOnboard = finalCargo.loadedQty - finalCargo.deliveredQty - finalCargo.damagedQty;
    assert.strictEqual(remainingOnboard, 0, 'Zero unaccounted units remain onboard');
    console.log('[PASS] 8.3 Cargo ledger balance mathematically reconciled in MongoDB: 12 loaded, 11 delivered, 1 damaged, 0 remaining onboard.');

    // -------------------------------------------------------------------------
    // TEST 9: Demo Data Cleanup Command (Dry-run by Default & Apply)
    // -------------------------------------------------------------------------
    console.log('\n--- Test 9: Demo Data Cleanup Script (Dry-run by Default) ---');

    const { auditAndCleanupDemoData } = require('../scripts/cleanupDemoData');

    // 9.1 Dry-run against our real records: must identify 0 demo records
    const dryRunEmpty = await auditAndCleanupDemoData({ apply: false });
    assert.strictEqual(dryRunEmpty.identifiedCount, 0, 'Real operational records must NOT be flagged as demo');
    assert.strictEqual(dryRunEmpty.deletedCount, 0, 'Dry-run must never delete records');
    console.log('[PASS] 9.1 Dry-run correctly left 100% of real created operational records untouched.');

    // 9.2 Inject a verifiable demo record with isDemo marker
    await models.Trip.create({
      id: 'TRIP-DEMO-TEST-VERIFY',
      driverId: 'DEMO-DRV-999',
      driverName: 'Demo Driver Placeholder',
      isDemo: true,
      status: 'completed',
      stops: []
    });

    // Run dry-run: must identify the demo trip, report its ID, and NOT delete it
    const dryRunFound = await auditAndCleanupDemoData({ apply: false });
    assert.strictEqual(dryRunFound.identifiedCount, 1, 'Must identify the 1 demo record');
    assert.strictEqual(dryRunFound.deletedCount, 0, 'Dry-run must NOT delete');
    const stillExists = await models.Trip.findOne({ id: 'TRIP-DEMO-TEST-VERIFY' });
    assert(stillExists, 'Record must still exist after dry-run');
    console.log('[PASS] 9.2 Dry-run identified demo record by ID without deleting it.');

    // 9.3 Run with apply: true: must permanently delete only the demo record
    const applyClean = await auditAndCleanupDemoData({ apply: true });
    assert.strictEqual(applyClean.deletedCount, 1, 'Apply must delete the demo record');
    const gone = await models.Trip.findOne({ id: 'TRIP-DEMO-TEST-VERIFY' });
    assert.strictEqual(gone, null, 'Demo record must be gone');

    // Verify real trip and real user still exist
    const realTripStillExists = await models.Trip.findOne({ id: trip.id });
    const realUserStillExists = await models.User.findOne({ email: 'sysadmin@company.com' });
    assert(realTripStillExists, 'Real operational trip must be preserved');
    assert(realUserStillExists, 'Real administrator user must be preserved');
    console.log('[PASS] 9.3 Apply mode permanently deleted demo record while safely preserving real operational records.');

    console.log('\n================================================================');
    console.log('ALL COMPREHENSIVE PRODUCTION VERIFICATION SUITES PASSED (9/9)');
    console.log('================================================================');

  } finally {
    if (server) {
      server.close();
    }
    if (mongoose.connection && mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
    if (mongoServer) {
      await mongoServer.stop();
      console.log('[Teardown] Isolated MongoMemoryServer cleanly stopped.');
    }
  }
}

runComprehensiveTests().catch((err) => {
  console.error('\n[FATAL TEST FAILURE]:', err);
  if (server) server.close();
  if (mongoServer) mongoServer.stop().catch(() => {});
  process.exit(1);
});
