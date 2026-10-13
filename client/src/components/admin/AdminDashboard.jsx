import React, { useState } from 'react';
import { 
  Truck, 
  Users, 
  MapPin, 
  Route, 
  CheckCircle2, 
  Clock, 
  AlertTriangle, 
  ShieldAlert, 
  Boxes, 
  Plus, 
  ArrowUpRight, 
  Calendar,
  Layers,
  Fuel,
  Search,
  HelpCircle,
  Zap,
  Sparkles,
  ChevronDown,
  ChevronUp,
  X
} from 'lucide-react';
import FleetMap from '../map/FleetMap';
import { useTranslation } from '../../hooks/useTranslation';

export default function AdminDashboard({
  stats = {},
  trips = [],
  activeTrip,
  safetyEvents = [],
  onSelectTrip,
  onCreateTripModal,
  onViewAllTrips,
  onViewSafety,
  onNavigateTab
}) {
  const { t, lang } = useTranslation();
  const [tripSearch, setTripSearch] = useState('');
  const [tripFilter, setTripFilter] = useState('all');
  const [showWorkflowGuide, setShowWorkflowGuide] = useState(false);

  const filteredTrips = trips.filter(t => {
    const q = tripSearch.toLowerCase().trim();
    const matchesSearch = !q || 
      t.id?.toLowerCase().includes(q) || 
      t.driverName?.toLowerCase().includes(q) || 
      t.vehicleRegistration?.toLowerCase().includes(q);

    const status = (t.status || '').toLowerCase();
    const matchesFilter = tripFilter === 'all' || 
      (tripFilter === 'active' && (status === 'in_transit' || status === 'in_progress' || status === 'planned')) ||
      (tripFilter === 'completed' && status === 'completed') ||
      (tripFilter === 'delayed' && status === 'delayed');

    return matchesSearch && matchesFilter;
  });

  const metricCards = [
    {
      id: 'active-trips',
      label: t('kpiActiveDispatched'),
      value: stats.activeTrips ?? 0,
      subtext: t('kpiActiveDispatchedSub'),
      icon: Route,
      color: 'var(--primary-blue)',
      bg: 'var(--sky-blue-light)'
    },
    {
      id: 'drivers-duty',
      label: t('kpiDriversDuty'),
      value: stats.driversOnDuty ?? 0,
      subtext: t('kpiDriversDutySub'),
      icon: Users,
      color: 'var(--primary-teal)',
      bg: 'rgba(13, 148, 136, 0.1)'
    },
    {
      id: 'avail-vehicles',
      label: t('kpiAvailableFleet'),
      value: stats.availableVehicles ?? 0,
      subtext: t('kpiAvailableFleetSub'),
      icon: Truck,
      color: '#4f46e5',
      bg: 'rgba(79, 70, 229, 0.1)'
    },
    {
      id: 'completed-deliv',
      label: t('kpiCompletedToday'),
      value: stats.completedDeliveriesToday ?? 0,
      subtext: t('kpiCompletedTodaySub'),
      icon: CheckCircle2,
      color: 'var(--status-emerald)',
      bg: 'var(--status-emerald-light)'
    },
    {
      id: 'pending-deliv',
      label: t('kpiPendingDrops'),
      value: stats.pendingDeliveries ?? 0,
      subtext: t('kpiPendingDropsSub'),
      icon: Clock,
      color: 'var(--status-amber)',
      bg: 'var(--status-amber-light)'
    },
    {
      id: 'delayed-trips',
      label: t('kpiDelayedTrips'),
      value: stats.delayedTrips ?? 0,
      subtext: t('kpiDelayedTripsSub'),
      icon: AlertTriangle,
      color: '#d97706',
      bg: 'rgba(217, 119, 6, 0.1)'
    },
    {
      id: 'safety-alerts',
      label: t('kpiSafetyAlerts'),
      value: stats.activeSafetyAlerts ?? 0,
      subtext: t('kpiSafetyAlertsSub'),
      icon: ShieldAlert,
      color: 'var(--status-rose)',
      bg: 'var(--status-rose-light)'
    }
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '18px', width: '100%', maxWidth: '1400px', margin: '0 auto' }}>
      
      {/* Header with Responsive Action Button */}
      <div style={{ 
        display: 'flex', 
        alignItems: 'flex-start', 
        justifyContent: 'space-between', 
        flexWrap: 'wrap', 
        gap: '12px' 
      }}>
        <div style={{ flex: '1 1 260px' }}>
          <h1 style={{ fontSize: '20px', fontWeight: 800, color: 'var(--navy-800)', letterSpacing: '-0.02em', lineHeight: 1.25 }}>
            {t('hubHeaderTitle')}
          </h1>
          <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '4px' }}>
            {t('hubHeaderDesc')}
          </p>
        </div>

        <button
          onClick={onCreateTripModal}
          className="btn btn-primary"
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '8px',
            padding: '10px 16px',
            fontSize: '13px',
            fontWeight: 700,
            flex: '0 0 auto'
          }}
        >
          <Plus size={16} />
          <span>{t('hubCreateTripBtn')}</span>
        </button>
      </div>

      {/* Operations Live Status Banner & Easy Guide Toggle */}
      <div style={{
        background: 'linear-gradient(135deg, rgba(2, 132, 199, 0.08) 0%, rgba(13, 148, 136, 0.08) 100%)',
        border: '1px solid rgba(2, 132, 199, 0.2)',
        borderRadius: '12px',
        padding: '10px 16px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '10px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: 'var(--status-emerald)', boxShadow: '0 0 8px var(--status-emerald)' }} />
          <span style={{ fontSize: '12.5px', fontWeight: 700, color: 'var(--navy-900)' }}>
            {t('hubSystemOnline', {
              trips: stats.activeTrips ?? trips.filter(t => t.status === 'in_transit' || t.status === 'active').length,
              drivers: stats.driversOnDuty ?? 0,
              deliveries: stats.completedDeliveriesToday ?? 0
            })}
          </span>
        </div>

        <button
          type="button"
          onClick={() => setShowWorkflowGuide(!showWorkflowGuide)}
          style={{
            background: '#ffffff',
            border: '1px solid var(--slate-200)',
            borderRadius: '9999px',
            padding: '4px 12px',
            fontSize: '11.5px',
            fontWeight: 700,
            color: 'var(--primary-blue)',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            boxShadow: '0 1px 3px rgba(0,0,0,0.05)'
          }}
        >
          <HelpCircle size={13} />
          <span>{showWorkflowGuide ? t('hubGuideHide') : t('hubGuideToggle')}</span>
          {showWorkflowGuide ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
        </button>
      </div>

      {/* Collapsible 3-Step Quick Guide for Users */}
      {showWorkflowGuide && (
        <div style={{
          background: '#ffffff',
          borderRadius: '14px',
          border: '1px solid var(--slate-200)',
          padding: '16px 20px',
          boxShadow: 'var(--shadow-card)',
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
          gap: '14px',
          animation: 'slideDownFade 0.2s ease'
        }}>
          {/* Step 1 */}
          <div style={{ display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
            <div style={{ width: '30px', height: '30px', borderRadius: '8px', background: 'var(--sky-blue-light)', color: 'var(--primary-blue)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '13px', flexShrink: 0 }}>
              1
            </div>
            <div>
              <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>{t('hubStep1Title')}</div>
              <p style={{ fontSize: '11.5px', color: 'var(--slate-500)', marginTop: '2px', lineHeight: 1.4 }}>
                {t('hubStep1Desc')}
              </p>
            </div>
          </div>

          {/* Step 2 */}
          <div style={{ display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
            <div style={{ width: '30px', height: '30px', borderRadius: '8px', background: 'rgba(13, 148, 136, 0.1)', color: 'var(--primary-teal)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '13px', flexShrink: 0 }}>
              2
            </div>
            <div>
              <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>{t('hubStep2Title')}</div>
              <p style={{ fontSize: '11.5px', color: 'var(--slate-500)', marginTop: '2px', lineHeight: 1.4 }}>
                {t('hubStep2Desc')}
              </p>
            </div>
          </div>

          {/* Step 3 */}
          <div style={{ display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
            <div style={{ width: '30px', height: '30px', borderRadius: '8px', background: 'var(--status-emerald-light)', color: 'var(--status-emerald)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '13px', flexShrink: 0 }}>
              3
            </div>
            <div>
              <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>{t('hubStep3Title')}</div>
              <p style={{ fontSize: '11.5px', color: 'var(--slate-500)', marginTop: '2px', lineHeight: 1.4 }}>
                {t('hubStep3Desc')}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Super Simple 4-Card Quick Action Hub */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))',
        gap: '12px'
      }}>
        {/* 1. Create Trip */}
        <button
          onClick={onCreateTripModal}
          style={{
            background: 'linear-gradient(135deg, #0284c7 0%, #0369a1 100%)',
            color: '#ffffff',
            borderRadius: '14px',
            padding: '16px 18px',
            border: 'none',
            display: 'flex',
            alignItems: 'center',
            gap: '14px',
            cursor: 'pointer',
            textAlign: 'left',
            boxShadow: '0 4px 16px rgba(2, 132, 199, 0.25)',
            transition: 'transform 0.15s ease'
          }}
        >
          <div style={{ width: '42px', height: '42px', borderRadius: '10px', background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Plus size={22} color="#ffffff" />
          </div>
          <div>
            <div style={{ fontSize: '15px', fontWeight: 800 }}>{t('actionHubCreateTrip')}</div>
            <div style={{ fontSize: '12px', opacity: 0.9, marginTop: '2px' }}>{t('actionHubCreateTripSub')}</div>
          </div>
        </button>

        {/* 2. Live Tracking */}
        <button
          onClick={() => onNavigateTab ? onNavigateTab('live-tracking') : onViewAllTrips()}
          style={{
            background: 'linear-gradient(135deg, #0d9488 0%, #0f766e 100%)',
            color: '#ffffff',
            borderRadius: '14px',
            padding: '16px 18px',
            border: 'none',
            display: 'flex',
            alignItems: 'center',
            gap: '14px',
            cursor: 'pointer',
            textAlign: 'left',
            boxShadow: '0 4px 16px rgba(13, 148, 136, 0.25)',
            transition: 'transform 0.15s ease'
          }}
        >
          <div style={{ width: '42px', height: '42px', borderRadius: '10px', background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <MapPin size={22} color="#ffffff" />
          </div>
          <div>
            <div style={{ fontSize: '15px', fontWeight: 800 }}>{t('actionHubLiveMap')}</div>
            <div style={{ fontSize: '12px', opacity: 0.9, marginTop: '2px' }}>{t('actionHubLiveMapSub')}</div>
          </div>
        </button>

        {/* 3. Drivers */}
        <button
          onClick={() => onNavigateTab ? onNavigateTab('drivers') : onViewAllTrips()}
          style={{
            background: '#ffffff',
            color: 'var(--navy-900)',
            borderRadius: '14px',
            padding: '16px 18px',
            border: '1px solid var(--slate-200)',
            display: 'flex',
            alignItems: 'center',
            gap: '14px',
            cursor: 'pointer',
            textAlign: 'left',
            boxShadow: '0 2px 8px rgba(15, 23, 42, 0.05)',
            transition: 'transform 0.15s ease'
          }}
        >
          <div style={{ width: '42px', height: '42px', borderRadius: '10px', background: 'var(--slate-100)', color: 'var(--primary-blue)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Users size={22} />
          </div>
          <div>
            <div style={{ fontSize: '15px', fontWeight: 800 }}>{t('actionHubDrivers')}</div>
            <div style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '2px' }}>{t('actionHubDriversSub')}</div>
          </div>
        </button>

        {/* 4. Delivery Proofs */}
        <button
          onClick={() => onNavigateTab ? onNavigateTab('deliveries') : onViewAllTrips()}
          style={{
            background: '#ffffff',
            color: 'var(--navy-900)',
            borderRadius: '14px',
            padding: '16px 18px',
            border: '1px solid var(--slate-200)',
            display: 'flex',
            alignItems: 'center',
            gap: '14px',
            cursor: 'pointer',
            textAlign: 'left',
            boxShadow: '0 2px 8px rgba(15, 23, 42, 0.05)',
            transition: 'transform 0.15s ease'
          }}
        >
          <div style={{ width: '42px', height: '42px', borderRadius: '10px', background: 'var(--status-emerald-light)', color: 'var(--status-emerald)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <CheckCircle2 size={22} />
          </div>
          <div>
            <div style={{ fontSize: '15px', fontWeight: 800 }}>{t('actionHubPOD')}</div>
            <div style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '2px' }}>{t('actionHubPODSub')}</div>
          </div>
        </button>
      </div>

      {/* Summary KPI Cards Grid (Mobile 2-column or 3-column wrap) */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))',
        gap: '10px'
      }}>
        {metricCards.map((m) => {
          const Icon = m.icon;
          return (
            <div
              key={m.id}
              style={{
                background: '#ffffff',
                borderRadius: '12px',
                padding: '12px 14px',
                boxShadow: 'var(--shadow-card)',
                border: '1px solid var(--slate-200)',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                minHeight: '84px'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
                <span style={{ fontSize: '10px', fontWeight: 700, color: 'var(--slate-500)', textTransform: 'uppercase', letterSpacing: '0.02em' }}>
                  {m.label}
                </span>
                <div style={{
                  width: '26px',
                  height: '26px',
                  borderRadius: '6px',
                  background: m.bg,
                  color: m.color,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0
                }}>
                  <Icon size={14} />
                </div>
              </div>
              <div>
                <div style={{ fontSize: '20px', fontWeight: 800, color: 'var(--navy-800)', lineHeight: 1.1 }}>
                  {m.value}
                </div>
                <div style={{ fontSize: '10px', color: 'var(--slate-400)', marginTop: '2px' }}>
                  {m.subtext}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Primary Row: Live Fleet Map & Active Trip Progress */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: '16px'
      }}>
        {/* Interactive Fleet Map */}
        <div style={{
          background: '#ffffff',
          borderRadius: '14px',
          padding: '16px',
          boxShadow: 'var(--shadow-card)',
          border: '1px solid var(--slate-200)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px', flexWrap: 'wrap', gap: '8px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div style={{
                width: '30px',
                height: '30px',
                borderRadius: '8px',
                background: 'var(--sky-blue-light)',
                color: 'var(--primary-blue)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}>
                <MapPin size={16} />
              </div>
              <div>
                <h3 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-800)' }}>
                  {t('mapTelematicsTitle')}
                </h3>
                <span style={{ fontSize: '11px', color: 'var(--slate-400)' }}>
                  {t('mapTelematicsSub')}
                </span>
              </div>
            </div>

            {activeTrip && (
              <span style={{
                fontSize: '11px',
                fontWeight: 700,
                color: 'var(--primary-blue)',
                background: 'var(--sky-blue-light)',
                padding: '3px 8px',
                borderRadius: '9999px',
                fontFamily: 'var(--font-mono)'
              }}>
                {activeTrip.id}
              </span>
            )}
          </div>

          <FleetMap
            trip={activeTrip}
            currentLocation={activeTrip?.currentLocation}
            speed={activeTrip?.currentSpeed || 0}
            height="280px"
          />

          {activeTrip && (
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(75px, 1fr))',
              gap: '8px',
              marginTop: '12px',
              padding: '10px',
              background: 'var(--slate-50)',
              borderRadius: '8px',
              border: '1px solid var(--slate-200)'
            }}>
              <div>
                <div style={{ fontSize: '9px', color: 'var(--slate-400)', fontWeight: 700, textTransform: 'uppercase' }}>Driver</div>
                <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{activeTrip.driverName}</div>
              </div>
              <div>
                <div style={{ fontSize: '9px', color: 'var(--slate-400)', fontWeight: 700, textTransform: 'uppercase' }}>Vehicle</div>
                <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', fontFamily: 'var(--font-mono)' }}>{activeTrip.vehicleRegistration}</div>
              </div>
              <div>
                <div style={{ fontSize: '9px', color: 'var(--slate-400)', fontWeight: 700, textTransform: 'uppercase' }}>Stop</div>
                <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--primary-blue)' }}>
                  {(activeTrip.currentStopIndex || 0) + 1} of {activeTrip.stops?.length || 0}
                </div>
              </div>
              <div>
                <div style={{ fontSize: '9px', color: 'var(--slate-400)', fontWeight: 700, textTransform: 'uppercase' }}>Speed</div>
                <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--primary-teal)', fontFamily: 'var(--font-mono)' }}>
                  {activeTrip.currentSpeed || 0} km/h
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Active Dispatched Trips List */}
        <div style={{
          background: '#ffffff',
          borderRadius: '14px',
          padding: '16px',
          boxShadow: 'var(--shadow-card)',
          border: '1px solid var(--slate-200)',
          display: 'flex',
          flexDirection: 'column'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
            <h3 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-800)' }}>
              Dispatched Routes &amp; Trips ({filteredTrips.length})
            </h3>
            <button
              onClick={onViewAllTrips}
              className="btn btn-secondary"
              style={{ fontSize: '11px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}
            >
              <span>Manage All</span>
              <ArrowUpRight size={13} />
            </button>
          </div>

          {/* Quick Search & Filter Pills */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: '10px' }}>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              background: 'var(--slate-100)',
              borderRadius: '8px',
              padding: '6px 10px',
              gap: '6px',
              border: '1px solid var(--slate-200)'
            }}>
              <Search size={14} color="var(--slate-400)" />
              <input
                type="text"
                value={tripSearch}
                onChange={(e) => setTripSearch(e.target.value)}
                placeholder="Filter trips by ID, driver, vehicle..."
                style={{
                  border: 'none',
                  background: 'transparent',
                  outline: 'none',
                  fontSize: '12px',
                  color: 'var(--navy-800)',
                  width: '100%'
                }}
              />
              {tripSearch && (
                <button
                  type="button"
                  onClick={() => setTripSearch('')}
                  style={{ background: 'none', border: 'none', color: 'var(--slate-400)', cursor: 'pointer', padding: '2px', display: 'flex' }}
                >
                  <X size={12} />
                </button>
              )}
            </div>

            <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
              {[
                { id: 'all', label: `All (${trips.length})` },
                { id: 'active', label: 'Active / In Transit' },
                { id: 'delayed', label: 'Delayed' },
                { id: 'completed', label: 'Completed' }
              ].map(f => (
                <button
                  key={f.id}
                  type="button"
                  onClick={() => setTripFilter(f.id)}
                  style={{
                    border: 'none',
                    borderRadius: '6px',
                    padding: '3px 8px',
                    fontSize: '10.5px',
                    fontWeight: 700,
                    cursor: 'pointer',
                    background: tripFilter === f.id ? 'var(--primary-blue)' : 'var(--slate-100)',
                    color: tripFilter === f.id ? '#ffffff' : 'var(--slate-600)',
                    transition: 'all 0.15s ease'
                  }}
                >
                  {f.label}
                </button>
              ))}
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', overflowY: 'auto', maxHeight: '300px' }}>
            {filteredTrips.length === 0 ? (
              <div style={{ padding: '20px', textAlign: 'center', color: 'var(--slate-400)', fontSize: '12px' }}>
                <div>No trips found matching filter</div>
                <button
                  type="button"
                  onClick={onCreateTripModal}
                  className="btn btn-secondary"
                  style={{ fontSize: '11px', padding: '6px 12px', marginTop: '8px', color: 'var(--primary-blue)' }}
                >
                  <Plus size={13} style={{ marginRight: '4px' }} />
                  Dispatch New Trip
                </button>
              </div>
            ) : (
              filteredTrips.slice(0, 10).map((t) => {
                const isSelected = activeTrip?.id === t.id;
                return (
                  <div
                    key={t.id}
                    onClick={() => onSelectTrip(t.id)}
                    style={{
                      padding: '10px 12px',
                      borderRadius: '10px',
                      border: `1px solid ${isSelected ? 'var(--primary-blue)' : 'var(--slate-200)'}`,
                      background: isSelected ? 'var(--sky-blue-light)' : '#ffffff',
                      cursor: 'pointer',
                      transition: 'all 0.15s ease'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '4px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <span style={{ fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', fontFamily: 'var(--font-mono)' }}>
                          {t.id}
                        </span>
                        <span style={{
                          fontSize: '9px',
                          fontWeight: 700,
                          padding: '2px 6px',
                          borderRadius: '9999px',
                          textTransform: 'uppercase',
                          background: t.status === 'completed' ? 'var(--status-emerald-light)' : (t.status === 'delayed' ? 'rgba(239, 68, 68, 0.15)' : 'rgba(2, 132, 199, 0.15)'),
                          color: t.status === 'completed' ? 'var(--status-emerald-text)' : (t.status === 'delayed' ? 'var(--status-rose-text)' : 'var(--primary-blue)')
                        }}>
                          {t.status.replace('_', ' ')}
                        </span>
                      </div>

                      <span style={{ fontSize: '11px', color: 'var(--slate-500)', fontWeight: 600 }}>
                        {t.stops?.length || 0} stops
                      </span>
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '11px' }}>
                      <div style={{ color: 'var(--navy-700)', fontWeight: 600 }}>
                        {t.driverName} <span style={{ color: 'var(--slate-400)' }}>({t.vehicleRegistration})</span>
                      </div>
                      <div style={{ color: 'var(--slate-500)' }}>
                        Activity: <strong style={{ color: 'var(--primary-teal)', textTransform: 'capitalize' }}>{t.currentActivity || 'Driving'}</strong>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>

      {/* Secondary Row: Safety Alerts Review & Audited Scenario Verification */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: '16px'
      }}>
        {/* Safety Alert Summary */}
        <div style={{
          background: '#ffffff',
          borderRadius: '14px',
          padding: '16px',
          boxShadow: 'var(--shadow-card)',
          border: '1px solid var(--slate-200)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div style={{
                width: '28px',
                height: '28px',
                borderRadius: '6px',
                background: 'var(--status-rose-light)',
                color: 'var(--status-rose)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}>
                <ShieldAlert size={16} />
              </div>
              <h3 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-800)' }}>
                Active Telematics Alerts
              </h3>
            </div>
            <button
              onClick={onViewSafety}
              className="btn btn-secondary"
              style={{ fontSize: '11px', padding: '4px 8px' }}
            >
              Review All
            </button>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {safetyEvents.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '24px 12px', color: 'var(--slate-400)', fontSize: '12px' }}>
                No safety alerts recorded. All telemetry within speed limits.
              </div>
            ) : (
              safetyEvents.slice(0, 3).map((evt) => (
                <div
                  key={evt.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '8px 12px',
                    borderRadius: '8px',
                    background: 'var(--slate-50)',
                    border: '1px solid var(--slate-200)'
                  }}
                >
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <span style={{
                        fontSize: '10px',
                        fontWeight: 700,
                        color: evt.type === 'overspeed' ? 'var(--status-rose)' : 'var(--status-amber)',
                        textTransform: 'uppercase'
                      }}>
                        {evt.type === 'overspeed' ? 'Speed Violation' : 'Seatbelt Alert'}
                      </span>
                      <span style={{ fontSize: '10px', color: 'var(--slate-400)' }}>•</span>
                      <span style={{ fontSize: '10px', color: 'var(--slate-500)', fontFamily: 'var(--font-mono)' }}>
                        {evt.tripId}
                      </span>
                    </div>
                    <div style={{ fontSize: '12px', fontWeight: 600, color: 'var(--navy-800)' }}>
                      {evt.driverName} ({evt.vehicleRegistration})
                    </div>
                  </div>

                  <div style={{ textAlign: 'right' }}>
                    {evt.type === 'overspeed' && (
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--status-rose)', fontFamily: 'var(--font-mono)' }}>
                        {evt.recordedSpeed} km/h
                      </div>
                    )}
                    <span style={{ fontSize: '9px', color: 'var(--slate-400)' }}>
                      Limit: {evt.speedThreshold || 80} km/h
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Real Operational Dispatch Overview */}
        <div style={{
          background: '#ffffff',
          borderRadius: '14px',
          padding: '16px',
          boxShadow: 'var(--shadow-card)',
          border: '1px solid var(--slate-200)'
        }}>
          <h3 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
            Operational Dispatch Overview
          </h3>
          <p style={{ fontSize: '11px', color: 'var(--slate-500)', marginBottom: '10px' }}>
            Live status of active dispatches, scheduled waypoints, and completed deliveries.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <div style={{ padding: '8px 12px', borderRadius: '6px', background: 'var(--sky-blue-light)', display: 'flex', justifyContent: 'space-between', fontSize: '11px' }}>
              <span style={{ fontWeight: 600, color: 'var(--navy-800)' }}>Total Dispatched Trips</span>
              <span style={{ fontWeight: 800, color: 'var(--primary-blue)' }}>{trips.length} Trips</span>
            </div>
            <div style={{ padding: '8px 12px', borderRadius: '6px', background: 'var(--slate-50)', display: 'flex', justifyContent: 'space-between', fontSize: '11px' }}>
              <span style={{ fontWeight: 600, color: 'var(--navy-800)' }}>Active Vehicles On Route</span>
              <span style={{ fontWeight: 800, color: 'var(--primary-teal)' }}>{stats.activeTrips ?? trips.filter(t => t.status === 'in_transit' || t.status === 'active').length} Active</span>
            </div>
            <div style={{ padding: '8px 12px', borderRadius: '6px', background: 'var(--slate-50)', display: 'flex', justifyContent: 'space-between', fontSize: '11px' }}>
              <span style={{ fontWeight: 600, color: 'var(--navy-800)' }}>Completed Deliveries Today</span>
              <span style={{ fontWeight: 800, color: 'var(--status-emerald-text)' }}>{stats.completedDeliveriesToday ?? 0} Delivered</span>
            </div>
            <div style={{ padding: '8px 12px', borderRadius: '6px', background: 'rgba(16, 185, 129, 0.1)', display: 'flex', justifyContent: 'space-between', fontSize: '11px', border: '1px solid rgba(16, 185, 129, 0.3)' }}>
              <span style={{ fontWeight: 700, color: 'var(--status-emerald-text)' }}>Pending Scheduled Drops</span>
              <span style={{ fontWeight: 800, color: 'var(--status-emerald-text)' }}>{stats.pendingDeliveries ?? 0} Pending</span>
            </div>
          </div>
        </div>
      </div>

    </div>
  );
}
