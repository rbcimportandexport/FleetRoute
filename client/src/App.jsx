import React, { useState, useEffect, useCallback } from 'react';
import Navbar from './components/layout/Navbar';
import Sidebar from './components/layout/Sidebar';
import ErrorBoundary from './components/common/ErrorBoundary';

// Admin Components
const AdminDashboard = React.lazy(() => import('./components/admin/AdminDashboard'));
const LiveTrackingView = React.lazy(() => import('./components/admin/LiveTrackingView'));
const TripsManager = React.lazy(() => import('./components/admin/TripsManager'));
const TripCreateModal = React.lazy(() => import('./components/admin/TripCreateModal'));
const LocationsManager = React.lazy(() => import('./components/admin/LocationsManager'));
const DriversManager = React.lazy(() => import('./components/admin/DriversManager'));
const VehiclesManager = React.lazy(() => import('./components/admin/VehiclesManager'));
const ProductsManager = React.lazy(() => import('./components/admin/ProductsManager'));
const CargoLedgerView = React.lazy(() => import('./components/admin/CargoLedgerView'));
const ActivityTimelineView = React.lazy(() => import('./components/admin/ActivityTimelineView'));
const DeliveriesView = React.lazy(() => import('./components/admin/DeliveriesView'));
const SafetyAlertsView = React.lazy(() => import('./components/admin/SafetyAlertsView'));
const EmergencyOpsView = React.lazy(() => import('./components/admin/EmergencyOpsView'));
const ReportsView = React.lazy(() => import('./components/admin/ReportsView'));
const SettingsView = React.lazy(() => import('./components/admin/SettingsView'));
const DelayModal = React.lazy(() => import('./components/common/DelayModal'));

// Driver Component
const DriverMobileHome = React.lazy(() => import('./components/driver/DriverMobileHome'));

import { api } from './utils/api';
import { soundEffects } from './utils/soundEffects';
import { useTranslation } from './hooks/useTranslation';

const UI_ONLY_PRINCIPAL = Object.freeze({
  id: 'fleetroute-ui-only',
  name: 'FleetRoute',
  role: 'admin',
  accessMode: 'ui-only'
});

// Mobile Bottom Nav Icons
import { 
  LayoutDashboard, 
  Compass,
  Route, 
  MapPin,
  ShieldAlert, 
  Menu 
} from 'lucide-react';

export default function App() {
  const { t } = useTranslation();
  // Authentication State
  const [currentUser, setCurrentUser] = useState(api.isUiOnlyMode ? UI_ONLY_PRINCIPAL : api.currentUser);
  const [isAuthChecking, setIsAuthChecking] = useState(true);
  const [authError, setAuthError] = useState('');

  // App Layout State
  const [activeTab, setActiveTab] = useState('dashboard');
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  
  // Logistics Data State
  const [trips, setTrips] = useState([]);
  const [drivers, setDrivers] = useState([]);
  const [vehicles, setVehicles] = useState([]);
  const [locations, setLocations] = useState([]);
  const [products, setProducts] = useState([]);
  const [safetyEvents, setSafetyEvents] = useState([]);
  const [stats, setStats] = useState({});
  const [loading, setLoading] = useState(false);
  const [operationError, setOperationError] = useState('');

  // Selected identifiers
  const [activeDriverId, setActiveDriverId] = useState(null);
  const [activeTripId, setActiveTripId] = useState(null);

  // Modals & Connectivity
  const [isDelayModalOpen, setIsDelayModalOpen] = useState(false);
  const [delayModalType, setDelayModalType] = useState('breakdown');
  const [isCreateTripModalOpen, setIsCreateTripModalOpen] = useState(false);
  const [isOnline, setIsOnline] = useState(true);

  // Data Loading Function
  const loadInitialData = useCallback(async () => {
    if (api.isUiOnlyMode) {
      setTrips([]);
      setDrivers([]);
      setVehicles([]);
      setLocations([]);
      setProducts([]);
      setSafetyEvents([]);
      setStats({
        activeTrips: 0,
        driversOnDuty: 0,
        completedDeliveriesToday: 0,
        pendingDeliveries: 0,
        safetyAlerts: 0
      });
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setOperationError('');
      const [tripsData, driversData, vehiclesData, locationsData, productsData, safetyData, dashStats] = await Promise.all([
        api.getTrips().catch(() => []),
        api.getDrivers().catch(() => []),
        api.getVehicles().catch(() => []),
        api.getLocations().catch(() => []),
        api.getProducts().catch(() => []),
        api.getSafetyEvents().catch(() => []),
        api.getDashboard().catch(() => ({}))
      ]);

      setTrips(Array.isArray(tripsData) ? tripsData : []);
      setDrivers(Array.isArray(driversData) ? driversData : []);
      setVehicles(Array.isArray(vehiclesData) ? vehiclesData : []);
      setLocations(Array.isArray(locationsData) ? locationsData : []);
      setProducts(Array.isArray(productsData) ? productsData : []);
      setSafetyEvents(Array.isArray(safetyData) ? safetyData : []);
      setStats(dashStats && typeof dashStats === 'object' ? dashStats : {});

      const safeDrivers = Array.isArray(driversData) ? driversData : [];
      const safeTrips = Array.isArray(tripsData) ? tripsData : [];

      if (safeDrivers.length > 0 && !activeDriverId) {
        setActiveDriverId(safeDrivers[0].id);
      }
      if (safeTrips.length > 0 && !activeTripId) {
        setActiveTripId(safeTrips[0].id);
      }
    } catch (err) {
      console.error('Failed to load logistics operational data:', err);
      setOperationError(err.message || 'Operational data could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [activeDriverId, activeTripId]);

  // Auth & Session Verification on Mount
  useEffect(() => {
    if (api.isUiOnlyMode) {
      setCurrentUser(UI_ONLY_PRINCIPAL);
      loadInitialData();
      setIsAuthChecking(false);
      return undefined;
    }

    const verifyAuth = async () => {
      try {
        setAuthError('');
        if (api.token) {
          try {
            const res = await api.getProfile();
            if (res && res.user) {
              setCurrentUser(res.user);
              await loadInitialData();
              return;
            }
          } catch (sessionError) {
            console.warn('Stored session could not be restored:', sessionError.message);
            api.clearSession();
          }
        }

        const res = await api.startEmbeddedSession();
        setCurrentUser(res.user);
        await loadInitialData();
      } catch (err) {
        console.error('Direct access initialization failed:', err);
        api.clearSession();
        setCurrentUser(null);
        setAuthError(err.message || 'FleetRoute could not connect to its live service.');
      } finally {
        setIsAuthChecking(false);
      }
    };

    verifyAuth();

    // Listen for unauthorized events from api client
    const handleUnauthorized = () => {
      setCurrentUser(null);
      api.clearSession();
      setAuthError('The live access session expired. Retry to reconnect.');
    };

    window.addEventListener('fleetroute:unauthorized', handleUnauthorized);
    return () => {
      window.removeEventListener('fleetroute:unauthorized', handleUnauthorized);
    };
  }, [loadInitialData]);

  // Safe Arrays
  const tripsArray = Array.isArray(trips) ? trips : [];
  const driversArray = Array.isArray(drivers) ? drivers : [];

  // Active Trip Object
  const currentTrip = tripsArray.find(t => t.id === activeTripId) || tripsArray[0];
  
  // In driver mode, identify driver entity
  const currentDriver = driversArray.find(d => 
    d.id === currentUser?.driverId || 
    d.userId === currentUser?.id || 
    d.email === currentUser?.email ||
    d.id === activeDriverId
  ) || driversArray[0];

  // In driver mode, strictly display ONLY their assigned active trip
  const driverTrip = tripsArray.find(t => 
    (t.driverId === currentDriver?.id || t.driverName === currentDriver?.name) && 
    t.status !== 'completed'
  ) || tripsArray.find(t => 
    t.driverId === currentDriver?.id || t.driverName === currentDriver?.name
  ) || null;

  // Workflow Handlers
  const handleAdvanceStop = async (payload = {}) => {
    const targetTrip = currentUser?.role === 'driver' ? driverTrip : currentTrip;
    if (!targetTrip) return;

    try {
      setOperationError('');
      const res = await api.advanceStop(targetTrip.id, payload);
      if (res && res.trip) {
        setTrips(prev => prev.map(t => t.id === res.trip.id ? res.trip : t));
        api.getDashboard().then(setStats).catch(() => {});
      }
    } catch (err) {
      console.error('Error advancing stop workflow:', err);
      setOperationError(err.message || 'Trip workflow could not be updated.');
    }
  };

  const handleCargoAction = async (payload) => {
    const targetTrip = currentUser?.role === 'driver' ? driverTrip : currentTrip;
    if (!targetTrip) return;

    try {
      setOperationError('');
      const res = await api.cargoAction(targetTrip.id, payload);
      if (res && res.trip) {
        setTrips(prev => prev.map(t => t.id === res.trip.id ? res.trip : t));
      }
    } catch (err) {
      console.error('Error recording cargo action:', err);
      setOperationError(err.message || 'Cargo action could not be recorded.');
    }
  };

  const handleRecordActivity = async (payload) => {
    const targetTrip = currentUser?.role === 'driver' ? driverTrip : currentTrip;
    if (!targetTrip) return;

    try {
      setOperationError('');
      const res = await api.recordActivity(targetTrip.id, payload);
      if (res && res.trip) {
        setTrips(prev => prev.map(t => t.id === res.trip.id ? res.trip : t));
      }
    } catch (err) {
      console.error('Error recording timed activity:', err);
      setOperationError(err.message || 'Activity could not be recorded.');
    }
  };

  const handleUpdateSafetyStatus = async (id, reviewStatus) => {
    try {
      const res = await api.updateSafetyEvent(id, { reviewStatus });
      if (res && res.safetyEvent) {
        setSafetyEvents(prev => prev.map(e => e.id === id ? res.safetyEvent : e));
      }
    } catch (err) {
      console.error('Error updating safety event status:', err);
    }
  };

  const handleCreateTrip = async (newTrip) => {
    try {
      const res = await api.createTrip(newTrip);
      if (res && res.trip) {
        setTrips(prev => [res.trip, ...prev]);
        setActiveTripId(res.trip.id);
        soundEffects.playSuccessChime();
        api.getDashboard().then(setStats).catch(() => {});
      }
    } catch (err) {
      console.error('Error creating trip:', err);
      throw err;
    }
  };

  const handleCreateDriver = async (newDriver) => {
    try {
      const res = await api.createDriver(newDriver);
      if (res && res.driver) {
        setDrivers(prev => [...prev, res.driver]);
        soundEffects.playSuccessChime();
      }
    } catch (err) {
      console.error('Error creating driver:', err);
      throw err;
    }
  };

  const handleCreateVehicle = async (newVehicle) => {
    try {
      const res = await api.createVehicle(newVehicle);
      if (res && res.vehicle) {
        setVehicles(prev => [...prev, res.vehicle]);
        soundEffects.playSuccessChime();
      }
    } catch (err) {
      console.error('Error creating vehicle:', err);
      throw err;
    }
  };

  const handleSimulateOffline = () => {
    const nextState = !isOnline;
    setIsOnline(nextState);
    if (!nextState) {
      soundEffects.playActionClick();
    } else {
      soundEffects.playSuccessChime();
      api.flushQueue();
    }
  };

  // If initial auth check is ongoing, show subtle loading state
  if (isAuthChecking) {
    return (
      <div style={{
        minHeight: '100vh',
        background: '#0f172a',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: '#94a3b8',
        fontSize: '14px',
        fontWeight: 600
      }}>
        Connecting FleetRoute to live operations...
      </div>
    );
  }

  // The embedded build intentionally has no login screen. If the live API or
  // database is unavailable, show an honest retry state instead of mock data.
  if (!currentUser) {
    return (
      <div style={{
        minHeight: '100vh',
        background: '#f1f5f9',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '24px'
      }}>
        <div role="alert" style={{
          width: 'min(460px, 100%)',
          background: '#fff',
          border: '1px solid #fecaca',
          borderRadius: '16px',
          padding: '28px',
          boxShadow: '0 18px 45px rgba(15, 23, 42, 0.08)',
          textAlign: 'center'
        }}>
          <h1 style={{ margin: '0 0 10px', color: '#0f172a', fontSize: '22px' }}>Live service unavailable</h1>
          <p style={{ margin: '0 0 20px', color: '#64748b', lineHeight: 1.6 }}>
            {authError || 'FleetRoute could not connect to its live database. No placeholder data has been loaded.'}
          </p>
          <button
            type="button"
            onClick={() => window.location.reload()}
            style={{ border: 0, borderRadius: '10px', background: '#0284c7', color: '#fff', padding: '11px 18px', fontWeight: 700, cursor: 'pointer' }}
          >
            Retry live connection
          </button>
        </div>
      </div>
    );
  }

  const isDriver = currentUser.role === 'driver';

  return (
    <React.Suspense fallback={<div style={{ padding: '24px', color: 'var(--slate-600)' }}>Loading workspace...</div>}>
    <div className="app-shell">
      {/* Top Navigation */}
      <Navbar
        currentUser={currentUser}
        isOnline={isOnline}
        onSimulateOffline={handleSimulateOffline}
        onToggleMobileMenu={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
        trips={trips}
        drivers={drivers}
        vehicles={vehicles}
        locations={locations}
        onSelectTrip={(id) => { setActiveTripId(id); setActiveTab('trips'); }}
        onNavigateTab={setActiveTab}
        onCreateTripModal={() => setIsCreateTripModalOpen(true)}
      />

      {/* Main Layout Container */}
      <div style={{ display: 'flex', flex: 1, position: 'relative', width: '100%' }}>
        
        {/* Responsive Desktop & Mobile Off-Canvas Drawer Sidebar for Admin */}
        {!isDriver && (
          <Sidebar
            activeTab={activeTab}
            onTabChange={setActiveTab}
            counts={{
              activeTrips: stats?.activeTrips || 0,
              liveDrivers: (Array.isArray(drivers) ? drivers : []).filter(d => d?.lastLocation).length,
              driversCount: (Array.isArray(drivers) ? drivers : []).length,
              vehiclesCount: (Array.isArray(vehicles) ? vehicles : []).length,
              locationsCount: (Array.isArray(locations) ? locations : []).length,
              productsCount: (Array.isArray(products) ? products : []).length,
              deliveriesCount: stats?.completedDeliveriesToday || 0,
              safetyAlerts: (Array.isArray(safetyEvents) ? safetyEvents : []).filter(e => e?.reviewStatus === 'new').length,
              emergencyIncidents: 0
            }}
            isMobileOpen={isMobileMenuOpen}
            onCloseMobile={() => setIsMobileMenuOpen(false)}
            onCreateTripModal={() => setIsCreateTripModalOpen(true)}
          />
        )}

        {/* Dynamic Main Viewport */}
        <main 
          className="main-viewport"
          style={{
            flex: 1,
            width: '100%',
            padding: isDriver ? '12px 10px 85px' : '20px 24px 85px',
            overflowY: 'auto',
            background: 'var(--slate-50)'
          }}
        >
          {operationError && (
            <div role="alert" style={{
              maxWidth: '1400px',
              margin: '0 auto 12px',
              padding: '10px 14px',
              borderRadius: '10px',
              border: '1px solid var(--status-rose)',
              background: 'var(--status-rose-light)',
              color: 'var(--status-rose-text)',
              fontSize: '12px',
              fontWeight: 700,
              display: 'flex',
              justifyContent: 'space-between',
              gap: '12px'
            }}>
              <span>{operationError}</span>
              <button type="button" onClick={() => setOperationError('')} style={{ border: 0, background: 'transparent', color: 'inherit', cursor: 'pointer', fontWeight: 800 }}>
                Dismiss
              </button>
            </div>
          )}
          <ErrorBoundary>
            {isDriver ? (
            /* Dedicated Driver Screen: Strictly Isolated to Driver's Assigned Trip */
            <DriverMobileHome
              driver={currentDriver}
              trip={driverTrip}
              onAdvanceStop={handleAdvanceStop}
              onCargoAction={handleCargoAction}
              onRecordActivity={handleRecordActivity}
              onTripUpdated={(updatedTrip) => {
                if (updatedTrip?.id) {
                  setTrips(prev => prev.map(trip => trip.id === updatedTrip.id ? updatedTrip : trip));
                }
              }}
              onOpenDelayModal={(type = 'breakdown') => {
                setDelayModalType(type);
                setIsDelayModalOpen(true);
              }}
              isOnline={isOnline}
            />
          ) : (
            /* Admin Management Operations Hub */
            <>
              {activeTab === 'dashboard' && (
                <AdminDashboard
                  stats={stats}
                  trips={trips}
                  activeTrip={currentTrip}
                  safetyEvents={safetyEvents}
                  onSelectTrip={(id) => { setActiveTripId(id); setActiveTab('trips'); }}
                  onCreateTripModal={() => setIsCreateTripModalOpen(true)}
                  onViewAllTrips={() => setActiveTab('trips')}
                  onViewSafety={() => setActiveTab('safety')}
                  onNavigateTab={setActiveTab}
                />
              )}

              {activeTab === 'emergency-ops' && (
                <EmergencyOpsView />
              )}

              {activeTab === 'live-tracking' && (
                <LiveTrackingView
                  drivers={drivers}
                  vehicles={vehicles}
                  trips={trips}
                  onOpenTrip={(id) => { setActiveTripId(id); setActiveTab('trips'); }}
                />
              )}

              {activeTab === 'trips' && (
                <TripsManager
                  trips={trips}
                  onCreateTripModal={() => setIsCreateTripModalOpen(true)}
                  onSelectTrip={(id) => setActiveTripId(id)}
                  onTripUpdated={loadInitialData}
                />
              )}

              {activeTab === 'locations' && (
                <LocationsManager
                  locations={locations}
                  onLocationsUpdated={loadInitialData}
                />
              )}

              {activeTab === 'drivers' && (
                <DriversManager
                  drivers={drivers}
                  onCreateDriver={handleCreateDriver}
                  onDriverUpdated={loadInitialData}
                />
              )}

              {activeTab === 'vehicles' && (
                <VehiclesManager
                  vehicles={vehicles}
                  onCreateVehicle={handleCreateVehicle}
                  onVehicleUpdated={loadInitialData}
                />
              )}

              {activeTab === 'products' && (
                <ProductsManager
                  products={products}
                  onProductsUpdated={loadInitialData}
                />
              )}

              {activeTab === 'cargo' && (
                <CargoLedgerView
                  trips={trips}
                  activeTrip={currentTrip}
                />
              )}

              {activeTab === 'timeline' && (
                <ActivityTimelineView
                  trips={trips}
                  activeTrip={currentTrip}
                />
              )}

              {activeTab === 'deliveries' && (
                <DeliveriesView
                  trips={trips}
                />
              )}

              {activeTab === 'safety' && (
                <SafetyAlertsView
                  safetyEvents={safetyEvents}
                  onUpdateStatus={handleUpdateSafetyStatus}
                />
              )}

              {activeTab === 'reports' && (
                <ReportsView
                  trips={trips}
                  drivers={drivers}
                  vehicles={vehicles}
                />
              )}

              {activeTab === 'settings' && (
                <SettingsView />
              )}
            </>
          )}
          </ErrorBoundary>
        </main>
      </div>

      {/* Mobile Bottom Navigation Bar for Admin on Small Screens (<768px) */}
      {!isDriver && (
        <nav className="mobile-bottom-nav">
          <button
            onClick={() => setActiveTab('dashboard')}
            className={`mobile-tab-btn ${activeTab === 'dashboard' ? 'active' : ''}`}
          >
            <LayoutDashboard size={18} />
            <span>{t('navDashboard')}</span>
          </button>

          <button
            onClick={() => setActiveTab('live-tracking')}
            className={`mobile-tab-btn ${activeTab === 'live-tracking' ? 'active' : ''}`}
          >
            <Compass size={18} />
            <span>{t('navTracking')}</span>
          </button>

          <button
            onClick={() => setActiveTab('trips')}
            className={`mobile-tab-btn ${activeTab === 'trips' ? 'active' : ''}`}
          >
            <Route size={18} />
            <span>{t('navTrips')}</span>
          </button>

          <button
            onClick={() => setActiveTab('locations')}
            className={`mobile-tab-btn ${activeTab === 'locations' ? 'active' : ''}`}
          >
            <MapPin size={18} />
            <span>{t('navLocations')}</span>
          </button>

          <button
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
            className="mobile-tab-btn"
          >
            <Menu size={18} />
            <span>{t('navMore')}</span>
          </button>
        </nav>
      )}

      {/* Operational Delay, Breakdown Incident & Police/RTO Challan Modal */}
      <DelayModal
        isOpen={isDelayModalOpen}
        onClose={() => setIsDelayModalOpen(false)}
        tripId={currentUser?.role === 'driver' ? driverTrip?.id : currentTrip?.id}
        driver={currentDriver}
        initialTab={delayModalType}
        onSaveActivity={handleRecordActivity}
      />

      {/* 7-Step Multi-Stop Trip Creation Wizard */}
      <ErrorBoundary fallbackTitle="Trip Dispatcher Wizard Error">
        <TripCreateModal
          isOpen={isCreateTripModalOpen}
          onClose={() => setIsCreateTripModalOpen(false)}
          onCreateTrip={handleCreateTrip}
          drivers={drivers}
          vehicles={vehicles}
          locations={locations}
          products={products}
        />
      </ErrorBoundary>

    </div>
    </React.Suspense>
  );
}
