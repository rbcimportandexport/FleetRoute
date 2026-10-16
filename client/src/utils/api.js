const getApiBase = () => {
  const configuredBase = import.meta.env.VITE_API_BASE_URL?.trim().replace(/\/+$/, '');

  if (typeof window !== 'undefined') {
    const isCapacitor = window.Capacitor !== undefined || 
                        window.location.origin.includes('capacitor://') || 
                        (window.location.hostname === 'localhost' && !window.location.port);
    if (isCapacitor) {
      const runtimeBase = localStorage.getItem('fleetroute_api_base_url')?.trim().replace(/\/+$/, '');
      return configuredBase || runtimeBase || null;
    }
  }
  return configuredBase || '/api';
};

const API_BASE = getApiBase();
const EMBEDDED_ACCESS = import.meta.env.VITE_EMBEDDED_ACCESS === 'true';
const UI_ONLY_MODE = import.meta.env.VITE_UI_ONLY_MODE === 'true';

// Collection endpoints have historically been returned both as a bare array and
// inside an object (for example, `{ trips: [...] }`).  Normalize those shapes at
// the API boundary so view components never receive an object and then fail on
// array operations such as `.filter()` or `.map()`.
const normalizeCollection = (payload, collectionKeys) => {
  if (Array.isArray(payload)) return payload;
  const keys = Array.isArray(collectionKeys) ? collectionKeys : [collectionKeys];
  for (const key of keys) {
    if (Array.isArray(payload?.[key])) return payload[key];
  }
  if (Array.isArray(payload?.data)) return payload.data;
  for (const key of keys) {
    if (Array.isArray(payload?.data?.[key])) return payload.data[key];
  }
  return [];
};

class ApiService {
  constructor() {
    this.token = this.loadToken();
    this.currentUser = this.loadUser();
    this.offlineQueue = this.loadQueue();
    this.isOnline = typeof navigator !== 'undefined' ? navigator.onLine : true;

    if (typeof window !== 'undefined') {
      try {
        ['fleetroute_demo_mode', 'fleetroute_mock_trips', 'fleetroute_demo_data', 'fleetroute_sim_state'].forEach(k => {
          localStorage.removeItem(k);
        });
      } catch {}

      window.addEventListener('online', () => {
        this.isOnline = true;
        this.flushQueue();
      });
      window.addEventListener('offline', () => {
        this.isOnline = false;
      });
    }
  }

  loadToken() {
    try {
      return localStorage.getItem('fleetroute_jwt_token') || null;
    } catch {
      return null;
    }
  }

  loadUser() {
    try {
      const data = localStorage.getItem('fleetroute_current_user');
      return data ? JSON.parse(data) : null;
    } catch {
      return null;
    }
  }

  setSession(token, user) {
    this.token = token;
    this.currentUser = user;
    try {
      if (token) localStorage.setItem('fleetroute_jwt_token', token);
      else localStorage.removeItem('fleetroute_jwt_token');

      if (user) localStorage.setItem('fleetroute_current_user', JSON.stringify(user));
      else localStorage.removeItem('fleetroute_current_user');
    } catch {
      // Storage can be unavailable in private/restricted browser contexts.
    }
    this.offlineQueue = this.loadQueue(user);
  }

  clearSession() {
    this.setSession(null, null);
  }

  getQueueStorageKey(user = this.currentUser) {
    return user?.id ? `fleetroute_offline_queue:${user.id}` : null;
  }

  loadQueue(user = this.currentUser) {
    try {
      // Remove the former cross-account queue. It cannot be safely attributed.
      localStorage.removeItem('fleetroute_offline_queue');
      const key = this.getQueueStorageKey(user);
      if (!key) return [];
      const data = localStorage.getItem(key);
      const parsed = data ? JSON.parse(data) : [];
      return Array.isArray(parsed) ? parsed.filter(item => item?.userId === user.id) : [];
    } catch {
      return [];
    }
  }

  saveQueue() {
    try {
      const key = this.getQueueStorageKey();
      if (key) localStorage.setItem(key, JSON.stringify(this.offlineQueue));
    } catch {
      // Storage can be unavailable in private/restricted browser contexts.
    }
  }

  async request(endpoint, options = {}) {
    if (UI_ONLY_MODE) {
      const method = (options.method || 'GET').toUpperCase();
      if (method === 'GET') {
        if (endpoint === '/dashboard') {
          return {
            activeTrips: 0,
            driversOnDuty: 0,
            completedDeliveriesToday: 0,
            pendingDeliveries: 0,
            safetyAlerts: 0
          };
        }
        if (endpoint === '/settings' || endpoint === '/reports') return {};
        if (endpoint.startsWith('/v1/emergencies')) return { incidents: [], timeline: [], deliveryAttempts: [], total: 0 };
        if (endpoint.startsWith('/v1/responders/nearby')) return { ambulances: [], hospitals: [] };
        if (endpoint.startsWith('/v1/safety-service/health')) return { healthRecords: [], total: 0 };
        return [];
      }

      const error = new Error('UI-only showcase: database operations are intentionally disabled.');
      error.code = 'UI_ONLY_MODE';
      throw error;
    }

    if (!API_BASE) {
      throw new Error('API endpoint is not configured for this device. Set VITE_API_BASE_URL to the production HTTPS /api URL.');
    }

    const { queueOffline = false, ...fetchOptions } = options;
    const url = `${API_BASE}${endpoint}`;
    const headers = {
      'Content-Type': 'application/json',
      ...(this.token ? { 'Authorization': `Bearer ${this.token}` } : {}),
      ...(fetchOptions.headers || {})
    };

    try {
      const res = await fetch(url, { ...fetchOptions, headers });
      const data = await res.json().catch(() => ({}));

      if (!res.ok) {
        if (res.status === 401 && endpoint !== '/auth/login') {
          this.clearSession();
          if (typeof window !== 'undefined') {
            window.dispatchEvent(new CustomEvent('fleetroute:unauthorized'));
          }
        }
        const error = new Error(data.error || data.message || `HTTP error ${res.status}`);
        error.status = res.status;
        error.code = data.code || 'HTTP_ERROR';
        throw error;
      }
      return data;
    } catch (err) {
      const isMutation = fetchOptions.method && fetchOptions.method !== 'GET';
      const canQueue = queueOffline && isMutation && !this.isOnline && this.currentUser?.id;
      if (canQueue) {
        const operationId = fetchOptions.headers?.['X-Idempotency-Key'] || crypto.randomUUID();
        const queuedItem = {
          id: operationId,
          operationId,
          userId: this.currentUser.id,
          endpoint,
          options: fetchOptions,
          queuedAt: new Date().toISOString(),
          status: 'pending',
          attempts: 0
        };
        this.offlineQueue.push(queuedItem);
        this.saveQueue();
        return { success: false, queued: true, syncStatus: 'pending', operationId };
      }
      throw err;
    }
  }

  async flushQueue() {
    if (!API_BASE || !this.currentUser?.id || this.offlineQueue.length === 0) return;
    const userId = this.currentUser.id;
    for (const item of [...this.offlineQueue]) {
      if (item.userId !== userId || item.status !== 'pending') continue;
      try {
        const response = await fetch(`${API_BASE}${item.endpoint}`, {
          ...item.options,
          headers: {
            'Content-Type': 'application/json',
            ...(this.token ? { 'Authorization': `Bearer ${this.token}` } : {}),
            ...(item.options.headers || {}),
            'X-Queued-Request-Id': item.id,
            'X-Idempotency-Key': item.operationId
          }
        });
        if (response.ok) {
          this.offlineQueue = this.offlineQueue.filter(queued => queued.id !== item.id);
          this.saveQueue();
          continue;
        }
        item.attempts += 1;
        item.lastAttemptAt = new Date().toISOString();
        item.lastError = `HTTP ${response.status}`;
        if (response.status >= 400 && response.status < 500 && response.status !== 408 && response.status !== 429) {
          item.status = 'failed';
        }
        this.saveQueue();
        break;
      } catch (error) {
        item.attempts += 1;
        item.lastAttemptAt = new Date().toISOString();
        item.lastError = error.message;
        this.saveQueue();
        break;
      }
    }
  }

  // --- Auth & Profile ---
  get isUiOnlyMode() {
    return UI_ONLY_MODE;
  }

  get isEmbeddedAccess() {
    return EMBEDDED_ACCESS;
  }

  async startEmbeddedSession() {
    if (!EMBEDDED_ACCESS) {
      throw new Error('Direct embedded access is not configured for this deployment.');
    }
    const data = await this.request('/auth/embedded-session', { method: 'POST' });
    if (!data.token || !data.user) {
      throw new Error('The server did not create an embedded access session.');
    }
    this.setSession(data.token, data.user);
    return data;
  }

  async login(identifier, password) {
    const data = await this.request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ identifier, password })
    });
    if (data.token && data.user) {
      this.setSession(data.token, data.user);
    }
    return data;
  }

  logout() {
    this.clearSession();
  }

  getProfile() {
    return this.request('/auth/me');
  }

  changePassword(currentPassword, newPassword) {
    return this.request('/auth/change-password', {
      method: 'POST',
      body: JSON.stringify({ currentPassword, newPassword })
    });
  }

  async getUsers() {
    return normalizeCollection(await this.request('/auth/users'), ['users', 'accounts']);
  }

  createUser(payload) {
    return this.request('/auth/users', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  updateUser(id, payload) {
    return this.request(`/auth/users/${id}`, {
      method: 'PUT',
      body: JSON.stringify(payload)
    });
  }

  autoProvisionDriverAccounts() {
    return this.request('/auth/users/auto-provision', {
      method: 'POST'
    });
  }

  updateUserStatus(id, status) {
    return this.request(`/auth/users/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status })
    });
  }

  // --- Locations & Geocoding ---
  async getLocations(activeOnly = false) {
    return normalizeCollection(
      await this.request(`/locations${activeOnly ? '?activeOnly=true' : ''}`),
      'locations'
    );
  }

  createLocation(payload) {
    return this.request('/locations', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  updateLocation(id, payload) {
    return this.request(`/locations/${id}`, {
      method: 'PUT',
      body: JSON.stringify(payload)
    });
  }

  archiveLocation(id) {
    return this.request(`/locations/${id}/archive`, {
      method: 'PATCH'
    });
  }

  searchAddress(q) {
    return this.request(`/geocode/search?q=${encodeURIComponent(q)}`);
  }

  reverseGeocode(lat, lng) {
    return this.request(`/geocode/reverse?lat=${lat}&lng=${lng}`);
  }

  // --- Live Telemetry & Location Sharing ---
  sendLocationSample(sample) {
    return this.request('/telemetry/location', {
      method: 'POST',
      body: JSON.stringify(sample),
      queueOffline: true
    });
  }

  async getFleetTelemetry() {
    return normalizeCollection(await this.request('/telemetry/drivers'), ['drivers', 'fleet']);
  }

  // --- Trips & Multi-Stop Dispatch ---
  async getTrips() {
    return normalizeCollection(await this.request('/trips'), 'trips');
  }

  getTrip(id) {
    return this.request(`/trips/${id}`);
  }

  createTrip(payload) {
    return this.request('/trips', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  advanceStop(tripId, payload) {
    return this.request(`/trips/${tripId}/advance-stop`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  updateTripGateProofs(tripId, payload) {
    return this.request(`/trips/${tripId}/gate-proofs`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  closeTripException(tripId, payload) {
    return this.request(`/trips/${tripId}/close-exception`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  cargoAction(tripId, payload) {
    const idempotencyKey = payload.idempotencyKey || crypto.randomUUID();
    return this.request(`/trips/${tripId}/cargo-action`, {
      method: 'POST',
      headers: { 'X-Idempotency-Key': idempotencyKey },
      body: JSON.stringify({ ...payload, idempotencyKey }),
      queueOffline: true
    });
  }

  recordActivity(tripId, payload) {
    return this.request(`/trips/${tripId}/activity`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  createSafetyEvent(tripId, payload) {
    return this.request(`/trips/${tripId}/safety-event`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  // --- Entities: Drivers, Vehicles, Products ---
  async getDrivers() {
    return normalizeCollection(await this.request('/drivers'), 'drivers');
  }

  createDriver(payload) {
    return this.request('/drivers', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  updateDriver(id, payload) {
    return this.request(`/drivers/${id}`, {
      method: 'PUT',
      body: JSON.stringify(payload)
    });
  }

  archiveDriver(id) {
    return this.request(`/drivers/${id}/archive`, {
      method: 'PATCH'
    });
  }

  async getVehicles() {
    return normalizeCollection(await this.request('/vehicles'), 'vehicles');
  }

  createVehicle(payload) {
    return this.request('/vehicles', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  updateVehicle(id, payload) {
    return this.request(`/vehicles/${id}`, {
      method: 'PUT',
      body: JSON.stringify(payload)
    });
  }

  archiveVehicle(id) {
    return this.request(`/vehicles/${id}/archive`, {
      method: 'PATCH'
    });
  }

  async getProducts() {
    return normalizeCollection(await this.request('/products'), 'products');
  }

  createProduct(payload) {
    return this.request('/products', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  updateProduct(id, payload) {
    return this.request(`/products/${id}`, {
      method: 'PUT',
      body: JSON.stringify(payload)
    });
  }

  archiveProduct(id) {
    return this.request(`/products/${id}/archive`, {
      method: 'PATCH'
    });
  }

  // --- Safety Events & Deliveries ---
  async getSafetyEvents() {
    return normalizeCollection(await this.request('/safety-events'), ['events', 'safetyEvents']);
  }

  updateSafetyEvent(id, payload) {
    return this.request(`/safety-events/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload)
    });
  }

  async getDeliveryProofs() {
    return normalizeCollection(await this.request('/delivery-proofs'), ['proofs', 'deliveryProofs']);
  }

  // --- Dashboard, Settings, Reset ---
  getDashboard() {
    return this.request('/dashboard');
  }

  getReports() {
    return this.request('/reports');
  }

  getSettings() {
    return this.request('/settings');
  }

  updateSettings(payload) {
    return this.request('/settings', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  // --- Emergency Response & Zero-Touch Dispatch API ---
  detectEmergency(payload) {
    const idempotencyKey = payload.idempotencyKey || crypto.randomUUID();
    return this.request('/v1/emergencies/detect', {
      method: 'POST',
      headers: { 'X-Idempotency-Key': idempotencyKey },
      body: JSON.stringify({ ...payload, idempotencyKey }),
      queueOffline: true
    });
  }

  confirmEmergency(id, payload = {}) {
    return this.request(`/v1/emergencies/${id}/confirm`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  cancelEmergency(id, payload = {}) {
    return this.request(`/v1/emergencies/${id}/cancel`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  acknowledgeEmergency(id) {
    return this.request(`/v1/emergencies/${id}/acknowledge`, {
      method: 'POST'
    });
  }

  assignAmbulance(id, payload) {
    return this.request(`/v1/emergencies/${id}/assign-ambulance`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  updateEmergencyStatus(id, payload) {
    return this.request(`/v1/emergencies/${id}/status`, {
      method: 'POST',
      body: JSON.stringify(payload)
    });
  }

  getEmergencies(params = {}) {
    const query = new URLSearchParams(params).toString();
    return this.request(`/v1/emergencies${query ? '?' + query : ''}`);
  }

  clearEmergencies() {
    return this.request('/v1/emergencies', {
      method: 'DELETE'
    });
  }

  getEmergency(id) {
    return this.request(`/v1/emergencies/${id}`);
  }

  getEmergencyTimeline(id) {
    return this.request(`/v1/emergencies/${id}/timeline`);
  }

  getEmergencyDeliveryAttempts(id) {
    return this.request(`/v1/emergencies/${id}/delivery-attempts`);
  }

  getNearbyResponders(lat, lng, radiusKm = 50) {
    return this.request(`/v1/responders/nearby?lat=${lat}&lng=${lng}&radiusKm=${radiusKm}`);
  }

  sendSafetyHeartbeat(payload) {
    return this.request('/v1/safety-service/heartbeat', {
      method: 'POST',
      body: JSON.stringify(payload),
      queueOffline: true
    });
  }

  getSafetyHealth() {
    return this.request('/v1/safety-service/health');
  }

  getHealth() {
    return this.request('/health');
  }
}

export const api = new ApiService();
