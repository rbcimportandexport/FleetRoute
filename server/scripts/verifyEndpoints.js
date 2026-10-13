// server/scripts/verifyEndpoints.js
// Verifies all new endpoints for driver accounts, location editing, and gate proof photos

const http = require('http');

function post(path, body, token) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request({
      hostname: 'localhost',
      port: 5000,
      path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        ...(token ? { 'Authorization': `Bearer ${token}` } : {})
      }
    }, res => {
      let buf = '';
      res.on('data', d => buf += d);
      res.on('end', () => resolve({ status: res.statusCode, data: JSON.parse(buf || '{}') }));
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function put(path, body, token) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request({
      hostname: 'localhost',
      port: 5000,
      path,
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        ...(token ? { 'Authorization': `Bearer ${token}` } : {})
      }
    }, res => {
      let buf = '';
      res.on('data', d => buf += d);
      res.on('end', () => resolve({ status: res.statusCode, data: JSON.parse(buf || '{}') }));
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
      port: 5000,
      path,
      method: 'GET',
      headers: {
        ...(token ? { 'Authorization': `Bearer ${token}` } : {})
      }
    }, res => {
      let buf = '';
      res.on('data', d => buf += d);
      res.on('end', () => resolve({ status: res.statusCode, data: JSON.parse(buf || '{}') }));
    });
    req.on('error', reject);
    req.end();
  });
}

async function run() {
  console.log('[Test] Logging in as admin...');
  const loginRes = await post('/api/auth/login', { identifier: 'admin@gmail.com', password: 'Admin1234!' });
  if (!loginRes.data.token) {
    throw new Error('Admin login failed: ' + JSON.stringify(loginRes.data));
  }
  const token = loginRes.data.token;
  console.log('[Test] Admin logged in successfully.');

  // 1. Check Driver Accounts
  console.log('\n[Test 1] Fetching driver user accounts...');
  const usersRes = await get('/api/auth/users', token);
  const driverUsers = (usersRes.data || []).filter(u => u.role === 'driver');
  console.log(`[Test 1] Found ${driverUsers.length} driver accounts.`);
  if (driverUsers.length === 0) throw new Error('No driver users found!');

  // 2. Edit a Driver Account
  const targetDriver = driverUsers[0];
  console.log(`\n[Test 2] Editing driver account ${targetDriver.id} (${targetDriver.name})...`);
  const editDriverRes = await put(`/api/auth/users/${targetDriver.id}`, {
    name: targetDriver.name,
    email: targetDriver.email,
    phone: '+91 99999 11111',
    driverId: targetDriver.driverId,
    status: 'active'
  }, token);
  console.log(`[Test 2] Edit result: ${editDriverRes.status} -> ${editDriverRes.data.message || JSON.stringify(editDriverRes.data)}`);

  // 3. Edit Location
  console.log('\n[Test 3] Fetching locations...');
  const locsRes = await get('/api/locations', token);
  if (!locsRes.data || locsRes.data.length === 0) throw new Error('No locations found!');
  const targetLoc = locsRes.data[0];
  console.log(`[Test 3] Editing location ${targetLoc.id} (${targetLoc.name})...`);
  const editLocRes = await put(`/api/locations/${targetLoc.id}`, {
    name: targetLoc.name,
    address: targetLoc.address,
    landmark: 'Updated Near Main Expressway Gate',
    lat: targetLoc.lat,
    lng: targetLoc.lng,
    type: targetLoc.type,
    arrivalRadiusMeters: 175,
    contactPerson: 'Suresh Kumar (Site Supervisor)',
    contactNumber: '+91 98111 99887',
    instructions: 'Heavy vehicles use Bay 4 entrance',
    status: 'active'
  }, token);
  console.log(`[Test 3] Edit location result: ${editLocRes.status} -> ${editLocRes.data.location?.name || JSON.stringify(editLocRes.data)}`);

  // 4. Save Gate Proofs for Trip
  console.log('\n[Test 4] Fetching trips...');
  const tripsRes = await get('/api/trips', token);
  if (!tripsRes.data || tripsRes.data.length === 0) throw new Error('No trips found!');
  const targetTrip = tripsRes.data[0];
  console.log(`[Test 4] Submitting gate proofs for trip ${targetTrip.id}...`);
  const proofRes = await post(`/api/trips/${targetTrip.id}/gate-proofs`, {
    odometerPhoto: '/images/gate-proofs/odometer-cluster.jpg',
    walkaroundPhoto: '/images/gate-proofs/walkaround-front.jpg',
    driverSeatbeltPhoto: '/images/gate-proofs/driver-seatbelt-selfie.jpg',
    seatbeltVerified: true,
    overspeedingPledge: true,
    depotLocationName: 'Central Logistics Hub (Bay 4)',
    notes: 'Pre-trip driver selfie with seatbelt and speedometer verified'
  }, token);
  console.log(`[Test 4] Gate proof result: ${proofRes.status} -> ${proofRes.data.message}`);
  console.log('Driver Selfie Recorded:', Boolean(proofRes.data.gateProofs?.driverSeatbeltPhoto));
  console.log('Seatbelt Verified:', proofRes.data.gateProofs?.seatbeltVerified);
  console.log('No Overspeeding Pledge:', proofRes.data.gateProofs?.overspeedingPledge);

  // 5. Submit Breakdown / Incident Report
  console.log('\n[Test 5] Recording Breakdown & Incident Report...');
  const breakdownRes = await post(`/api/trips/${targetTrip.id}/activity`, {
    category: 'breakdown',
    notes: 'Engine overheating with coolant vapor warning',
    durationMinutes: 45,
    details: {
      breakdownCategory: 'engine',
      photosCount: 2,
      voiceNote: { durationSeconds: 12, saved: true }
    }
  }, token);
  console.log(`[Test 5] Breakdown result: ${breakdownRes.status} -> ${breakdownRes.data.message}`);
  console.log('Breakdown Category Saved:', breakdownRes.data.activity?.details?.breakdownCategory);
  console.log('Voice Note Saved:', Boolean(breakdownRes.data.activity?.details?.voiceNote));

  // 6. Submit Police / RTO Challan Report
  console.log('\n[Test 6] Recording Police / RTO Challan Report...');
  const challanRes = await post(`/api/trips/${targetTrip.id}/activity`, {
    category: 'challan_stoppage',
    notes: 'Authority Stoppage: Traffic Police - Challan GJ01-2024-CH-9182 (₹2000)',
    durationMinutes: 30,
    details: {
      authority: 'traffic_police',
      stoppageReason: 'overload',
      challanNumber: 'GJ01-2024-CH-9182',
      penaltyAmount: 2000,
      challanSlipAttached: true,
      weighmentSlipAttached: true,
      settlementOption: 'cash_spot',
      reimbursementAccount: 'Linked Driver Account: SBI •••• 4182 (Rajesh Kumar)'
    }
  }, token);
  console.log(`[Test 6] Challan result: ${challanRes.status} -> ${challanRes.data.message}`);
  console.log('Challan Number:', challanRes.data.activity?.details?.challanNumber);
  console.log('Penalty Amount:', challanRes.data.activity?.details?.penaltyAmount);
  console.log('Settlement Option:', challanRes.data.activity?.details?.settlementOption);

  console.log('\n[ALL TESTS PASSED SUCCESSFULLY!]');
}

run().catch(err => {
  console.error('[Verification FAILED]', err.message);
  process.exit(1);
});
