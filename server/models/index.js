// server/models/index.js
// Production MongoDB Mongoose Schemas & Models for FleetRoute
// STRICTLY ZERO EMOJIS.

const mongoose = require('mongoose');

// 1. User Model
const UserSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  email: { type: String, lowercase: true, trim: true },
  phone: { type: String, trim: true, index: true },
  name: { type: String, required: true },
  role: { type: String, enum: ['admin', 'driver'], default: 'driver', required: true },
  status: { type: String, enum: ['active', 'disabled'], default: 'active' },
  driverId: { type: String, default: null },
  tokenVersion: { type: Number, default: 0 },
  mustChangePassword: { type: Boolean, default: false },
  passwordHash: { type: String, required: true },
  isDemo: { type: Boolean, default: false, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});
UserSchema.index({ email: 1 }, { unique: true, sparse: true });
UserSchema.index(
  { driverId: 1 },
  { unique: true, partialFilterExpression: { driverId: { $type: 'string' }, role: 'driver' } }
);

// 2. Driver Model
const DriverSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  name: { type: String, required: true },
  phone: { type: String, required: true },
  alternatePhone: { type: String, default: '' },
  avatar: { type: String, default: null },
  licenseNumber: { type: String, default: '' },
  licenseExpiry: { type: String, default: '' },
  assignedVehicleId: { type: String, default: null },
  availability: { type: String, default: 'available' },
  emergencyContact: { type: String, default: '' },
  safetyScore: { type: Number, default: 100 },
  activeTripId: { type: String, default: null },
  completedTripsCount: { type: Number, default: 0 },
  currentLocation: { type: mongoose.Schema.Types.Mixed, default: null },
  lastLocation: { type: mongoose.Schema.Types.Mixed, default: null },
  lastSampleTimestamp: { type: String, default: null },
  lastLocationUpdate: { type: String, default: null },
  status: { type: String, enum: ['active', 'archived'], default: 'active' },
  isDemo: { type: Boolean, default: false, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// 3. Vehicle Model
const VehicleSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  registrationNumber: { type: String, required: true, unique: true, index: true },
  model: { type: String, required: true },
  type: { type: String, default: 'commercial' },
  capacityKg: { type: Number, default: 1000 },
  maxVolumeM3: { type: Number, default: 5 },
  availability: { type: String, default: 'available' },
  assignedDriverId: { type: String, default: null },
  fuelType: { type: String, default: 'diesel' },
  status: { type: String, enum: ['active', 'archived'], default: 'active' },
  isDemo: { type: Boolean, default: false, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// 4. Product Model
const ProductSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  name: { type: String, required: true },
  category: { type: String, required: true },
  defaultWeightKg: { type: Number, default: 1 },
  defaultVolumeM3: { type: Number, default: 0.05 },
  unit: { type: String, default: 'units' },
  fragile: { type: Boolean, default: false },
  description: { type: String, default: '' },
  status: { type: String, enum: ['active', 'archived'], default: 'active' },
  isDemo: { type: Boolean, default: false, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// 5. Location Model
const LocationSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  name: { type: String, required: true },
  address: { type: String, required: true },
  landmark: { type: String, default: '' },
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  type: { type: String, default: 'delivery' },
  arrivalRadiusMeters: { type: Number, default: 150 },
  contactPerson: { type: String, default: '' },
  contactNumber: { type: String, default: '' },
  contactName: { type: String, default: '' },
  contactPhone: { type: String, default: '' },
  instructions: { type: String, default: '' },
  status: { type: String, enum: ['active', 'archived'], default: 'active' },
  isDemo: { type: Boolean, default: false, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// 6. Trip Model
const TripSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  driverId: { type: String, default: null, index: true },
  driverName: { type: String, default: '' },
  vehicleId: { type: String, default: null },
  vehicleRegistration: { type: String, default: '' },
  status: { type: String, default: 'planned', index: true },
  currentStopIndex: { type: Number, default: 0 },
  currentLocation: { type: mongoose.Schema.Types.Mixed, default: null },
  currentSpeed: { type: Number, default: 0 },
  currentActivity: { type: String, default: 'idle' },
  scheduledStartTime: { type: String, default: null },
  actualStartTime: { type: String, default: null },
  completedTime: { type: String, default: null },
  notes: { type: String, default: '' },
  stops: { type: Array, default: [] },
  cargo: { type: Array, default: [] },
  activities: { type: Array, default: [] },
  gateProofs: { type: mongoose.Schema.Types.Mixed, default: null },
  processedCargoActionKeys: [{ type: String }],
  operationVersion: { type: Number, default: 0 },
  isDemo: { type: Boolean, default: false, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// 7. Safety Event Model
const SafetyEventSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  tripId: { type: String, default: null, index: true },
  driverId: { type: String, default: null, index: true },
  driverName: { type: String, default: '' },
  vehicleRegistration: { type: String, default: '' },
  type: { type: String, required: true },
  title: { type: String, default: '' },
  recordedSpeed: { type: Number, default: null },
  speedThreshold: { type: Number, default: null },
  durationSeconds: { type: Number, default: null },
  location: { type: String, default: '' },
  timestamp: { type: String, default: () => new Date().toISOString() },
  source: { type: String, default: 'live_telematics' },
  reviewStatus: { type: String, enum: ['new', 'under_review', 'resolved', 'dismissed'], default: 'new', index: true },
  reviewerNotes: { type: String, default: '' },
  reviewedBy: { type: String, default: null },
  reviewedAt: { type: String, default: null },
  isDemo: { type: Boolean, default: false, index: true },
  createdAt: { type: Date, default: Date.now }
});

// 8. Delivery Proof Model
const DeliveryProofSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  tripId: { type: String, required: true, index: true },
  stopId: { type: String, required: true },
  stopIndex: { type: Number, default: 0, index: true },
  driverId: { type: String, default: null },
  recipientName: { type: String, required: true },
  deliveredQty: { type: Number, default: 0 },
  damagedQty: { type: Number, default: 0 },
  rejectedQty: { type: Number, default: 0 },
  notes: { type: String, default: '' },
  hasPhoto: { type: Boolean, default: false },
  photoData: { type: String, default: null },
  hasSignature: { type: Boolean, default: false },
  signature: { type: String, default: null },
  signatureData: { type: String, default: null },
  timestamp: { type: String, default: () => new Date().toISOString() },
  isDemo: { type: Boolean, default: false, index: true },
  createdAt: { type: Date, default: Date.now }
});

// 9. Location Sample Telematics Model
const LocationSampleSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  driverId: { type: String, required: true, index: true },
  tripId: { type: String, default: null },
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  accuracy: { type: Number, default: null },
  speed: { type: Number, default: null },
  heading: { type: Number, default: null },
  deviceTimestamp: { type: String, required: true },
  serverReceivedTimestamp: { type: String, default: () => new Date().toISOString() },
  source: { type: String, default: 'live_gps' },
  createdAt: { type: Date, default: Date.now }
});

// 10. System Settings Model
const SystemSettingSchema = new mongoose.Schema({
  key: { type: String, required: true, unique: true, index: true },
  value: { type: mongoose.Schema.Types.Mixed, required: true },
  updatedAt: { type: Date, default: Date.now }
});

// 11. Emergency Incident Model (Automatic Accident & Zero-Touch SOS)
const EmergencyIncidentSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  incidentId: { type: String, index: true },
  idempotencyKey: { type: String, index: true },
  tripId: { type: String, default: null, index: true },
  driverId: { type: String, required: true, index: true },
  driverName: { type: String, default: '' },
  driverPhone: { type: String, default: '' },
  vehicleId: { type: String, default: null, index: true },
  vehicleRegistration: { type: String, default: '' },
  detectionSource: { 
    type: String, 
    default: 'sensor_fusion',
    index: true
  },
  severity: { 
    type: String, 
    default: 'high',
    index: true
  },
  confidenceScore: { type: Number, default: 0.85 }, // 0.0 to 1.0
  confidenceLevel: { 
    type: String, 
    enum: ['low', 'medium', 'high', 'confirmed_by_hardware'],
    default: 'high'
  },
  status: {
    type: String,
    enum: [
      'detected',
      'countdown_active',
      'cancelled_by_driver',
      'sos_created',
      'alerting',
      'acknowledged',
      'ambulance_assigned',
      'ambulance_en_route',
      'ambulance_arrived',
      'patient_transporting',
      'hospital_arrived',
      'resolved',
      'false_positive',
      'failed_delivery'
    ],
    default: 'sos_created',
    index: true
  },
  coordinates: {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true }
  },
  // GeoJSON field for 2dsphere indexing
  locationPoint: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] } // [lng, lat]
  },
  locationAccuracy: { type: Number, default: null },
  isLastKnownLocation: { type: Boolean, default: false },
  lastKnownLocationTimestamp: { type: String, default: null },
  detectedAtDevice: { type: String, required: true },
  detectedAtServer: { type: String, default: () => new Date().toISOString() },
  speedBeforeImpact: { type: Number, default: 0 }, // in km/h
  estimatedImpactForce: { type: Number, default: 0 }, // in G-force
  suddenDeceleration: { type: Number, default: 0 }, // in m/s^2 or km/h drop
  sensorSummary: { type: mongoose.Schema.Types.Mixed, default: {} },
  crashWindowSamples: { type: Array, default: [] }, // 60s pre/post impact buffer samples
  crashWindowReference: { type: String, default: null },
  networkState: { type: String, default: 'online' },
  batteryLevel: { type: Number, default: null },
  medicalProfile: {
    bloodGroup: { type: String, default: 'Unknown' },
    medicalConditions: { type: String, default: 'None reported' },
    allergies: { type: String, default: 'None reported' }
  },
  emergencyContactsNotified: { type: Array, default: [] },
  assignedAmbulanceId: { type: String, default: null, index: true },
  selectedHospitalId: { type: String, default: null, index: true },
  assignedAmbulance: { type: mongoose.Schema.Types.Mixed, default: null },
  selectedHospital: { type: mongoose.Schema.Types.Mixed, default: null },
  acknowledgedBy: { type: String, default: null },
  acknowledgedAt: { type: String, default: null },
  resolvedBy: { type: String, default: null },
  resolvedAt: { type: String, default: null },
  resolutionNotes: { type: String, default: '' },
  cancellationReason: { type: String, default: null },
  falsePositiveReason: { type: String, default: null },
  timeline: [{
    action: { type: String, default: 'status_transition' },
    status: { type: String },
    fromStatus: { type: String },
    toStatus: { type: String },
    actor: { type: String, required: true },
    role: { type: String, default: 'system' },
    timestamp: { type: String, default: () => new Date().toISOString() },
    reason: { type: String, default: '' },
    sourceDevice: { type: String, default: 'native_sensor_fusion' },
    metadata: { type: mongoose.Schema.Types.Mixed, default: {} }
  }],
  isTestMode: { type: Boolean, default: false, index: true },
  isDemo: { type: Boolean, default: false, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

EmergencyIncidentSchema.index({ locationPoint: '2dsphere' });

// 12. Emergency Delivery Attempt Model
const EmergencyDeliveryAttemptSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  incidentId: { type: String, required: true, index: true },
  channel: { 
    type: String, 
    enum: ['dashboard_websocket', 'sms', 'automated_voice_call', 'push_notification', 'email', 'ambulance_partner_api', 'hospital_partner_api', 'official_112_psap'], 
    required: true,
    index: true
  },
  provider: { type: String, default: 'unconfigured' },
  recipientType: { 
    type: String, 
    enum: ['dispatch_control_room', 'emergency_contact', 'ambulance_unit', 'partner_hospital', 'supervisor'],
    required: true 
  },
  recipientReference: { type: String, required: true },
  status: { 
    type: String, 
    enum: ['pending', 'submitted', 'sent', 'delivered', 'acknowledged', 'failed'],
    default: 'pending',
    index: true
  },
  providerMessageId: { type: String, default: null },
  failureCode: { type: String, default: null },
  failureMessage: { type: String, default: null },
  attemptNumber: { type: Number, default: 1 },
  sentAt: { type: String, default: null },
  deliveredAt: { type: String, default: null },
  acknowledgedAt: { type: String, default: null },
  createdAt: { type: Date, default: Date.now }
});

// 13. Emergency Contact Model
const EmergencyContactSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  driverId: { type: String, required: true, index: true },
  name: { type: String, required: true },
  relationship: { type: String, default: 'Family' },
  phone: { type: String, required: true },
  priority: { type: Number, default: 1 }, // 1 = primary, 2 = secondary
  smsEnabled: { type: Boolean, default: true },
  voiceEnabled: { type: Boolean, default: true },
  verified: { type: Boolean, default: true },
  verifiedAt: { type: String, default: () => new Date().toISOString() },
  status: { type: String, enum: ['active', 'archived'], default: 'active' },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// 14. Partner Hospital Model
const HospitalSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  legalName: { type: String, required: true },
  coordinates: {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true }
  },
  locationPoint: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] }
  },
  address: { type: String, required: true },
  verifiedPhoneNumbers: [{ type: String }],
  emergencyCapabilities: [{ type: String }], // e.g. ['trauma_level_1', 'icu', 'burn_unit', 'neurosurgery', 'blood_bank']
  operatingStatus: { type: String, enum: ['open_24x7', 'capacity_full', 'diverting', 'maintenance'], default: 'open_24x7' },
  integrationType: { type: String, enum: ['direct_webhook', 'email_telecom', 'manual_control_room', 'none'], default: 'manual_control_room' },
  APIConfigurationReference: { type: String, default: null },
  serviceRadiusKm: { type: Number, default: 35 },
  verified: { type: Boolean, default: true },
  active: { type: Boolean, default: true, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});
HospitalSchema.index({ locationPoint: '2dsphere' });

// 15. Partner Ambulance Unit Model
const AmbulanceUnitSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  providerId: { type: String, required: true, index: true },
  providerName: { type: String, required: true },
  registrationNumber: { type: String, required: true, unique: true, index: true },
  vehicleType: { type: String, enum: ['ALS', 'BLS', 'PatientTransport', 'AirAmbulance'], default: 'ALS' }, // Advanced Life Support
  capabilities: [{ type: String }], // ['ventilator', 'defibrillator', 'oxygen', 'paramedic_staff']
  currentCoordinates: {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true }
  },
  locationPoint: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] }
  },
  availability: { type: String, enum: ['available', 'dispatched', 'en_route', 'busy', 'off_duty'], default: 'available', index: true },
  contactPhone: { type: String, required: true },
  assignedIncidentId: { type: String, default: null, index: true },
  lastTelemetryAt: { type: String, default: () => new Date().toISOString() },
  active: { type: Boolean, default: true, index: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});
AmbulanceUnitSchema.index({ locationPoint: '2dsphere' });

// 16. Driver Safety Service Health Heartbeat Model
const SafetyServiceHealthSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  driverId: { type: String, required: true, index: true },
  deviceId: { type: String, default: 'native_device' },
  activeTripId: { type: String, default: null, index: true },
  serviceRunning: { type: Boolean, default: true },
  locationPermission: { type: String, enum: ['granted_fine', 'granted_coarse', 'denied', 'prompt'], default: 'granted_fine' },
  notificationPermission: { type: String, enum: ['granted', 'denied', 'prompt'], default: 'granted' },
  batteryOptimizationExempt: { type: Boolean, default: false },
  sensorAvailability: {
    accelerometer: { type: Boolean, default: true },
    gyroscope: { type: Boolean, default: true },
    gps: { type: Boolean, default: true },
    obd2: { type: Boolean, default: false }
  },
  networkState: { type: String, default: 'online' },
  batteryLevel: { type: Number, default: 85 },
  applicationVersion: { type: String, default: '2.4.0' },
  lastHeartbeatAt: { type: String, default: () => new Date().toISOString() },
  lastLocationAt: { type: String, default: () => new Date().toISOString() },
  updatedAt: { type: Date, default: Date.now }
});

// Export Mongoose Models (reuse existing model if already registered)
const User = mongoose.models.User || mongoose.model('User', UserSchema);
const Driver = mongoose.models.Driver || mongoose.model('Driver', DriverSchema);
const Vehicle = mongoose.models.Vehicle || mongoose.model('Vehicle', VehicleSchema);
const Product = mongoose.models.Product || mongoose.model('Product', ProductSchema);
const Location = mongoose.models.Location || mongoose.model('Location', LocationSchema);
const Trip = mongoose.models.Trip || mongoose.model('Trip', TripSchema);
const SafetyEvent = mongoose.models.SafetyEvent || mongoose.model('SafetyEvent', SafetyEventSchema);
const DeliveryProof = mongoose.models.DeliveryProof || mongoose.model('DeliveryProof', DeliveryProofSchema);
const LocationSample = mongoose.models.LocationSample || mongoose.model('LocationSample', LocationSampleSchema);
const SystemSetting = mongoose.models.SystemSetting || mongoose.model('SystemSetting', SystemSettingSchema);
const EmergencyIncident = mongoose.models.EmergencyIncident || mongoose.model('EmergencyIncident', EmergencyIncidentSchema);
const EmergencyDeliveryAttempt = mongoose.models.EmergencyDeliveryAttempt || mongoose.model('EmergencyDeliveryAttempt', EmergencyDeliveryAttemptSchema);
const EmergencyContact = mongoose.models.EmergencyContact || mongoose.model('EmergencyContact', EmergencyContactSchema);
const Hospital = mongoose.models.Hospital || mongoose.model('Hospital', HospitalSchema);
const AmbulanceUnit = mongoose.models.AmbulanceUnit || mongoose.model('AmbulanceUnit', AmbulanceUnitSchema);
const SafetyServiceHealth = mongoose.models.SafetyServiceHealth || mongoose.model('SafetyServiceHealth', SafetyServiceHealthSchema);

module.exports = {
  User,
  Driver,
  Vehicle,
  Product,
  Location,
  Trip,
  SafetyEvent,
  DeliveryProof,
  LocationSample,
  SystemSetting,
  EmergencyIncident,
  EmergencyDeliveryAttempt,
  EmergencyContact,
  Hospital,
  AmbulanceUnit,
  SafetyServiceHealth
};
