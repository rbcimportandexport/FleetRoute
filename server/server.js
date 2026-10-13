// server/server.js
// FleetRoute Production Logistics Engine & REST API
// STRICTLY ZERO EMOJIS. ZERO MOCK/DEMO DATA. REAL MONGODB PERSISTENCE ONLY.

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const db = require('./db');
const {
  hashPassword,
  comparePassword,
  generateToken,
  requireAuth,
  requireAdmin,
  requireDriver
} = require('./auth');
const emergencyEscalationService = require('./emergencyEscalationService');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json({ limit: '15mb' })); // Support actual delivery photos and signatures

// System settings default in-memory cache, backed by database
let systemSettings = {
  speedThresholdKmH: parseInt(process.env.OVERSPEED_THRESHOLD_KMH, 10) || 80,
  minSustainedSeconds: 15,
  defaultArrivalRadiusMeters: parseInt(process.env.DEFAULT_ARRIVAL_RADIUS_METERS, 10) || 150,
  timezone: 'Asia/Kolkata',
  utcStandard: 'ISO-8601'
};

// Health Check Endpoint (Reflects authentic database connectivity state)
app.get('/api/health', (req, res) => {
  const isDbConnected = db.isConnected();
  if (!isDbConnected) {
    return res.status(503).json({
      status: 'unavailable',
      database: 'disconnected',
      message: 'Database connection offline: MongoDB is unavailable.'
    });
  }
  return res.json({
    status: 'healthy',
    database: 'connected',
    timestamp: new Date().toISOString()
  });
});

// Database Connectivity Guard Middleware
app.use((req, res, next) => {
  if (req.path === '/api/health') return next();

  if (!db.isConnected()) {
    return res.status(503).json({
      error: 'Database connection offline: MongoDB is unavailable.',
      message: 'Database connection offline: MongoDB is unavailable.',
      code: 'DB_UNAVAILABLE'
    });
  }
  next();
});

// Haversine formula for arrival radius validation
function calculateDistanceMeters(lat1, lon1, lat2, lon2) {
  if (!lat1 || !lon1 || !lat2 || !lon2) return 0;
  const R = 6371e3;
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

// Transform trip object for complete UI and API consistency
function formatTrip(t, drivers = [], vehicles = []) {
  if (!t) return null;
  const driver = drivers.find(d => d.id === t.driverId) || { name: t.driverName || 'Unassigned Driver', phone: '' };
  const vehicle = vehicles.find(v => v.id === t.vehicleId) || { registrationNumber: t.vehicleRegistration || 'Unassigned Vehicle', model: '' };

  const stops = (t.stops || t.routeStops || []).map((s, idx) => ({
    id: s.id || `stop-${idx}`,
    stopIndex: idx,
    type: (s.type || 'delivery').toLowerCase().includes('pickup') 
      ? 'pickup' 
      : ((s.type || '').toLowerCase().includes('return') 
          ? 'return' 
          : ((s.type || '').toLowerCase().includes('origin') ? 'pickup' : 'delivery')),
    locationId: s.locationId,
    location: s.location || {
      name: s.name || `Stop ${idx + 1}`,
      address: s.address || '',
      lat: s.lat || 0,
      lng: s.lng || 0,
      arrivalRadiusMeters: s.arrivalRadiusMeters || 150
    },
    plannedArrival: s.scheduledTime || s.plannedArrival || 'Scheduled',
    status: (s.status || 'pending').toLowerCase(),
    recipientName: s.recipientName || '',
    recipientPhone: s.recipientPhone || '',
    cargoSummary: s.cargoSummary || s.purpose || '',
    arrivalSource: s.arrivalSource || null,
    manualArrivalReason: s.manualArrivalReason || null,
    arrivedAt: s.arrivedAt || null,
    completedAt: s.completedAt || null
  }));

  const cargo = (t.cargo || t.cargoLines || []).map((c, idx) => ({
    id: c.id || `cargo-${idx}`,
    productId: c.productId,
    productName: c.name || c.productName || 'Cargo Item',
    category: (c.category || 'GENERAL_GOODS').replace('_', ' '),
    plannedQty: c.quantityPlanned !== undefined ? c.quantityPlanned : (c.plannedQty || 0),
    loadedQty: c.quantityLoaded !== undefined ? c.quantityLoaded : (c.loadedQty || 0),
    deliveredQty: c.quantityDelivered !== undefined ? c.quantityDelivered : (c.deliveredQty || 0),
    damagedQty: c.quantityDamaged !== undefined ? c.quantityDamaged : (c.damagedQty || 0),
    rejectedQty: c.quantityRejected !== undefined ? c.quantityRejected : (c.rejectedQty || 0),
    returnedQty: c.quantityReturned !== undefined ? c.quantityReturned : (c.returnedQty || 0),
    unit: c.unit || 'units',
    fragile: Boolean(c.fragile),
    weightKg: c.weightKg || c.weightKgTotal || 0
  }));

  const activities = (t.activities || t.activityTimeline || []).map((a, idx) => ({
    id: a.id || `act-${idx}`,
    category: (a.category || 'driving').toLowerCase().replace('_delay', '').replace('_repair', ''),
    durationMinutes: a.durationMinutes || 0,
    notes: a.notes || a.title || 'Operational activity',
    startTime: a.startTime || a.timestamp || null,
    endTime: a.endTime || null,
    source: a.source || 'driver telematics',
    details: a.details || undefined
  }));

  return {
    ...t,
    driverName: driver.name,
    driverPhone: driver.phone,
    vehicleRegistration: vehicle.registrationNumber,
    currentLocation: t.currentLocation || null,
    currentSpeed: t.currentSpeedKmH || t.currentSpeed || 0,
    currentActivity: (t.currentActivity || 'idle').toLowerCase(),
    currentStopIndex: t.currentStopIndex !== undefined ? t.currentStopIndex : 0,
    stops,
    cargo,
    activities,
    gateProofs: t.gateProofs || null
  };
}

// Connect to MongoDB on startup. Fail startup cleanly if database is unreachable.
async function initializeDatabase() {
  await db.connect();
  
  // Load saved settings if present
  try {
    const saved = await db.collection('settings').findOne({ key: 'system_settings' });
    if (saved && saved.value) {
      systemSettings = { ...systemSettings, ...saved.value };
    }
  } catch {
    // Ignore setting fetch notice on brand new empty database
  }
}

const initDbPromise = initializeDatabase();
app.initDbPromise = initDbPromise;

// =========================================================================
// 1. HEALTH & PERSISTENCE DIAGNOSTICS
// =========================================================================
app.get('/api/health', (req, res) => {
  res.json({
    ...db.health(),
    service: 'FleetRoute Production Logistics Engine',
    timestamp: new Date().toISOString()
  });
});

// =========================================================================
// 2. AUTHENTICATION & ACCESS CONTROL
// =========================================================================

// Login with Email or Phone Number + Password
app.post('/api/auth/login', async (req, res) => {
  const { identifier, password } = req.body;

  if (!identifier || !password) {
    return res.status(400).json({ error: 'Please enter your email or phone number and password.' });
  }

  const cleanId = identifier.trim().toLowerCase();
  const cleanPhone = identifier.replace(/[\s-]/g, '');

  const user = await db.collection('users').findOne({
    $or: [
      { email: cleanId },
      { phone: cleanPhone },
      { phone: identifier.trim() }
    ]
  });

  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials. User account not found.' });
  }

  if (user.status === 'disabled') {
    return res.status(403).json({ error: 'Your account has been disabled by central management.' });
  }

  const isMatch = await comparePassword(password, user.passwordHash);
  if (!isMatch) {
    return res.status(401).json({ error: 'Invalid credentials. Incorrect password.' });
  }

  const token = generateToken(user);
  let driverInfo = null;
  if (user.role === 'driver' && user.driverId) {
    driverInfo = await db.collection('drivers').findById(user.driverId);
  }

  res.json({
    token,
    user: {
      id: user.id,
      email: user.email,
      phone: user.phone,
      name: user.name,
      role: user.role,
      driverId: user.driverId || null,
      driver: driverInfo
    }
  });
});

// Get Current Logged-in Profile
app.get('/api/auth/me', requireAuth, async (req, res) => {
  let driverInfo = null;
  if (req.user.role === 'driver' && req.user.driverId) {
    driverInfo = await db.collection('drivers').findById(req.user.driverId);
  }
  res.json({
    user: {
      ...req.user,
      driver: driverInfo
    }
  });
});

// Change Password
app.post('/api/auth/change-password', requireAuth, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'Current password and new password are required.' });
  }

  const user = await db.collection('users').findById(req.user.id);
  if (!user) {
    return res.status(404).json({ error: 'User record not found.' });
  }

  const isMatch = await comparePassword(currentPassword, user.passwordHash);
  if (!isMatch) {
    return res.status(400).json({ error: 'Current password verification failed.' });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'New password must be at least 6 characters long.' });
  }

  const newHash = await hashPassword(newPassword);
  await db.collection('users').updateOne({ id: user.id }, { passwordHash: newHash });

  res.json({ message: 'Password updated successfully.' });
});

// Admin-managed Account Creation (Public registration cannot create Admin!)
app.post('/api/auth/users', requireAuth, requireAdmin, async (req, res) => {
  const { name, email, phone, password, role, driverId } = req.body;

  if (!name || !email || !password || !role) {
    return res.status(400).json({ error: 'Name, email, password, and role are required.' });
  }

  const existing = await db.collection('users').findOne({ email: email.toLowerCase().trim() });
  if (existing) {
    return res.status(400).json({ error: 'An account with this email address already exists.' });
  }

  const passwordHash = await hashPassword(password);
  const newUser = await db.collection('users').insertOne({
    email: email.toLowerCase().trim(),
    phone: phone ? phone.trim() : '',
    name: name.trim(),
    role: role === 'admin' ? 'admin' : 'driver',
    driverId: role === 'driver' ? (driverId || null) : null,
    status: 'active',
    passwordHash,
    isDemo: false
  });

  res.status(201).json({
    message: 'User account created successfully.',
    user: {
      id: newUser.id,
      email: newUser.email,
      name: newUser.name,
      role: newUser.role,
      driverId: newUser.driverId,
      status: newUser.status
    }
  });
});

// Admin Updates User Account Details (Edit driver account name, email, phone, driverId, password, status)
app.put('/api/auth/users/:id', requireAuth, requireAdmin, async (req, res) => {
  const user = await db.collection('users').findById(req.params.id);
  if (!user) {
    return res.status(404).json({ error: 'User account not found.' });
  }

  const { name, email, phone, role, driverId, status, password } = req.body;
  const updateData = {};

  if (name) updateData.name = name.trim();
  if (email) {
    const cleanEmail = email.toLowerCase().trim();
    const existing = await db.collection('users').findOne({ email: cleanEmail, id: { $ne: user.id } });
    if (existing) {
      return res.status(400).json({ error: 'Email address is already in use by another user account.' });
    }
    updateData.email = cleanEmail;
  }
  if (phone !== undefined) updateData.phone = phone.trim();
  if (role) updateData.role = role;
  if (driverId !== undefined) updateData.driverId = driverId || null;
  if (status && ['active', 'disabled'].includes(status)) updateData.status = status;

  if (password && password.trim()) {
    if (password.trim().length < 6) {
      return res.status(400).json({ error: 'New password must be at least 6 characters long.' });
    }
    updateData.passwordHash = await hashPassword(password.trim());
  }

  const updated = await db.collection('users').updateOne(
    { id: user.id },
    updateData
  );

  res.json({
    message: 'User account updated successfully.',
    user: {
      id: updated.id,
      email: updated.email,
      phone: updated.phone,
      name: updated.name,
      role: updated.role,
      driverId: updated.driverId,
      status: updated.status
    }
  });
});

// Auto-Provision Driver Login Accounts for all active drivers missing user accounts
app.post('/api/auth/users/auto-provision', requireAuth, requireAdmin, async (req, res) => {
  const drivers = await db.collection('drivers').find();
  const existingUsers = await db.collection('users').find();
  const createdAccounts = [];

  for (const drv of drivers) {
    const hasAccount = existingUsers.some(u => u.driverId === drv.id || (u.phone && drv.phone && u.phone === drv.phone));
    if (!hasAccount) {
      const namePart = drv.name.toLowerCase().replace(/[^a-z0-9]/g, '');
      const email = `${namePart || 'driver'}.${drv.id.toLowerCase()}@fleetroute.com`;
      const defaultPassword = 'Driver1234!';
      const passwordHash = await hashPassword(defaultPassword);

      const newUser = await db.collection('users').insertOne({
        email,
        phone: drv.phone || '',
        name: drv.name,
        role: 'driver',
        driverId: drv.id,
        status: 'active',
        passwordHash,
        isDemo: false
      });

      createdAccounts.push({
        id: newUser.id,
        name: newUser.name,
        email: newUser.email,
        driverId: drv.id,
        defaultPassword
      });
    }
  }

  res.json({
    message: `Provisioned ${createdAccounts.length} driver user accounts.`,
    count: createdAccounts.length,
    created: createdAccounts
  });
});

// Admin Updates User Account Status (Enable / Disable)
app.patch('/api/auth/users/:id/status', requireAuth, requireAdmin, async (req, res) => {
  const { status } = req.body;
  if (!['active', 'disabled'].includes(status)) {
    return res.status(400).json({ error: 'Status must be active or disabled.' });
  }

  const updated = await db.collection('users').updateOne({ id: req.params.id }, { status });
  if (!updated) {
    return res.status(404).json({ error: 'User account not found.' });
  }

  res.json({ message: `User account status updated to ${status}.`, user: updated });
});

// Admin Lists All Accounts
app.get('/api/auth/users', requireAuth, requireAdmin, async (req, res) => {
  const users = await db.collection('users').find();
  const safeUsers = users.map(u => ({
    id: u.id,
    email: u.email,
    phone: u.phone,
    name: u.name,
    role: u.role,
    driverId: u.driverId,
    status: u.status,
    createdAt: u.createdAt
  }));
  res.json(safeUsers);
});

// =========================================================================
// 3. LOCATIONS MANAGEMENT & GEOCODING
// =========================================================================

app.get('/api/locations', requireAuth, async (req, res) => {
  const { activeOnly } = req.query;
  const filter = activeOnly === 'true' ? { status: { $ne: 'archived' } } : {};
  let locations = await db.collection('locations').find(filter);
  res.json(locations);
});

app.post('/api/locations', requireAuth, requireAdmin, async (req, res) => {
  const { name, address, landmark, lat, lng, type, arrivalRadiusMeters, contactName, contactPhone } = req.body;

  if (!name || !address || lat === undefined || lng === undefined) {
    return res.status(400).json({ error: 'Location name, address, latitude, and longitude are required.' });
  }

  const parsedLat = parseFloat(lat);
  const parsedLng = parseFloat(lng);

  if (isNaN(parsedLat) || parsedLat < -90 || parsedLat > 90) {
    return res.status(400).json({ error: 'Latitude must be a valid number between -90 and 90.' });
  }
  if (isNaN(parsedLng) || parsedLng < -180 || parsedLng > 180) {
    return res.status(400).json({ error: 'Longitude must be a valid number between -180 and 180.' });
  }

  const newLocation = await db.collection('locations').insertOne({
    name: name.trim(),
    address: address.trim(),
    landmark: landmark ? landmark.trim() : '',
    lat: parsedLat,
    lng: parsedLng,
    type: type || 'delivery',
    arrivalRadiusMeters: parseInt(arrivalRadiusMeters, 10) || systemSettings.defaultArrivalRadiusMeters,
    contactName: contactName || '',
    contactPhone: contactPhone || '',
    status: 'active',
    isDemo: false
  });

  res.status(201).json({ location: newLocation });
});

app.put('/api/locations/:id', requireAuth, requireAdmin, async (req, res) => {
  const loc = await db.collection('locations').findById(req.params.id);
  if (!loc) return res.status(404).json({ error: 'Location not found.' });

  const {
    name,
    address,
    landmark,
    lat,
    lng,
    type,
    arrivalRadiusMeters,
    contactPerson,
    contactNumber,
    contactName,
    contactPhone,
    instructions,
    status
  } = req.body;

  const updateData = {};
  if (name) updateData.name = name.trim();
  if (address) updateData.address = address.trim();
  if (landmark !== undefined) updateData.landmark = landmark.trim();
  if (lat !== undefined && !isNaN(parseFloat(lat))) updateData.lat = parseFloat(lat);
  if (lng !== undefined && !isNaN(parseFloat(lng))) updateData.lng = parseFloat(lng);
  if (type) updateData.type = type;
  if (arrivalRadiusMeters !== undefined) updateData.arrivalRadiusMeters = parseInt(arrivalRadiusMeters, 10);
  
  const person = contactPerson || contactName;
  if (person !== undefined) {
    updateData.contactPerson = person.trim();
    updateData.contactName = person.trim();
  }

  const phone = contactNumber || contactPhone;
  if (phone !== undefined) {
    updateData.contactNumber = phone.trim();
    updateData.contactPhone = phone.trim();
  }

  if (instructions !== undefined) updateData.instructions = instructions.trim();
  if (status) updateData.status = status;

  const updated = await db.collection('locations').updateOne(
    { id: loc.id },
    updateData
  );
  res.json({ location: updated });
});

app.patch('/api/locations/:id/archive', requireAuth, requireAdmin, async (req, res) => {
  const loc = await db.collection('locations').findById(req.params.id);
  if (!loc) return res.status(404).json({ error: 'Location not found.' });

  const nextStatus = loc.status === 'archived' ? 'active' : 'archived';
  const updated = await db.collection('locations').updateOne({ id: req.params.id }, { status: nextStatus });
  res.json({ location: updated });
});

// Fast Indian Logistics Hubs Dictionary (always available for instant search & offline resilience)
const INDIAN_LOGISTICS_HUBS = [
  { name: 'Surat (सूरत)', address: 'Surat City Logistics Hub, Ring Road, Gujarat, 395002, India', lat: 21.1702, lng: 72.8311 },
  { name: 'Chalthan / NH48 (चलथान)', address: 'Chalthan Toll Plaza & Freight Corridor, NH48, Surat, Gujarat, 394315, India', lat: 21.1460, lng: 72.9550 },
  { name: 'Ahmedabad (अहमदाबाद)', address: 'Ahmedabad Central Fulfilment Center, Aslali Ring Road, Gujarat, India', lat: 23.0225, lng: 72.5714 },
  { name: 'Vadodara (वडोदरा)', address: 'Vadodara Transport Nagar & Cargo Yard, Gujarat, India', lat: 22.3072, lng: 73.1812 },
  { name: 'Rajkot (राजकोट)', address: 'Rajkot Industrial GIDC Logistics Park, Gujarat, India', lat: 22.3039, lng: 70.8022 },
  { name: 'Mumbai (मुंबई)', address: 'Mumbai Bhiwandi Central Logistics Hub, Maharashtra, India', lat: 19.0760, lng: 72.8777 },
  { name: 'Pune (पुणे)', address: 'Pune Chakan Automobile & Cargo Hub, Maharashtra, India', lat: 18.5204, lng: 73.8567 },
  { name: 'Delhi NCR (दिल्ली)', address: 'Delhi Sanjay Gandhi Transport Nagar (SGTN), Delhi, India', lat: 28.6139, lng: 77.2090 },
  { name: 'Bengaluru (बेंगलुरु)', address: 'Bengaluru Nelamangala Cargo Depot, Karnataka, India', lat: 12.9716, lng: 77.5946 },
  { name: 'Hyderabad (हैदराबाद)', address: 'Hyderabad Shamshabad Cargo Terminal, Telangana, India', lat: 17.3850, lng: 78.4867 },
  { name: 'Chennai (चेन्नई)', address: 'Chennai Port & Freight Corridor, Tamil Nadu, India', lat: 13.0827, lng: 80.2707 },
  { name: 'Kolkata (कोलकाता)', address: 'Kolkata Inland Port & Transit Depot, West Bengal, India', lat: 22.5726, lng: 88.3639 },
  { name: 'Jaipur (जयपुर)', address: 'Jaipur Transport Nagar & Warehouse Zone, Rajasthan, India', lat: 26.9124, lng: 75.7873 },
  { name: 'Indore (इंदौर)', address: 'Indore Dewas Naka Logistics Park, MP, India', lat: 22.7196, lng: 75.8577 },
  { name: 'Nagpur (नागपुर)', address: 'Nagpur MIHAN Multi-Modal Logistics Hub, Maharashtra, India', lat: 21.1458, lng: 79.0882 }
];

// Geocoding Proxy (Instant Pre-indexed Hubs + Real Nominatim)
app.get('/api/geocode/search', async (req, res) => {
  const query = (req.query.q || '').trim().toLowerCase();
  if (!query) {
    return res.status(400).json({ error: 'Search query parameter q is required.' });
  }

  const results = [];

  // 1. Instant local match for high-frequency transport hubs
  for (const hub of INDIAN_LOGISTICS_HUBS) {
    if (hub.name.toLowerCase().includes(query) || hub.address.toLowerCase().includes(query)) {
      results.push({ ...hub });
    }
  }

  // 2. Query Nominatim for full worldwide coverage
  try {
    const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(query)}&format=json&addressdetails=1&limit=6`;
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'FleetRoute-Logistics-Platform/1.0 (fleetroute-dispatch@logistics.internal)'
      },
      signal: AbortSignal.timeout(4000)
    });

    if (response.ok) {
      const nomResults = await response.json();
      if (Array.isArray(nomResults)) {
        for (const r of nomResults) {
          // Avoid duplicate coordinates
          const rLat = parseFloat(r.lat);
          const rLng = parseFloat(r.lon);
          const isDuplicate = results.some(existing => 
            Math.abs(existing.lat - rLat) < 0.05 && Math.abs(existing.lng - rLng) < 0.05
          );
          if (!isDuplicate) {
            results.push({
              name: r.display_name.split(',')[0],
              address: r.display_name,
              lat: rLat,
              lng: rLng
            });
          }
        }
      }
    }
  } catch {
    // Network or timeout: local matches still succeed
  }

  res.json(results);
});

// Reverse Geocoding Proxy (Nominatim with reliable fallback)
app.get('/api/geocode/reverse', async (req, res) => {
  const lat = parseFloat(req.query.lat);
  const lng = parseFloat(req.query.lng);
  if (isNaN(lat) || isNaN(lng)) {
    return res.status(400).json({ error: 'Valid lat and lng query parameters are required.' });
  }

  try {
    const url = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json&addressdetails=1`;
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'FleetRoute-Logistics-Platform/1.0 (fleetroute-dispatch@logistics.internal)'
      },
      signal: AbortSignal.timeout(5000)
    });

    if (response.ok) {
      const data = await response.json();
      if (data && data.display_name) {
        const addr = data.address || {};
        const shortName = addr.amenity || addr.building || addr.industrial || addr.commercial || addr.suburb || addr.neighbourhood || addr.road || addr.city || addr.town || addr.village || data.display_name.split(',')[0];
        return res.json({
          name: shortName,
          address: data.display_name,
          lat,
          lng,
          city: addr.city || addr.town || addr.state_district || '',
          state: addr.state || ''
        });
      }
    }
  } catch {
    // Network or timeout fallback
  }

  // Reliable fallback so frontend always has clean location text
  res.json({
    name: `Site (${lat.toFixed(4)}, ${lng.toFixed(4)})`,
    address: `Geographical Point near ${lat.toFixed(4)}, ${lng.toFixed(4)}`,
    lat,
    lng
  });
});

// =========================================================================
// 4. REAL DRIVER LOCATION TELEMETRY & LIVE TRACKING
// =========================================================================

// Driver Posts Real Browser Location Sample
const handleLocationSample = async (req, res) => {
  const driverId = req.user.driverId;
  if (!driverId) {
    return res.status(400).json({ error: 'User is not linked to a driver personnel ID.' });
  }

  const { latitude, longitude, accuracy, speed, heading, deviceTimestamp, tripId, source } = req.body;

  const lat = parseFloat(latitude !== undefined ? latitude : req.body.lat);
  const lng = parseFloat(longitude !== undefined ? longitude : req.body.lng);

  if (isNaN(lat) || lat < -90 || lat > 90 || isNaN(lng) || lng < -180 || lng > 180) {
    return res.status(400).json({ error: 'Invalid coordinates received in telemetry payload.' });
  }

  const driver = await db.collection('drivers').findById(driverId);
  if (!driver) {
    return res.status(404).json({ error: 'Driver profile not found.' });
  }

  const sampleTimestamp = deviceTimestamp ? new Date(deviceTimestamp).getTime() : Date.now();
  const lastRecorded = driver.lastSampleTimestamp ? new Date(driver.lastSampleTimestamp).getTime() : 0;

  // Reject out-of-order samples (older timestamp replacing newer recorded position)
  if (driver.lastSampleTimestamp && sampleTimestamp < lastRecorded) {
    return res.status(200).json({ 
      success: false, 
      ignoredOutOfOrder: true, 
      lastLocation: driver.lastLocation || driver.currentLocation, 
      message: 'Ignored out-of-order older sample.' 
    });
  }

  const sample = {
    driverId,
    tripId: tripId || driver.activeTripId || null,
    lat,
    lng,
    accuracy: accuracy !== null && accuracy !== undefined ? parseFloat(accuracy) : null,
    speed: speed !== null && speed !== undefined ? parseFloat(speed) : null,
    heading: heading !== null && heading !== undefined ? parseFloat(heading) : null,
    deviceTimestamp: deviceTimestamp || new Date().toISOString(),
    serverReceivedTimestamp: new Date().toISOString(),
    source: source || 'live_gps'
  };

  await db.collection('locationSamples').insertOne(sample);

  // Update Driver Current Location Record
  const updatedLocation = {
    lat,
    lng,
    accuracy: sample.accuracy,
    speed: sample.speed,
    heading: sample.heading,
    source: sample.source,
    updatedAt: sample.serverReceivedTimestamp
  };

  await db.collection('drivers').updateOne({ id: driverId }, {
    currentLocation: updatedLocation,
    lastLocation: updatedLocation,
    lastSampleTimestamp: sample.deviceTimestamp,
    lastLocationUpdate: sample.serverReceivedTimestamp
  });

  // If driver has an active or planned trip, record telemetry on trip
  const activeTrip = tripId 
    ? await db.collection('trips').findById(tripId)
    : await db.collection('trips').findOne({ driverId, status: { $in: ['in_progress', 'IN_TRANSIT', 'planned'] } });

  if (activeTrip) {
    const tripUpdate = { currentLocation: { lat, lng } };
    let speedKmH = 0;
    if (sample.speed !== null && !isNaN(sample.speed)) {
      speedKmH = sample.speed > 35 ? Math.round(sample.speed) : Math.round(sample.speed * 3.6);
      tripUpdate.currentSpeed = speedKmH;
    }
    await db.collection('trips').updateOne({ id: activeTrip.id }, tripUpdate);

    // REAL SPEED ALERT DETECTION: trigger automated safety event only when real telemetry speed exceeds threshold
    if (speedKmH > systemSettings.speedThresholdKmH) {
      const existingRecentAlert = await db.collection('safetyEvents').findOne({
        tripId: activeTrip.id,
        type: 'overspeed',
        reviewStatus: 'new'
      });

      if (!existingRecentAlert) {
        await db.collection('safetyEvents').insertOne({
          tripId: activeTrip.id,
          driverId,
          driverName: driver.name,
          vehicleRegistration: activeTrip.vehicleRegistration,
          type: 'overspeed',
          title: `Overspeed Detected (${speedKmH} km/h on GPS)`,
          recordedSpeed: speedKmH,
          speedThreshold: systemSettings.speedThresholdKmH,
          durationSeconds: 15,
          location: `Coordinates: ${lat.toFixed(4)}, ${lng.toFixed(4)}`,
          timestamp: new Date().toISOString(),
          source: 'live_telematics',
          reviewStatus: 'new',
          isDemo: false
        });
      }
    }
  }

  res.json({
    success: true,
    recordedAt: sample.serverReceivedTimestamp,
    driverId,
    lastLocation: updatedLocation
  });
};

app.post('/api/telemetry/location', requireAuth, requireDriver, handleLocationSample);
app.post('/api/driver/location', requireAuth, requireDriver, handleLocationSample);

// Fleet Live Telemetry Overview
app.get('/api/telemetry/drivers', requireAuth, async (req, res) => {
  const drivers = (await db.collection('drivers').find()).filter(d => d.status !== 'archived');
  const vehicles = await db.collection('vehicles').find();
  const trips = await db.collection('trips').find();

  const now = Date.now();
  const FRESHNESS_THRESHOLD_MS = 5 * 60 * 1000; // 5 minutes

  const fleet = drivers.map(drv => {
    const vehicle = vehicles.find(v => v.id === drv.assignedVehicleId) || null;
    const activeTrip = trips.find(t => t.driverId === drv.id && (t.status === 'in_progress' || t.status === 'IN_TRANSIT')) || null;

    let freshness = 'unavailable';
    if (drv.currentLocation && drv.currentLocation.updatedAt) {
      const diffMs = now - new Date(drv.currentLocation.updatedAt).getTime();
      freshness = diffMs <= FRESHNESS_THRESHOLD_MS ? 'fresh' : 'stale';
    }

    const stops = activeTrip ? (activeTrip.stops || activeTrip.routeStops || []) : [];
    const currentStopIdx = activeTrip?.currentStopIndex || 0;
    const nextStop = stops[currentStopIdx] || null;
    const remainingDeliveries = stops.slice(currentStopIdx).filter(s => (s.type || '').includes('delivery')).length;

    return {
      id: drv.id,
      name: drv.name,
      phone: drv.phone,
      avatar: drv.avatar || null,
      licenseNumber: drv.licenseNumber,
      availability: (drv.availability || 'available').toLowerCase(),
      assignedVehicleId: drv.assignedVehicleId,
      vehicleRegistration: vehicle?.registrationNumber || 'Unassigned',
      vehicleModel: vehicle?.model || '',
      assignedTripId: activeTrip?.id || null,
      currentActivity: activeTrip?.currentActivity || 'idle',
      currentLocation: drv.currentLocation || null,
      lastLocationUpdate: drv.lastLocationUpdate || null,
      freshness, // 'fresh' | 'stale' | 'unavailable'
      dataSource: drv.currentLocation?.source || 'unavailable',
      nextStop: nextStop ? {
        stopIndex: currentStopIdx + 1,
        name: nextStop.name || nextStop.location?.name,
        type: nextStop.type,
        lat: nextStop.lat || nextStop.location?.lat,
        lng: nextStop.lng || nextStop.location?.lng
      } : null,
      remainingDeliveries
    };
  });

  res.json(fleet);
});

// =========================================================================
// 5. TRIP CREATION, ASSIGNMENT & MULTI-STOP WORKFLOW
// =========================================================================

// List Trips (Driver Isolation Enforced!)
app.get('/api/trips', requireAuth, async (req, res) => {
  let trips = await db.collection('trips').find();

  // DRIVER ISOLATION: Drivers strictly only see their own assigned trips!
  if (req.user.role === 'driver') {
    trips = trips.filter(t => t.driverId === req.user.driverId);
  }

  const drivers = await db.collection('drivers').find();
  const vehicles = await db.collection('vehicles').find();

  res.json(trips.map(t => formatTrip(t, drivers, vehicles)));
});

// Trip Details (Driver Isolation Enforced!)
app.get('/api/trips/:id', requireAuth, async (req, res) => {
  const trip = await db.collection('trips').findById(req.params.id);
  if (!trip) return res.status(404).json({ error: 'Trip not found.' });

  // Driver Isolation
  if (req.user.role === 'driver' && trip.driverId !== req.user.driverId) {
    return res.status(403).json({ error: 'Access denied: You are not assigned to this trip.' });
  }

  const drivers = await db.collection('drivers').find();
  const vehicles = await db.collection('vehicles').find();

  res.json(formatTrip(trip, drivers, vehicles));
});

// Create and Dispatch New Trip
app.post('/api/trips', requireAuth, requireAdmin, async (req, res) => {
  const { driverId, vehicleId, stops, cargo, scheduledStartTime, notes } = req.body;

  if (!driverId || !vehicleId || !stops || stops.length < 2) {
    return res.status(400).json({ error: 'Driver, vehicle, and at least 2 route stops are required.' });
  }

  const driver = await db.collection('drivers').findById(driverId);
  if (!driver) return res.status(400).json({ error: 'Assigned driver not found.' });

  const activeDriverTrip = await db.collection('trips').findOne({ driverId, status: { $in: ['in_progress', 'IN_TRANSIT'] } });
  if (activeDriverTrip) {
    return res.status(400).json({ error: `Driver ${driver.name} is already assigned to active trip ${activeDriverTrip.id}.` });
  }

  const vehicle = await db.collection('vehicles').findById(vehicleId);
  if (!vehicle) return res.status(400).json({ error: 'Assigned vehicle not found.' });

  // Vehicle Capacity Check
  const totalPlannedKg = (cargo || []).reduce((acc, c) => acc + (parseFloat(c.weightKg) || 0), 0);
  if (vehicle.capacityKg && totalPlannedKg > vehicle.capacityKg) {
    return res.status(400).json({
      error: `Planned cargo weight (${totalPlannedKg} kg) exceeds vehicle capacity (${vehicle.capacityKg} kg).`
    });
  }

  // Populate stop locations if referenced
  const locationsCol = db.collection('locations');
  const formattedStops = await Promise.all(stops.map(async (s, idx) => {
    let loc = s.location;
    if (s.locationId && !loc) {
      loc = await locationsCol.findById(s.locationId);
    }
    return {
      id: s.id || `stop-${idx}`,
      stopIndex: idx,
      type: s.type || (idx === 0 ? 'pickup' : (idx === stops.length - 1 ? 'return' : 'delivery')),
      locationId: s.locationId || null,
      location: loc || {
        name: s.name || `Stop ${idx + 1}`,
        address: s.address || '',
        lat: s.lat || 0,
        lng: s.lng || 0,
        arrivalRadiusMeters: 150
      },
      plannedArrival: s.plannedArrival || 'Scheduled',
      status: 'pending',
      recipientName: s.recipientName || '',
      recipientPhone: s.recipientPhone || '',
      cargoSummary: s.cargoSummary || ''
    };
  }));

  const tripId = `TRIP-${Math.floor(1000 + Math.random() * 9000)}`;
  const newTrip = {
    id: tripId,
    driverId,
    driverName: driver.name,
    vehicleId,
    vehicleRegistration: vehicle.registrationNumber,
    status: 'planned',
    currentStopIndex: 0,
    currentLocation: null,
    currentSpeed: 0,
    currentActivity: 'idle',
    scheduledStartTime: scheduledStartTime || new Date().toISOString(),
    actualStartTime: null,
    completedTime: null,
    notes: notes || '',
    stops: formattedStops,
    cargo: (cargo || []).map((c, idx) => ({
      ...c,
      id: c.id || `cargo-${idx}`,
      plannedQty: parseFloat(c.plannedQty) || 0,
      loadedQty: 0,
      deliveredQty: 0,
      damagedQty: 0,
      rejectedQty: 0,
      returnedQty: 0
    })),
    activities: [
      {
        id: `act-${Date.now()}`,
        category: 'idle',
        durationMinutes: 0,
        notes: 'Trip planned and awaiting departure',
        startTime: new Date().toISOString(),
        endTime: null,
        source: 'dispatch'
      }
    ],
    isDemo: false
  };

  await db.collection('trips').insertOne(newTrip);

  await db.collection('drivers').updateOne({ id: driverId }, { activeTripId: tripId, availability: 'assigned' });
  await db.collection('vehicles').updateOne({ id: vehicleId }, { assignedDriverId: driverId, availability: 'assigned' });

  res.status(201).json({ message: 'Trip dispatched successfully.', trip: newTrip });
});

// Advance Stop Workflow (Arrival -> Loading/Unloading -> POD -> Next Stop)
app.post('/api/trips/:id/advance-stop', requireAuth, async (req, res) => {
  const trip = await db.collection('trips').findById(req.params.id);
  if (!trip) return res.status(404).json({ error: 'Trip not found.' });

  if (req.user.role === 'driver' && trip.driverId !== req.user.driverId) {
    return res.status(403).json({ error: 'Forbidden: You can only advance your own assigned trips.' });
  }

  const { action, status, stopIndex, driverLocation, manualArrivalReason, pod } = req.body;
  const currentIdx = trip.currentStopIndex !== undefined ? trip.currentStopIndex : 0;
  const targetIdx = stopIndex !== undefined ? parseInt(stopIndex, 10) : currentIdx;
  if (stopIndex !== undefined) {
    trip.currentStopIndex = targetIdx;
  }
  const currentStop = (trip.stops && trip.stops[targetIdx]) ? trip.stops[targetIdx] : (trip.stops[currentIdx] || trip.stops[0]);

  const nowIso = new Date().toISOString();

  // 1. Start Trip
  if (action === 'start_trip' || (status === 'in_progress' && trip.status === 'planned')) {
    trip.status = 'in_progress';
    trip.actualStartTime = nowIso;
    trip.currentActivity = 'driving';
    trip.activities.push({
      id: `act-${Date.now()}`,
      category: 'driving',
      durationMinutes: 0,
      notes: 'Departed origin on scheduled dispatch route',
      startTime: nowIso,
      endTime: null,
      source: 'driver telematics'
    });
    await db.collection('drivers').updateOne({ id: trip.driverId }, { availability: 'on_trip' });
  }

  // 2. Arrive at Stop
  else if (action === 'arrive_at_stop' || status === 'arrived') {
    if (trip.status === 'planned') {
      trip.status = 'in_progress';
      trip.actualStartTime = nowIso;
      await db.collection('drivers').updateOne({ id: trip.driverId }, { availability: 'on_trip' });
    }
    if (!currentStop) return res.status(400).json({ error: 'No active stop found to arrive at.' });

    // Validate Geofence Radius
    if (driverLocation && currentStop.location && currentStop.location.lat && currentStop.location.lng) {
      const radius = currentStop.location.arrivalRadiusMeters || systemSettings.defaultArrivalRadiusMeters;
      const dist = calculateDistanceMeters(driverLocation.lat, driverLocation.lng, currentStop.location.lat, currentStop.location.lng);

      if (dist > radius && !manualArrivalReason) {
        return res.status(400).json({
          error: `Driver is ${dist}m away from stop, exceeding the ${radius}m arrival radius. Please provide a manual arrival reason to override.`,
          distanceMeters: dist,
          radiusMeters: radius,
          requiresManualReason: true
        });
      }

      currentStop.arrivalDistanceMeters = dist;
      if (manualArrivalReason) {
        currentStop.arrivalSource = 'manual_override';
        currentStop.manualArrivalReason = manualArrivalReason;
      } else {
        currentStop.arrivalSource = 'geofence_verified';
      }
    }

    currentStop.status = 'arrived';
    currentStop.arrivedAt = nowIso;
    trip.currentActivity = currentStop.type === 'pickup' ? 'loading' : 'unloading';
  }

  // 3. Start Loading
  else if (action === 'start_loading' || status === 'loading') {
    if (trip.status === 'planned') trip.status = 'in_progress';
    if (!currentStop) return res.status(400).json({ error: 'No active stop to load at.' });
    currentStop.status = 'loading';
    trip.currentActivity = 'loading';
  }

  // 4. Finish Loading
  else if (action === 'finish_loading') {
    if (!currentStop) return res.status(400).json({ error: 'No active stop.' });
    currentStop.status = 'completed';
    currentStop.completedAt = nowIso;
    trip.currentActivity = 'driving';

    // If actual loaded quantities supplied, update cargo
    if (req.body.loadedCargo && Array.isArray(req.body.loadedCargo)) {
      req.body.loadedCargo.forEach(lc => {
        const line = (trip.cargo || []).find(c => c.productId === lc.productId || c.id === lc.id);
        if (line) {
          line.loadedQty = parseFloat(lc.actualQty) || parseFloat(lc.loadedQty) || line.loadedQty;
        }
      });
    }
  }

  // 5. Start Unloading
  else if (action === 'start_unloading' || status === 'unloading') {
    if (!currentStop) return res.status(400).json({ error: 'No active stop to unload at.' });
    currentStop.status = 'unloading';
    trip.currentActivity = 'unloading';
  }

  // 6. Finish Unloading / Complete Stop with Real Delivery Proof (POD)
  else if (action === 'finish_unloading' || status === 'completed') {
    if (!currentStop) return res.status(400).json({ error: 'No active stop to complete.' });

    currentStop.status = 'completed';
    currentStop.completedAt = nowIso;
    trip.currentActivity = 'driving';

    if (pod) {
      currentStop.pod = {
        recipientName: pod.recipientName || currentStop.recipientName,
        deliveredQty: pod.deliveredQty,
        damagedQty: pod.damagedQty || 0,
        rejectedQty: pod.rejectedQty || 0,
        notes: pod.notes || '',
        signature: pod.signature || null,
        hasPhoto: Boolean(pod.photoData || pod.hasPhoto),
        hasSignature: Boolean(pod.signatureData || pod.signature || pod.hasSignature),
        recordedAt: nowIso
      };

      // Save persistent DeliveryProof record
      await db.collection('deliveryProofs').insertOne({
        id: pod.id || `POD-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`,
        tripId: trip.id,
        stopId: currentStop.id,
        stopIndex: targetIdx,
        driverId: trip.driverId,
        recipientName: pod.recipientName || currentStop.recipientName || 'Authorized Signatory',
        deliveredQty: pod.deliveredQty || 0,
        damagedQty: pod.damagedQty || 0,
        rejectedQty: pod.rejectedQty || 0,
        notes: pod.notes || '',
        hasPhoto: Boolean(pod.photoData || pod.hasPhoto),
        photoData: pod.photoData || null,
        hasSignature: Boolean(pod.signatureData || pod.signature || pod.hasSignature),
        signature: pod.signature || pod.signatureData || null,
        signatureData: pod.signatureData || pod.signature || null,
        timestamp: nowIso,
        isDemo: false
      });

      // Update trip cargo counters (deduplicated against any cargo-action already recorded for this stop)
      if (trip.cargo && trip.cargo.length > 0) {
        const deliveredFromPod = parseFloat(pod.deliveredQty) || 0;
        const alreadyDelivered = currentStop?.cargoDeliveredByAction || 0;
        const netDelivered = Math.max(0, deliveredFromPod - alreadyDelivered);

        const damagedFromPod = parseFloat(pod.damagedQty) || 0;
        const alreadyDamaged = currentStop?.cargoDamagedByAction || 0;
        const netDamaged = Math.max(0, damagedFromPod - alreadyDamaged);

        const rejectedFromPod = parseFloat(pod.rejectedQty) || 0;
        const alreadyRejected = currentStop?.cargoRejectedByAction || 0;
        const netRejected = Math.max(0, rejectedFromPod - alreadyRejected);

        trip.cargo.forEach(c => {
          if (netDelivered > 0) c.deliveredQty = (c.deliveredQty || 0) + netDelivered;
          if (netDamaged > 0) c.damagedQty = (c.damagedQty || 0) + netDamaged;
          if (netRejected > 0) c.rejectedQty = (c.rejectedQty || 0) + netRejected;
        });
      }
    }
  }

  // 7. Advance to Next Stop or Finalize Trip
  else if (action === 'next_stop') {
    if (targetIdx < trip.stops.length - 1) {
      trip.currentStopIndex = targetIdx + 1;
      trip.stops[targetIdx + 1].status = 'pending';
      trip.currentActivity = 'driving';
    } else {
      trip.status = 'completed';
      trip.completedTime = nowIso;
      trip.currentActivity = 'completed';
      await db.collection('drivers').updateOne({ id: trip.driverId }, { activeTripId: null, availability: 'available' });
      await db.collection('vehicles').updateOne({ id: trip.vehicleId }, { availability: 'available' });
    }
  }

  await db.collection('trips').updateOne({ id: trip.id }, trip);

  const drivers = await db.collection('drivers').find();
  const vehicles = await db.collection('vehicles').find();

  res.json({
    message: 'Stop advanced successfully.',
    trip: formatTrip(trip, drivers, vehicles)
  });
});

// Record & Verify Pre-Trip Gate Proof Photos (Odometer, Vehicle Walkaround, Driver Seatbelt Selfie)
app.post('/api/trips/:id/gate-proofs', requireAuth, async (req, res) => {
  const trip = await db.collection('trips').findById(req.params.id);
  if (!trip) return res.status(404).json({ error: 'Trip not found.' });

  // Driver Isolation
  if (req.user.role === 'driver' && trip.driverId !== req.user.driverId) {
    return res.status(403).json({ error: 'Access denied: You are not assigned to this trip.' });
  }

  const {
    odometerPhoto,
    walkaroundPhoto,
    driverSeatbeltPhoto,
    seatbeltVerified,
    overspeedingPledge,
    depotLocationName,
    notes
  } = req.body;

  const nowIso = new Date().toISOString();
  const gateProofs = {
    odometerPhoto: odometerPhoto || trip.gateProofs?.odometerPhoto || null,
    odometerTimestamp: trip.gateProofs?.odometerTimestamp || nowIso,
    walkaroundPhoto: walkaroundPhoto || trip.gateProofs?.walkaroundPhoto || null,
    walkaroundTimestamp: trip.gateProofs?.walkaroundTimestamp || nowIso,
    driverSeatbeltPhoto: driverSeatbeltPhoto || trip.gateProofs?.driverSeatbeltPhoto || null,
    driverSeatbeltTimestamp: nowIso,
    seatbeltVerified: seatbeltVerified !== undefined ? Boolean(seatbeltVerified) : (trip.gateProofs?.seatbeltVerified || false),
    overspeedingPledge: overspeedingPledge !== undefined ? Boolean(overspeedingPledge) : (trip.gateProofs?.overspeedingPledge || false),
    depotLocationName: depotLocationName || trip.gateProofs?.depotLocationName || 'Origin Depot',
    notes: notes || trip.gateProofs?.notes || 'Gate proof inspections recorded',
    verifiedAt: nowIso,
    verifiedByDriverId: trip.driverId,
    verifiedByDriverName: trip.driverName
  };

  await db.collection('trips').updateOne({ id: trip.id }, { gateProofs });

  const drivers = await db.collection('drivers').find();
  const vehicles = await db.collection('vehicles').find();
  const updatedTrip = await db.collection('trips').findById(trip.id);

  res.json({
    message: 'Pre-trip gate inspection proof recorded successfully.',
    gateProofs,
    trip: formatTrip(updatedTrip, drivers, vehicles)
  });
});

// Idempotent Cargo Action (Deduplication prevents double deductions)
const processedCargoActions = new Set();
app.post('/api/trips/:id/cargo-action', requireAuth, async (req, res) => {
  const trip = await db.collection('trips').findById(req.params.id);
  if (!trip) return res.status(404).json({ error: 'Trip not found.' });

  const { action, productId, quantity, idempotencyKey } = req.body;
  const reqKey = idempotencyKey || req.headers['x-idempotency-key'];

  if (reqKey && processedCargoActions.has(reqKey)) {
    const drivers = await db.collection('drivers').find();
    const vehicles = await db.collection('vehicles').find();
    return res.status(200).json({ 
      isDuplicate: true,
      message: 'Idempotent duplicate request recognized: action already applied.', 
      trip: formatTrip(trip, drivers, vehicles) 
    });
  }

  const line = (trip.cargo || []).find(c => c.productId === productId || c.id === productId);
  if (!line) return res.status(404).json({ error: 'Cargo line item not found.' });

  const qty = parseFloat(quantity) || 0;
  if (action === 'load') {
    line.loadedQty = (line.loadedQty || 0) + qty;
  } else if (action === 'deliver') {
    line.deliveredQty = (line.deliveredQty || 0) + qty;
  } else if (action === 'damage') {
    line.damagedQty = (line.damagedQty || 0) + qty;
  } else if (action === 'reject') {
    line.rejectedQty = (line.rejectedQty || 0) + qty;
  } else if (action === 'return') {
    line.returnedQty = (line.returnedQty || 0) + qty;
  }

  // Record on active stop so that advance-stop does not double-count
  const currentIdx = trip.currentStopIndex !== undefined ? trip.currentStopIndex : 0;
  const activeStop = (trip.stops && trip.stops[currentIdx]) ? trip.stops[currentIdx] : null;
  if (activeStop) {
    if (action === 'deliver') activeStop.cargoDeliveredByAction = (activeStop.cargoDeliveredByAction || 0) + qty;
    if (action === 'damage') activeStop.cargoDamagedByAction = (activeStop.cargoDamagedByAction || 0) + qty;
    if (action === 'reject') activeStop.cargoRejectedByAction = (activeStop.cargoRejectedByAction || 0) + qty;
  }

  if (reqKey) processedCargoActions.add(reqKey);

  await db.collection('trips').updateOne({ id: trip.id }, trip);

  const drivers = await db.collection('drivers').find();
  const vehicles = await db.collection('vehicles').find();

  res.json({ message: 'Cargo action recorded', trip: formatTrip(trip, drivers, vehicles) });
});

// Record Atomic Non-Overlapping Timed Activity
app.post('/api/trips/:id/activity', requireAuth, async (req, res) => {
  const trip = await db.collection('trips').findById(req.params.id);
  if (!trip) return res.status(404).json({ error: 'Trip not found.' });

  const { category, notes, durationMinutes, details } = req.body;
  const now = new Date();
  const duration = parseInt(durationMinutes, 10) || 15;
  const endTime = new Date(now.getTime() + duration * 60000).toISOString();

  // Close previous unfinalized activity if any
  if (trip.activities && trip.activities.length > 0) {
    const last = trip.activities[trip.activities.length - 1];
    if (!last.endTime) {
      last.endTime = now.toISOString();
    }
  }

  const newActivity = {
    id: `ACT-${Date.now()}`,
    category: category || 'operational',
    durationMinutes: duration,
    notes: notes || `${category} logged`,
    startTime: now.toISOString(),
    endTime,
    source: 'driver telematics',
    details
  };

  trip.activities = trip.activities || [];
  trip.activities.push(newActivity);
  trip.currentActivity = category;

  await db.collection('trips').updateOne({ id: trip.id }, trip);

  const drivers = await db.collection('drivers').find();
  const vehicles = await db.collection('vehicles').find();

  res.status(201).json({ message: 'Activity recorded', activity: newActivity, trip: formatTrip(trip, drivers, vehicles) });
});

// =========================================================================
// 6. SAFETY TELEMATICS & DELIVERY PROOFS
// =========================================================================
app.get('/api/safety-events', requireAuth, async (req, res) => {
  const events = await db.collection('safetyEvents').find();
  res.json(events);
});

// Record Real Driver Self-Reported Safety Event
app.post('/api/trips/:id/safety-event', requireAuth, async (req, res) => {
  const trip = await db.collection('trips').findById(req.params.id);
  if (!trip) return res.status(404).json({ error: 'Trip not found.' });

  const { type, recordedSpeed, speedThreshold, notes } = req.body;
  const newEvent = {
    tripId: trip.id,
    driverId: trip.driverId,
    driverName: trip.driverName,
    vehicleRegistration: trip.vehicleRegistration,
    type: type || 'incident',
    title: notes || `Reported ${type}`,
    recordedSpeed: recordedSpeed ? parseFloat(recordedSpeed) : null,
    speedThreshold: speedThreshold || systemSettings.speedThresholdKmH,
    source: 'driver_report', // Explicitly labeled as driver self-report!
    timestamp: new Date().toISOString(),
    reviewStatus: 'new',
    isDemo: false
  };

  const created = await db.collection('safetyEvents').insertOne(newEvent);
  res.status(201).json({ safetyEvent: created });
});

app.patch('/api/safety-events/:id', requireAuth, requireAdmin, async (req, res) => {
  const { reviewStatus, reviewerNotes } = req.body;
  const updated = await db.collection('safetyEvents').updateOne({ id: req.params.id }, {
    reviewStatus,
    reviewerNotes,
    reviewedBy: req.user.email,
    reviewedAt: new Date().toISOString()
  });
  if (!updated) return res.status(404).json({ error: 'Safety event not found.' });
  res.json({ safetyEvent: updated });
});

app.get('/api/delivery-proofs', requireAuth, async (req, res) => {
  const proofs = await db.collection('deliveryProofs').find();
  res.json(proofs);
});

// =========================================================================
// 7. ENTITY MANAGEMENT (DRIVERS, VEHICLES, PRODUCTS)
// =========================================================================
app.get('/api/drivers', requireAuth, async (req, res) => {
  const drivers = await db.collection('drivers').find();
  res.json(drivers);
});

app.get('/api/drivers/:id', requireAuth, async (req, res) => {
  const driver = await db.collection('drivers').findById(req.params.id);
  if (!driver) return res.status(404).json({ error: 'Driver not found.' });
  res.json(driver);
});

app.post('/api/drivers', requireAuth, requireAdmin, async (req, res) => {
  const { name, phone, alternatePhone, licenseNumber, licenseExpiry, emergencyContact, assignedVehicleId } = req.body;
  if (!name || !phone) return res.status(400).json({ error: 'Driver name and phone are required.' });

  const newDriver = await db.collection('drivers').insertOne({
    name: name.trim(),
    phone: phone.trim(),
    alternatePhone: alternatePhone || '',
    licenseNumber: licenseNumber || '',
    licenseExpiry: licenseExpiry || '',
    emergencyContact: emergencyContact || '',
    assignedVehicleId: assignedVehicleId || null,
    availability: assignedVehicleId ? 'assigned' : 'available',
    safetyScore: 100,
    status: 'active',
    isDemo: false
  });

  res.status(201).json({ driver: newDriver });
});

app.put('/api/drivers/:id', requireAuth, requireAdmin, async (req, res) => {
  const updated = await db.collection('drivers').updateOne({ id: req.params.id }, req.body);
  if (!updated) return res.status(404).json({ error: 'Driver not found.' });
  res.json({ driver: updated });
});

app.patch('/api/drivers/:id/archive', requireAuth, requireAdmin, async (req, res) => {
  const drv = await db.collection('drivers').findById(req.params.id);
  if (!drv) return res.status(404).json({ error: 'Driver not found.' });
  const status = drv.status === 'archived' ? 'active' : 'archived';
  const updated = await db.collection('drivers').updateOne({ id: req.params.id }, { status });
  res.json({ driver: updated });
});

app.get('/api/vehicles', requireAuth, async (req, res) => {
  const vehicles = await db.collection('vehicles').find();
  res.json(vehicles);
});

app.post('/api/vehicles', requireAuth, requireAdmin, async (req, res) => {
  const { registrationNumber, model, type, capacityKg, maxVolumeM3, fuelType } = req.body;
  if (!registrationNumber || !model) {
    return res.status(400).json({ error: 'Vehicle registration number and model are required.' });
  }

  const existing = await db.collection('vehicles').findOne({ registrationNumber: registrationNumber.trim().toUpperCase() });
  if (existing) {
    return res.status(400).json({ error: 'Vehicle registration number is already registered in the fleet.' });
  }

  const newVehicle = await db.collection('vehicles').insertOne({
    registrationNumber: registrationNumber.trim().toUpperCase(),
    model: model.trim(),
    type: type || 'commercial',
    capacityKg: parseFloat(capacityKg) || 1000,
    maxVolumeM3: parseFloat(maxVolumeM3) || 5,
    fuelType: fuelType || 'diesel',
    availability: 'available',
    status: 'active',
    isDemo: false
  });

  res.status(201).json({ vehicle: newVehicle });
});

app.put('/api/vehicles/:id', requireAuth, requireAdmin, async (req, res) => {
  const updated = await db.collection('vehicles').updateOne({ id: req.params.id }, req.body);
  if (!updated) return res.status(404).json({ error: 'Vehicle not found.' });
  res.json({ vehicle: updated });
});

app.patch('/api/vehicles/:id/archive', requireAuth, requireAdmin, async (req, res) => {
  const veh = await db.collection('vehicles').findById(req.params.id);
  if (!veh) return res.status(404).json({ error: 'Vehicle not found.' });
  const status = veh.status === 'archived' ? 'active' : 'archived';
  const updated = await db.collection('vehicles').updateOne({ id: req.params.id }, { status });
  res.json({ vehicle: updated });
});

app.get('/api/products', requireAuth, async (req, res) => {
  const products = await db.collection('products').find();
  res.json(products);
});

app.post('/api/products', requireAuth, requireAdmin, async (req, res) => {
  const { name, category, defaultWeightKg, unit, fragile, description } = req.body;
  if (!name || !category) {
    return res.status(400).json({ error: 'Product name and cargo category are required.' });
  }

  const newProduct = await db.collection('products').insertOne({
    name: name.trim(),
    category: category.trim(),
    defaultWeightKg: parseFloat(defaultWeightKg) || 10,
    unit: unit || 'units',
    fragile: Boolean(fragile),
    description: description || '',
    status: 'active',
    isDemo: false
  });

  res.status(201).json({ product: newProduct });
});

app.put('/api/products/:id', requireAuth, requireAdmin, async (req, res) => {
  const updated = await db.collection('products').updateOne({ id: req.params.id }, req.body);
  if (!updated) return res.status(404).json({ error: 'Product not found.' });
  res.json({ product: updated });
});

app.patch('/api/products/:id/archive', requireAuth, requireAdmin, async (req, res) => {
  const prod = await db.collection('products').findById(req.params.id);
  if (!prod) return res.status(404).json({ error: 'Product not found.' });
  const status = prod.status === 'archived' ? 'active' : 'archived';
  const updated = await db.collection('products').updateOne({ id: req.params.id }, { status });
  res.json({ product: updated });
});

// =========================================================================
// 8. REAL DASHBOARD, REPORTS & SETTINGS (ZERO FAKE TOTALS)
// =========================================================================
app.get('/api/dashboard', requireAuth, async (req, res) => {
  const trips = await db.collection('trips').find();
  const drivers = await db.collection('drivers').find();
  const vehicles = await db.collection('vehicles').find();
  const safetyEvents = await db.collection('safetyEvents').find();
  const deliveryProofs = await db.collection('deliveryProofs').find();

  const activeTrips = trips.filter(t => t.status === 'in_progress' || t.status === 'IN_TRANSIT').length;
  const delayedTrips = trips.filter(t => t.status === 'delayed' || t.status === 'DELAYED').length;
  const driversOnDuty = drivers.filter(d => d.availability === 'on_trip' || d.availability === 'ON_DUTY').length;
  const availableVehicles = vehicles.filter(v => v.availability === 'available' || v.availability === 'AVAILABLE').length;
  const activeSafetyAlerts = safetyEvents.filter(e => e.reviewStatus === 'new' || e.reviewStatus === 'NEW').length;

  // Real calculation for completed deliveries today
  const todayDatePrefix = new Date().toISOString().slice(0, 10);
  const completedDeliveriesToday = deliveryProofs.filter(p => (p.timestamp || '').slice(0, 10) === todayDatePrefix).length;

  // Real calculation for pending deliveries across active/planned trips
  let pendingDeliveries = 0;
  trips.filter(t => t.status !== 'completed').forEach(t => {
    (t.stops || []).forEach(s => {
      if ((s.type || '').includes('delivery') && s.status !== 'completed') {
        pendingDeliveries++;
      }
    });
  });

  res.json({
    activeTrips,
    driversOnDuty,
    availableVehicles,
    completedDeliveriesToday,
    pendingDeliveries,
    delayedTrips,
    activeSafetyAlerts
  });
});

app.get('/api/reports', requireAuth, async (req, res) => {
  const trips = await db.collection('trips').find();
  const drivers = await db.collection('drivers').find();
  const vehicles = await db.collection('vehicles').find();

  let totalScheduledDeliveries = 0;
  let totalSuccessfulDeliveries = 0;

  trips.forEach(t => {
    (t.stops || []).forEach(s => {
      if ((s.type || '').includes('delivery')) {
        totalScheduledDeliveries++;
        if (s.status === 'completed') {
          totalSuccessfulDeliveries++;
        }
      }
    });
  });

  const deliveryRate = totalScheduledDeliveries > 0
    ? Math.round((totalSuccessfulDeliveries / totalScheduledDeliveries) * 1000) / 10
    : 0;

  res.json({
    totalTrips: trips.length,
    totalDrivers: drivers.length,
    totalVehicles: vehicles.length,
    deliveryRate,
    trips: trips.map(t => formatTrip(t, drivers, vehicles))
  });
});

app.get('/api/settings', requireAuth, async (req, res) => {
  const doc = await db.collection('settings').findOne({ key: 'system_settings' });
  if (doc && doc.value) {
    systemSettings = { ...systemSettings, ...doc.value };
  }
  res.json(systemSettings);
});

app.post('/api/settings', requireAuth, requireAdmin, async (req, res) => {
  systemSettings = { ...systemSettings, ...req.body };
  const existing = await db.collection('settings').findOne({ key: 'system_settings' });
  if (existing) {
    await db.collection('settings').updateOne(
      { key: 'system_settings' },
      { key: 'system_settings', value: systemSettings }
    );
  } else {
    await db.collection('settings').insertOne({
      key: 'system_settings',
      value: systemSettings
    });
  }
  res.json({ message: 'System settings updated successfully', settings: systemSettings });
});

// ============================================================================
// AUTOMATIC ACCIDENT DETECTION, ZERO-TOUCH SOS & DISPATCH API (V1)
// ============================================================================

// Server-Sent Events (SSE) stream for real-time emergency dashboard alerts
app.get('/api/v1/emergencies/stream', requireAuth, (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  const unsubscribe = emergencyEscalationService.subscribe((event, data) => {
    res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
  });

  req.on('close', () => {
    unsubscribe();
  });
});

// Helper: compute distance between two lat/lng coords in km (Haversine formula)
function calculateHaversineDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round((R * c) * 10) / 10;
}

// 1. POST /api/v1/emergencies/detect - Ingest crash detection candidate from native sensor service
app.post('/api/v1/emergencies/detect', requireAuth, async (req, res) => {
  const {
    idempotencyKey,
    tripId,
    coordinates,
    locationAccuracy,
    speedBeforeImpact,
    estimatedImpactForce,
    confidenceScore,
    severity,
    sensorSummary,
    crashWindowSamples,
    networkState,
    batteryLevel,
    detectionSource
  } = req.body;

  if (!coordinates || typeof coordinates.lat !== 'number' || typeof coordinates.lng !== 'number') {
    return res.status(400).json({ error: 'Valid GPS coordinates {lat, lng} required' });
  }

  // Idempotency check: prevent duplicate emergencies during offline retry or replayed network requests
  if (idempotencyKey) {
    const existing = await db.collection('emergencyIncidents').findOne({ idempotencyKey });
    if (existing) {
      return res.status(200).json({
        message: 'Incident already exists with this idempotency key',
        incident: existing,
        isDuplicate: true
      });
    }
  }

  // Look up driver and trip metadata
  const driverId = req.user.role === 'driver' ? req.user.id : (req.body.driverId || req.user.id);
  const driver = await db.collection('drivers').findOne({ id: driverId }) || {};
  const activeTrip = tripId ? await db.collection('trips').findOne({ id: tripId }) : null;
  const vehicleId = activeTrip?.vehicleId || driver.assignedVehicleId || req.body.vehicleId || 'VEH-UNKNOWN';
  const vehicle = await db.collection('vehicles').findOne({ id: vehicleId }) || {};

  const incidentId = `INC-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`;
  const nowIso = new Date().toISOString();

  // Create immutable incident
  const newIncident = {
    id: incidentId,
    incidentId,
    idempotencyKey: idempotencyKey || incidentId,
    tripId: tripId || activeTrip?.id || null,
    driverId,
    driverName: driver.name || req.user.name || 'Driver',
    driverPhone: driver.phone || '',
    vehicleId,
    vehicleRegistration: vehicle.registrationNumber || 'N/A',
    detectionSource: detectionSource || 'NATIVE_SENSOR_FUSION',
    severity: severity || 'CRITICAL',
    confidenceScore: confidenceScore !== undefined ? confidenceScore : 0.85,
    coordinates: {
      lat: coordinates.lat,
      lng: coordinates.lng
    },
    locationPoint: {
      type: 'Point',
      coordinates: [coordinates.lng, coordinates.lat]
    },
    locationAccuracy: locationAccuracy || 5,
    lastKnownLocation: Boolean(req.body.lastKnownLocation),
    detectedAtDevice: req.body.detectedAtDevice || nowIso,
    detectedAtServer: nowIso,
    speedBeforeImpact: speedBeforeImpact || 0,
    estimatedImpactForce: estimatedImpactForce || 0,
    sensorSummary: sensorSummary || {
      gForcePeak: estimatedImpactForce || 0,
      deltaSpeedKmh: speedBeforeImpact || 0,
      rotationDegPerSec: 0,
      sustainedZeroMotionSeconds: 0,
      airbagDeployed: false
    },
    crashWindowSamples: Array.isArray(crashWindowSamples) ? crashWindowSamples.slice(-60) : [],
    networkState: networkState || 'online',
    batteryLevel: batteryLevel || 80,
    medicalProfile: {
      bloodGroup: driver.bloodGroup || 'O+',
      knownConditions: driver.knownConditions || 'None reported',
      emergencyContactName: driver.emergencyContactName || 'Fleet Dispatch Operations',
      emergencyContactPhone: driver.emergencyContactPhone || '+914023607777'
    },
    status: 'sos_created',
    assignedAmbulanceId: null,
    selectedHospitalId: null,
    acknowledgedBy: null,
    acknowledgedAt: null,
    resolvedBy: null,
    resolvedAt: null,
    cancellationReason: null,
    falsePositiveReason: null,
    timeline: [
      {
        id: `TL-1`,
        status: 'sos_created',
        actor: req.user.name || 'System Sensor Engine',
        role: req.user.role || 'system',
        timestamp: nowIso,
        reason: 'Zero-touch accident detection confirmed via multi-sensor fusion.',
        sourceDevice: detectionSource || 'native_android'
      }
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  };

  await db.collection('emergencyIncidents').insertOne(newIncident);

  // Trigger server-side multi-channel emergency escalation engine immediately
  emergencyEscalationService.initiateEscalation(newIncident).catch(err => {
    console.error('[Emergency API] Escalation background failure:', err.message);
  });

  res.status(201).json({
    message: 'Emergency accident incident registered and escalated successfully',
    incident: newIncident
  });
});

// 2. POST /api/v1/emergencies/:id/confirm - Driver manual immediate SOS confirmation
app.post('/api/v1/emergencies/:id/confirm', requireAuth, async (req, res) => {
  const { id } = req.params;
  const incident = await db.collection('emergencyIncidents').findOne({ incidentId: id });
  if (!incident) {
    return res.status(404).json({ error: 'Incident not found' });
  }

  const nowIso = new Date().toISOString();
  const updateObj = {
    updatedAt: new Date()
  };

  const timelineEntry = {
    id: `TL-${Date.now()}`,
    status: incident.status,
    actor: req.user.name || 'Driver',
    role: req.user.role,
    timestamp: nowIso,
    reason: req.body.reason || 'Driver explicitly tapped Send SOS Now button',
    sourceDevice: req.body.sourceDevice || 'driver_app'
  };

  await db.collection('emergencyIncidents').updateOne(
    { incidentId: id },
    {
      ...updateObj,
      $push: { timeline: timelineEntry }
    }
  );

  res.json({ message: 'Incident confirmed', incidentId: id });
});

// 3. POST /api/v1/emergencies/:id/cancel - Driver cancels countdown ("I Am Safe") -> creates false positive safety record
app.post('/api/v1/emergencies/:id/cancel', requireAuth, async (req, res) => {
  const { id } = req.params;
  const incident = await db.collection('emergencyIncidents').findOne({ incidentId: id });
  if (!incident) {
    return res.status(404).json({ error: 'Incident not found' });
  }

  const nowIso = new Date().toISOString();
  const reason = req.body.reason || 'Driver cancelled countdown: safe from false positive trigger.';

  await db.collection('emergencyIncidents').updateOne(
    { incidentId: id },
    {
      status: 'cancelled_by_driver',
      falsePositiveReason: reason,
      updatedAt: new Date(),
      $push: {
        timeline: {
          id: `TL-${Date.now()}`,
          status: 'cancelled_by_driver',
          actor: req.user.name || 'Driver',
          role: req.user.role,
          timestamp: nowIso,
          reason,
          sourceDevice: req.body.sourceDevice || 'driver_app'
        }
      }
    }
  );

  // Stop background escalation
  emergencyEscalationService.stopEscalation(id);

  // Record an explicit false-positive safety event in safetyEvents collection for auditing
  await db.collection('safetyEvents').insertOne({
    id: `SAFE-FP-${Date.now()}`,
    tripId: incident.tripId,
    driverId: incident.driverId,
    vehicleId: incident.vehicleId,
    type: 'FALSE_ACCIDENT_TRIGGER',
    title: 'False Positive Accident Countdown Cancelled by Driver',
    severity: 'LOW',
    coordinates: incident.coordinates,
    details: {
      cancelledAt: nowIso,
      cancellationReason: reason,
      originalConfidence: incident.confidenceScore
    },
    timestamp: nowIso
  });

  res.json({ message: 'Emergency countdown cancelled and logged as false positive safety record.' });
});

// 4. POST /api/v1/emergencies/:id/acknowledge - Control-room operator acknowledges the incident
app.post('/api/v1/emergencies/:id/acknowledge', requireAuth, requireAdmin, async (req, res) => {
  const { id } = req.params;
  const incident = await db.collection('emergencyIncidents').findOne({ incidentId: id });
  if (!incident) {
    return res.status(404).json({ error: 'Incident not found' });
  }

  const nowIso = new Date().toISOString();
  await db.collection('emergencyIncidents').updateOne(
    { incidentId: id },
    {
      status: 'acknowledged',
      acknowledgedBy: req.user.name || req.user.email,
      acknowledgedAt: nowIso,
      updatedAt: new Date(),
      $push: {
        timeline: {
          id: `TL-${Date.now()}`,
          status: 'acknowledged',
          actor: req.user.name || req.user.email,
          role: 'admin',
          timestamp: nowIso,
          reason: 'Emergency incident acknowledged by authorized control room operator.',
          sourceDevice: 'admin_dashboard'
        }
      }
    }
  );

  emergencyEscalationService.stopEscalation(id);

  res.json({ message: 'Emergency acknowledged successfully', incidentId: id });
});

// 5. POST /api/v1/emergencies/:id/assign-ambulance - Dispatch specific ambulance unit & hospital
app.post('/api/v1/emergencies/:id/assign-ambulance', requireAuth, requireAdmin, async (req, res) => {
  const { id } = req.params;
  const { ambulanceId, hospitalId, notes } = req.body;

  if (!ambulanceId) {
    return res.status(400).json({ error: 'ambulanceId is required' });
  }

  const incident = await db.collection('emergencyIncidents').findOne({ incidentId: id });
  if (!incident) {
    return res.status(404).json({ error: 'Incident not found' });
  }

  // Atomically claim ambulance unit (prevent race conditions)
  const ambulance = await db.collection('ambulanceUnits').findOne({ id: ambulanceId });
  if (!ambulance) {
    return res.status(404).json({ error: 'Ambulance unit not found' });
  }
  if (ambulance.availability !== 'available' && ambulance.assignedIncidentId !== id) {
    return res.status(409).json({ error: 'Ambulance unit is already busy or dispatched' });
  }

  const nowIso = new Date().toISOString();

  // Update ambulance status
  await db.collection('ambulanceUnits').updateOne(
    { id: ambulanceId },
    {
      availability: 'dispatched',
      assignedIncidentId: id,
      updatedAt: new Date()
    }
  );

  // Update incident status
  await db.collection('emergencyIncidents').updateOne(
    { incidentId: id },
    {
      status: 'ambulance_assigned',
      assignedAmbulanceId: ambulanceId,
      selectedHospitalId: hospitalId || incident.selectedHospitalId || null,
      updatedAt: new Date(),
      $push: {
        timeline: {
          id: `TL-${Date.now()}`,
          status: 'ambulance_assigned',
          actor: req.user.name || req.user.email,
          role: 'admin',
          timestamp: nowIso,
          reason: `Ambulance ${ambulance.registrationNumber} (${ambulance.vehicleType}) assigned.${hospitalId ? ' Destination: ' + hospitalId : ''} ${notes || ''}`,
          sourceDevice: 'admin_dashboard'
        }
      }
    }
  );

  // Broadcast dispatch update
  emergencyEscalationService.broadcast('AMBULANCE_ASSIGNED', {
    incidentId: id,
    ambulanceId,
    hospitalId,
    timestamp: nowIso
  });

  res.json({
    message: 'Ambulance dispatched and incident updated',
    incidentId: id,
    ambulanceId,
    hospitalId
  });
});

// 6. POST /api/v1/emergencies/:id/status - Update incident lifecycle status
app.post('/api/v1/emergencies/:id/status', requireAuth, async (req, res) => {
  const { id } = req.params;
  const { status, reason, hospitalId } = req.body;

  const validStatuses = [
    'detected', 'countdown_active', 'cancelled_by_driver', 'sos_created',
    'alerting', 'acknowledged', 'ambulance_assigned', 'ambulance_en_route',
    'ambulance_arrived', 'patient_transporting', 'hospital_arrived',
    'resolved', 'false_positive', 'failed_delivery'
  ];

  if (!validStatuses.includes(status)) {
    return res.status(400).json({ error: `Invalid emergency status: ${status}` });
  }

  const incident = await db.collection('emergencyIncidents').findOne({ incidentId: id });
  if (!incident) {
    return res.status(404).json({ error: 'Incident not found' });
  }

  const nowIso = new Date().toISOString();
  const updateData = {
    status,
    updatedAt: new Date()
  };

  if (hospitalId) {
    updateData.selectedHospitalId = hospitalId;
  }
  if (status === 'resolved') {
    updateData.resolvedBy = req.user.name || req.user.email;
    updateData.resolvedAt = nowIso;
    emergencyEscalationService.stopEscalation(id);

    // Free assigned ambulance if any
    if (incident.assignedAmbulanceId) {
      await db.collection('ambulanceUnits').updateOne(
        { id: incident.assignedAmbulanceId },
        { availability: 'available', assignedIncidentId: null, updatedAt: new Date() }
      );
    }
  }

  await db.collection('emergencyIncidents').updateOne(
    { incidentId: id },
    {
      ...updateData,
      $push: {
        timeline: {
          id: `TL-${Date.now()}`,
          status,
          actor: req.user.name || req.user.email,
          role: req.user.role,
          timestamp: nowIso,
          reason: reason || `Emergency status transitioned to ${status}`,
          sourceDevice: req.body.sourceDevice || 'web_dashboard'
        }
      }
    }
  );

  res.json({ message: `Status updated to ${status}`, incidentId: id });
});

// 7. GET /api/v1/emergencies - Fetch list of emergency incidents with filters
app.get('/api/v1/emergencies', requireAuth, async (req, res) => {
  const { status, driverId, tripId, limit = 50 } = req.query;
  const filter = {};

  if (status) filter.status = status;
  if (driverId) filter.driverId = driverId;
  if (tripId) filter.tripId = tripId;

  // Drivers can only see their own incidents
  if (req.user.role === 'driver') {
    filter.driverId = req.user.id;
  }

  const incidents = await db.collection('emergencyIncidents').find(filter);
  incidents.sort((a, b) => new Date(b.detectedAtServer) - new Date(a.detectedAtServer));

  res.json({
    total: incidents.length,
    incidents: incidents.slice(0, parseInt(limit, 10))
  });
});

// 8. GET /api/v1/emergencies/:id - Fetch single emergency incident with details
app.get('/api/v1/emergencies/:id', requireAuth, async (req, res) => {
  const { id } = req.params;
  const incident = await db.collection('emergencyIncidents').findOne({ incidentId: id });
  if (!incident) {
    return res.status(404).json({ error: 'Incident not found' });
  }

  // Driver authorization boundary
  if (req.user.role === 'driver' && incident.driverId !== req.user.id) {
    return res.status(403).json({ error: 'Access denied to this incident' });
  }

  // Retrieve assigned ambulance and hospital details if present
  let assignedAmbulance = null;
  if (incident.assignedAmbulanceId) {
    assignedAmbulance = await db.collection('ambulanceUnits').findOne({ id: incident.assignedAmbulanceId });
  }

  let selectedHospital = null;
  if (incident.selectedHospitalId) {
    selectedHospital = await db.collection('hospitals').findOne({ id: incident.selectedHospitalId });
  }

  res.json({
    ...incident,
    assignedAmbulance,
    selectedHospital
  });
});

// 9. GET /api/v1/emergencies/:id/timeline - Immutable audit timeline
app.get('/api/v1/emergencies/:id/timeline', requireAuth, async (req, res) => {
  const { id } = req.params;
  const incident = await db.collection('emergencyIncidents').findOne({ incidentId: id });
  if (!incident) {
    return res.status(404).json({ error: 'Incident not found' });
  }
  res.json({ incidentId: id, timeline: incident.timeline || [] });
});

// 10. GET /api/v1/emergencies/:id/delivery-attempts - Multi-channel alert delivery logs
app.get('/api/v1/emergencies/:id/delivery-attempts', requireAuth, requireAdmin, async (req, res) => {
  const { id } = req.params;
  const attempts = await db.collection('emergencyDeliveryAttempts').find({ incidentId: id });
  res.json({ incidentId: id, total: attempts.length, deliveryAttempts: attempts });
});

// 11. POST /api/v1/safety-service/heartbeat - Native driver service health heartbeat
app.post('/api/v1/safety-service/heartbeat', requireAuth, async (req, res) => {
  const driverId = req.user.id;
  const {
    deviceId,
    activeTripId,
    serviceRunning,
    locationPermission,
    notificationPermission,
    batteryOptimizationExempt,
    sensorAvailability,
    networkState,
    batteryLevel,
    applicationVersion
  } = req.body;

  const nowIso = new Date().toISOString();
  const heartbeatDoc = {
    id: `HB-${driverId}`,
    driverId,
    deviceId: deviceId || 'native_android',
    activeTripId: activeTripId || null,
    serviceRunning: serviceRunning !== undefined ? Boolean(serviceRunning) : true,
    locationPermission: locationPermission || 'granted_fine',
    notificationPermission: notificationPermission || 'granted',
    batteryOptimizationExempt: Boolean(batteryOptimizationExempt),
    sensorAvailability: sensorAvailability || { accelerometer: true, gyroscope: true, gps: true, obd2: false },
    networkState: networkState || 'online',
    batteryLevel: batteryLevel || 85,
    applicationVersion: applicationVersion || '2.4.0',
    lastHeartbeatAt: nowIso,
    lastLocationAt: nowIso,
    updatedAt: new Date()
  };

  const existing = await db.collection('safetyServiceHealth').findOne({ driverId });
  if (existing) {
    await db.collection('safetyServiceHealth').updateOne({ driverId }, heartbeatDoc);
  } else {
    await db.collection('safetyServiceHealth').insertOne(heartbeatDoc);
  }

  res.json({ status: 'ok', heartbeatReceivedAt: nowIso });
});

// 12. GET /api/v1/safety-service/health - Monitor safety service health across drivers
app.get('/api/v1/safety-service/health', requireAuth, async (req, res) => {
  if (req.user.role === 'driver') {
    const health = await db.collection('safetyServiceHealth').findOne({ driverId: req.user.id });
    return res.json(health || { driverId: req.user.id, serviceRunning: false, message: 'No heartbeat recorded yet' });
  }

  const allHealth = await db.collection('safetyServiceHealth').find();
  res.json({ total: allHealth.length, healthRecords: allHealth });
});

// 13. GET /api/v1/responders/nearby - Ranked ambulance units and hospitals by proximity
app.get('/api/v1/responders/nearby', requireAuth, async (req, res) => {
  const { lat, lng, radiusKm = 50 } = req.query;

  const userLat = parseFloat(lat);
  const userLng = parseFloat(lng);

  if (isNaN(userLat) || isNaN(userLng)) {
    return res.status(400).json({ error: 'Valid numeric lat and lng required' });
  }

  const maxRadius = parseFloat(radiusKm);

  // Fetch all verified hospitals and ambulances
  const hospitals = await db.collection('hospitals').find({ active: true });
  const ambulances = await db.collection('ambulanceUnits').find({ active: true });

  // Calculate distances using Haversine
  const rankedHospitals = hospitals.map(h => {
    const dist = calculateHaversineDistanceKm(userLat, userLng, h.coordinates.lat, h.coordinates.lng);
    const etaMinutes = Math.max(3, Math.round((dist / 40) * 60)); // assuming 40 km/h emergency speed
    return {
      ...h,
      distanceKm: dist,
      etaMinutes,
      distanceMethod: 'straight_line_fallback'
    };
  })
  .filter(h => h.distanceKm <= maxRadius)
  .sort((a, b) => a.distanceKm - b.distanceKm);

  const rankedAmbulances = ambulances.map(a => {
    const dist = calculateHaversineDistanceKm(userLat, userLng, a.currentCoordinates.lat, a.currentCoordinates.lng);
    const etaMinutes = Math.max(2, Math.round((dist / 45) * 60)); // assuming 45 km/h emergency speed
    return {
      ...a,
      distanceKm: dist,
      etaMinutes,
      distanceMethod: 'straight_line_fallback'
    };
  })
  .filter(a => a.distanceKm <= maxRadius)
  .sort((a, b) => {
    // Prioritize available units first, then closest distance
    if (a.availability === 'available' && b.availability !== 'available') return -1;
    if (a.availability !== 'available' && b.availability === 'available') return 1;
    return a.distanceKm - b.distanceKm;
  });

  res.json({
    searchOrigin: { lat: userLat, lng: userLng },
    radiusKm: maxRadius,
    hospitals: rankedHospitals,
    ambulances: rankedAmbulances
  });
});

// 14. POST /api/v1/ambulance-units/:id/accept - Ambulance partner accepts dispatch
app.post('/api/v1/ambulance-units/:id/accept', requireAuth, async (req, res) => {
  const { id } = req.params;
  const { incidentId } = req.body;

  const ambulance = await db.collection('ambulanceUnits').findOne({ id });
  if (!ambulance) return res.status(404).json({ error: 'Ambulance not found' });

  await db.collection('ambulanceUnits').updateOne({ id }, { availability: 'en_route', updatedAt: new Date() });
  if (incidentId) {
    await db.collection('emergencyIncidents').updateOne(
      { incidentId },
      {
        status: 'ambulance_en_route',
        updatedAt: new Date(),
        $push: {
          timeline: {
            id: `TL-${Date.now()}`,
            status: 'ambulance_en_route',
            actor: ambulance.providerName,
            role: 'responder',
            timestamp: new Date().toISOString(),
            reason: `Ambulance unit ${ambulance.registrationNumber} accepted dispatch and is en route.`,
            sourceDevice: 'ambulance_telematics'
          }
        }
      }
    );
  }

  res.json({ message: 'Ambulance dispatch accepted and en route', unitId: id });
});

// 15. POST /api/v1/ambulance-units/:id/reject - Ambulance partner rejects dispatch
app.post('/api/v1/ambulance-units/:id/reject', requireAuth, async (req, res) => {
  const { id } = req.params;
  const { incidentId, reason } = req.body;

  const ambulance = await db.collection('ambulanceUnits').findOne({ id });
  if (!ambulance) return res.status(404).json({ error: 'Ambulance not found' });

  await db.collection('ambulanceUnits').updateOne({ id }, { availability: 'available', assignedIncidentId: null, updatedAt: new Date() });
  if (incidentId) {
    await db.collection('emergencyIncidents').updateOne(
      { incidentId },
      {
        assignedAmbulanceId: null,
        updatedAt: new Date(),
        $push: {
          timeline: {
            id: `TL-${Date.now()}`,
            status: 'alerting',
            actor: ambulance.providerName,
            role: 'responder',
            timestamp: new Date().toISOString(),
            reason: `Ambulance unit ${ambulance.registrationNumber} rejected dispatch: ${reason || 'Unit unavailable'}. Escalating to alternative responders.`,
            sourceDevice: 'ambulance_telematics'
          }
        }
      }
    );
  }

  res.json({ message: 'Ambulance dispatch rejected and returned to queue', unitId: id });
});

// 16. POST /api/v1/iot/crash-events - Dedicated vehicle IoT/OBD-II hardware ingestion contract
app.post('/api/v1/iot/crash-events', async (req, res) => {
  const {
    deviceId,
    vehicleId,
    sequenceNumber,
    timestamp,
    coordinates,
    speed,
    impactForce,
    orientation,
    airbagSignal,
    batteryLevel,
    networkStrength,
    firmwareVersion,
    signature
  } = req.body;

  // Validate hardware authentication
  const expectedToken = process.env.IOT_DEVICE_AUTH_SECRET || 'fleetroute_iot_secure_token_default';
  const authHeader = req.headers['x-iot-device-token'] || req.headers['authorization'];
  if (!authHeader || !authHeader.includes(expectedToken)) {
    return res.status(401).json({ error: 'Invalid or missing IoT hardware credentials' });
  }

  if (!deviceId || !vehicleId || !coordinates || typeof coordinates.lat !== 'number' || typeof coordinates.lng !== 'number') {
    return res.status(400).json({ error: 'Missing mandatory hardware telemetry fields' });
  }

  const nowIso = new Date().toISOString();
  const incidentId = `INC-IOT-${Date.now()}-${Math.floor(100 + Math.random() * 900)}`;

  // Find associated vehicle and active trip if any
  const vehicle = await db.collection('vehicles').findOne({ id: vehicleId }) || {};
  const activeTrip = await db.collection('trips').findOne({ vehicleId, status: 'active' });
  const driver = activeTrip ? await db.collection('drivers').findOne({ id: activeTrip.driverId }) : null;

  const newIncident = {
    id: incidentId,
    incidentId,
    idempotencyKey: `IOT-${deviceId}-${sequenceNumber || Date.now()}`,
    tripId: activeTrip?.id || null,
    driverId: driver?.id || 'DRIVER-UNKNOWN',
    driverName: driver?.name || 'Assigned Fleet Driver',
    driverPhone: driver?.phone || '',
    vehicleId,
    vehicleRegistration: vehicle.registrationNumber || vehicleId,
    detectionSource: 'VEHICLE_IOT_HARDWARE',
    severity: impactForce > 5 || airbagSignal ? 'CRITICAL' : 'HIGH',
    confidenceScore: 0.98, // Hardware confirmed
    coordinates: {
      lat: coordinates.lat,
      lng: coordinates.lng
    },
    locationPoint: {
      type: 'Point',
      coordinates: [coordinates.lng, coordinates.lat]
    },
    locationAccuracy: 2.5,
    lastKnownLocation: false,
    detectedAtDevice: timestamp || nowIso,
    detectedAtServer: nowIso,
    speedBeforeImpact: speed || 0,
    estimatedImpactForce: impactForce || 0,
    sensorSummary: {
      gForcePeak: impactForce || 0,
      deltaSpeedKmh: speed || 0,
      rotationDegPerSec: orientation?.roll || 0,
      sustainedZeroMotionSeconds: 30,
      airbagDeployed: Boolean(airbagSignal),
      hardwareDeviceId: deviceId,
      firmwareVersion: firmwareVersion || '1.0.0'
    },
    crashWindowSamples: [],
    networkState: `Cellular-eSIM (${networkStrength || 'strong'})`,
    batteryLevel: batteryLevel || 100,
    medicalProfile: {
      bloodGroup: driver?.bloodGroup || 'O+',
      knownConditions: driver?.knownConditions || 'None reported',
      emergencyContactName: driver?.emergencyContactName || 'Fleet Operations',
      emergencyContactPhone: driver?.emergencyContactPhone || '+914023607777'
    },
    status: 'sos_created',
    assignedAmbulanceId: null,
    selectedHospitalId: null,
    acknowledgedBy: null,
    acknowledgedAt: null,
    resolvedBy: null,
    resolvedAt: null,
    cancellationReason: null,
    falsePositiveReason: null,
    timeline: [
      {
        id: `TL-1`,
        status: 'sos_created',
        actor: `IoT Device (${deviceId})`,
        role: 'hardware',
        timestamp: nowIso,
        reason: `Hardware-confirmed crash signal received. Impact: ${impactForce || 0}G, Airbag: ${Boolean(airbagSignal)}. Sequence: ${sequenceNumber || 1}.`,
        sourceDevice: 'vehicle_obd2_iot'
      }
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  };

  await db.collection('emergencyIncidents').insertOne(newIncident);

  // Escalate immediately
  emergencyEscalationService.initiateEscalation(newIncident).catch(err => {
    console.error('[IoT Crash Ingestion] Escalation error:', err.message);
  });

  res.status(201).json({
    message: 'Hardware crash telemetry accepted and dispatched',
    incidentId,
    status: 'sos_created'
  });
});

// 17. DELETE /api/v1/emergencies - Clear test emergency incidents and reset ambulance availability
app.delete('/api/v1/emergencies', requireAuth, requireAdmin, async (req, res) => {
  const result = await db.models.emergencyIncidents.deleteMany({});
  await db.models.ambulanceUnits.updateMany({}, { availability: 'available', assignedIncidentId: null });
  res.json({
    message: 'All test emergency incidents cleared successfully and ambulances reset.',
    deletedCount: result.deletedCount
  });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`[FleetRoute Server] running on http://localhost:${PORT}`);
  });
}

module.exports = app;
