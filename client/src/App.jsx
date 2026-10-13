import React, { useState, useEffect, useCallback } from 'react';
import Navbar from './components/layout/Navbar';
import Sidebar from './components/layout/Sidebar';
import DelayModal from './components/common/DelayModal';
import ErrorBoundary from './components/common/ErrorBoundary';

// Auth Components
import LoginPage from './components/auth/LoginPage';
import UserProfileModal from './components/auth/UserProfileModal';

// Admin Components
import AdminDashboard from './components/admin/AdminDashboard';
import LiveTrackingView from './components/admin/LiveTrackingView';
import TripsManager from './components/admin/TripsManager';
import TripCreateModal from './components/admin/TripCreateModal';
import LocationsManager from './components/admin/LocationsManager';
import DriversManager from './components/admin/DriversManager';
import VehiclesManager from './components/admin/VehiclesManager';
import ProductsManager from './components/admin/ProductsManager';
import CargoLedgerView from './components/admin/CargoLedgerView';
import ActivityTimelineView from './components/admin/ActivityTimelineView';
import DeliveriesView from './components/admin/DeliveriesView';
import SafetyAlertsView from './components/admin/SafetyAlertsView';
import EmergencyOpsView from './components/admin/EmergencyOpsView';
import ReportsView from './components/admin/ReportsView';
import SettingsView from './components/admin/SettingsView';

// Driver Component
import DriverMobileHome from './components/driver/DriverMobileHome';

import { api } from './utils/api';
import { soundEffects } from './utils/soundEffects';
import { useTranslation } from './hooks/useTranslation';

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
  const [currentUser, setCurrentUser] = useState(api.currentUser);
  const [isAuthChecking, setIsAuthChecking] = useState(true);
  const [isProfileOpen, setIsProfileOpen] = useState(false);

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
    try {
      setLoading(true);
      const [tripsData, driversData, vehiclesData, locationsData, productsData, safetyData, dashStats] = await Promise.all([
        api.getTrips().catch(() => []),
        api.getDrivers().catch(() => []),
        api.getVehicles().catch(() => []),
        api.getLocations().catch(() => []),
        api.getProducts().catch(() => []),
        api.getSafetyEvents().catch(() => []),
        api.getDashboard().catch(() => ({}))
      ]);

      setTrips(tripsData);
      setDrivers(driversData);
      setVehicles(vehiclesData);
      setLocations(locationsData);
      setProducts(productsData);
      setSafetyEvents(safetyData);
      setStats(dashStats);

      if (driversData.length > 0 && !activeDriverId) {
        setActiveDriverId(driversData[0].id);
      }
      if (tripsData.length > 0 && !activeTripId) {
        setActiveTripId(tripsData[0].id);
      }
    } catch (err) {
      console.error('Failed to load logistics operational data:', err);
    } finally {
      setLoading(false);
    }
  }, [activeDriverId, activeTripId]);

  // Auth & Session Verification on Mount
  useEffect(() => {
    const verifyAuth = async () => {
      try {
        if (api.token) {
          const res = await api.getProfile();
          if (res && res.user) {
            setCurrentUser(res.user);
            await loadInitialData();
          } else {
            api.clearSession();
            setCurrentUser(null);
          }
        } else {
          setCurrentUser(null);
        }
      } catch (err) {
        console.warn('Session verification notice:', err.message);
        api.clearSession();
        setCurrentUser(null);
      } finally {
        setIsAuthChecking(false);
      }
    };

    verifyAuth();

    // Listen for unauthorized events from api client
    const handleUnauthorized = () => {
      setCurrentUser(null);
      api.clearSession();
    };

    window.addEventListener('fleetroute:unauthorized', handleUnauthorized);
    return () => {
      window.removeEventListener('fleetroute:unauthorized', handleUnauthorized);
    };
  }, [loadInitialData]);

  // Handle Login Success
  const handleLoginSuccess = async (user) => {
    setCurrentUser(user);
    if (user.driverId) {
      setActiveDriverId(user.driverId);
    }
    await loadInitialData();
    soundEffects.playSuccessChime();
  };

  // Handle Logout
  const handleLogout = () => {
    api.logout();
    setCurrentUser(null);
    soundEffects.playActionClick();
  };

  // Active Trip Object
  const currentTrip = trips.find(t => t.id === activeTripId) || trips[0];
  
  // In driver mode, identify driver entity
  const currentDriver = drivers.find(d => 
    d.id === currentUser?.driverId || 
    d.userId === currentUser?.id || 
    d.email === currentUser?.email ||
    d.id === activeDriverId
  ) || drivers[0];

  // In driver mode, strictly display ONLY their assigned active trip
  const driverTrip = trips.find(t => 
    (t.driverId === currentDriver?.id || t.driverName === currentDriver?.name) && 
    t.status !== 'completed'
  ) || trips.find(t => 
    t.driverId === currentDriver?.id || t.driverName === currentDriver?.name
  ) || null;

  // Workflow Handlers
  const handleAdvanceStop = async (payload = {}) => {
    const targetTrip = currentUser?.role === 'driver' ? driverTrip : currentTrip;
    if (!targetTrip) return;

    try {
      const res = await api.advanceStop(targetTrip.id, payload);
      if (res && res.trip) {
        setTrips(prev => prev.map(t => t.id === res.trip.id ? res.trip : t));
        api.getDashboard().then(setStats).catch(() => {});
      }
    } catch (err) {
      console.error('Error advancing stop workflow:', err);
    }
  };

  const handleCargoAction = async (payload) => {
    const targetTrip = currentUser?.role === 'driver' ? driverTrip : currentTrip;
    if (!targetTrip) return;

    try {
      const res = await api.cargoAction(targetTrip.id, payload);
      if (res && res.trip) {
        setTrips(prev => prev.map(t => t.id === res.trip.id ? res.trip : t));
      }
    } catch (err) {
      console.error('Error recording cargo action:', err);
    }
  };

  const handleRecordActivity = async (payload) => {
    const targetTrip = currentUser?.role === 'driver' ? driverTrip : currentTrip;
    if (!targetTrip) return;

    try {
      const res = await api.recordActivity(targetTrip.id, payload);
      if (res && res.trip) {
        setTrips(prev => prev.map(t => t.id === res.trip.id ? res.trip : t));
      }
    } catch (err) {
      console.error('Error recording timed activity:', err);
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
        Initializing FleetRoute Authentication Engine...
      </div>
    );
  }

  // If user is not authenticated, present the professional login page
  if (!currentUser) {
    return (
      <LoginPage 
        onLoginSuccess={handleLoginSuccess}
      />
    );
  }

  const isDriver = currentUser.role === 'driver';

  return (
    <div className="app-shell">
      {/* Top Navigation */}
      <Navbar
        currentUser={currentUser}
        onOpenProfile={() => setIsProfileOpen(true)}
        onLogout={handleLogout}
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
              activeTrips: stats.activeTrips,
              liveDrivers: drivers.filter(d => d.lastLocation).length,
              driversCount: drivers.length,
              vehiclesCount: vehicles.length,
              locationsCount: locations.length,
              productsCount: products.length,
              deliveriesCount: stats.completedDeliveriesToday,
              safetyAlerts: safetyEvents.filter(e => e.reviewStatus === 'new').length,
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
          <ErrorBoundary>
            {isDriver ? (
            /* Dedicated Driver Screen: Strictly Isolated to Driver's Assigned Trip */
            <DriverMobileHome
              driver={currentDriver}
              trip={driverTrip}
              onAdvanceStop={handleAdvanceStop}
              onCargoAction={handleCargoAction}
              onRecordActivity={handleRecordActivity}
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

      {/* User Profile & Password Change Modal */}
      <UserProfileModal
        isOpen={isProfileOpen}
        onClose={() => setIsProfileOpen(false)}
        currentUser={currentUser}
        driver={currentDriver}
        driverTrip={driverTrip}
        assignedVehicle={vehicles.find(v => v.id === currentDriver?.assignedVehicleId || v.id === driverTrip?.vehicleId)}
        onLogout={handleLogout}
        onProfileUpdated={(updatedUser) => setCurrentUser(updatedUser)}
      />
    </div>
  );
}
