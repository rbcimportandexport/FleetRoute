import React from 'react';
import { 
  LayoutDashboard, 
  Compass,
  Route, 
  MapPin, 
  Users, 
  Truck, 
  Package,
  Boxes, 
  Clock, 
  CheckCircle2,
  ShieldAlert, 
  BarChart3, 
  Sliders,
  Plus,
  Zap,
  X,
  Siren
} from 'lucide-react';

import { useTranslation } from '../../hooks/useTranslation';

export default function Sidebar({ 
  activeTab, 
  onTabChange, 
  counts = {}, 
  isMobileOpen = false, 
  onCloseMobile,
  onCreateTripModal
}) {
  const { t } = useTranslation();

  const sections = [
    {
      title: t('navOperations') || 'Operations',
      items: [
        { id: 'dashboard', label: t('navDashboard'), icon: LayoutDashboard },
        { id: 'emergency-ops', label: t('navEmergencyOps') || 'Emergency Operations', icon: Siren, badge: counts.emergencyIncidents, alert: Boolean(counts.emergencyIncidents) },
        { id: 'live-tracking', label: t('navTracking'), icon: Compass, badge: counts.liveDrivers },
        { id: 'trips', label: t('navTrips'), icon: Route, badge: counts.activeTrips },
        { id: 'deliveries', label: t('actionHubPOD'), icon: CheckCircle2, badge: counts.deliveriesCount },
      ]
    },
    {
      title: t('navFleetAssets') || 'Fleet & Assets',
      items: [
        { id: 'drivers', label: t('actionHubDrivers'), icon: Users, badge: counts.driversCount },
        { id: 'vehicles', label: t('navVehicles'), icon: Truck, badge: counts.vehiclesCount },
        { id: 'locations', label: t('navLocations'), icon: MapPin, badge: counts.locationsCount },
        { id: 'products', label: t('navProducts'), icon: Package, badge: counts.productsCount },
      ]
    },
    {
      title: t('navMonitoringAudit') || 'Monitoring & Audit',
      items: [
        { id: 'safety', label: t('kpiSafetyAlerts'), icon: ShieldAlert, badge: counts.safetyAlerts, alert: true },
        { id: 'timeline', label: t('navTimeline') || 'Activity & Delays', icon: Clock },
        { id: 'reports', label: t('navReports'), icon: BarChart3 },
        { id: 'settings', label: t('navSettings'), icon: Sliders }
      ]
    }
  ];

  const handleSelectTab = (id) => {
    onTabChange(id);
    if (onCloseMobile) {
      onCloseMobile();
    }
  };

  return (
    <>
      {/* Mobile Backdrop Overlay */}
      <div 
        className={`sidebar-overlay ${isMobileOpen ? 'active' : ''}`}
        onClick={onCloseMobile} 
      />

      {/* Sidebar Drawer */}
      <aside className={`desktop-sidebar ${isMobileOpen ? 'mobile-open' : ''}`}>
        
        {/* Sidebar Header with Mobile Close Button */}
        <div style={{ 
          padding: '12px 14px', 
          borderBottom: '1px solid var(--slate-100)', 
          display: 'flex', 
          alignItems: 'center', 
          justifyContent: 'space-between',
          marginBottom: '8px'
        }}>
          <div>
            <div style={{ fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.08em', color: 'var(--slate-500)', fontWeight: 700 }}>
              Dispatch Console
            </div>
            <div style={{ fontSize: '13px', color: 'var(--navy-900)', fontWeight: 700, marginTop: '1px' }}>
              Central Operations Hub
            </div>
          </div>

          {/* Close Button on Mobile Viewports */}
          <button
            onClick={onCloseMobile}
            style={{
              background: 'transparent',
              border: 'none',
              color: 'var(--slate-400)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '6px'
            }}
            className="mobile-close-btn"
          >
            <X size={18} />
          </button>
        </div>

        {/* 1-Click Quick Dispatch Action in Sidebar */}
        {onCreateTripModal && (
          <div style={{ padding: '0 8px 10px' }}>
            <button
              onClick={() => {
                if (onCloseMobile) onCloseMobile();
                onCreateTripModal();
              }}
              style={{
                width: '100%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
                padding: '9px 12px',
                borderRadius: '8px',
                background: 'linear-gradient(135deg, #0284c7 0%, #0d9488 100%)',
                color: '#ffffff',
                border: 'none',
                fontWeight: 700,
                fontSize: '12.5px',
                cursor: 'pointer',
                boxShadow: '0 2px 8px rgba(2, 132, 199, 0.25)',
                transition: 'all 0.15s ease'
              }}
            >
              <Zap size={15} />
              <span>Quick Dispatch Trip</span>
            </button>
          </div>
        )}

        {/* Navigation Items Grouped into Sections */}
        <nav style={{ display: 'flex', flexDirection: 'column', gap: '2px', flex: 1, overflowY: 'auto' }}>
          {sections.map((section, sIdx) => (
            <div key={section.title} style={{ marginBottom: sIdx < sections.length - 1 ? '8px' : 0 }}>
              <div className="sidebar-section-title">
                {section.title}
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                {section.items.map((item) => {
                  const Icon = item.icon;
                  const isActive = activeTab === item.id;
                  return (
                    <button
                      key={item.id}
                      onClick={() => handleSelectTab(item.id)}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        width: '100%',
                        padding: '8.5px 12px',
                        borderRadius: '8px',
                        border: 'none',
                        background: isActive ? 'var(--primary-blue)' : 'transparent',
                        color: isActive ? '#ffffff' : 'var(--slate-700)',
                        fontSize: '13px',
                        fontWeight: isActive ? 700 : 500,
                        cursor: 'pointer',
                        textAlign: 'left',
                        transition: 'all 0.15s ease'
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <Icon size={16} color={isActive ? '#ffffff' : 'var(--slate-500)'} />
                        <span>{item.label}</span>
                      </div>
                      {item.badge !== undefined && item.badge !== 0 && (
                        <span style={{
                          fontSize: '10px',
                          fontWeight: 700,
                          padding: '2px 6px',
                          borderRadius: '9999px',
                          background: item.alert ? 'rgba(239, 68, 68, 0.15)' : (isActive ? 'rgba(255, 255, 255, 0.2)' : 'var(--slate-100)'),
                          color: item.alert ? '#ef4444' : (isActive ? '#ffffff' : 'var(--slate-600)')
                        }}>
                          {item.badge}
                        </span>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </nav>
      </aside>
    </>
  );
}
