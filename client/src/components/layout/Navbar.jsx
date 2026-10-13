import React, { useState, useEffect, useRef } from 'react';
import { 
  Navigation, 
  Menu,
  WifiOff, 
  LogOut, 
  Shield, 
  Truck,
  Search,
  Route,
  Users,
  MapPin,
  Plus,
  Compass,
  CheckCircle2,
  X,
  Zap,
  ArrowRight,
  Globe,
  Check,
  ChevronDown
} from 'lucide-react';
import { useTranslation } from '../../hooks/useTranslation';

export default function Navbar({ 
  currentUser,
  onOpenProfile,
  onLogout,
  isOnline = true, 
  onToggleMobileMenu,
  trips = [],
  drivers = [],
  vehicles = [],
  locations = [],
  onSelectTrip,
  onNavigateTab,
  onCreateTripModal
}) {
  const { lang, setLanguage } = useTranslation();
  const isAdmin = currentUser?.role === 'admin';

  // Global Quick Search State
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const searchInputRef = useRef(null);
  const searchContainerRef = useRef(null);

  // Language Dropdown Menu State
  const [isLangMenuOpen, setIsLangMenuOpen] = useState(false);
  const langMenuRef = useRef(null);

  // Global Keyboard shortcut: '/' or 'Ctrl+K'
  useEffect(() => {
    const handleKeyDown = (e) => {
      if ((e.key === '/' || (e.ctrlKey && e.key === 'k') || (e.metaKey && e.key === 'k')) && 
          document.activeElement?.tagName !== 'INPUT' && 
          document.activeElement?.tagName !== 'TEXTAREA') {
        e.preventDefault();
        searchInputRef.current?.focus();
        setIsSearchOpen(true);
      } else if (e.key === 'Escape') {
        setIsSearchOpen(false);
        setIsLangMenuOpen(false);
        searchInputRef.current?.blur();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Click outside to close search and language dropdowns
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (searchContainerRef.current && !searchContainerRef.current.contains(e.target)) {
        setIsSearchOpen(false);
      }
      if (langMenuRef.current && !langMenuRef.current.contains(e.target)) {
        setIsLangMenuOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('touchstart', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('touchstart', handleClickOutside);
    };
  }, []);

  // Search Results filtering
  const q = searchQuery.toLowerCase().trim();
  const matchedTrips = q ? trips.filter(t => 
    t.id?.toLowerCase().includes(q) ||
    t.driverName?.toLowerCase().includes(q) ||
    t.vehicleRegistration?.toLowerCase().includes(q)
  ).slice(0, 4) : [];

  const matchedDrivers = q ? drivers.filter(d => 
    d.name?.toLowerCase().includes(q) ||
    d.phone?.includes(q)
  ).slice(0, 3) : [];

  const matchedVehicles = q ? vehicles.filter(v => 
    v.registrationNumber?.toLowerCase().includes(q) ||
    v.model?.toLowerCase().includes(q)
  ).slice(0, 3) : [];

  const matchedLocations = q ? locations.filter(l => 
    l.name?.toLowerCase().includes(q) ||
    l.address?.toLowerCase().includes(q)
  ).slice(0, 3) : [];

  const hasResults = matchedTrips.length > 0 || matchedDrivers.length > 0 || matchedVehicles.length > 0 || matchedLocations.length > 0;

  const handleActionClick = (cb) => {
    setIsSearchOpen(false);
    setSearchQuery('');
    if (cb) cb();
  };

  return (
    <header className="navbar-root">
      {/* Brand & Mobile Menu Hamburger */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexShrink: 0 }}>
        {/* Mobile Hamburger Button for Admin */}
        {isAdmin && (
          <button
            onClick={onToggleMobileMenu}
            aria-label="Open Navigation Drawer"
            style={{
              background: 'var(--slate-100)',
              border: '1px solid var(--slate-200)',
              borderRadius: '8px',
              color: 'var(--navy-800)',
              padding: '6px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer'
            }}
          >
            <Menu size={18} />
          </button>
        )}

        <div style={{
          width: '34px',
          height: '34px',
          borderRadius: '8px',
          background: 'linear-gradient(135deg, #0284c7 0%, #0d9488 100%)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#ffffff',
          boxShadow: '0 2px 8px rgba(2, 132, 199, 0.3)',
          flexShrink: 0
        }}>
          <Navigation size={18} />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
          <span style={{ fontSize: '17px', fontWeight: 800, letterSpacing: '-0.02em', color: 'var(--navy-900)', whiteSpace: 'nowrap' }}>
            FleetRoute
          </span>
          <span className="brand-subtitle-hide" style={{ fontSize: '11px', color: 'var(--slate-500)', lineHeight: 1.1 }}>
            Logistics Engine
          </span>
        </div>
      </div>

      {/* Global Quick Search & Jump Bar for Admin */}
      {isAdmin && (
        <div ref={searchContainerRef} className="navbar-search-container">
          <div className="navbar-search-box">
            <Search size={15} color="var(--slate-400)" />
            <input
              ref={searchInputRef}
              type="text"
              value={searchQuery}
              onChange={(e) => { setSearchQuery(e.target.value); setIsSearchOpen(true); }}
              onFocus={() => setIsSearchOpen(true)}
              placeholder="Search trips, drivers, plates, locations... (Press /)"
              className="navbar-search-input"
            />
            {searchQuery ? (
              <button
                type="button"
                onClick={() => { setSearchQuery(''); searchInputRef.current?.focus(); }}
                style={{ background: 'none', border: 'none', color: 'var(--slate-400)', cursor: 'pointer', padding: '2px', display: 'flex' }}
              >
                <X size={14} />
              </button>
            ) : (
              <span className="navbar-search-kbd">/</span>
            )}
          </div>

          {/* Search Dropdown / Quick Launch Hub */}
          {isSearchOpen && (
            <div className="navbar-search-dropdown">
              {!q ? (
                /* Quick Shortcuts when empty */
                <div>
                  <div className="navbar-search-section-header">Quick Operations</div>
                  
                  {onCreateTripModal && (
                    <button
                      type="button"
                      onClick={() => handleActionClick(onCreateTripModal)}
                      className="navbar-search-item"
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{ width: '26px', height: '26px', borderRadius: '6px', background: 'var(--sky-blue-light)', color: 'var(--primary-blue)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          <Zap size={14} />
                        </div>
                        <span style={{ fontSize: '13px', fontWeight: 700, color: 'var(--navy-900)' }}>Quick Dispatch Trip</span>
                      </div>
                      <span style={{ fontSize: '11px', color: 'var(--primary-blue)', fontWeight: 600 }}>1-Minute Setup</span>
                    </button>
                  )}

                  {onNavigateTab && (
                    <>
                      <button
                        type="button"
                        onClick={() => handleActionClick(() => onNavigateTab('live-tracking'))}
                        className="navbar-search-item"
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <div style={{ width: '26px', height: '26px', borderRadius: '6px', background: 'rgba(13, 148, 136, 0.1)', color: 'var(--primary-teal)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            <Compass size={14} />
                          </div>
                          <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--navy-800)' }}>Live Fleet GPS Tracking</span>
                        </div>
                        <ArrowRight size={14} color="var(--slate-400)" />
                      </button>

                      <button
                        type="button"
                        onClick={() => handleActionClick(() => onNavigateTab('trips'))}
                        className="navbar-search-item"
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <div style={{ width: '26px', height: '26px', borderRadius: '6px', background: 'var(--slate-100)', color: 'var(--navy-800)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            <Route size={14} />
                          </div>
                          <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--navy-800)' }}>Trips & Route Dispatch</span>
                        </div>
                        <ArrowRight size={14} color="var(--slate-400)" />
                      </button>

                      <button
                        type="button"
                        onClick={() => handleActionClick(() => onNavigateTab('deliveries'))}
                        className="navbar-search-item"
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <div style={{ width: '26px', height: '26px', borderRadius: '6px', background: 'var(--status-emerald-light)', color: 'var(--status-emerald)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            <CheckCircle2 size={14} />
                          </div>
                          <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--navy-800)' }}>Delivery Proofs (POD)</span>
                        </div>
                        <ArrowRight size={14} color="var(--slate-400)" />
                      </button>
                    </>
                  )}
                </div>
              ) : hasResults ? (
                /* Filtered Search Results */
                <div>
                  {matchedTrips.length > 0 && (
                    <div>
                      <div className="navbar-search-section-header">Trips ({matchedTrips.length})</div>
                      {matchedTrips.map(trip => (
                        <button
                          key={trip.id}
                          type="button"
                          onClick={() => handleActionClick(() => onSelectTrip && onSelectTrip(trip.id))}
                          className="navbar-search-item"
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <Route size={15} color="var(--primary-blue)" />
                            <div>
                              <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--navy-900)' }}>{trip.id}</div>
                              <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                                {trip.driverName} • {trip.vehicleRegistration}
                              </div>
                            </div>
                          </div>
                          <span style={{
                            fontSize: '10px',
                            fontWeight: 700,
                            padding: '2px 6px',
                            borderRadius: '4px',
                            textTransform: 'uppercase',
                            background: trip.status === 'completed' ? 'var(--status-emerald-light)' : 'var(--sky-blue-light)',
                            color: trip.status === 'completed' ? 'var(--status-emerald-text)' : 'var(--primary-blue)'
                          }}>
                            {trip.status}
                          </span>
                        </button>
                      ))}
                    </div>
                  )}

                  {matchedDrivers.length > 0 && (
                    <div>
                      <div className="navbar-search-section-header">Drivers ({matchedDrivers.length})</div>
                      {matchedDrivers.map(drv => (
                        <button
                          key={drv.id}
                          type="button"
                          onClick={() => handleActionClick(() => onNavigateTab && onNavigateTab('drivers'))}
                          className="navbar-search-item"
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <Users size={15} color="var(--primary-teal)" />
                            <div>
                              <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--navy-900)' }}>{drv.name}</div>
                              <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>{drv.phone}</div>
                            </div>
                          </div>
                          <span style={{ fontSize: '11px', color: 'var(--slate-400)' }}>Driver</span>
                        </button>
                      ))}
                    </div>
                  )}

                  {matchedVehicles.length > 0 && (
                    <div>
                      <div className="navbar-search-section-header">Vehicles ({matchedVehicles.length})</div>
                      {matchedVehicles.map(veh => (
                        <button
                          key={veh.id}
                          type="button"
                          onClick={() => handleActionClick(() => onNavigateTab && onNavigateTab('vehicles'))}
                          className="navbar-search-item"
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <Truck size={15} color="var(--navy-800)" />
                            <div>
                              <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--navy-900)' }}>{veh.registrationNumber}</div>
                              <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>{veh.model} ({veh.capacityKg} kg)</div>
                            </div>
                          </div>
                          <span style={{ fontSize: '11px', color: 'var(--slate-400)' }}>Vehicle</span>
                        </button>
                      ))}
                    </div>
                  )}

                  {matchedLocations.length > 0 && (
                    <div>
                      <div className="navbar-search-section-header">Locations ({matchedLocations.length})</div>
                      {matchedLocations.map(loc => (
                        <button
                          key={loc.id}
                          type="button"
                          onClick={() => handleActionClick(() => onNavigateTab && onNavigateTab('locations'))}
                          className="navbar-search-item"
                        >
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <MapPin size={15} color="var(--status-amber)" />
                            <div>
                              <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--navy-900)' }}>{loc.name}</div>
                              <div style={{ fontSize: '11px', color: 'var(--slate-500)', maxWidth: '240px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                {loc.address}
                              </div>
                            </div>
                          </div>
                          <span style={{ fontSize: '11px', color: 'var(--slate-400)', textTransform: 'capitalize' }}>{loc.type}</span>
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              ) : (
                /* No matching items */
                <div style={{ padding: '16px', textAlign: 'center', color: 'var(--slate-500)', fontSize: '12px' }}>
                  No trips, drivers, or vehicles matching "{searchQuery}"
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* Right Controls - Simplified, Clean & Zero-Clipped */}
      <div className="navbar-right-controls">
        
        {/* World Icon Language Switcher with Dropdown Menu */}
        <div ref={langMenuRef} style={{ position: 'relative' }}>
          <button
            type="button"
            onClick={() => setIsLangMenuOpen(!isLangMenuOpen)}
            className="navbar-lang-btn"
            title={`Language / भाषा (${lang?.toUpperCase() || 'EN'})`}
            aria-label="Select Language"
            aria-haspopup="listbox"
            aria-expanded={isLangMenuOpen}
          >
            <Globe size={16} />
            <span className="navbar-lang-code">{lang?.toUpperCase() || 'EN'}</span>
            <ChevronDown 
              size={11} 
              style={{ 
                transform: isLangMenuOpen ? 'rotate(180deg)' : 'none', 
                transition: 'transform 0.15s ease',
                opacity: 0.7 
              }} 
            />
          </button>

          {isLangMenuOpen && (
            <div className="navbar-lang-dropdown" role="listbox">
              <div className="navbar-lang-dropdown-title">
                Language / भाषा
              </div>
              {[
                { code: 'en', label: 'English', native: 'English', short: 'EN' },
                { code: 'hi', label: 'Hindi', native: 'हिन्दी', short: 'HI' },
                { code: 'gu', label: 'Gujarati', native: 'ગુજરાતી', short: 'GU' }
              ].map(l => {
                const isSelected = lang === l.code;
                return (
                  <button
                    key={l.code}
                    type="button"
                    role="option"
                    aria-selected={isSelected}
                    onClick={() => {
                      setLanguage(l.code);
                      setIsLangMenuOpen(false);
                    }}
                    className={`navbar-lang-option ${isSelected ? 'active' : ''}`}
                  >
                    <div style={{ display: 'flex', flexDirection: 'column', textAlign: 'left' }}>
                      <span className="navbar-lang-native">{l.native}</span>
                      <span className="navbar-lang-name">{l.label}</span>
                    </div>
                    {isSelected && (
                      <Check size={14} color="var(--primary-blue)" />
                    )}
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* Offline Indicator Badge (Only shown if actually disconnected) */}
        {!isOnline && (
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '5px',
            background: 'rgba(239, 68, 68, 0.2)',
            border: '1px solid #ef4444',
            color: '#f87171',
            borderRadius: '9999px',
            padding: '4px 10px',
            fontSize: '11px',
            fontWeight: 700
          }}>
            <WifiOff size={13} />
            <span>Offline</span>
          </div>
        )}

        {/* Authenticated User Profile Pill */}
        {currentUser && (
          <button
            onClick={onOpenProfile}
            title={`${currentUser.name || currentUser.username} (${currentUser.role}) - Open Profile & Settings`}
            className="navbar-user-btn"
          >
            <div className={`navbar-user-avatar ${isAdmin ? 'admin' : 'driver'}`}>
              {isAdmin ? <Shield size={14} /> : <Truck size={14} />}
            </div>
            <span className="navbar-user-role-badge">
              {currentUser.role || 'User'}
            </span>
          </button>
        )}

        {/* Logout Button */}
        {currentUser && (
          <button
            onClick={onLogout}
            title="Sign out of FleetRoute"
            className="navbar-logout-btn"
          >
            <LogOut size={14} />
            <span className="logout-text-label">Logout</span>
          </button>
        )}

      </div>
    </header>
  );
}
