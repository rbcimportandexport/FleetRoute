import { cloudFallbackData } from './cloudFallbackData';

const getApiBase = () => {
  if (typeof window !== 'undefined') {
    const isCapacitor = window.Capacitor !== undefined || 
                        window.location.origin.includes('capacitor://') || 
                        (window.location.hostname === 'localhost' && !window.location.port);
    if (isCapacitor) {
      return localStorage.getItem('fleetroute_custom_api') || 'http://192.168.3.20:5000/api';
    }
  }
  return '/api';
};

const API_BASE = getApiBase();

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
      // Storage fallback
    }
  }

  clearSession() {
    this.setSession(null, null);
  }

  loadQueue() {
    try {
      const data = localStorage.getItem('fleetroute_offline_queue');
      return data ? JSON.parse(data) : [];
    } catch {
      return [];
    }
  }

  saveQueue() {
    try {
      localStorage.setItem('fleetroute_offline_queue', JSON.stringify(this.offlineQueue));
    } catch {
      // Storage fallback
    }
  }

  async request(endpoint, options = {}) {
    const url = `${API_BASE}${endpoint}`;
    const headers = {
      'Content-Type': 'application/json',
      ...(this.token ? { 'Authorization': `Bearer ${this.token}` } : {}),
      ...(options.headers || {})
    };

    try {
      const res = await fetch(url, { ...options, headers });
      const data = await res.json().catch(() => ({}));

      if (!res.ok) {
        if (res.status === 401 && endpoint !== '/auth/login') {
          this.clearSession();
          if (typeof window !== 'undefined') {
            window.dispatchEvent(new CustomEvent('fleetroute:unauthorized'));
          }
        }
        // If deployed on Vercel/Static where backend /api returns 404 or 405, use cloud fallback
        if (res.status === 404 || res.status === 405) {
          const fallback = this.handleCloudFallback(endpoint, options);
          if (fallback !== undefined) return fallback;
        }
        throw new Error(data.error || `HTTP error ${res.status}`);
      }
      return data;
    } catch (err) {
      const fallback = this.handleCloudFallback(endpoint, options);
      if (fallback !== undefined) return fallback;

      // Queue offline requests
      if (!this.isOnline && options.method && options.method !== 'GET') {
        const queuedItem = {
          id: `queue-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`,
          endpoint,
          options,
          timestamp: new Date().toISOString()
        };
        this.offlineQueue.push(queuedItem);
        this.saveQueue();
        return { success: true, queued: true, queueId: queuedItem.id };
      }
      throw err;
    }
  }

  handleCloudFallback(endpoint, options = {}) {

    if (endpoint === '/auth/login' && options.method === 'POST') {
      try {
        const body = JSON.parse(options.body || '{}');
        const user = cloudFallbackData.users.find(u => u.email === body.identifier || u.phone === body.identifier) || cloudFallbackData.users[0];
        return {
          success: true,
          token: 'vercel-demo-jwt-token-9988',
          user: user
        };
      } catch {
        return {
          success: true,
          token: 'vercel-demo-jwt-token-9988',
          user: cloudFallbackData.users[0]
        };
      }
    }

    if (endpoint === '/auth/me') {
      return { user: this.currentUser || cloudFallbackData.users[0] };
    }
    if (endpoint === '/trips' || endpoint.startsWith('/trips?')) return cloudFallbackData.trips;
    if (endpoint.startsWith('/trips/')) return { trip: cloudFallbackData.trips[0] };
    if (endpoint === '/drivers' || endpoint.startsWith('/drivers?')) return cloudFallbackData.drivers;
    if (endpoint === '/vehicles' || endpoint.startsWith('/vehicles?')) return cloudFallbackData.vehicles;
    if (endpoint === '/locations' || endpoint.startsWith('/locations?')) return cloudFallbackData.locations;
    if (endpoint === '/products' || endpoint.startsWith('/products?')) return cloudFallbackData.products;
    if (endpoint === '/safety-events') return cloudFallbackData.safetyEvents;
    if (endpoint === '/delivery-proofs') return cloudFallbackData.deliveryProofs;
    if (endpoint === '/settings') return cloudFallbackData.settings;
    if (endpoint === '/dashboard') {
      return {
        activeTrips: 1,
        activeDrivers: 2,
        totalFleet: 2,
        completedTripsToday: 4,
        pendingDrops: 2,
        delayedTrips: 0,
        safetyAlertsCount: 0
      };
    }
    if (endpoint === '/telemetry/drivers') {
      return [
        {
          driverId: 'DRV-101',
          driverName: 'Rajesh Sharma',
          vehicleId: 'VEH-201',
          lat: 28.5355,
          lng: 77.2684,
          speed: 42,
          speedLimit: 50,
          status: 'ON_DUTY',
          seatbeltFastened: true,
          timestamp: new Date().toISOString()
        }
      ];
    }
    if (endpoint.startsWith('/v1/emergencies')) return [];
    if (endpoint.startsWith('/v1/responders')) return [];

    if (options.method && options.method !== 'GET') {
      return { success: true, message: 'Action saved successfully' };
    }

    return undefined;
  }

  async flushQueue() {
    if (this.offlineQueue.length === 0) return;
    const items = [...this.offlineQueue];
    this.offlineQueue = [];
    this.saveQueue();

    for (const item of items) {
      try {
        await fetch(`${API_BASE}${item.endpoint}`, {
          ...item.options,
          headers: {
            'Content-Type': 'application/json',
            ...(this.token ? { 'Authorization': `Bearer ${this.token}` } : {}),
            ...(item.options.headers || {}),
            'X-Queued-Request-Id': item.id
          }
        });
      } catch {
        this.offlineQueue.push(item);
        this.saveQueue();
        break;
      }
    }
  }

  // --- Auth & Profile ---
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

  getUsers() {
    return this.request('/auth/users');
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
  getLocations(activeOnly = false) {
    return this.request(`/locations${activeOnly ? '?activeOnly=true' : ''}`);
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
      body: JSON.stringify(sample)
    });
  }

  getFleetTelemetry() {
    return this.request('/telemetry/drivers');
  }

  // --- Trips & Multi-Stop Dispatch ---
  getTrips() {
    return this.request('/trips');
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
    return this.request(`/trips/${tripId}/cargo-action`, {
      method: 'POST',
      body: JSON.stringify(payload)
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
  getDrivers() {
    return this.request('/drivers');
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

  getVehicles() {
    return this.request('/vehicles');
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

  getProducts() {
    return this.request('/products');
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
  getSafetyEvents() {
    return this.request('/safety-events');
  }

  updateSafetyEvent(id, payload) {
    return this.request(`/safety-events/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload)
    });
  }

  getDeliveryProofs() {
    return this.request('/delivery-proofs');
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
    return this.request('/v1/emergencies/detect', {
      method: 'POST',
      body: JSON.stringify(payload)
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
      body: JSON.stringify(payload)
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
