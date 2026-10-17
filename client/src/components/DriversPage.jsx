import { useState } from 'react';
import { playNotificationChime } from '../utils/notifications';

function DriverIcon({ name, size = 16 }) {
  const icons = {
    truck: <><rect x="1" y="5" width="14" height="11" rx="1"/><path d="M15 9h4l3 3.5V16h-7z"/><circle cx="5.5" cy="18.5" r="2.5"/><circle cx="17.5" cy="18.5" r="2.5"/></>,
    bike: <><circle cx="5.5" cy="17.5" r="3.5"/><circle cx="18.5" cy="17.5" r="3.5"/><path d="M15 6h-3l-2.5 6.5h6zM5.5 17.5l4-8h5l4 8M12 10.5l-3 7"/></>,
    car: <><path d="m5 11 2-5h10l2 5M4 11h16v7H4z"/><circle cx="7" cy="18" r="1.5"/><circle cx="17" cy="18" r="1.5"/></>,
    phone: <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/>,
    mail: <><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></>,
    lock: <><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></>,
    badge: <><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></>,
    route: <><circle cx="5" cy="18" r="2"/><circle cx="19" cy="6" r="2"/><path d="M7 18h2a3 3 0 0 0 3-3V9a3 3 0 0 1 3-3h5"/></>,
    clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
    bell: <><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/></>,
    check: <path d="M20 6 9 17l-5-5"/>,
    plus: <><path d="M12 5v14M5 12h14"/></>,
    alert: <><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></>,
    grid: <><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></>,
    list: <><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></>,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {icons[name] || icons.truck}
    </svg>
  );
}

export default function DriversPage({
  drivers = [],
  onAddDriver,
  onAssignTrip,
  onSendDriverAlert,
  onPlanTripForDriver,
}) {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [vehicleFilter, setVehicleFilter] = useState('all');

  // Modals state
  const [addModalOpen, setAddModalOpen] = useState(false);
  const [alertModalTarget, setAlertModalTarget] = useState(null); // driver object
  const [historyModalTarget, setHistoryModalTarget] = useState(null); // driver object

  // Add Driver Form State
  const [newDriverName, setNewDriverName] = useState('');
  const [newDriverPhone, setNewDriverPhone] = useState('');
  const [newDriverEmail, setNewDriverEmail] = useState('');
  const [newDriverPassword, setNewDriverPassword] = useState('');
  const [newDriverLoginPin, setNewDriverLoginPin] = useState('');
  const [newDriverLicense, setNewDriverLicense] = useState('');
  const [newDriverExp, setNewDriverExp] = useState('5 Years');
  const [newVehicleModel, setNewVehicleModel] = useState('6-Wheeler MCV (Eicher 11.10)');
  const [newVehiclePlate, setNewVehiclePlate] = useState('GJ-05-');
  const [newDriverHub, setNewDriverHub] = useState('Surat Central Depot');
  const [newDriverStatus, setNewDriverStatus] = useState('available');

  // Alert Modal Form State
  const [alertTitle, setAlertTitle] = useState('');
  const [alertMessage, setAlertMessage] = useState('');
  const [alertSeverity, setAlertSeverity] = useState('warning');
  const [alertCategory, setAlertCategory] = useState('Speed');

  // Quick preset alerts
  const presetAlerts = [
    { title: 'Speed Limit Advisory', message: 'Reduce speed: Exceeding safety threshold on state highway.', category: 'Speed', severity: 'critical' },
    { title: 'Heavy Traffic Congestion Ahead', message: 'High congestion detected near Chalthan junction: Use ring road bypass.', category: 'Traffic', severity: 'warning' },
    { title: 'Toll Inspection Check Due', message: 'Report to commercial lane for mandatory axle weight check at next toll.', category: 'Maintenance', severity: 'info' },
    { title: 'Priority Delivery Consignment', message: 'Customer requested expedited delivery. Direct routing required.', category: 'Route', severity: 'info' },
  ];

  // Filtering
  const filteredDrivers = drivers.filter((driver) => {
    if (search.trim()) {
      const q = search.toLowerCase();
      const match =
        driver.name.toLowerCase().includes(q) ||
        driver.phone.toLowerCase().includes(q) ||
        driver.license.toLowerCase().includes(q) ||
        driver.vehicle.plate.toLowerCase().includes(q) ||
        driver.vehicle.model.toLowerCase().includes(q) ||
        driver.baseHub.toLowerCase().includes(q);
      if (!match) return false;
    }
    if (statusFilter !== 'all' && driver.status !== statusFilter) return false;
    if (vehicleFilter !== 'all') {
      if (vehicleFilter === 'truck' && driver.vehicle.category !== 'truck') return false;
      if (vehicleFilter === 'bike' && driver.vehicle.category !== 'bike') return false;
      if (vehicleFilter === 'car' && driver.vehicle.category !== 'car') return false;
    }
    return true;
  });

  const totalDrivers = drivers.length;
  const onTripCount = drivers.filter((d) => d.status === 'on_trip').length;
  const availableCount = drivers.filter((d) => d.status === 'available').length;
  const offDutyCount = drivers.filter((d) => d.status === 'off_duty').length;

  const handleCreateDriver = (e) => {
    e.preventDefault();
    if (!newDriverName.trim() || !newDriverPhone.trim() || !newVehiclePlate.trim()) return;

    const emailValue = newDriverEmail.trim() || `${newDriverName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '.')}@fleetroute.in`;
    const passwordValue = newDriverPassword.trim() || 'Driver@123';
    const pinValue = newDriverLoginPin.trim() || String(Math.floor(1000 + Math.random() * 9000));

    const newDriver = {
      id: `driver-${Date.now()}`,
      name: newDriverName.trim(),
      phone: newDriverPhone.trim(),
      email: emailValue,
      license: newDriverLicense.trim() || `GJ05-${new Date().getFullYear()}-00${Math.floor(1000 + Math.random() * 9000)}`,
      experience: newDriverExp,
      rating: '4.8',
      status: newDriverStatus,
      baseHub: newDriverHub,
      loginCredentials: {
        username: emailValue,
        password: passwordValue,
        pin: pinValue,
        loginEnabled: true,
      },
      vehicle: {
        model: newVehicleModel,
        plate: newVehiclePlate.trim().toUpperCase() || `GJ-05-XX-${Math.floor(1000 + Math.random() * 9000)}`,
        category: newVehicleModel.toLowerCase().includes('bike') ? 'bike' : newVehicleModel.toLowerCase().includes('car') ? 'car' : 'truck',
        type: newVehicleModel,
        maxSpeed: newVehicleModel.includes('Trailer') ? 40 : newVehicleModel.includes('HCV') ? 48 : newVehicleModel.includes('Tata Ace') ? 65 : 55,
        capacity: newVehicleModel.includes('Trailer') ? '38 Ton' : newVehicleModel.includes('Signa') ? '20 Ton' : '7.5 Ton',
      },
      currentTrip: newDriverStatus === 'on_trip' ? {
        id: `TRIP-${Math.floor(1000 + Math.random() * 9000)}`,
        origin: newDriverHub,
        destination: 'Sachin GIDC Logistics Park',
        distance: '28 km',
        cargo: 'General Logistics Load',
        departure: 'Just now',
        eta: '1 hr 15 min',
        progress: 15,
        speed: 45,
        traffic: 'Smooth Flow',
        status: 'In Transit',
        remark: 'Initial commercial dispatch',
      } : null,
      lastTrip: null,
      recentTrips: [],
      alertHistory: [],
    };

    onAddDriver(newDriver);
    playNotificationChime();
    setNewDriverName('');
    setNewDriverPhone('');
    setNewDriverEmail('');
    setNewDriverPassword('');
    setNewDriverLoginPin('');
    setNewDriverLicense('');
    setAddModalOpen(false);
  };

  const handleSendAlertSubmit = (e) => {
    e.preventDefault();
    if (!alertModalTarget || !alertTitle.trim()) return;

    onSendDriverAlert({
      driverId: alertModalTarget.id,
      driverName: alertModalTarget.name,
      vehiclePlate: alertModalTarget.vehicle.plate,
      vehicleModel: alertModalTarget.vehicle.model,
      title: alertTitle.trim(),
      message: alertMessage.trim() || `Operational alert transmitted to ${alertModalTarget.name}.`,
      severity: alertSeverity,
      category: alertCategory,
    });

    playNotificationChime();
    setAlertModalTarget(null);
    setAlertTitle('');
    setAlertMessage('');
  };



  return (
    <div className="drivers-page-container">
      <div className="page-heading">
        <div>
          <p className="overline">Fleet Operations & Transport</p>
          <h1>Driver Directory & Transport Fleet</h1>
          <p className="page-description">
            Live driver rosters, assigned vehicles, real-time active trips, vehicle last trip logs, and direct operational alert dispatch.
          </p>
        </div>
        <div className="driver-heading-actions">
          <button
            className="primary-action"
            type="button"
            onClick={() => setAddModalOpen(true)}
          >
            <DriverIcon name="plus" size={15} /> Add New Driver
          </button>
        </div>
      </div>

      {/* KPI Metrics */}
      <section className="summary-grid drivers-kpi-grid" aria-label="Driver metrics">
        <article className="summary-card">
          <div className="summary-top">
            <span>Total Drivers</span>
            <span className="status-dot active-dot" />
          </div>
          <strong>{totalDrivers}</strong>
          <p>Registered commercial drivers</p>
          <span className="badge-tag">Directory Active</span>
        </article>

        <article className="summary-card kpi-success">
          <div className="summary-top">
            <span>On Active Trip</span>
            <span className="status-dot success-dot" />
          </div>
          <strong className="text-success">{onTripCount}</strong>
          <p>Vehicles on the road now</p>
          <span className="badge-tag success">In Transit</span>
        </article>

        <article className="summary-card kpi-warning">
          <div className="summary-top">
            <span>Available / Standby</span>
            <span className="status-dot warning-dot" />
          </div>
          <strong className="text-warning-metric">{availableCount}</strong>
          <p>Ready for new dispatch</p>
          <span className="badge-tag warning">Ready to Assign</span>
        </article>

        <article className="summary-card">
          <div className="summary-top">
            <span>Off Duty / Resting</span>
            <span className="status-dot" />
          </div>
          <strong>{offDutyCount}</strong>
          <p>Rest period & maintenance</p>
          <span className="badge-tag">Shift Closed</span>
        </article>
      </section>

      {/* Search, Filters, and Easy View Switcher */}
      <section className="module-toolbar drivers-toolbar">
        <div className="toolbar-search">
          <svg className="icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>
          </svg>
          <input
            placeholder="Search driver by name, phone, plate, or hub..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button type="button" className="clear-search" onClick={() => setSearch('')}>✕</button>
          )}
        </div>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="alerts-filter-select"
          aria-label="Filter by driver status"
        >
          <option value="all">All Statuses ({drivers.length})</option>
          <option value="on_trip">On Trip ({onTripCount})</option>
          <option value="available">Available ({availableCount})</option>
          <option value="off_duty">Off Duty ({offDutyCount})</option>
        </select>

        <select
          value={vehicleFilter}
          onChange={(e) => setVehicleFilter(e.target.value)}
          className="alerts-filter-select"
          aria-label="Filter by vehicle type"
        >
          <option value="all">All Vehicle Types</option>
          <option value="truck">Trucks & Commercial</option>
          <option value="bike">Two-Wheeler Bikes</option>
          <option value="car">Passenger / Light Cars</option>
        </select>


      </section>

      {/* =====================================================================
          FLEET COMMERCIAL DRIVERS DIRECTORY - TABLE VIEW
          ===================================================================== */}
      <div className="drivers-table-wrapper">
          <table className="drivers-easy-table">
            <thead>
              <tr>
                <th>Driver & Contact</th>
                <th>Vehicle & Plate</th>
                <th>Status</th>
                <th>New / Active Trip</th>
                <th>Gadi Ki Last Trip</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredDrivers.length === 0 ? (
                <tr>
                  <td colSpan="6" style={{ textAlign: 'center', padding: '44px 20px' }}>
                    <div style={{ maxWidth: '420px', margin: '0 auto' }}>
                      <strong style={{ fontSize: '14px', color: 'var(--navy)' }}>
                        {drivers.length === 0 ? 'No Drivers in Fleet Roster' : 'No drivers match your current filter'}
                      </strong>
                      <p style={{ margin: '6px 0 16px', color: '#64748b', fontSize: '12.5px' }}>
                        {drivers.length === 0
                          ? 'Zero mock data. Click "+ Add New Driver" to register commercial drivers.'
                          : 'Try clearing the search or status filter to see all registered drivers.'}
                      </p>
                      {drivers.length === 0 && (
                        <button
                          type="button"
                          className="primary-action sm"
                          onClick={() => setAddModalOpen(true)}
                          style={{ margin: '0 auto' }}
                        >
                          <DriverIcon name="plus" size={14} /> Add First Driver
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ) : (
                filteredDrivers.map((driver) => {
                  const initials = driver.name.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase();

                  return (
                    <tr key={driver.id}>
                      {/* Driver & Contact */}
                      <td>
                        <div className="table-driver-info">
                          <span className="driver-avatar sm">{initials}</span>
                          <div>
                            <strong className="table-driver-name">{driver.name}</strong>
                            <span className="table-subtext">{driver.phone}</span>
                            {driver.email && (
                              <span className="table-subtext table-email-sub">{driver.email}</span>
                            )}
                          </div>
                        </div>
                      </td>

                      {/* Vehicle & Plate */}
                      <td>
                        <strong className="plate-tag">{driver.vehicle.plate}</strong>
                        <span className="table-subtext">{driver.vehicle.model}</span>
                      </td>

                      {/* Status */}
                      <td>
                        <span className={`driver-status-badge ${driver.status}`}>
                          {driver.status === 'on_trip' ? 'On Trip' : driver.status === 'available' ? 'Available' : 'Off Duty'}
                        </span>
                      </td>

                      {/* Active Trip */}
                      <td>
                        {driver.currentTrip ? (
                          <div className="table-trip-cell">
                            <strong>{driver.currentTrip.origin} → {driver.currentTrip.destination}</strong>
                            <span className="table-subtext">
                              ETA: {driver.currentTrip.eta} • {driver.currentTrip.speed} km/h ({driver.currentTrip.progress}%)
                            </span>
                            {driver.currentTrip.remark && (
                              <span className="table-remark-pill">Remark: {driver.currentTrip.remark}</span>
                            )}
                          </div>
                        ) : (
                          <span className="table-trip-idle">Vehicle Idle / Standby</span>
                        )}
                      </td>

                      {/* Last Trip */}
                      <td>
                        {driver.lastTrip ? (
                          <div className="table-trip-cell">
                            <span>{driver.lastTrip.origin} → {driver.lastTrip.destination}</span>
                            <span className="table-subtext">{driver.lastTrip.completedAt} ({driver.lastTrip.distance})</span>
                          </div>
                        ) : (
                          <span className="table-trip-idle">-</span>
                        )}
                      </td>

                      {/* Actions */}
                      <td style={{ textAlign: 'right' }}>
                        <div className="table-actions-cell">
                          <button
                            type="button"
                            className="action-btn-alert sm"
                            onClick={() => {
                              setAlertModalTarget(driver);
                              setAlertTitle(`Speed Advisory: ${driver.vehicle.plate}`);
                              setAlertMessage(`Attention ${driver.name}: Please observe the safe driving speed limit.`);
                              setAlertSeverity('warning');
                              setAlertCategory('Speed');
                            }}
                            title="Send alert message"
                          >
                            <DriverIcon name="bell" size={13} /> Alert
                          </button>

                          <button
                            type="button"
                            className="action-btn-trip sm"
                            onClick={() => {
                              if (onPlanTripForDriver) {
                                onPlanTripForDriver(driver);
                              }
                            }}
                            title={`Plan & dispatch real trip on Google map for ${driver.name}`}
                          >
                            <DriverIcon name="route" size={13} /> <span>+ Trip</span>
                          </button>

                          <button
                            type="button"
                            className="action-btn-history sm"
                            onClick={() => setHistoryModalTarget(driver)}
                            title="View history and login information"
                          >
                            History
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

      {/* =====================================================================
          MODAL 1: SEND ALERT MESSAGE DIRECTLY TO DRIVER
          ===================================================================== */}
      {alertModalTarget && (
        <div className="modal-backdrop" onClick={() => setAlertModalTarget(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <h2>Send Alert Message to Driver</h2>
              <button type="button" className="modal-close" onClick={() => setAlertModalTarget(null)}>✕</button>
            </div>

            <form onSubmit={handleSendAlertSubmit} className="modal-form">
              <div className="driver-recipient-banner">
                <strong>{alertModalTarget.name}</strong>
                <span>{alertModalTarget.vehicle.plate} • {alertModalTarget.vehicle.model}</span>
              </div>

              {/* Quick Presets */}
              <div className="quick-presets-group">
                <label>Quick Preset Alert:</label>
                <div className="preset-chips">
                  {presetAlerts.map((preset) => (
                    <button
                      type="button"
                      key={preset.title}
                      className="preset-chip-btn"
                      onClick={() => {
                        setAlertTitle(preset.title);
                        setAlertMessage(preset.message);
                        setAlertCategory(preset.category);
                        setAlertSeverity(preset.severity);
                      }}
                    >
                      {preset.title}
                    </button>
                  ))}
                </div>
              </div>

              <div className="form-group">
                <label>Alert Title</label>
                <input
                  required
                  placeholder="e.g. Over-speeding Warning or Road Closure"
                  value={alertTitle}
                  onChange={(e) => setAlertTitle(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>Direct Operational Message</label>
                <textarea
                  required
                  rows="3"
                  placeholder="Type message to driver..."
                  value={alertMessage}
                  onChange={(e) => setAlertMessage(e.target.value)}
                />
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>Severity</label>
                  <select value={alertSeverity} onChange={(e) => setAlertSeverity(e.target.value)}>
                    <option value="critical">Critical (Red Alert)</option>
                    <option value="warning">Warning (Amber Alert)</option>
                    <option value="info">Info (Operational)</option>
                    <option value="success">Success</option>
                  </select>
                </div>

                <div className="form-group">
                  <label>Category</label>
                  <select value={alertCategory} onChange={(e) => setAlertCategory(e.target.value)}>
                    <option value="Speed">Speed & Safety</option>
                    <option value="Traffic">Traffic & Route</option>
                    <option value="Maintenance">Maintenance & Checkpoint</option>
                    <option value="Route">Consignment & Dispatch</option>
                  </select>
                </div>
              </div>

              <div className="modal-actions">
                <button type="button" className="secondary-action" onClick={() => setAlertModalTarget(null)}>
                  Cancel
                </button>
                <button type="submit" className="primary-action">
                  <DriverIcon name="bell" size={15} /> Transmit Alert Now
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* =====================================================================
          MODAL 2: ADD NEW DRIVER
          ===================================================================== */}
      {addModalOpen && (
        <div className="modal-backdrop" onClick={() => setAddModalOpen(false)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <h2>Add Commercial Driver to Fleet</h2>
              <button type="button" className="modal-close" onClick={() => setAddModalOpen(false)}>✕</button>
            </div>

            <form onSubmit={handleCreateDriver} className="modal-form">
              <div className="form-row">
                <div className="form-group">
                  <label>Full Driver Name *</label>
                  <input
                    required
                    placeholder="e.g. Ramesh Chandra"
                    value={newDriverName}
                    onChange={(e) => setNewDriverName(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label>Phone Number *</label>
                  <input
                    required
                    placeholder="e.g. +91 98250 12345"
                    value={newDriverPhone}
                    onChange={(e) => setNewDriverPhone(e.target.value)}
                  />
                </div>
              </div>

              {/* Driver Email & Login Information */}
              <div className="form-section-banner">
                <DriverIcon name="lock" size={14} />
                <span>Driver Login Credentials (Web & Mobile App)</span>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>Driver Login Email ID *</label>
                  <input
                    type="email"
                    placeholder="e.g. ramesh.driver@fleetroute.in"
                    value={newDriverEmail}
                    onChange={(e) => setNewDriverEmail(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label>Portal Password & PIN</label>
                  <div className="login-pin-row">
                    <input
                      type="text"
                      placeholder="Password (e.g. Driver@123)"
                      value={newDriverPassword}
                      onChange={(e) => setNewDriverPassword(e.target.value)}
                    />
                    <input
                      type="text"
                      placeholder="PIN (4 digits)"
                      value={newDriverLoginPin}
                      onChange={(e) => setNewDriverLoginPin(e.target.value)}
                      style={{ maxWidth: '110px' }}
                    />
                  </div>
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>Commercial Driving License (DL)</label>
                  <input
                    placeholder="e.g. GJ05-2019-0021940"
                    value={newDriverLicense}
                    onChange={(e) => setNewDriverLicense(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label>Driving Experience</label>
                  <select value={newDriverExp} onChange={(e) => setNewDriverExp(e.target.value)}>
                    <option value="2 Years">2 Years</option>
                    <option value="5 Years">5 Years</option>
                    <option value="8 Years">8 Years</option>
                    <option value="12+ Years">12+ Years</option>
                  </select>
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label>Assigned Vehicle Model</label>
                  <select value={newVehicleModel} onChange={(e) => setNewVehicleModel(e.target.value)}>
                    <option value="Tata Ace (Chota Hathi)">Tata Ace (LCV 1T Mini Truck)</option>
                    <option value="6-Wheeler MCV (Eicher 11.10)">6-Wheeler MCV (Eicher 11.10 - 7.5T)</option>
                    <option value="10-12 Wheeler HCV (Signa 2823)">10-12 Wheeler HCV (Signa 2823 - 20T)</option>
                    <option value="Multi-Axle Trailer (40ft Container)">Multi-Axle Trailer (40ft Container - 38T)</option>
                    <option value="Two-Wheeler Express Courier">Two-Wheeler Express Bike</option>
                  </select>
                </div>
                <div className="form-group">
                  <label>Vehicle Plate Number</label>
                  <input
                    required
                    placeholder="e.g. GJ-05-BX-1234"
                    value={newVehiclePlate}
                    onChange={(e) => setNewVehiclePlate(e.target.value)}
                  />
                </div>
              </div>

              <div className="modal-actions">
                <button type="button" className="secondary-action" onClick={() => setAddModalOpen(false)}>
                  Cancel
                </button>
                <button type="submit" className="primary-action">
                  Register Driver & Vehicle
                </button>
              </div>
            </form>
          </div>
        </div>
      )}



      {/* =====================================================================
          MODAL 4: TRIP HISTORY FOR DRIVER
          ===================================================================== */}
      {historyModalTarget && (
        <div className="modal-backdrop" onClick={() => setHistoryModalTarget(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <h2>Trip Logs: {historyModalTarget.name}</h2>
              <button type="button" className="modal-close" onClick={() => setHistoryModalTarget(null)}>✕</button>
            </div>

            <div className="modal-form">
              <div className="driver-recipient-banner">
                <strong>{historyModalTarget.name} ({historyModalTarget.vehicle.plate})</strong>
                <span>{historyModalTarget.vehicle.model} • Hub: {historyModalTarget.baseHub}</span>
              </div>

              {/* Driver Portal & Login Information */}
              <div className="driver-credentials-card">
                <div className="credentials-card-title">
                  <DriverIcon name="lock" size={14} />
                  <strong>Driver Portal & Mobile App Login Information</strong>
                </div>
                <div className="credentials-grid">
                  <div>
                    <small>Login Email / Username</small>
                    <strong>{historyModalTarget.email || historyModalTarget.loginCredentials?.username || historyModalTarget.phone}</strong>
                  </div>
                  <div>
                    <small>Portal Password</small>
                    <strong>{historyModalTarget.loginCredentials?.password || 'Driver@123'}</strong>
                  </div>
                  <div>
                    <small>Mobile App PIN</small>
                    <strong>{historyModalTarget.loginCredentials?.pin || '4821'}</strong>
                  </div>
                  <div>
                    <small>Account Status</small>
                    <span className="cred-status-active">Login Access Enabled</span>
                  </div>
                </div>
              </div>

              <div className="history-trips-list">
                {historyModalTarget.recentTrips && historyModalTarget.recentTrips.length > 0 ? (
                  historyModalTarget.recentTrips.map((trip) => (
                    <div key={trip.id} className="history-trip-item">
                      <div className="history-trip-head">
                        <strong>{trip.route}</strong>
                        <span className="history-status-tag">{trip.status}</span>
                      </div>
                      <div className="history-trip-meta">
                        <span>{trip.distance}</span>
                        <span>•</span>
                        <span>{trip.duration}</span>
                        <span>•</span>
                        <span>{trip.date}</span>
                        <span>•</span>
                        <span className="trip-id-code">{trip.id}</span>
                      </div>
                    </div>
                  ))
                ) : (
                  <p className="no-last-trip">No historical trips found.</p>
                )}
              </div>

              <div className="modal-actions">
                <button type="button" className="secondary-action" onClick={() => setHistoryModalTarget(null)}>
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
