import { useState, useEffect } from 'react';
import RoutePlanner from './RoutePlanner';
import NotificationCenter, { NotificationToasts } from './components/NotificationCenter';
import AlertsPage from './components/AlertsPage';
import DriversPage from './components/DriversPage';
import TripsPage from './components/TripsPage';
import { INITIAL_DRIVERS } from './utils/fleetData';
import {
  INITIAL_NOTIFICATIONS,
  FLEET_NOTIFICATION_EVENT,
  playNotificationChime,
  sendBrowserNotification,
  dispatchFleetNotification,
} from './utils/notifications';

const modules = [
  { id: 'overview', label: 'Overview', icon: 'grid', group: 'Workspace' },
  { id: 'fleet', label: 'Fleet', icon: 'truck', group: 'Operations' },
  { id: 'drivers', label: 'Drivers', icon: 'users', group: 'Operations' },
  { id: 'trips', label: 'Trips', icon: 'route', group: 'Operations' },
  { id: 'routes', label: 'Routes', icon: 'map', group: 'Operations' },
  { id: 'maintenance', label: 'Maintenance', icon: 'tool', group: 'Management' },
  { id: 'alerts', label: 'Alerts', icon: 'bell', group: 'Management' },
  { id: 'reports', label: 'Reports', icon: 'chart', group: 'Management' },
];

const moduleCopy = {
  fleet: ['Fleet', 'Vehicle management', 'Your vehicle directory and fleet controls will appear here after integration.'],
  drivers: ['Drivers', 'Driver management', 'Driver profiles, assignments, and availability will appear here after integration.'],
  trips: ['Trips', 'Trip operations', 'Planned, active, and completed trips will appear here after integration.'],
  routes: ['Routes', 'Route planning', 'Saved routes and planning tools will appear here after integration.'],
  maintenance: ['Maintenance', 'Service management', 'Maintenance schedules and service records will appear here after integration.'],
  alerts: ['Alerts', 'Operations alerts', 'Fleet alerts and notification rules will appear here after integration.'],
  reports: ['Reports', 'Performance reporting', 'Operational reports and export tools will appear here after integration.'],
};

function Icon({ name, size = 19 }) {
  const paths = {
    grid: <><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></>,
    truck: <><path d="M3 6h11v10H3zM14 10h4l3 3v3h-7z"/><circle cx="7" cy="18" r="2"/><circle cx="18" cy="18" r="2"/></>,
    users: <><circle cx="9" cy="8" r="3"/><path d="M3.5 19v-2.2A4.8 4.8 0 0 1 8.3 12h1.4a4.8 4.8 0 0 1 4.8 4.8V19M16 5.5a3 3 0 0 1 0 5.8M17 13a4.5 4.5 0 0 1 3.5 4.4V19"/></>,
    route: <><circle cx="5" cy="18" r="2"/><circle cx="19" cy="6" r="2"/><path d="M7 18h2a3 3 0 0 0 3-3V9a3 3 0 0 1 3-3h2"/></>,
    map: <><path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3zM9 3v15M15 6v15"/></>,
    tool: <><path d="M14.7 6.3a4 4 0 0 0-5-5L12 3.6 9.6 6 7.3 3.7a4 4 0 0 0 5 5l-8.6 8.6a2.1 2.1 0 0 0 3 3z"/></>,
    bell: <><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/></>,
    chart: <><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></>,
    search: <><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></>,
    menu: <><path d="M4 7h16M4 12h16M4 17h16"/></>,
    close: <><path d="m6 6 12 12M18 6 6 18"/></>,
    chevron: <path d="m9 18 6-6-6-6"/>,
    plus: <><path d="M12 5v14M5 12h14"/></>,
    link: <><path d="M10 13a5 5 0 0 0 7.5.5l2-2a5 5 0 0 0-7-7l-1.2 1.2M14 11a5 5 0 0 0-7.5-.5l-2 2a5 5 0 0 0 7 7l1.2-1.2"/></>,
    inbox: <><path d="M4 4h16v14H4zM4 14h4l2 3h4l2-3h4"/></>,
  };
  return <svg className="icon" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name]}</svg>;
}

function Brand() {
  return (
    <div className="brand">
      <span className="brand-symbol"><svg viewBox="0 0 28 28" aria-hidden="true"><path d="M6 20c0-4 3-5.5 6.5-5.5h3c3.5 0 6.5-1.5 6.5-5.5"/><circle cx="6" cy="20" r="2.2"/><circle cx="22" cy="9" r="2.2"/></svg></span>
      <span>FleetRoute</span>
    </div>
  );
}

function EmptyPanel({ compact = false, title = 'No information to display', text = 'Information will appear here when your workspace is connected.' }) {
  return (
    <div className={`empty-panel${compact ? ' compact' : ''}`}>
      <span className="empty-icon"><Icon name="inbox" size={22} /></span>
      <h3>{title}</h3>
      <p>{text}</p>
    </div>
  );
}

function Overview({
  unreadAlertsCount = 0,
  criticalAlertsCount = 0,
  totalDriversCount = 6,
  activeTripsCount = 4,
}) {
  const summaries = [
    ['Fleet', 'Vehicles registered', `${totalDriversCount}`, 'Commercial fleet active'],
    ['Drivers', 'Active team members', `${totalDriversCount}`, `${totalDriversCount - 1} on duty`],
    ['Trips', 'Active transit runs', `${activeTripsCount}`, `${activeTripsCount} on the road`],
    ['Alerts', 'Open notifications', unreadAlertsCount > 0 ? `${unreadAlertsCount}` : '0', unreadAlertsCount > 0 ? `${criticalAlertsCount} critical` : 'All clear'],
  ];

  return (
    <>
      <div className="page-heading">
        <div>
          <p className="overline">Admin workspace</p>
          <h1>Operations overview</h1>
          <p className="page-description">A clear starting point for your fleet management workspace.</p>
        </div>
        <button className="primary-action" type="button"><Icon name="link" size={17} /> Connect workspace</button>
      </div>

      <section className="summary-grid" aria-label="Workspace summaries">
        {summaries.map(([label, description, val, sub]) => (
          <article className="summary-card" key={label}>
            <div className="summary-top">
              <span>{label}</span>
              <span className={`status-dot${label === 'Alerts' && unreadAlertsCount > 0 ? ' critical-dot' : ''}`} />
            </div>
            <strong>{val}</strong>
            <p>{description}</p>
            <span className={`not-connected${label === 'Alerts' && unreadAlertsCount > 0 ? ' active-alert-tag' : ''}`}>{sub}</span>
          </article>
        ))}
      </section>

      <section className="dashboard-grid">
        <article className="panel activity-panel">
          <div className="panel-heading">
            <div><h2>Recent activity</h2><p>Latest workspace events</p></div>
            <button className="text-button" type="button">View all <Icon name="chevron" size={15} /></button>
          </div>
          <EmptyPanel />
        </article>

        <article className="panel setup-panel">
          <div className="panel-heading"><div><h2>Workspace setup</h2><p>Prepare your admin environment</p></div></div>
          <div className="setup-list">
            {['Connect your data source', 'Configure fleet modules', 'Review workspace access'].map((item, index) => (
              <div className="setup-item" key={item}>
                <span>{String(index + 1).padStart(2, '0')}</span>
                <p>{item}</p>
                <Icon name="chevron" size={16} />
              </div>
            ))}
          </div>
        </article>
      </section>
    </>
  );
}

function ModulePage({ moduleId }) {
  const [title, subtitle, description] = moduleCopy[moduleId] || [moduleId, 'Module', 'Module content will appear here.'];
  return (
    <>
      <div className="page-heading">
        <div>
          <p className="overline">{subtitle}</p>
          <h1>{title}</h1>
          <p className="page-description">{description}</p>
        </div>
        <button className="secondary-action" type="button"><Icon name="plus" size={17} /> Configure module</button>
      </div>
      <section className="module-toolbar">
        <div className="toolbar-search"><Icon name="search" size={17} /><span>Search {title.toLowerCase()}</span></div>
        <button type="button">Filters</button>
        <button type="button">Columns</button>
      </section>
      <section className="panel module-panel">
        <div className="module-table-head"><span>{title}</span><span>Status</span><span>Updated</span><span /></div>
        <EmptyPanel title={`${title} module is ready`} text="No records have been added. Connect your workspace when you want to display information here." />
      </section>
    </>
  );
}

export default function App() {
  const [active, setActive] = useState('overview');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [notifications, setNotifications] = useState(INITIAL_NOTIFICATIONS);
  const [drivers, setDrivers] = useState(INITIAL_DRIVERS);
  const [toasts, setToasts] = useState([]);
  const [preselectedDriverId, setPreselectedDriverId] = useState(null);
  const current = modules.find((item) => item.id === active) || modules[0];
  const groups = [...new Set(modules.map((item) => item.group))];

  useEffect(() => {
    const handleFleetNotification = (event) => {
      const alert = event.detail;
      if (!alert) return;
      setNotifications((prev) => [alert, ...prev]);
      setToasts((prev) => [alert, ...prev.slice(0, 3)]);
      playNotificationChime();
      sendBrowserNotification(alert.title, alert.message);

      setTimeout(() => {
        setToasts((prev) => prev.filter((t) => t.id !== alert.id));
      }, 5000);
    };

    window.addEventListener(FLEET_NOTIFICATION_EVENT, handleFleetNotification);
    return () => window.removeEventListener(FLEET_NOTIFICATION_EVENT, handleFleetNotification);
  }, []);

  const selectModule = (id) => {
    setActive(id);
    setSidebarOpen(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const markRead = (id) => {
    setNotifications((prev) =>
      prev.map((item) => (item.id === id ? { ...item, read: true } : item))
    );
  };

  const markAllRead = () => {
    setNotifications((prev) => prev.map((item) => ({ ...item, read: true })));
  };

  const clearAll = () => {
    setNotifications([]);
  };

  const deleteNotification = (id) => {
    setNotifications((prev) => prev.filter((item) => item.id !== id));
  };

  const toggleResolve = (id) => {
    setNotifications((prev) =>
      prev.map((item) => (item.id === id ? { ...item, resolved: !item.resolved } : item))
    );
  };

  const addCustomNotification = (alert) => {
    setNotifications((prev) => [alert, ...prev]);
    setToasts((prev) => [alert, ...prev.slice(0, 3)]);
    playNotificationChime();
    sendBrowserNotification(alert.title, alert.message);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== alert.id));
    }, 5000);
  };

  const dismissToast = (id) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  const handleAddDriver = (newDriver) => {
    setDrivers((prev) => [newDriver, ...prev]);
  };

  const handlePlanTripForDriver = (driver) => {
    setPreselectedDriverId(driver.id);
    setActive('routes');
    setSidebarOpen(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleAssignTrip = ({ driverId, origin, destination, cargo, distance, eta, remark }) => {
    setDrivers((prev) =>
      prev.map((d) => {
        if (d.id !== driverId) return d;
        const prevTrip = d.currentTrip;
        const cleanRemark = remark ? remark.trim() : '';
        const newTrip = {
          id: `TRIP-${Math.floor(1000 + Math.random() * 9000)}`,
          origin,
          destination,
          cargo: cargo || 'Commercial Freight',
          distance: distance || 'Calculated Route',
          departure: 'Just now',
          eta: eta || 'On Schedule',
          progress: 10,
          speed: Math.round(d.vehicle.maxSpeed * 0.8),
          traffic: 'Smooth Flow',
          status: 'In Transit',
          remark: cleanRemark,
        };
        const updatedLastTrip = prevTrip
          ? {
              id: prevTrip.id,
              origin: prevTrip.origin,
              destination: prevTrip.destination,
              distance: prevTrip.distance,
              duration: 'Completed',
              completedAt: 'Earlier today',
              status: 'Delivered',
              fuelEfficiency: d.lastTrip?.fuelEfficiency || '5.2 km/L',
              remark: prevTrip.remark || '',
            }
          : d.lastTrip;

        const updatedRecent = prevTrip
          ? [
              {
                id: prevTrip.id,
                route: `${prevTrip.origin.split(',')[0]} to ${prevTrip.destination.split(',')[0]}`,
                distance: prevTrip.distance,
                duration: 'Completed',
                date: 'Earlier today',
                status: 'Completed',
              },
              ...(d.recentTrips || []),
            ]
          : d.recentTrips;

        return {
          ...d,
          status: 'on_trip',
          currentTrip: newTrip,
          lastTrip: updatedLastTrip,
          recentTrips: updatedRecent,
        };
      })
    );
  };

  const handleSendDriverAlert = ({ driverId, driverName, vehiclePlate, vehicleModel, title, message, severity, category }) => {
    setDrivers((prev) =>
      prev.map((d) => {
        if (d.id !== driverId) return d;
        return {
          ...d,
          alertHistory: [
            {
              id: `da-${Date.now()}`,
              title,
              message,
              severity,
              time: 'Just now',
            },
            ...(d.alertHistory || []),
          ],
        };
      })
    );

    dispatchFleetNotification({
      title: `Direct Alert to ${driverName} (${vehiclePlate})`,
      message: `${title}: ${message}`,
      severity: severity || 'warning',
      category: category || 'Speed',
      vehicleId: vehiclePlate,
    });
  };

  const unreadCount = notifications.filter((n) => !n.read).length;
  const criticalCount = notifications.filter((n) => n.severity === 'critical' && !n.resolved).length;

  return (
    <div className="admin-shell">
      <aside className={`sidebar${sidebarOpen ? ' open' : ''}`}>
        <div className="sidebar-head">
          <Brand />
          <button className="mobile-close" type="button" onClick={() => setSidebarOpen(false)} aria-label="Close navigation"><Icon name="close" /></button>
        </div>
        <nav className="sidebar-nav" aria-label="Admin navigation">
          {groups.map((group) => (
            <div className="nav-group" key={group}>
              <p>{group}</p>
              {modules.filter((item) => item.group === group).map((item) => (
                <button className={active === item.id ? 'active' : ''} type="button" key={item.id} onClick={() => selectModule(item.id)}>
                  <Icon name={item.icon} />
                  <span>{item.label}</span>
                  {item.id === 'alerts' && unreadCount > 0 && (
                    <span className="sidebar-alert-badge">{unreadCount}</span>
                  )}
                </button>
              ))}
            </div>
          ))}
        </nav>
        <div className="sidebar-footer">
          <span className="connection-mark" />
          <div><strong>UI preview</strong><p>No data connected</p></div>
        </div>
      </aside>

      {sidebarOpen && <button className="sidebar-backdrop" type="button" aria-label="Close navigation" onClick={() => setSidebarOpen(false)} />}

      <div className="main-shell">
        <header className="topbar">
          <div className="topbar-left">
            <button className="menu-button" type="button" onClick={() => setSidebarOpen(true)} aria-label="Open navigation"><Icon name="menu" /></button>
            <div className="breadcrumb"><span>FleetRoute</span><Icon name="chevron" size={14}/><strong>{current.label}</strong></div>
          </div>
          <div className="topbar-actions">
            <label className="global-search"><Icon name="search" size={17}/><input aria-label="Search workspace" placeholder="Search workspace" /></label>
            <NotificationCenter
              notifications={notifications}
              onMarkRead={markRead}
              onMarkAllRead={markAllRead}
              onClearAll={clearAll}
              onDeleteNotification={deleteNotification}
              onSelectAlertsPage={() => selectModule('alerts')}
            />
            <button className="profile-button" type="button" aria-label="Workspace profile"><span>FR</span><div><strong>FleetRoute</strong><small>Administrator</small></div></button>
          </div>
        </header>

        <main className="content">
          {active === 'overview' ? (
            <Overview
              unreadAlertsCount={unreadCount}
              criticalAlertsCount={criticalCount}
              totalDriversCount={drivers.length}
              activeTripsCount={drivers.filter((d) => d.status === 'on_trip').length}
            />
          ) : active === 'routes' ? (
            <RoutePlanner
              drivers={drivers}
              onAssignTrip={handleAssignTrip}
              onAddDriver={handleAddDriver}
              preselectedDriverId={preselectedDriverId}
            />
          ) : active === 'drivers' ? (
            <DriversPage
              drivers={drivers}
              onAddDriver={handleAddDriver}
              onAssignTrip={handleAssignTrip}
              onSendDriverAlert={handleSendDriverAlert}
              onPlanTripForDriver={handlePlanTripForDriver}
            />
          ) : active === 'trips' ? (
            <TripsPage
              drivers={drivers}
              onAssignTrip={handleAssignTrip}
              onSendDriverAlert={handleSendDriverAlert}
              onSelectRoutes={() => selectModule('routes')}
            />
          ) : active === 'alerts' ? (
            <AlertsPage
              notifications={notifications}
              onAddNotification={addCustomNotification}
              onToggleResolve={toggleResolve}
              onToggleRead={markRead}
              onDeleteNotification={deleteNotification}
              onClearAll={clearAll}
            />
          ) : (
            <ModulePage moduleId={active} />
          )}
        </main>
      </div>

      <NotificationToasts toasts={toasts} onDismissToast={dismissToast} />
    </div>
  );
}
