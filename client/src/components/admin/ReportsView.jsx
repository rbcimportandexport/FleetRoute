import React, { useState } from 'react';
import { 
  BarChart3, 
  Download, 
  Printer, 
  Filter, 
  CheckCircle2, 
  Clock, 
  Fuel, 
  Wrench, 
  ShieldAlert,
  Truck,
  Users,
  Boxes,
  RotateCcw,
  Calendar,
  AlertTriangle
} from 'lucide-react';

export default function ReportsView({ trips = [], drivers = [], vehicles = [] }) {
  const [activeReportTab, setActiveReportTab] = useState('completion'); // 'completion' | 'drivers' | 'time' | 'safety'
  const [selectedDriver, setSelectedDriver] = useState('all');
  const [selectedVehicle, setSelectedVehicle] = useState('all');

  const filteredTrips = trips.filter(t => {
    if (selectedDriver !== 'all' && t.driverId !== selectedDriver) return false;
    if (selectedVehicle !== 'all' && t.vehicleId !== selectedVehicle) return false;
    return true;
  });

  // Export CSV handler tailored to active report
  const handleExportCSV = () => {
    let headers = [];
    let rows = [];
    let filename = `fleetroute_${activeReportTab}_report_${Date.now()}.csv`;

    if (activeReportTab === 'completion') {
      headers = ['Trip ID', 'Driver', 'Vehicle', 'Status', 'Stops', 'Planned Qty', 'Delivered Qty', 'Damaged/Rejected', 'Returned to Depot', 'Fulfillment Rate %'];
      rows = filteredTrips.map(t => {
        const planned = (t.cargo || []).reduce((acc, c) => acc + (c.plannedQty || 0), 0);
        const delivered = (t.cargo || []).reduce((acc, c) => acc + (c.deliveredQty || 0), 0);
        const damaged = (t.cargo || []).reduce((acc, c) => acc + ((c.damagedQty || 0) + (c.rejectedQty || 0)), 0);
        const returned = (t.cargo || []).reduce((acc, c) => acc + (c.returnedQty || 0), 0);
        const rate = planned > 0 ? Math.round((delivered / planned) * 100) : 100;
        return [t.id, `"${t.driverName}"`, t.vehicleRegistration, t.status, t.stops?.length || 0, planned, delivered, damaged, returned, rate];
      });
    } else if (activeReportTab === 'drivers') {
      headers = ['Driver ID', 'Name', 'Phone', 'Assigned Vehicle', 'Total Trips', 'Completed Trips', 'Active Assignment'];
      rows = drivers.map(d => {
        const dTrips = trips.filter(t => t.driverId === d.id);
        const completed = dTrips.filter(t => t.status === 'completed').length;
        const current = dTrips.find(t => t.status !== 'completed')?.id || 'None';
        return [d.id, `"${d.name}"`, d.phone, d.assignedVehicleId || 'Unassigned', dTrips.length, completed, current];
      });
    } else if (activeReportTab === 'time') {
      headers = ['Trip ID', 'Driver', 'Total Duration (min)', 'Driving (min)', 'Loading (min)', 'Unloading (min)', 'Delay Reason', 'Delay (min)', 'Fuel/Repair (INR)'];
      rows = filteredTrips.map(t => {
        const elapsed = t.elapsedMinutes || 0;
        const driving = (t.activities || []).filter(a => a.category === 'driving').reduce((sum, a) => sum + (a.durationMinutes || 0), 0);
        const loading = (t.activities || []).filter(a => a.category === 'loading').reduce((sum, a) => sum + (a.durationMinutes || 0), 0);
        const unloading = (t.activities || []).filter(a => a.category === 'unloading').reduce((sum, a) => sum + (a.durationMinutes || 0), 0);
        const delayReason = t.delayReason || (t.activities || []).find(a => ['traffic', 'puncture', 'breakdown', 'customer_waiting', 'other'].includes(a.category))?.notes || 'None';
        const delayMin = t.delayDurationMinutes || (t.activities || []).filter(a => ['traffic', 'puncture', 'breakdown', 'customer_waiting', 'other'].includes(a.category)).reduce((sum, a) => sum + (a.durationMinutes || 0), 0);
        const expense = t.expenses?.fuelOrRepair || 0;
        return [t.id, `"${t.driverName}"`, elapsed, driving, loading, unloading, `"${delayReason}"`, delayMin, expense];
      });
    } else {
      headers = ['Trip ID', 'Driver', 'Vehicle', 'Safety Event Type', 'Review Status', 'Timestamp'];
      rows = filteredTrips.flatMap(t => {
        return (t.safetyEvents || []).map(e => [t.id, `"${t.driverName}"`, t.vehicleRegistration, e.type, e.reviewStatus || 'new', e.timestamp || 'N/A']);
      });
    }

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(e => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handlePrint = () => {
    window.print();
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Header with Export & Print */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
            Operational Logistics Reports &amp; Audit
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Multi-stop performance metrics, time breakdowns, fuel and puncture expenditures, and completion ratios.
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <button
            onClick={handleExportCSV}
            className="btn btn-secondary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px' }}
          >
            <Download size={14} />
            Export CSV
          </button>
          <button
            onClick={handlePrint}
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px' }}
          >
            <Printer size={14} />
            Print Summary
          </button>
        </div>
      </div>

      {/* Navigation Sub-Tabs */}
      <div style={{
        display: 'flex',
        gap: '8px',
        borderBottom: '1px solid var(--slate-200)',
        paddingBottom: '8px',
        flexWrap: 'wrap'
      }}>
        <button
          onClick={() => setActiveReportTab('completion')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            padding: '8px 14px',
            borderRadius: '8px',
            border: 'none',
            cursor: 'pointer',
            fontSize: '13px',
            fontWeight: 700,
            background: activeReportTab === 'completion' ? 'var(--primary-blue)' : 'transparent',
            color: activeReportTab === 'completion' ? '#ffffff' : 'var(--slate-600)'
          }}
        >
          <CheckCircle2 size={15} />
          <span>Delivery Completion &amp; Cargo</span>
        </button>

        <button
          onClick={() => setActiveReportTab('drivers')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            padding: '8px 14px',
            borderRadius: '8px',
            border: 'none',
            cursor: 'pointer',
            fontSize: '13px',
            fontWeight: 700,
            background: activeReportTab === 'drivers' ? 'var(--primary-blue)' : 'transparent',
            color: activeReportTab === 'drivers' ? '#ffffff' : 'var(--slate-600)'
          }}
        >
          <Users size={15} />
          <span>Driver History &amp; Vehicles</span>
        </button>

        <button
          onClick={() => setActiveReportTab('time')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            padding: '8px 14px',
            borderRadius: '8px',
            border: 'none',
            cursor: 'pointer',
            fontSize: '13px',
            fontWeight: 700,
            background: activeReportTab === 'time' ? 'var(--primary-blue)' : 'transparent',
            color: activeReportTab === 'time' ? '#ffffff' : 'var(--slate-600)'
          }}
        >
          <Clock size={15} />
          <span>Arrival, Delays &amp; Expenses</span>
        </button>

        <button
          onClick={() => setActiveReportTab('safety')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            padding: '8px 14px',
            borderRadius: '8px',
            border: 'none',
            cursor: 'pointer',
            fontSize: '13px',
            fontWeight: 700,
            background: activeReportTab === 'safety' ? 'var(--primary-blue)' : 'transparent',
            color: activeReportTab === 'safety' ? '#ffffff' : 'var(--slate-600)'
          }}
        >
          <ShieldAlert size={15} />
          <span>Safety Review Outcomes</span>
        </button>
      </div>

      {/* Filter Bar */}
      <div style={{
        background: '#ffffff',
        padding: '12px 16px',
        borderRadius: '10px',
        border: '1px solid var(--slate-200)',
        display: 'flex',
        alignItems: 'center',
        gap: '16px',
        flexWrap: 'wrap'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <Filter size={15} color="var(--slate-400)" />
          <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--slate-600)' }}>Driver:</span>
          <select
            value={selectedDriver}
            onChange={(e) => setSelectedDriver(e.target.value)}
            style={{
              background: 'var(--slate-50)',
              border: '1px solid var(--slate-300)',
              borderRadius: '6px',
              padding: '5px 10px',
              fontSize: '12px',
              fontWeight: 600,
              color: 'var(--navy-800)'
            }}
          >
            <option value="all">All Drivers ({drivers.length})</option>
            {drivers.map(d => (
              <option key={d.id} value={d.id}>{d.name}</option>
            ))}
          </select>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--slate-600)' }}>Vehicle:</span>
          <select
            value={selectedVehicle}
            onChange={(e) => setSelectedVehicle(e.target.value)}
            style={{
              background: 'var(--slate-50)',
              border: '1px solid var(--slate-300)',
              borderRadius: '6px',
              padding: '5px 10px',
              fontSize: '12px',
              fontWeight: 600,
              color: 'var(--navy-800)'
            }}
          >
            <option value="all">All Vehicles ({vehicles.length})</option>
            {vehicles.map(v => (
              <option key={v.id} value={v.id}>{v.registrationNumber} ({v.model})</option>
            ))}
          </select>
        </div>
      </div>

      {/* REPORT CONTENT: DELIVERY COMPLETION */}
      {activeReportTab === 'completion' && (
        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '20px', border: '1px solid var(--slate-200)' }}>
          <h3 style={{ fontSize: '16px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '14px' }}>
            Delivery Completion &amp; Cargo Reconciliation ({filteredTrips.length} Trips)
          </h3>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
              <thead>
                <tr style={{ borderBottom: '2px solid var(--slate-200)', textAlign: 'left', color: 'var(--slate-500)', fontSize: '11px', textTransform: 'uppercase' }}>
                  <th style={{ padding: '10px 12px' }}>Trip ID</th>
                  <th style={{ padding: '10px 12px' }}>Driver</th>
                  <th style={{ padding: '10px 12px' }}>Vehicle</th>
                  <th style={{ padding: '10px 12px' }}>Status</th>
                  <th style={{ padding: '10px 12px' }}>Planned Qty</th>
                  <th style={{ padding: '10px 12px' }}>Delivered</th>
                  <th style={{ padding: '10px 12px' }}>Damaged/Reject</th>
                  <th style={{ padding: '10px 12px' }}>Depot Return</th>
                  <th style={{ padding: '10px 12px' }}>Fulfillment</th>
                </tr>
              </thead>
              <tbody>
                {filteredTrips.map((t) => {
                  const planned = (t.cargo || []).reduce((acc, c) => acc + (c.plannedQty || 0), 0);
                  const delivered = (t.cargo || []).reduce((acc, c) => acc + (c.deliveredQty || 0), 0);
                  const damaged = (t.cargo || []).reduce((acc, c) => acc + ((c.damagedQty || 0) + (c.rejectedQty || 0)), 0);
                  const returned = (t.cargo || []).reduce((acc, c) => acc + (c.returnedQty || 0), 0);
                  const rate = planned > 0 ? Math.round((delivered / planned) * 100) : 100;

                  return (
                    <tr key={t.id} style={{ borderBottom: '1px solid var(--slate-100)' }}>
                      <td style={{ padding: '12px', fontWeight: 700, fontFamily: 'var(--font-mono)', color: 'var(--navy-800)' }}>
                        {t.id}
                      </td>
                      <td style={{ padding: '12px', fontWeight: 600, color: 'var(--navy-800)' }}>{t.driverName}</td>
                      <td style={{ padding: '12px', fontFamily: 'var(--font-mono)', color: 'var(--slate-600)' }}>{t.vehicleRegistration}</td>
                      <td style={{ padding: '12px' }}>
                        <span style={{
                          fontSize: '10px',
                          fontWeight: 700,
                          padding: '3px 8px',
                          borderRadius: '9999px',
                          textTransform: 'uppercase',
                          background: t.status === 'completed' ? 'var(--status-emerald-light)' : 'var(--sky-blue-light)',
                          color: t.status === 'completed' ? 'var(--status-emerald-text)' : 'var(--primary-blue)'
                        }}>
                          {t.status.replace('_', ' ')}
                        </span>
                      </td>
                      <td style={{ padding: '12px', fontWeight: 600 }}>{planned} units</td>
                      <td style={{ padding: '12px', fontWeight: 700, color: 'var(--status-emerald)' }}>{delivered} units</td>
                      <td style={{ padding: '12px', fontWeight: 600, color: damaged > 0 ? '#b91c1c' : 'var(--slate-400)' }}>
                        {damaged} units
                      </td>
                      <td style={{ padding: '12px', fontWeight: 600, color: returned > 0 ? '#d97706' : 'var(--slate-400)' }}>
                        {returned} units
                      </td>
                      <td style={{ padding: '12px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <div style={{ width: '60px', height: '6px', borderRadius: '3px', background: 'var(--slate-200)', overflow: 'hidden' }}>
                            <div style={{ width: `${rate}%`, height: '100%', background: rate >= 90 ? 'var(--status-emerald)' : 'var(--primary-blue)' }} />
                          </div>
                          <span style={{ fontSize: '11px', fontWeight: 700, color: 'var(--navy-800)' }}>{rate}%</span>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* REPORT CONTENT: DRIVER TRIP HISTORY & VEHICLE USAGE */}
      {activeReportTab === 'drivers' && (
        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '20px', border: '1px solid var(--slate-200)' }}>
          <h3 style={{ fontSize: '16px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '14px' }}>
            Driver Roster &amp; Vehicle Usage Allocation ({drivers.length} Drivers)
          </h3>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
              <thead>
                <tr style={{ borderBottom: '2px solid var(--slate-200)', textAlign: 'left', color: 'var(--slate-500)', fontSize: '11px', textTransform: 'uppercase' }}>
                  <th style={{ padding: '10px 12px' }}>Driver</th>
                  <th style={{ padding: '10px 12px' }}>Phone</th>
                  <th style={{ padding: '10px 12px' }}>Assigned Vehicle</th>
                  <th style={{ padding: '10px 12px' }}>Total Trips</th>
                  <th style={{ padding: '10px 12px' }}>Completed</th>
                  <th style={{ padding: '10px 12px' }}>Current Active Trip</th>
                </tr>
              </thead>
              <tbody>
                {drivers.map(d => {
                  const dTrips = trips.filter(t => t.driverId === d.id);
                  const completed = dTrips.filter(t => t.status === 'completed').length;
                  const active = dTrips.find(t => t.status !== 'completed');

                  return (
                    <tr key={d.id} style={{ borderBottom: '1px solid var(--slate-100)' }}>
                      <td style={{ padding: '12px', fontWeight: 700, color: 'var(--navy-800)' }}>{d.name}</td>
                      <td style={{ padding: '12px', color: 'var(--slate-600)' }}>{d.phone}</td>
                      <td style={{ padding: '12px', fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{d.assignedVehicleId || 'Unassigned'}</td>
                      <td style={{ padding: '12px', fontWeight: 600 }}>{dTrips.length}</td>
                      <td style={{ padding: '12px', fontWeight: 700, color: 'var(--status-emerald)' }}>{completed}</td>
                      <td style={{ padding: '12px' }}>
                        {active ? (
                          <span style={{ fontSize: '11px', fontWeight: 700, color: 'var(--primary-blue)', fontFamily: 'var(--font-mono)' }}>
                            {active.id} ({active.status})
                          </span>
                        ) : (
                          <span style={{ fontSize: '11px', color: 'var(--slate-400)' }}>Available</span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* REPORT CONTENT: ARRIVAL, DELAYS & EXPENSES */}
      {activeReportTab === 'time' && (
        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '20px', border: '1px solid var(--slate-200)' }}>
          <h3 style={{ fontSize: '16px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '14px' }}>
            Time Breakdown, Delay Reasons &amp; Operational Expenses
          </h3>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
              <thead>
                <tr style={{ borderBottom: '2px solid var(--slate-200)', textAlign: 'left', color: 'var(--slate-500)', fontSize: '11px', textTransform: 'uppercase' }}>
                  <th style={{ padding: '10px 12px' }}>Trip ID</th>
                  <th style={{ padding: '10px 12px' }}>Driver</th>
                  <th style={{ padding: '10px 12px' }}>Total Elapsed</th>
                  <th style={{ padding: '10px 12px' }}>Loading Time</th>
                  <th style={{ padding: '10px 12px' }}>Unloading Time</th>
                  <th style={{ padding: '10px 12px' }}>Recorded Delay Reason</th>
                  <th style={{ padding: '10px 12px' }}>Delay Duration</th>
                  <th style={{ padding: '10px 12px' }}>Fuel / Repair</th>
                </tr>
              </thead>
              <tbody>
                {filteredTrips.map(t => {
                  const elapsed = t.elapsedMinutes || 0;
                  const loading = (t.activities || []).filter(a => a.category === 'loading').reduce((sum, a) => sum + (a.durationMinutes || 0), 0);
                  const unloading = (t.activities || []).filter(a => a.category === 'unloading').reduce((sum, a) => sum + (a.durationMinutes || 0), 0);
                  const delayReason = t.delayReason || (t.activities || []).find(a => ['traffic', 'puncture', 'breakdown', 'customer_waiting', 'other'].includes(a.category))?.notes || 'None reported';
                  const delayMin = t.delayDurationMinutes || (t.activities || []).filter(a => ['traffic', 'puncture', 'breakdown', 'customer_waiting', 'other'].includes(a.category)).reduce((sum, a) => sum + (a.durationMinutes || 0), 0);
                  const expense = t.expenses?.fuelOrRepair || 0;

                  return (
                    <tr key={t.id} style={{ borderBottom: '1px solid var(--slate-100)' }}>
                      <td style={{ padding: '12px', fontWeight: 700, fontFamily: 'var(--font-mono)', color: 'var(--navy-800)' }}>{t.id}</td>
                      <td style={{ padding: '12px', fontWeight: 600 }}>{t.driverName}</td>
                      <td style={{ padding: '12px', fontWeight: 700 }}>{elapsed} min</td>
                      <td style={{ padding: '12px', color: 'var(--slate-600)' }}>{loading} min</td>
                      <td style={{ padding: '12px', color: 'var(--slate-600)' }}>{unloading} min</td>
                      <td style={{ padding: '12px', fontWeight: 600, color: t.status === 'delayed' ? '#b91c1c' : 'var(--slate-500)' }}>
                        {t.delayReason || (t.status === 'delayed' ? 'Delayed' : 'None reported')}
                      </td>
                      <td style={{ padding: '12px', fontWeight: 700, color: (t.delayDurationMinutes || 0) > 0 ? '#b91c1c' : 'var(--slate-400)' }}>
                        {(t.delayDurationMinutes || 0) > 0 ? `${t.delayDurationMinutes} min` : '0 min'}
                      </td>
                      <td style={{ padding: '12px', fontFamily: 'var(--font-mono)', fontWeight: 600 }}>
                        {expense > 0 ? `INR ${expense}` : 'INR 0'}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* REPORT CONTENT: SAFETY REVIEW OUTCOMES */}
      {activeReportTab === 'safety' && (
        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '20px', border: '1px solid var(--slate-200)' }}>
          <h3 style={{ fontSize: '16px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '14px' }}>
            Telematics Incident Reviews &amp; Outcomes
          </h3>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
              <thead>
                <tr style={{ borderBottom: '2px solid var(--slate-200)', textAlign: 'left', color: 'var(--slate-500)', fontSize: '11px', textTransform: 'uppercase' }}>
                  <th style={{ padding: '10px 12px' }}>Event ID</th>
                  <th style={{ padding: '10px 12px' }}>Type</th>
                  <th style={{ padding: '10px 12px' }}>Driver</th>
                  <th style={{ padding: '10px 12px' }}>Vehicle</th>
                  <th style={{ padding: '10px 12px' }}>Telemetry Source</th>
                  <th style={{ padding: '10px 12px' }}>Review State</th>
                  <th style={{ padding: '10px 12px' }}>Reviewer Notes</th>
                </tr>
              </thead>
              <tbody>
                {filteredTrips.flatMap(t => t.safetyEvents || []).length === 0 ? (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', padding: '24px', color: 'var(--slate-400)' }}>
                      No safety events recorded across selected trips.
                    </td>
                  </tr>
                ) : (
                  filteredTrips.flatMap(t => t.safetyEvents || []).map((evt, idx) => (
                    <tr key={evt.id || idx} style={{ borderBottom: '1px solid var(--slate-100)' }}>
                      <td style={{ padding: '12px', fontFamily: 'var(--font-mono)', fontWeight: 700 }}>{evt.id || `EVT-${idx + 1}`}</td>
                      <td style={{ padding: '12px', fontWeight: 700, color: evt.type === 'overspeed' ? '#b91c1c' : '#d97706', textTransform: 'uppercase', fontSize: '11px' }}>
                        {evt.type}
                      </td>
                      <td style={{ padding: '12px', fontWeight: 600 }}>{evt.driverName || 'N/A'}</td>
                      <td style={{ padding: '12px', fontFamily: 'var(--font-mono)' }}>{evt.vehicleRegistration || 'N/A'}</td>
                      <td style={{ padding: '12px', color: 'var(--slate-500)' }}>{evt.source || 'telematics GPS'}</td>
                      <td style={{ padding: '12px' }}>
                        <span style={{
                          fontSize: '10px',
                          fontWeight: 700,
                          padding: '3px 8px',
                          borderRadius: '9999px',
                          textTransform: 'uppercase',
                          background: evt.reviewStatus === 'confirmed' ? 'rgba(239, 68, 68, 0.15)' : (evt.reviewStatus === 'dismissed' ? 'var(--slate-200)' : 'rgba(245, 158, 11, 0.15)'),
                          color: evt.reviewStatus === 'confirmed' ? '#b91c1c' : (evt.reviewStatus === 'dismissed' ? 'var(--slate-600)' : '#b45309')
                        }}>
                          {evt.reviewStatus || 'new'}
                        </span>
                      </td>
                      <td style={{ padding: '12px', color: 'var(--slate-600)', fontSize: '12px' }}>
                        {evt.notes || 'Audited by Fleet Safety Dispatch'}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

    </div>
  );
}
