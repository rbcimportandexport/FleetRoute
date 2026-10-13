import React, { useState } from 'react';
import { 
  Route, 
  Search, 
  Plus, 
  MapPin, 
  Truck, 
  User, 
  Calendar, 
  Clock, 
  Boxes, 
  AlertTriangle, 
  CheckCircle2, 
  ShieldAlert,
  ArrowRight,
  ExternalLink,
  X
} from 'lucide-react';
import { api } from '../../utils/api';
import { soundEffects } from '../../utils/soundEffects';

export default function TripsManager({ 
  trips = [], 
  onCreateTripModal, 
  onSelectTrip,
  onRefreshTrips 
}) {
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [exceptionTrip, setExceptionTrip] = useState(null);
  const [exceptionReason, setExceptionReason] = useState('');
  const [exceptionDisposition, setExceptionDisposition] = useState('returned_to_depot');
  const [submittingException, setSubmittingException] = useState(false);

  const filteredTrips = trips.filter(t => {
    const q = searchTerm.toLowerCase();
    const matchesSearch = 
      t.id.toLowerCase().includes(q) ||
      (t.driverName && t.driverName.toLowerCase().includes(q)) ||
      (t.vehicleRegistration && t.vehicleRegistration.toLowerCase().includes(q));

    const matchesStatus = statusFilter === 'all' || (t.status || '').toLowerCase() === statusFilter.toLowerCase();
    return matchesSearch && matchesStatus;
  });

  const handleCloseException = async (e) => {
    e.preventDefault();
    if (!exceptionReason.trim()) return;

    setSubmittingException(true);
    soundEffects.playActionClick();

    try {
      await api.closeTripException(exceptionTrip.id, {
        reason: exceptionReason.trim(),
        unresolvedDisposition: exceptionDisposition
      });
      soundEffects.playSuccessChime();
      setExceptionTrip(null);
      setExceptionReason('');
      if (onRefreshTrips) onRefreshTrips();
    } catch (err) {
      console.error('Failed to close trip with exception:', err);
    } finally {
      setSubmittingException(false);
    }
  };

  const getStatusBadge = (status) => {
    const st = (status || '').toLowerCase();
    if (st === 'completed') {
      return { bg: 'var(--status-emerald-light)', color: 'var(--status-emerald-text)', label: 'Completed' };
    }
    if (st === 'in_progress' || st === 'in_transit') {
      return { bg: 'var(--sky-blue-light)', color: 'var(--primary-blue)', label: 'In Progress' };
    }
    if (st === 'delayed') {
      return { bg: 'var(--status-amber-light)', color: 'var(--status-amber-text)', label: 'Delayed' };
    }
    return { bg: 'var(--slate-100)', color: 'var(--slate-600)', label: 'Planned' };
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
            Trips &amp; Route Dispatch
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Manage multi-stop dispatches, route waypoints, driver allocations, and administrative exception closures.
          </p>
        </div>

        <button
          onClick={onCreateTripModal}
          className="btn btn-primary"
          style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
        >
          <Plus size={16} />
          Create Multi-Stop Trip
        </button>
      </div>

      {/* Filter and Search Bar */}
      <div style={{
        background: '#ffffff',
        padding: '14px 18px',
        borderRadius: '12px',
        border: '1px solid var(--slate-200)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '12px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flex: 1, minWidth: '240px' }}>
          <Search size={16} color="var(--slate-400)" />
          <input
            type="text"
            placeholder="Search by trip ID, driver name, or vehicle registration..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={{
              border: 'none',
              outline: 'none',
              fontSize: '13px',
              width: '100%',
              color: 'var(--navy-800)'
            }}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
          {[
            { id: 'all', label: `All (${trips.length})` },
            { id: 'in_progress', label: 'In Progress' },
            { id: 'planned', label: 'Planned' },
            { id: 'delayed', label: 'Delayed' },
            { id: 'completed', label: 'Completed' }
          ].map(f => (
            <button
              key={f.id}
              type="button"
              onClick={() => setStatusFilter(f.id)}
              style={{
                border: 'none',
                borderRadius: '8px',
                padding: '6px 12px',
                fontSize: '12px',
                fontWeight: 700,
                cursor: 'pointer',
                background: statusFilter === f.id ? 'var(--primary-blue)' : 'var(--slate-100)',
                color: statusFilter === f.id ? '#ffffff' : 'var(--slate-600)',
                transition: 'all 0.15s ease'
              }}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {/* Trips Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(380px, 1fr))', gap: '16px' }}>
        {filteredTrips.length === 0 ? (
          <div style={{
            gridColumn: '1 / -1',
            background: '#ffffff',
            borderRadius: '12px',
            padding: '48px 20px',
            textAlign: 'center',
            color: 'var(--slate-500)',
            border: '1px solid var(--slate-200)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '12px'
          }}>
            <div style={{ width: '48px', height: '48px', borderRadius: '50%', background: 'var(--slate-100)', color: 'var(--slate-400)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Route size={24} />
            </div>
            <div>
              <div style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)' }}>No trips found</div>
              <div style={{ fontSize: '12px', color: 'var(--slate-400)', marginTop: '4px' }}>No dispatches match the current search or status filter.</div>
            </div>
            <button
              type="button"
              onClick={onCreateTripModal}
              className="btn btn-primary"
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12.5px', marginTop: '6px' }}
            >
              <Plus size={15} />
              <span>Dispatch New Trip</span>
            </button>
          </div>
        ) : (
          filteredTrips.map(trip => {
            const badge = getStatusBadge(trip.status);
            const stopsCount = trip.stops?.length || 0;
            const currentIdx = trip.currentStopIndex || 0;
            const totalCargoLoaded = (trip.cargo || []).reduce((acc, c) => acc + (c.loadedQty || 0), 0);
            const totalCargoDelivered = (trip.cargo || []).reduce((acc, c) => acc + (c.deliveredQty || 0), 0);

            return (
              <div
                key={trip.id}
                style={{
                  background: '#ffffff',
                  borderRadius: '14px',
                  padding: '18px',
                  border: '1px solid var(--slate-200)',
                  boxShadow: 'var(--shadow-card)',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '12px'
                }}
              >
                {/* Trip ID & Status */}
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <div style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '8px',
                      background: 'var(--navy-800)',
                      color: '#ffffff',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center'
                    }}>
                      <Route size={16} />
                    </div>
                    <div>
                      <span style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-800)', fontFamily: 'var(--font-mono)' }}>
                        {trip.id}
                      </span>
                      <div style={{ fontSize: '11px', color: 'var(--slate-400)' }}>
                        Priority: <strong style={{ textTransform: 'capitalize' }}>{trip.priority || 'Standard'}</strong>
                      </div>
                    </div>
                  </div>

                  <span style={{
                    fontSize: '11px',
                    fontWeight: 700,
                    padding: '3px 8px',
                    borderRadius: '9999px',
                    background: badge.bg,
                    color: badge.color
                  }}>
                    {badge.label}
                  </span>
                </div>

                {/* Driver & Vehicle Allocation */}
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr 1fr',
                  gap: '8px',
                  background: 'var(--slate-50)',
                  padding: '10px 12px',
                  borderRadius: '10px',
                  border: '1px solid var(--slate-200)',
                  fontSize: '12px'
                }}>
                  <div>
                    <span style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>
                      Assigned Driver
                    </span>
                    <div style={{ fontWeight: 700, color: 'var(--navy-800)' }}>
                      {trip.driverName}
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                      {trip.driverPhone}
                    </div>
                  </div>

                  <div>
                    <span style={{ color: 'var(--slate-400)', fontSize: '10px', textTransform: 'uppercase', fontWeight: 700 }}>
                      Assigned Vehicle
                    </span>
                    <div style={{ fontWeight: 700, color: 'var(--navy-800)', fontFamily: 'var(--font-mono)' }}>
                      {trip.vehicleRegistration}
                    </div>
                  </div>
                </div>

                {/* Stops & Progress */}
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '12px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--slate-600)' }}>
                    <MapPin size={14} color="var(--primary-blue)" />
                    <span>{stopsCount} Stops (Current: #{currentIdx + 1})</span>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--slate-600)' }}>
                    <Boxes size={14} color="var(--primary-teal)" />
                    <span>Delivered: {totalCargoDelivered}/{totalCargoLoaded}</span>
                  </div>
                </div>

                {/* Notes or Exception Tag */}
                {trip.exceptionClosure ? (
                  <div style={{
                    background: 'var(--status-amber-light)',
                    border: '1px solid rgba(245, 158, 11, 0.3)',
                    borderRadius: '8px',
                    padding: '8px 10px',
                    fontSize: '11px',
                    color: 'var(--status-amber-text)'
                  }}>
                    <strong>Exception Closed:</strong> {trip.exceptionClosure.reason}
                  </div>
                ) : (
                  <div style={{ fontSize: '11px', color: 'var(--slate-500)', fontStyle: 'italic' }}>
                    {trip.notes || 'Multi-stop logistics manifest'}
                  </div>
                )}

                {/* Actions */}
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingTop: '8px', borderTop: '1px solid var(--slate-100)', marginTop: 'auto' }}>
                  <button
                    onClick={() => onSelectTrip(trip.id)}
                    className="btn btn-secondary"
                    style={{ padding: '6px 12px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
                  >
                    <span>View Manifest</span>
                    <ArrowRight size={13} />
                  </button>

                  {trip.status !== 'completed' && (
                    <button
                      onClick={() => setExceptionTrip(trip)}
                      className="btn btn-secondary"
                      style={{ padding: '6px 10px', fontSize: '11px', color: 'var(--status-amber-text)' }}
                      title="Authorize administrative closure"
                    >
                      <span>Authorize Exception</span>
                    </button>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Exception Authorization Modal */}
      {exceptionTrip && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(15, 23, 42, 0.6)',
          backdropFilter: 'blur(4px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '16px',
          zIndex: 9999
        }}>
          <div style={{
            background: '#ffffff',
            borderRadius: '16px',
            width: '100%',
            maxWidth: '480px',
            boxShadow: 'var(--shadow-modal)',
            overflow: 'hidden'
          }}>
            <div style={{
              background: 'var(--navy-800)',
              color: '#ffffff',
              padding: '18px 20px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <ShieldAlert size={18} color="#f59e0b" />
                <h3 style={{ fontSize: '16px', fontWeight: 800 }}>
                  Administrative Exception Closure ({exceptionTrip.id})
                </h3>
              </div>
              <button
                onClick={() => setExceptionTrip(null)}
                style={{ background: 'none', border: 'none', color: '#94a3b8', cursor: 'pointer' }}
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleCloseException} style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <p style={{ fontSize: '12px', color: 'var(--slate-500)', lineHeight: '1.5' }}>
                Authorize dispatcher closure of this trip when unresolved stops, damaged items, or customer cancellations occurred. An immutable audit record will be persisted.
              </p>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  Authorized Reason *
                </label>
                <textarea
                  required
                  rows="3"
                  value={exceptionReason}
                  onChange={(e) => setExceptionReason(e.target.value)}
                  placeholder="e.g. Recipient unavailable at Stop B; authorized return of 2 units to Bhiwandi Depot."
                  className="form-control"
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  Unresolved Items Disposition
                </label>
                <select
                  value={exceptionDisposition}
                  onChange={(e) => setExceptionDisposition(e.target.value)}
                  className="form-control"
                >
                  <option value="returned_to_depot">Return to Depot / Base</option>
                  <option value="rescheduled_tomorrow">Rescheduled for Next Day Dispatch</option>
                  <option value="quarantine_damaged">Quarantine Damaged Cargo at Hub</option>
                </select>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '6px' }}>
                <button
                  type="button"
                  onClick={() => setExceptionTrip(null)}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submittingException}
                  className="btn btn-primary"
                  style={{ background: '#d97706', border: 'none' }}
                >
                  {submittingException ? 'Authorizing...' : 'Authorize Closure'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
