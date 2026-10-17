import { useState } from 'react';
import { playNotificationChime } from '../utils/notifications';

export default function TripsPage({
  drivers = [],
  onAssignTrip,
  onSendDriverAlert,
  onSelectRoutes,
}) {
  const [tab, setTab] = useState('active'); // 'active' | 'completed'
  const [search, setSearch] = useState('');
  const [assignModalOpen, setAssignModalOpen] = useState(false);
  const [selectedDriverId, setSelectedDriverId] = useState(drivers[0]?.id || '');
  const [tripOrigin, setTripOrigin] = useState('');
  const [tripDestination, setTripDestination] = useState('');
  const [tripCargo, setTripCargo] = useState('');
  const [tripDistance, setTripDistance] = useState('32 km');
  const [tripRemark, setTripRemark] = useState('');

  // Extract all active trips from drivers
  const activeTrips = drivers
    .filter((d) => d.currentTrip)
    .map((d) => ({
      ...d.currentTrip,
      driverName: d.name,
      driverPhone: d.phone,
      driverId: d.id,
      vehiclePlate: d.vehicle.plate,
      vehicleModel: d.vehicle.model,
      vehicleCategory: d.vehicle.category,
    }));

  // Extract all last/completed trips from drivers
  const completedTrips = drivers
    .filter((d) => d.lastTrip)
    .map((d) => ({
      ...d.lastTrip,
      driverName: d.name,
      driverPhone: d.phone,
      driverId: d.id,
      vehiclePlate: d.vehicle.plate,
      vehicleModel: d.vehicle.model,
      vehicleCategory: d.vehicle.category,
    }));

  const displayedTrips = (tab === 'active' ? activeTrips : completedTrips).filter((trip) => {
    if (!search.trim()) return true;
    const q = search.toLowerCase();
    return (
      trip.id.toLowerCase().includes(q) ||
      trip.origin.toLowerCase().includes(q) ||
      trip.destination.toLowerCase().includes(q) ||
      trip.driverName.toLowerCase().includes(q) ||
      trip.vehiclePlate.toLowerCase().includes(q)
    );
  });

  const handleCreateTripSubmit = (e) => {
    e.preventDefault();
    if (!selectedDriverId || !tripOrigin.trim() || !tripDestination.trim()) return;

    onAssignTrip({
      driverId: selectedDriverId,
      origin: tripOrigin.trim(),
      destination: tripDestination.trim(),
      cargo: tripCargo.trim() || 'General Commercial Freight',
      distance: tripDistance.trim() || '30 km',
      eta: '1 hr 15 min',
      remark: tripRemark.trim(),
    });

    playNotificationChime();
    setAssignModalOpen(false);
    setTripOrigin('');
    setTripDestination('');
    setTripCargo('');
    setTripRemark('');
  };

  return (
    <div className="trips-page-container">
      <div className="page-heading">
        <div>
          <p className="overline">Operations & Dispatch Logistics</p>
          <h1>Fleet Transport & Trip Management</h1>
          <p className="page-description">
            Live overview of active transit runs, vehicle last completed trips, delivery schedules, and direct route communications.
          </p>
        </div>
        <div>
          <button
            className="primary-action"
            type="button"
            onClick={() => {
              if (onSelectRoutes) onSelectRoutes();
              else setAssignModalOpen(true);
            }}
          >
            + Dispatch New Trip
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <section className="summary-grid trips-kpi-grid" aria-label="Trip metrics">
        <article className="summary-card">
          <div className="summary-top">
            <span>Active Trips</span>
            <span className="status-dot success-dot" />
          </div>
          <strong className="text-success">{activeTrips.length}</strong>
          <p>Vehicles on the road now</p>
          <span className="badge-tag success">In Transit</span>
        </article>

        <article className="summary-card">
          <div className="summary-top">
            <span>Last Completed</span>
            <span className="status-dot active-dot" />
          </div>
          <strong>{completedTrips.length}</strong>
          <p>Delivered and logged</p>
          <span className="badge-tag">Closed Runs</span>
        </article>

        <article className="summary-card kpi-warning">
          <div className="summary-top">
            <span>Traffic Slowdowns</span>
            <span className="status-dot warning-dot" />
          </div>
          <strong className="text-warning-metric">
            {activeTrips.filter((t) => t.traffic && t.traffic.toLowerCase().includes('delay')).length}
          </strong>
          <p>Corridors with delays</p>
          <span className="badge-tag warning">Alerts Active</span>
        </article>

        <article className="summary-card">
          <div className="summary-top">
            <span>Avg Transit Speed</span>
            <span className="status-dot" />
          </div>
          <strong>46 km/h</strong>
          <p>Fleet efficiency index</p>
          <span className="badge-tag">Standard Flow</span>
        </article>
      </section>

      {/* Toolbar & Tabs */}
      <section className="module-toolbar trips-toolbar">
        <div className="toolbar-search">
          <svg className="icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>
          </svg>
          <input
            placeholder="Search by trip ID, city, driver, vehicle plate..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button type="button" className="clear-search" onClick={() => setSearch('')}>✕</button>
          )}
        </div>

        <div className="trips-tab-toggle" role="tablist">
          <button
            type="button"
            className={`trips-toggle-btn${tab === 'active' ? ' active' : ''}`}
            onClick={() => setTab('active')}
          >
            New / Active Trips ({activeTrips.length})
          </button>
          <button
            type="button"
            className={`trips-toggle-btn${tab === 'completed' ? ' active' : ''}`}
            onClick={() => setTab('completed')}
          >
            Gadi Ki Last Trip Logs ({completedTrips.length})
          </button>
        </div>
      </section>

      {/* Trips Table Panel */}
      <section className="panel trips-table-panel">
        <div className="trips-table-head">
          <span>Trip ID & Status</span>
          <span>Route (Origin → Destination)</span>
          <span>Driver & Assigned Vehicle</span>
          <span>Cargo & Distance</span>
          <span>{tab === 'active' ? 'Progress / ETA' : 'Completed Log'}</span>
          <span className="text-right">Action</span>
        </div>

        <div className="trips-table-body">
          {displayedTrips.length === 0 ? (
            <div className="empty-panel" style={{ padding: '40px 20px', textAlign: 'center' }}>
              <span className="empty-icon">✓</span>
              <h3>No {tab === 'active' ? 'active' : 'completed'} trips found</h3>
              <p style={{ maxWidth: '460px', margin: '8px auto 0', color: '#64748b', fontSize: '13px' }}>
                {drivers.length === 0
                  ? 'All mock trips have been cleared. Register drivers in the Drivers roster and assign transport dispatches to track live trips here.'
                  : `There are no ${tab === 'active' ? 'active' : 'completed'} trips matching your filter.`}
              </p>
            </div>
          ) : (
            displayedTrips.map((trip) => (
              <div key={trip.id} className="trip-table-row">
                <div className="trip-col-id">
                  <strong className="trip-code">{trip.id}</strong>
                  <span className={`trip-status-pill ${tab === 'active' ? 'in-transit' : 'delivered'}`}>
                    {tab === 'active' ? (trip.status || 'In Transit') : 'Delivered'}
                  </span>
                </div>

                <div className="trip-col-route">
                  <div className="route-origin">
                    <span className="dot origin-dot" />
                    <strong>{trip.origin}</strong>
                  </div>
                  <div className="route-arrow-down">↓</div>
                  <div className="route-dest">
                    <span className="dot dest-dot" />
                    <strong>{trip.destination}</strong>
                  </div>
                </div>

                <div className="trip-col-driver">
                  <strong className="driver-name-text">{trip.driverName}</strong>
                  <span className="driver-plate-sub">{trip.vehiclePlate} • {trip.vehicleModel}</span>
                </div>

                <div className="trip-col-cargo">
                  <span>{trip.cargo || 'Commercial Freight'}</span>
                  <small>{trip.distance}</small>
                  {trip.remark && (
                    <span className="trip-remark-text">Remark: {trip.remark}</span>
                  )}
                </div>

                <div className="trip-col-progress">
                  {tab === 'active' ? (
                    <div>
                      <div className="progress-info-row">
                        <span>{trip.progress || 50}%</span>
                        <small>ETA: {trip.eta}</small>
                      </div>
                      <div className="progress-bar-small">
                        <div className="progress-fill" style={{ width: `${trip.progress || 50}%` }} />
                      </div>
                    </div>
                  ) : (
                    <div>
                      <strong className="delivered-time-text">{trip.completedAt || 'Recently'}</strong>
                      <span className="fuel-tag-sm">{trip.fuelEfficiency || 'Standard'}</span>
                    </div>
                  )}
                </div>

                <div className="trip-col-actions text-right">
                  <button
                    type="button"
                    className="action-btn-pill warning"
                    onClick={() =>
                      onSendDriverAlert({
                        driverId: trip.driverId,
                        driverName: trip.driverName,
                        vehiclePlate: trip.vehiclePlate,
                        vehicleModel: trip.vehicleModel,
                        title: `Route Alert: ${trip.id}`,
                        message: `Trip operational advisory for ${trip.driverName}: Check road traffic condition.`,
                        severity: 'warning',
                        category: 'Route',
                      })
                    }
                  >
                    Send Alert
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </section>

      {/* Modal for Creating New Trip */}
      {assignModalOpen && (
        <div className="modal-backdrop" onClick={() => setAssignModalOpen(false)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-head">
              <h2>Dispatch New Transport Trip</h2>
              <button type="button" className="modal-close" onClick={() => setAssignModalOpen(false)}>✕</button>
            </div>

            <form onSubmit={handleCreateTripSubmit} className="modal-form">
              <div className="form-group">
                <label>Select Driver & Vehicle</label>
                <select value={selectedDriverId} onChange={(e) => setSelectedDriverId(e.target.value)}>
                  {drivers.map((d) => (
                    <option key={d.id} value={d.id}>
                      {d.name} ({d.vehicle.plate} - {d.vehicle.model}) [{d.status.toUpperCase()}]
                    </option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label>Origin Hub</label>
                <input
                  required
                  placeholder="e.g. Jolva Industrial Area, Surat"
                  value={tripOrigin}
                  onChange={(e) => setTripOrigin(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>Destination</label>
                <input
                  required
                  placeholder="e.g. Sachin GIDC Logistics Park"
                  value={tripDestination}
                  onChange={(e) => setTripDestination(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>Cargo Details</label>
                <input
                  placeholder="e.g. 7.5 Ton Industrial Goods"
                  value={tripCargo}
                  onChange={(e) => setTripCargo(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>Estimated Distance</label>
                <input
                  value={tripDistance}
                  onChange={(e) => setTripDistance(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>Admin Remark / Instructions</label>
                <textarea
                  rows={2}
                  placeholder="e.g. Avoid toll bypass, urgent delivery, collect weighbridge slip"
                  value={tripRemark}
                  onChange={(e) => setTripRemark(e.target.value)}
                  className="alerts-textarea"
                />
              </div>

              <div className="modal-actions">
                <button type="button" className="secondary-action" onClick={() => setAssignModalOpen(false)}>
                  Cancel
                </button>
                <button type="submit" className="primary-action">
                  Confirm Dispatch
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
