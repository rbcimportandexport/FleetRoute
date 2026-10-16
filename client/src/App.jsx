import { useState } from 'react';
import RoutePlanner from './RoutePlanner';

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

function Overview() {
  const summaries = [
    ['Fleet', 'Vehicles'],
    ['Drivers', 'Team members'],
    ['Trips', 'Active journeys'],
    ['Alerts', 'Open notifications'],
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
        {summaries.map(([label, description]) => (
          <article className="summary-card" key={label}>
            <div className="summary-top"><span>{label}</span><span className="status-dot" /></div>
            <strong>—</strong>
            <p>{description}</p>
            <span className="not-connected">Not connected</span>
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
  const [title, subtitle, description] = moduleCopy[moduleId];
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
  const current = modules.find((item) => item.id === active);
  const groups = [...new Set(modules.map((item) => item.group))];

  const selectModule = (id) => {
    setActive(id);
    setSidebarOpen(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

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
                  <Icon name={item.icon} /><span>{item.label}</span>
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
            <button className="icon-button" type="button" aria-label="Notifications"><Icon name="bell" /></button>
            <button className="profile-button" type="button" aria-label="Workspace profile"><span>FR</span><div><strong>FleetRoute</strong><small>Administrator</small></div></button>
          </div>
        </header>

        <main className="content">
          {active === 'overview' ? <Overview /> : active === 'routes' ? <RoutePlanner /> : <ModulePage moduleId={active} />}
        </main>
      </div>
    </div>
  );
}
