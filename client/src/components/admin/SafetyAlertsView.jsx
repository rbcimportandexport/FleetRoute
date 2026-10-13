import React, { useState } from 'react';
import { ShieldAlert, ShieldCheck, Gauge, AlertTriangle, CheckCircle2, XCircle, Sliders, FileText, Info } from 'lucide-react';

export default function SafetyAlertsView({ safetyEvents = [], onUpdateStatus }) {
  const [speedThreshold, setSpeedThreshold] = useState(80);
  const [filterType, setFilterType] = useState('all');

  const filtered = safetyEvents.filter(e => {
    if (filterType === 'all') return true;
    return e.type === filterType;
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)' }}>
            Safety Telematics &amp; Driver Behavior
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Monitored speed thresholds, telemetry violation triggers, and seatbelt telematics review workflow.
          </p>
        </div>

        {/* Configurable Speed Threshold Control */}
        <div style={{
          background: '#ffffff',
          borderRadius: '12px',
          padding: '8px 16px',
          border: '1px solid var(--slate-200)',
          display: 'flex',
          alignItems: 'center',
          gap: '12px',
          boxShadow: 'var(--shadow-subtle)'
        }}>
          <Sliders size={16} color="var(--primary-blue)" />
          <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--slate-600)' }}>
            Fleet Speed Threshold:
          </span>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <input
              type="number"
              min="40"
              max="120"
              value={speedThreshold}
              onChange={(e) => setSpeedThreshold(parseInt(e.target.value, 10) || 80)}
              style={{
                width: '60px',
                padding: '4px 8px',
                borderRadius: '6px',
                border: '1px solid var(--slate-300)',
                fontFamily: 'var(--font-mono)',
                fontWeight: 700,
                fontSize: '13px',
                textAlign: 'center'
              }}
            />
            <span style={{ fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)' }}>km/h</span>
          </div>
        </div>
      </div>

      {/* Legal & Telematics Transparency Notice */}
      <div style={{
        background: 'var(--sky-blue-light)',
        border: '1px solid rgba(2, 132, 199, 0.25)',
        borderRadius: '12px',
        padding: '14px 18px',
        display: 'flex',
        alignItems: 'flex-start',
        gap: '12px'
      }}>
        <Info size={20} color="var(--primary-blue)" style={{ flexShrink: 0, marginTop: '2px' }} />
        <div style={{ fontSize: '12px', color: 'var(--navy-800)', lineHeight: '1.6' }}>
          <strong>Telematics Compliance Notice:</strong> Company speed thresholds reflect fleet safety policy calculated from authenticated real driver telemetry. 
          Browser GPS cannot confirm physical vehicle seatbelt engagement. Hardware-derived safety events only appear when integrated with authentic vehicle telematics hardware, or when drivers submit verified self-reports.
        </div>
      </div>

      {/* Filter Tabs */}
      <div style={{ display: 'flex', gap: '8px' }}>
        <button
          onClick={() => setFilterType('all')}
          className={`btn ${filterType === 'all' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '12px', padding: '6px 14px' }}
        >
          All Events ({safetyEvents.length})
        </button>
        <button
          onClick={() => setFilterType('overspeed')}
          className={`btn ${filterType === 'overspeed' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '12px', padding: '6px 14px' }}
        >
          Speed Violations
        </button>
        <button
          onClick={() => setFilterType('seatbelt')}
          className={`btn ${filterType === 'seatbelt' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ fontSize: '12px', padding: '6px 14px' }}
        >
          Seatbelt Alerts
        </button>
      </div>

      {/* Safety Events Review Cards */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
        {filtered.map((evt) => {
          const isOverspeed = evt.type === 'overspeed';
          return (
            <div
              key={evt.id}
              style={{
                background: '#ffffff',
                borderRadius: '14px',
                padding: '18px 20px',
                border: '1px solid var(--slate-200)',
                boxShadow: 'var(--shadow-card)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                flexWrap: 'wrap',
                gap: '16px'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: '14px' }}>
                <div style={{
                  width: '42px',
                  height: '42px',
                  borderRadius: '10px',
                  background: isOverspeed ? 'var(--status-rose-light)' : 'var(--status-amber-light)',
                  color: isOverspeed ? 'var(--status-rose)' : 'var(--status-amber)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0
                }}>
                  {isOverspeed ? <Gauge size={22} /> : <AlertTriangle size={22} />}
                </div>

                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                    <span style={{
                      fontSize: '11px',
                      fontWeight: 800,
                      textTransform: 'uppercase',
                      color: isOverspeed ? 'var(--status-rose)' : 'var(--status-amber)'
                    }}>
                      {isOverspeed ? 'Overspeed Violation' : 'Seatbelt Unbuckled Alert'}
                    </span>
                    <span style={{ fontSize: '11px', color: 'var(--slate-400)' }}>•</span>
                    <span style={{ fontSize: '11px', fontFamily: 'var(--font-mono)', color: 'var(--slate-500)' }}>
                      {evt.tripId}
                    </span>
                    <span style={{
                      fontSize: '10px',
                      fontWeight: 700,
                      padding: '2px 8px',
                      borderRadius: '9999px',
                      background: 'var(--slate-100)',
                      color: 'var(--slate-600)',
                      textTransform: 'uppercase'
                    }}>
                      Source: {evt.source}
                    </span>
                  </div>

                  <div style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-800)' }}>
                    Driver: {evt.driverName} • Vehicle: {evt.vehicleRegistration}
                  </div>

                  <div style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '2px' }}>
                    {isOverspeed 
                      ? `Recorded Speed: ${evt.recordedSpeed} km/h (Policy Limit: ${evt.speedThreshold || speedThreshold} km/h)` 
                      : `Telematics sensor triggered unbuckled state on transit segment`}
                  </div>

                  {evt.reviewerNotes && (
                    <div style={{ fontSize: '11px', color: 'var(--slate-600)', marginTop: '4px', fontStyle: 'italic' }}>
                      Dispatcher Note: "{evt.reviewerNotes}"
                    </div>
                  )}
                </div>
              </div>

              {/* Status & Review Action Controls */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={{
                  fontSize: '11px',
                  fontWeight: 800,
                  padding: '4px 10px',
                  borderRadius: '6px',
                  textTransform: 'uppercase',
                  background: evt.reviewStatus === 'confirmed' ? 'var(--status-rose-light)' : (evt.reviewStatus === 'dismissed' ? 'var(--slate-100)' : 'var(--sky-blue-light)'),
                  color: evt.reviewStatus === 'confirmed' ? 'var(--status-rose)' : (evt.reviewStatus === 'dismissed' ? 'var(--slate-500)' : 'var(--primary-blue)')
                }}>
                  {evt.reviewStatus.replace('_', ' ')}
                </span>

                <select
                  value={evt.reviewStatus}
                  onChange={(e) => onUpdateStatus(evt.id, e.target.value)}
                  style={{
                    background: '#ffffff',
                    border: '1px solid var(--slate-300)',
                    borderRadius: '8px',
                    padding: '6px 10px',
                    fontSize: '12px',
                    fontWeight: 600,
                    color: 'var(--navy-800)',
                    cursor: 'pointer'
                  }}
                >
                  <option value="new">New</option>
                  <option value="under_review">Under Review</option>
                  <option value="confirmed">Confirmed</option>
                  <option value="dismissed">Dismissed</option>
                </select>
              </div>
            </div>
          );
        })}
      </div>

    </div>
  );
}
