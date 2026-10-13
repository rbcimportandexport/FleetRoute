import React, { useState } from 'react';
import { Boxes, ArrowDownLeft, ArrowUpRight, AlertTriangle, RotateCcw, CheckCircle2, ShieldCheck, Layers, FileText } from 'lucide-react';

export default function CargoLedgerView({ trips = [], activeTrip }) {
  const [selectedTripId, setSelectedTripId] = useState(activeTrip?.id || (trips[0]?.id || ''));

  if (!trips || trips.length === 0) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
            Cargo Manifest &amp; Inventory Ledger
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Multi-product compartmentalization, onboard inventory balances, and immutable audit ledgers.
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
          <Boxes size={40} style={{ margin: '0 auto 12px', color: 'var(--slate-400)' }} />
          <h3 style={{ fontSize: '16px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '6px' }}>
            No Trips Recorded
          </h3>
          <p style={{ fontSize: '13px' }}>
            Create a trip with assigned cargo to view onboard manifest balances and delivery ledgers.
          </p>
        </div>
      </div>
    );
  }

  const trip = trips.find(t => t.id === selectedTripId) || trips[0];

  const totalLoaded = (trip?.cargo || []).reduce((acc, c) => acc + (c.loadedQty || 0), 0);
  const totalDelivered = (trip?.cargo || []).reduce((acc, c) => acc + (c.deliveredQty || 0), 0);
  const totalDamaged = (trip?.cargo || []).reduce((acc, c) => acc + (c.damagedQty || 0), 0);
  const totalRejected = (trip?.cargo || []).reduce((acc, c) => acc + (c.rejectedQty || 0), 0);
  const totalReturned = (trip?.cargo || []).reduce((acc, c) => acc + (c.returnedQty || 0), 0);
  const totalOnboard = totalLoaded - totalDelivered - totalDamaged - totalRejected - totalReturned;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Header & Trip Selector */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
            Cargo Manifest &amp; Inventory Ledger
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Multi-product compartmentalization, onboard inventory balances, and immutable audit ledgers.
          </p>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--slate-500)' }}>Select Trip:</span>
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
                {t.id} - {t.driverName} ({t.status.toUpperCase()})
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Cargo Status Metrics Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
        gap: '14px'
      }}>
        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '16px', border: '1px solid var(--slate-200)', boxShadow: 'var(--shadow-card)' }}>
          <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--slate-500)', textTransform: 'uppercase' }}>Loaded at Pickup</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)', marginTop: '4px' }}>{totalLoaded}</div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '16px', border: '1px solid var(--slate-200)', boxShadow: 'var(--shadow-card)' }}>
          <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--primary-blue)', textTransform: 'uppercase' }}>Currently Onboard</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: 'var(--primary-blue)', marginTop: '4px' }}>{totalOnboard}</div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '16px', border: '1px solid var(--slate-200)', boxShadow: 'var(--shadow-card)' }}>
          <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--status-emerald)', textTransform: 'uppercase' }}>Delivered Successfully</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: 'var(--status-emerald)', marginTop: '4px' }}>{totalDelivered}</div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '16px', border: '1px solid var(--slate-200)', boxShadow: 'var(--shadow-card)' }}>
          <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--status-rose)', textTransform: 'uppercase' }}>Damaged / Rejected</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: 'var(--status-rose)', marginTop: '4px' }}>{totalDamaged + totalRejected}</div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '12px', padding: '16px', border: '1px solid var(--slate-200)', boxShadow: 'var(--shadow-card)' }}>
          <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--status-amber)', textTransform: 'uppercase' }}>Returned to Depot</div>
          <div style={{ fontSize: '24px', fontWeight: 800, color: 'var(--status-amber)', marginTop: '4px' }}>{totalReturned}</div>
        </div>
      </div>

      {/* Cargo Items Table */}
      <div style={{
        background: '#ffffff',
        borderRadius: '16px',
        padding: '20px',
        boxShadow: 'var(--shadow-card)',
        border: '1px solid var(--slate-200)'
      }}>
        <h3 style={{ fontSize: '16px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '14px' }}>
          Manifest Lines for {trip?.id}
        </h3>

        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
            <thead>
              <tr style={{ borderBottom: '2px solid var(--slate-200)', textAlign: 'left', color: 'var(--slate-500)', fontSize: '11px', textTransform: 'uppercase' }}>
                <th style={{ padding: '10px 12px' }}>Product</th>
                <th style={{ padding: '10px 12px' }}>Category</th>
                <th style={{ padding: '10px 12px' }}>Planned</th>
                <th style={{ padding: '10px 12px' }}>Loaded</th>
                <th style={{ padding: '10px 12px' }}>Delivered</th>
                <th style={{ padding: '10px 12px' }}>Damaged</th>
                <th style={{ padding: '10px 12px' }}>Returned</th>
                <th style={{ padding: '10px 12px' }}>Current Onboard</th>
              </tr>
            </thead>
            <tbody>
              {trip?.cargo?.map((item) => {
                const onboard = item.loadedQty - item.deliveredQty - item.damagedQty - item.rejectedQty - item.returnedQty;
                return (
                  <tr key={item.id} style={{ borderBottom: '1px solid var(--slate-100)' }}>
                    <td style={{ padding: '12px', fontWeight: 700, color: 'var(--navy-800)' }}>
                      {item.productName}
                      {item.fragile && (
                        <span style={{ marginLeft: '6px', fontSize: '10px', background: 'var(--status-rose-light)', color: 'var(--status-rose)', padding: '2px 6px', borderRadius: '4px', fontWeight: 800 }}>
                          FRAGILE
                        </span>
                      )}
                    </td>
                    <td style={{ padding: '12px', color: 'var(--slate-500)' }}>{item.category}</td>
                    <td style={{ padding: '12px', fontWeight: 600 }}>{item.plannedQty}</td>
                    <td style={{ padding: '12px', fontWeight: 600, color: 'var(--navy-800)' }}>{item.loadedQty}</td>
                    <td style={{ padding: '12px', fontWeight: 700, color: 'var(--status-emerald)' }}>{item.deliveredQty}</td>
                    <td style={{ padding: '12px', fontWeight: 600, color: item.damagedQty > 0 ? 'var(--status-rose)' : 'var(--slate-400)' }}>
                      {item.damagedQty}
                    </td>
                    <td style={{ padding: '12px', fontWeight: 600, color: item.returnedQty > 0 ? 'var(--status-amber)' : 'var(--slate-400)' }}>
                      {item.returnedQty}
                    </td>
                    <td style={{ padding: '12px', fontWeight: 800, color: 'var(--primary-blue)', fontSize: '14px' }}>
                      {onboard} {item.unit}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

    </div>
  );
}
