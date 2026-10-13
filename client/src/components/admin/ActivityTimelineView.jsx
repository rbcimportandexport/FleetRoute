import React, { useState } from 'react';
import { Clock, Car, Fuel, Wrench, AlertTriangle, Coffee, CheckCircle2, Timer, Layers, ShieldCheck, Shield } from 'lucide-react';
import GateProofPhotosCard from '../common/GateProofPhotosCard';

export default function ActivityTimelineView({ trips = [], activeTrip }) {
  const [selectedTripId, setSelectedTripId] = useState(activeTrip?.id || (trips[0]?.id || ''));

  if (!trips || trips.length === 0) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
            Activity &amp; Operational Delay Timeline
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Atomic, non-overlapping intervals displaying driving, loading, delays, and repairs in Asia/Kolkata (IST).
          </p>
        </div>
        <div style={{
          background: '#ffffff',
          borderRadius: '16px',
          padding: '48px 24px',
          textAlign: 'center',
          border: '1px solid var(--slate-200)',
          color: 'var(--slate-500)'
        }}>
          <Clock size={40} style={{ margin: '0 auto 12px', color: 'var(--slate-400)' }} />
          <h3 style={{ fontSize: '16px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
            No Trips Recorded
          </h3>
          <p style={{ fontSize: '13px' }}>
            Trips and operational driver activity intervals will appear here once recorded.
          </p>
        </div>
      </div>
    );
  }

  const trip = trips.find(t => t.id === selectedTripId) || trips[0];

  const categoryIcons = {
    driving: Car,
    loading: Layers,
    unloading: CheckCircle2,
    traffic: AlertTriangle,
    refueling: Fuel,
    puncture: Wrench,
    breakdown: AlertTriangle,
    challan_stoppage: Shield,
    customer_waiting: Timer,
    break: Coffee,
    other: Clock
  };

  const categoryColors = {
    driving: '#0284c7',
    loading: '#0d9488',
    unloading: '#10b981',
    traffic: '#f59e0b',
    refueling: '#d97706',
    puncture: '#ef4444',
    breakdown: '#b91c1c',
    challan_stoppage: '#0f172a',
    customer_waiting: '#6366f1',
    break: '#8b5cf6',
    other: '#64748b'
  };

  // Group durations
  const breakdown = (trip?.activities || []).reduce((acc, a) => {
    acc[a.category] = (acc[a.category] || 0) + (a.durationMinutes || 0);
    return acc;
  }, {});

  const totalCategorized = Object.values(breakdown).reduce((acc, v) => acc + v, 0);
  const drivingTime = breakdown.driving || 0;
  const operationalStopTime = totalCategorized - drivingTime;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
            Activity &amp; Operational Delay Timeline
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Atomic, non-overlapping intervals displaying driving, loading, delays, and repairs in Asia/Kolkata (IST).
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--slate-500)' }}>Trip:</span>
          <select
            value={selectedTripId || trip?.id}
            onChange={(e) => setSelectedTripId(e.target.value)}
            style={{
              background: '#ffffff',
              border: '1px solid var(--slate-300)',
              borderRadius: '8px',
              padding: '6px 12px',
              fontSize: '13px',
              fontWeight: 700,
              color: 'var(--navy-800)'
            }}
          >
            {trips.map(t => (
              <option key={t.id} value={t.id}>
                {t.id} - {t.driverName}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Overview KPI Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
        gap: '14px'
      }}>
        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '16px', border: '1px solid var(--slate-200)', boxShadow: 'var(--shadow-card)' }}>
          <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--slate-500)', textTransform: 'uppercase' }}>Total Elapsed Journey</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)', marginTop: '4px' }}>
            {totalCategorized} <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--slate-400)' }}>min</span>
          </div>
          <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '2px' }}>
            {Math.floor(totalCategorized / 60)}h {totalCategorized % 60}m authoritative server time
          </div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '16px', border: '1px solid var(--slate-200)', boxShadow: 'var(--shadow-card)' }}>
          <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--primary-blue)', textTransform: 'uppercase' }}>Active Driving Time</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: 'var(--primary-blue)', marginTop: '4px' }}>
            {drivingTime} <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--slate-400)' }}>min</span>
          </div>
          <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '2px' }}>
            Wheel in motion on transit legs
          </div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '16px', border: '1px solid var(--slate-200)', boxShadow: 'var(--shadow-card)' }}>
          <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--primary-teal)', textTransform: 'uppercase' }}>Operational Stop &amp; Delay Time</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: 'var(--primary-teal)', marginTop: '4px' }}>
            {operationalStopTime} <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--slate-400)' }}>min</span>
          </div>
          <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '2px' }}>
            Loading, unloading, maintenance &amp; halts
          </div>
        </div>
      </div>

      {/* Mandatory Pre-Trip Gate Proof Photos Verification (Admin Audit) */}
      <GateProofPhotosCard
        trip={trip}
        readOnly={true}
        depotName={trip?.stops?.[0]?.location?.name || 'Depot 4'}
      />

      {/* Detailed Chronological Timeline Table */}
      <div style={{
        background: '#ffffff',
        borderRadius: '16px',
        padding: '20px',
        boxShadow: 'var(--shadow-card)',
        border: '1px solid var(--slate-200)'
      }}>
        <h3 style={{ fontSize: '16px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '14px' }}>
          Chronological Event Ledger for {trip?.id}
        </h3>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
          {(trip?.activities || []).map((act, idx) => {
            const Icon = categoryIcons[act.category] || Clock;
            const color = categoryColors[act.category] || '#64748b';
            const startStr = act.startTime ? act.startTime.slice(11, 16) : '00:00';
            const endStr = act.endTime ? act.endTime.slice(11, 16) : 'Active';

            return (
              <div
                key={act.id || idx}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 16px',
                  borderRadius: '12px',
                  background: 'var(--slate-50)',
                  border: '1px solid var(--slate-200)'
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <div style={{
                    width: '36px',
                    height: '36px',
                    borderRadius: '8px',
                    background: `${color}15`,
                    color,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}>
                    <Icon size={18} />
                  </div>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <span style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-800)', textTransform: 'capitalize' }}>
                        {act.category.replace('_', ' ')}
                      </span>
                      <span style={{
                        fontSize: '11px',
                        fontWeight: 700,
                        padding: '2px 6px',
                        borderRadius: '4px',
                        background: `${color}20`,
                        color
                      }}>
                        {act.durationMinutes} min
                      </span>
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '2px' }}>
                      {act.notes || 'Routine transit movement'}
                    </div>
                    {act.details && (
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)', marginTop: '2px', fontWeight: 600 }}>
                        {act.details.fuelLiters && `Liters: ${act.details.fuelLiters}L • Cost: INR ${act.details.fuelCost}`}
                        {act.details.repairCost && `Repair: INR ${act.details.repairCost} • ${act.details.repairDesc}`}
                        {act.details.challanNumber && `Challan #${act.details.challanNumber} • Penalty: INR ${act.details.penaltyAmount} • ${act.details.settlementOption === 'cash_spot' ? 'Driver Paid Cash (Immediate UPI)' : act.details.settlementOption}`}
                        {act.details.breakdownCategory && `Issue: ${act.details.breakdownCategory.toUpperCase()} • Photos: ${act.details.photosCount || 0} • Voice Note: ${act.details.voiceNote ? 'Attached' : 'None'}`}
                      </div>
                    )}
                  </div>
                </div>

                <div style={{ textAlign: 'right', fontSize: '12px', color: 'var(--slate-600)', fontFamily: 'var(--font-mono)' }}>
                  <div>{startStr} - {endStr} IST</div>
                  <div style={{ fontSize: '11px', color: 'var(--slate-400)' }}>
                    Source: {act.source}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

    </div>
  );
}
