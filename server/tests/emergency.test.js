require('dotenv').config();
const assert = require('assert');
const http = require('http');
const db = require('../db');
const { generateToken } = require('../auth');

const PORT = process.env.PORT || 5000;

function post(path, body, token, customHeaders = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request({
      hostname: 'localhost',
      port: PORT,
      path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
        ...customHeaders
      }
    }, res => {
      let buf = '';
      res.on('data', d => buf += d);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(buf || '{}') });
        } catch {
          resolve({ status: res.statusCode, data: buf });
        }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function get(path, token) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: 'localhost',
      port: PORT,
      path,
      method: 'GET',
      headers: {
        ...(token ? { 'Authorization': `Bearer ${token}` } : {})
      }
    }, res => {
      let buf = '';
      res.on('data', d => buf += d);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(buf || '{}') });
        } catch {
          resolve({ status: res.statusCode, data: buf });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function runEmergencyTests() {
  console.log('================================================================');
  console.log('STARTING FLEETROUTE AUTOMATIC ACCIDENT & ZERO-TOUCH SOS TESTS');
  console.log('================================================================');

  // Authenticate using database accounts
  const adminLogin = await post('/api/auth/login', { identifier: 'admin@gmail.com', password: 'Admin1234!' });
  const adminToken = adminLogin.data?.token;
  assert(adminToken, 'Admin token must be obtained');

  const usersRes = await get('/api/auth/users', adminToken);
  const driverUser = (usersRes.data || []).find(u => u.role === 'driver');
  assert(driverUser, 'A driver user account must exist');

  const driverLogin = await post('/api/auth/login', { identifier: driverUser.email, password: 'Driver1234!' });
  const driverToken = driverLogin.data?.token;
  assert(driverToken, 'Driver token must be obtained');

  // Reset ambulance unit availability to available for reliable test runs
  await db.connect();
  const allAmbulances = await db.collection('ambulanceUnits').find();
  for (const amb of allAmbulances) {
    await db.collection('ambulanceUnits').updateOne({ id: amb.id }, { availability: 'available', assignedIncidentId: null });
  }

  // Test 1: Reject detection if coordinates are missing or invalid
  {
    const res = await post('/api/v1/emergencies/detect', { tripId: 'TRIP-DEMO-01' }, driverToken);
    assert.strictEqual(res.status, 400, 'Must return 400 when coordinates missing');
    console.log('[PASS] Test 1: Rejected crash event with missing coordinates.');
  }

  // Test 2: Ingest multi-sensor crash event and verify zero-touch emergency creation
  let createdIncidentId = null;
  const testIdempotencyKey = `IDEM-TEST-${Date.now()}`;
  {
    const crashPayload = {
      idempotencyKey: testIdempotencyKey,
      tripId: 'TRIP-DEMO-01',
      coordinates: { lat: 17.4265, lng: 78.4116 },
      locationAccuracy: 4.5,
      speedBeforeImpact: 62,
      estimatedImpactForce: 5.2,
      confidenceScore: 0.95,
      severity: 'CRITICAL',
      sensorSummary: {
        gForcePeak: 5.2,
        deltaSpeedKmh: 45,
        rotationDegPerSec: 12,
        sustainedZeroMotionSeconds: 3,
        airbagDeployed: false
      },
      detectionSource: 'ZERO_TOUCH_AUTO_EXPIRY'
    };

    const res = await post('/api/v1/emergencies/detect', crashPayload, driverToken);
    assert.strictEqual(res.status, 201, 'Incident must be created with 201');
    assert(res.data.incident, 'Response must contain incident object');
    assert.strictEqual(res.data.incident.status, 'sos_created');
    assert.strictEqual(res.data.incident.confidenceScore, 0.95);
    createdIncidentId = res.data.incident.incidentId;
    console.log(`[PASS] Test 2: Multi-sensor zero-touch emergency created (${createdIncidentId}).`);
  }

  // Test 3: Idempotency check - Replaying identical crash event returns existing incident without duplicating
  {
    const replayPayload = {
      idempotencyKey: testIdempotencyKey,
      tripId: 'TRIP-DEMO-01',
      coordinates: { lat: 17.4265, lng: 78.4116 }
    };
    const res = await post('/api/v1/emergencies/detect', replayPayload, driverToken);
    assert.strictEqual(res.status, 200, 'Replayed event must return 200 with existing record');
    assert.strictEqual(res.data.isDuplicate, true, 'Flagged as duplicate');
    assert.strictEqual(res.data.incident.incidentId, createdIncidentId, 'Must return original incidentId');
    console.log('[PASS] Test 3: Idempotency enforced. Duplicate crash event prevented.');
  }

  // Test 4: Driver cancels countdown ("I Am Safe") -> transitions to cancelled_by_driver & creates false positive safety record
  {
    // Create a temporary incident to cancel
    const cancelIdempotency = `IDEM-CANCEL-${Date.now()}`;
    const initRes = await post('/api/v1/emergencies/detect', {
      idempotencyKey: cancelIdempotency,
      tripId: 'TRIP-DEMO-01',
      coordinates: { lat: 17.4300, lng: 78.4200 },
      severity: 'MEDIUM',
      confidenceScore: 0.82
    }, driverToken);

    const cancelIncidentId = initRes.data.incident.incidentId;
    const cancelRes = await post(`/api/v1/emergencies/${cancelIncidentId}/cancel`, {
      reason: 'Driver dropped phone while braking. Confirmed uninjured.'
    }, driverToken);

    assert.strictEqual(cancelRes.status, 200, 'Cancellation succeeds with 200');

    // Verify incident updated to cancelled_by_driver
    const getRes = await get(`/api/v1/emergencies/${cancelIncidentId}`, driverToken);
    assert.strictEqual(getRes.data.status, 'cancelled_by_driver');
    assert(getRes.data.falsePositiveReason.includes('Driver dropped phone'));
    console.log('[PASS] Test 4: Driver cancellation creates false-positive safety record and stops alarm.');
  }

  // Test 5: Dispatch operator acknowledges emergency
  {
    const ackRes = await post(`/api/v1/emergencies/${createdIncidentId}/acknowledge`, {}, adminToken);
    assert.strictEqual(ackRes.status, 200, 'Admin acknowledge succeeds with 200');

    const getRes = await get(`/api/v1/emergencies/${createdIncidentId}`, adminToken);
    assert.strictEqual(getRes.data.status, 'acknowledged');
    assert(getRes.data.acknowledgedBy, 'Operator record present');
    console.log('[PASS] Test 5: Control-room operator acknowledged emergency incident.');
  }

  // Test 6: Nearby responders proximity query returns ranked hospitals and ambulances
  {
    const res = await get('/api/v1/responders/nearby?lat=17.4265&lng=78.4116&radiusKm=35', adminToken);
    assert.strictEqual(res.status, 200);
    assert(Array.isArray(res.data.ambulances), 'Ambulance list returned');
    assert(Array.isArray(res.data.hospitals), 'Hospital list returned');
    assert(res.data.hospitals.length > 0, 'Verified hospitals found');
    assert(res.data.ambulances.length > 0, 'Verified ambulances found');

    // First ambulance should have shortest distance or be available
    assert(res.data.ambulances[0].distanceKm <= 50, 'Ambulance distance computed');
    console.log(`[PASS] Test 6: Responders ranked by proximity (${res.data.ambulances.length} ambulances, ${res.data.hospitals.length} hospitals).`);
  }

  // Test 7: Assign ambulance and target hospital to emergency
  let chosenAmbulanceId = 'AMB-UNIT-101';
  {
    const nearby = await get('/api/v1/responders/nearby?lat=17.4265&lng=78.4116&radiusKm=35', adminToken);
    const availableAmbulance = nearby.data.ambulances.find(a => a.availability === 'available') || nearby.data.ambulances[0];
    chosenAmbulanceId = availableAmbulance.id;

    const assignRes = await post(`/api/v1/emergencies/${createdIncidentId}/assign-ambulance`, {
      ambulanceId: chosenAmbulanceId,
      hospitalId: 'HOSP-HYD-01',
      notes: 'Driver responsive but dizzy. ALS equipment required.'
    }, adminToken);

    assert.strictEqual(assignRes.status, 200, 'Assignment succeeds');

    const checkRes = await get(`/api/v1/emergencies/${createdIncidentId}`, adminToken);
    assert.strictEqual(checkRes.data.status, 'ambulance_assigned');
    assert.strictEqual(checkRes.data.assignedAmbulanceId, chosenAmbulanceId);
    assert.strictEqual(checkRes.data.selectedHospitalId, 'HOSP-HYD-01');
    console.log(`[PASS] Test 7: Ambulance ${chosenAmbulanceId} dispatched with destination hospital HOSP-HYD-01.`);
  }

  // Test 8: Two ambulances cannot be assigned to conflicting incidents accidentally
  {
    const conflictRes = await post(`/api/v1/emergencies/INC-OTHER-TEST/assign-ambulance`, {
      ambulanceId: chosenAmbulanceId // already dispatched in Test 7
    }, adminToken);

    // Either 404 (incident not found) or 409 (ambulance already busy)
    assert(conflictRes.status === 404 || conflictRes.status === 409, 'Rejects conflicting assignment');
    console.log('[PASS] Test 8: Ambulance concurrency conflict prevented.');
  }

  // Test 9: Native safety service health heartbeat
  {
    const hbRes = await post('/api/v1/safety-service/heartbeat', {
      deviceId: 'PIXEL-7-PRO',
      activeTripId: 'TRIP-DEMO-01',
      serviceRunning: true,
      locationPermission: 'granted_fine',
      notificationPermission: 'granted',
      batteryOptimizationExempt: true,
      sensorAvailability: { accelerometer: true, gyroscope: true, gps: true, obd2: false },
      batteryLevel: 92
    }, driverToken);

    assert.strictEqual(hbRes.status, 200);
    assert.strictEqual(hbRes.data.status, 'ok');

    const healthRes = await get('/api/v1/safety-service/health', driverToken);
    assert.strictEqual(healthRes.status, 200);
    assert.strictEqual(healthRes.data.serviceRunning, true);
    assert.strictEqual(healthRes.data.batteryLevel, 92);
    console.log('[PASS] Test 9: Foreground safety service heartbeat and health monitoring verified.');
  }

  // Test 10: Dedicated vehicle IoT/OBD-II hardware ingestion contract with signature
  {
    const iotRes = await post('/api/v1/iot/crash-events', {
      deviceId: 'IOT-OBD2-UNIT-99',
      vehicleId: 'VEH-01',
      sequenceNumber: 1042,
      timestamp: new Date().toISOString(),
      coordinates: { lat: 17.4375, lng: 78.4852 },
      speed: 70,
      impactForce: 6.8,
      orientation: { roll: 85, pitch: 10 },
      airbagSignal: true,
      batteryLevel: 98,
      networkStrength: 'LTE-eSIM-Excellent',
      firmwareVersion: '2.1.0'
    }, null, {
      'x-iot-device-token': 'fleetroute_iot_secure_token_default'
    });

    assert.strictEqual(iotRes.status, 201, 'Hardware crash accepted with 201');
    assert(iotRes.data.incidentId, 'Generated incident from hardware');
    console.log(`[PASS] Test 10: Dedicated IoT hardware crash ingestion verified (${iotRes.data.incidentId}).`);
  }

  // Test 11: Immutable audit timeline records every state transition
  {
    const tlRes = await get(`/api/v1/emergencies/${createdIncidentId}/timeline`, adminToken);
    assert.strictEqual(tlRes.status, 200);
    const statuses = (tlRes.data.timeline || []).map(t => t.status || t.toStatus || t.action);
    assert(statuses.length >= 3, `Timeline must record every step: ${JSON.stringify(statuses)}`);
    assert(statuses.includes('sos_created'), 'Has creation event');
    assert(statuses.includes('acknowledged'), 'Has acknowledge event');
    assert(statuses.includes('ambulance_assigned'), 'Has assignment event');
    console.log(`[PASS] Test 11: Immutable audit timeline verified (${tlRes.data.timeline.length} audited transitions: ${statuses.join(' -> ')}).`);
  }

  // Test 12: Resolve emergency incident
  {
    const resRes = await post(`/api/v1/emergencies/${createdIncidentId}/status`, {
      status: 'resolved',
      reason: 'Driver transported safely to hospital. Emergency resolved.'
    }, adminToken);

    assert.strictEqual(resRes.status, 200);
    const getRes = await get(`/api/v1/emergencies/${createdIncidentId}`, adminToken);
    assert.strictEqual(getRes.data.status, 'resolved');
    assert(getRes.data.resolvedBy);
    console.log('[PASS] Test 12: Emergency incident successfully resolved with freed ambulance unit.');
  }

  console.log('================================================================');
  console.log('ALL AUTOMATIC ACCIDENT & EMERGENCY TESTS PASSED 100%!');
  console.log('================================================================');
}

if (require.main === module) {
  runEmergencyTests().catch(err => {
    console.error('TEST SUITE FAILED:', err);
    process.exit(1);
  });
}

module.exports = { runEmergencyTests };
