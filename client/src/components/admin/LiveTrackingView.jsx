import React, { useState, useEffect, useRef } from 'react';
import L from 'leaflet';
import { 
  Navigation, 
  Search, 
  Phone, 
  Truck, 
  Route, 
  MapPin, 
  Clock, 
  ShieldCheck, 
  Activity, 
  Maximize2, 
  Compass, 
  ExternalLink, 
  RefreshCw,
  Filter,
  Eye,
  CheckCircle2,
  AlertTriangle,
  Radio,
  Layers,
  Smartphone,
  User,
  ArrowLeft
} from 'lucide-react';
import { api } from '../../utils/api';
import { soundEffects } from '../../utils/soundEffects';

export default function LiveTrackingView({ onOpenTrip }) {
  const [fleet, setFleet] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [activityFilter, setActivityFilter] = useState('all');
  const [freshnessFilter, setFreshnessFilter] = useState('all');
  const [selectedDriverId, setSelectedDriverId] = useState(null);
  const [followDriver, setFollowDriver] = useState(false);
  const [showFullRoute, setShowFullRoute] = useState(true);
  const [mobileViewTab, setMobileViewTab] = useState('list'); // 'list' | 'map'
  const [mapLayer, setMapLayer] = useState('streets'); // 'streets' | 'satellite'
  const [tripsData, setTripsData] = useState([]);
  const [lastRefreshed, setLastRefreshed] = useState(new Date());

  // Leaflet map refs
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const driverMarkersRef = useRef({});
  const routePolylineRef = useRef(null);
  const stopMarkersRef = useRef([]);
  const streetTileLayerRef = useRef(null);
  const satelliteTileLayerRef = useRef(null);
  const satelliteLabelsLayerRef = useRef(null);

  // Load telemetry data
  const loadFleetData = async () => {
    try {
      const [fleetData, trips] = await Promise.all([
        api.getFleetTelemetry().catch(() => []),
        api.getTrips().catch(() => [])
      ]);
      setFleet(fleetData);
      setTripsData(trips);
      setLastRefreshed(new Date());

      if (fleetData.length > 0 && !selectedDriverId) {
        setSelectedDriverId(fleetData[0].id);
      }
    } catch (err) {
      console.error('Failed to load fleet telemetry:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadFleetData();
    const interval = setInterval(loadFleetData, 4000); // Poll every 4 seconds
    return () => clearInterval(interval);
  }, []);

  // Initialize Map
  useEffect(() => {
    if (!mapContainerRef.current) return;

    if (!mapInstanceRef.current) {
      const map = L.map(mapContainerRef.current, {
        attributionControl: false,
        zoomControl: false // Positioned at bottom-left to avoid colliding with top-left controls
      }).setView([28.5355, 77.2684], 11);

      // Move zoom control to bottom-left
      L.control.zoom({ position: 'bottomleft' }).addTo(map);

      // OpenStreetMap clean street tiles
      streetTileLayerRef.current = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19
      });

      // Esri World Imagery high-resolution satellite tiles
      satelliteTileLayerRef.current = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        maxZoom: 19
      });

      // Reference boundaries, roads & place labels overlay
      satelliteLabelsLayerRef.current = L.tileLayer('https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}', {
        maxZoom: 19
      });

      // Add default tile layer
      streetTileLayerRef.current.addTo(map);

      mapInstanceRef.current = map;
    }
  }, []);

  // Map Layer Switcher (Streets vs Satellite Mode)
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map || !streetTileLayerRef.current || !satelliteTileLayerRef.current) return;

    if (mapLayer === 'satellite') {
      if (map.hasLayer(streetTileLayerRef.current)) {
        map.removeLayer(streetTileLayerRef.current);
      }
      if (!map.hasLayer(satelliteTileLayerRef.current)) {
        satelliteTileLayerRef.current.addTo(map);
      }
      if (!map.hasLayer(satelliteLabelsLayerRef.current)) {
        satelliteLabelsLayerRef.current.addTo(map);
      }
    } else {
      if (map.hasLayer(satelliteTileLayerRef.current)) {
        map.removeLayer(satelliteTileLayerRef.current);
      }
      if (map.hasLayer(satelliteLabelsLayerRef.current)) {
        map.removeLayer(satelliteLabelsLayerRef.current);
      }
      if (!map.hasLayer(streetTileLayerRef.current)) {
        streetTileLayerRef.current.addTo(map);
      }
    }
  }, [mapLayer]);

  // ResizeObserver to ensure Leaflet recalculates size whenever visible (prevents blank/white map bug)
  useEffect(() => {
    if (!mapContainerRef.current) return;

    const observer = new ResizeObserver(() => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current.invalidateSize();
      }
    });

    observer.observe(mapContainerRef.current);
    return () => observer.disconnect();
  }, []);

  // Invalidate map size on mobile tab switch
  useEffect(() => {
    if (mobileViewTab === 'map' && mapInstanceRef.current) {
      setTimeout(() => mapInstanceRef.current?.invalidateSize(), 50);
      setTimeout(() => mapInstanceRef.current?.invalidateSize(), 200);
      setTimeout(() => mapInstanceRef.current?.invalidateSize(), 500);
    }
  }, [mobileViewTab]);

  // Update Markers and Map Elements
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map) return;

    // Clear previous stop markers and polyline
    stopMarkersRef.current.forEach(m => map.removeLayer(m));
    stopMarkersRef.current = [];
    if (routePolylineRef.current) {
      map.removeLayer(routePolylineRef.current);
      routePolylineRef.current = null;
    }

    const boundsCoords = [];

    // Update / create driver markers
    fleet.forEach(drv => {
      const hasLocation = drv.currentLocation && drv.currentLocation.lat && drv.currentLocation.lng;
      if (!hasLocation) {
        if (driverMarkersRef.current[drv.id]) {
          map.removeLayer(driverMarkersRef.current[drv.id]);
          delete driverMarkersRef.current[drv.id];
        }
        return;
      }

      const lat = drv.currentLocation.lat;
      const lng = drv.currentLocation.lng;
      boundsCoords.push([lat, lng]);

      const isSelected = drv.id === selectedDriverId;
      const isFresh = drv.freshness === 'fresh';
      const isStale = drv.freshness === 'stale';

      let markerBg = '#0284c7'; // default blue
      let statusLabel = 'ACTIVE';
      if (drv.currentActivity === 'driving') {
        markerBg = '#10b981'; // emerald
        statusLabel = 'DRIVING';
      } else if (drv.currentActivity === 'loading' || drv.currentActivity === 'unloading') {
        markerBg = '#0d9488'; // teal
        statusLabel = drv.currentActivity.toUpperCase();
      } else if (drv.currentActivity === 'delayed' || drv.currentActivity === 'traffic') {
        markerBg = '#f59e0b'; // amber
        statusLabel = 'DELAYED';
      }

      if (isStale) {
        markerBg = '#d97706';
        statusLabel = 'STALE GPS';
      }

      const iconHtml = `
        <div style="
          position: relative;
          display: flex;
          flex-direction: column;
          align-items: center;
          cursor: pointer;
        ">
          <div style="
            background: #0f172a;
            color: #ffffff;
            font-size: 10px;
            font-weight: 800;
            padding: 2px 6px;
            border-radius: 4px;
            white-space: nowrap;
            box-shadow: 0 2px 6px rgba(0,0,0,0.3);
            margin-bottom: 4px;
            border: 1px solid ${isSelected ? '#38bdf8' : '#334155'};
            display: flex;
            align-items: center;
            gap: 4px;
          ">
            <span>${drv.name.split(' ')[0]}</span>
            <span style="color: ${markerBg}; font-size: 9px;">[${statusLabel}]</span>
          </div>

          <div style="
            width: ${isSelected ? '38px' : '32px'};
            height: ${isSelected ? '38px' : '32px'};
            border-radius: 50%;
            background: ${markerBg};
            border: ${isSelected ? '3px solid #ffffff' : '2px solid #ffffff'};
            box-shadow: 0 4px 12px rgba(0,0,0,0.35);
            display: flex;
            align-items: center;
            justify-content: center;
            color: #ffffff;
            transition: all 0.2s ease;
          ">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <rect x="1" y="3" width="15" height="13"></rect>
              <polygon points="16 8 20 8 23 11 23 16 16 16 16 8"></polygon>
              <circle cx="5.5" cy="18.5" r="2.5"></circle>
              <circle cx="18.5" cy="18.5" r="2.5"></circle>
            </svg>
          </div>
        </div>
      `;

      const customIcon = L.divIcon({
        className: 'custom-driver-vehicle-marker',
        html: iconHtml,
        iconSize: [80, 50],
        iconAnchor: [40, 44]
      });

      if (!driverMarkersRef.current[drv.id]) {
        const marker = L.marker([lat, lng], { icon: customIcon }).addTo(map);
        marker.on('click', () => {
          setSelectedDriverId(drv.id);
          soundEffects.playActionClick();
        });
        driverMarkersRef.current[drv.id] = marker;
      } else {
        driverMarkersRef.current[drv.id].setLatLng([lat, lng]);
        driverMarkersRef.current[drv.id].setIcon(customIcon);
      }
    });

    // Render active trip route & stops for selected driver
    const selectedDriver = fleet.find(d => d.id === selectedDriverId);
    if (selectedDriver && selectedDriver.assignedTripId && showFullRoute) {
      const activeTrip = tripsData.find(t => t.id === selectedDriver.assignedTripId);
      if (activeTrip && activeTrip.stops && activeTrip.stops.length > 0) {
        const routeCoords = [];

        // If driver has location, start line from driver
        if (selectedDriver.currentLocation) {
          routeCoords.push([selectedDriver.currentLocation.lat, selectedDriver.currentLocation.lng]);
        }

        activeTrip.stops.forEach((stop, idx) => {
          if (stop.location && stop.location.lat && stop.location.lng) {
            routeCoords.push([stop.location.lat, stop.location.lng]);

            // Add numbered stop pin
            const stopIconHtml = `
              <div style="
                width: 24px;
                height: 24px;
                border-radius: 50%;
                background: ${stop.status === 'completed' ? '#10b981' : '#4f46e5'};
                border: 2px solid #ffffff;
                color: #ffffff;
                font-size: 11px;
                font-weight: 800;
                display: flex;
                align-items: center;
                justify-content: center;
                box-shadow: 0 2px 6px rgba(0,0,0,0.3);
              ">
                ${idx + 1}
              </div>
            `;
            const stopIcon = L.divIcon({
              className: 'custom-stop-marker',
              html: stopIconHtml,
              iconSize: [24, 24],
              iconAnchor: [12, 12]
            });

            const stopMarker = L.marker([stop.location.lat, stop.location.lng], { icon: stopIcon })
              .bindPopup(`<b>Stop ${idx + 1}: ${stop.location.name}</b><br>${stop.location.address}`)
              .addTo(map);
            stopMarkersRef.current.push(stopMarker);
          }
        });

        if (routeCoords.length > 1) {
          routePolylineRef.current = L.polyline(routeCoords, {
            color: mapLayer === 'satellite' ? '#38bdf8' : '#0284c7',
            weight: 4,
            opacity: 0.9,
            dashArray: '6, 6'
          }).addTo(map);
        }
      }
    }

    // Follow mode
    if (followDriver && selectedDriver && selectedDriver.currentLocation) {
      map.panTo([selectedDriver.currentLocation.lat, selectedDriver.currentLocation.lng], { animate: true });
    }
  }, [fleet, selectedDriverId, followDriver, showFullRoute, tripsData, mapLayer]);

  // Handle focus on specific driver
  const handleFocusDriver = (drv) => {
    setSelectedDriverId(drv.id);
    soundEffects.playActionClick();

    if (window.innerWidth <= 860) {
      setMobileViewTab('map');
      setTimeout(() => {
        if (mapInstanceRef.current) {
          mapInstanceRef.current.invalidateSize();
        }
      }, 200);
    }

    if (drv.currentLocation && drv.currentLocation.lat && mapInstanceRef.current) {
      mapInstanceRef.current.flyTo([drv.currentLocation.lat, drv.currentLocation.lng], 14, {
        duration: 1
      });
    }
  };

  // Fit all drivers
  const handleFitAllDrivers = () => {
    const map = mapInstanceRef.current;
    if (!map) return;

    const coords = fleet
      .filter(d => d.currentLocation && d.currentLocation.lat && d.currentLocation.lng)
      .map(d => [d.currentLocation.lat, d.currentLocation.lng]);

    if (coords.length > 0) {
      map.fitBounds(coords, { padding: [50, 50], maxZoom: 15 });
    }
  };

  // Filter fleet drivers
  const filteredFleet = fleet.filter(d => {
    const q = searchTerm.toLowerCase();
    const matchesSearch = 
      d.name.toLowerCase().includes(q) ||
      (d.phone && d.phone.toLowerCase().includes(q)) ||
      (d.vehicleRegistration && d.vehicleRegistration.toLowerCase().includes(q)) ||
      (d.assignedTripId && d.assignedTripId.toLowerCase().includes(q));

    const matchesActivity = activityFilter === 'all' || (d.currentActivity || 'idle') === activityFilter;
    const matchesFreshness = freshnessFilter === 'all' || d.freshness === freshnessFilter;

    return matchesSearch && matchesActivity && matchesFreshness;
  });

  const selectedDriver = fleet.find(d => d.id === selectedDriverId) || fleet[0];

  return (
    <div className="tracking-root">
      
      {/* Top Header & Filter Controls Bar */}
      <div style={{
        background: '#ffffff',
        padding: '12px 18px',
        borderRadius: '12px',
        border: '1px solid var(--slate-200)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '12px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div>
            <h1 style={{ fontSize: '20px', fontWeight: 800, color: 'var(--navy-800)', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Radio size={20} color="var(--primary-blue)" />
              <span>Where is Each Driver? Live Fleet Tracking</span>
            </h1>
            <p style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
              Real-time browser telemetry, verified GPS positions, active route stops, and telematics freshness.
            </p>
          </div>
        </div>

        {/* Global Controls & Refresh info */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
          
          {/* Satellite Mode Toggle */}
          <button
            type="button"
            onClick={() => {
              const next = mapLayer === 'satellite' ? 'streets' : 'satellite';
              setMapLayer(next);
              soundEffects.playActionClick();
            }}
            className={`btn ${mapLayer === 'satellite' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ padding: '6px 12px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
            title={mapLayer === 'satellite' ? 'Switch to Street Map' : 'Switch to Satellite Mode'}
          >
            <Layers size={13} />
            <span>{mapLayer === 'satellite' ? 'Satellite Active' : 'Satellite Mode'}</span>
          </button>

          <button
            onClick={handleFitAllDrivers}
            className="btn btn-secondary"
            style={{ padding: '6px 12px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            <Maximize2 size={13} />
            <span>Fit All Drivers</span>
          </button>

          <button
            onClick={() => setFollowDriver(!followDriver)}
            className={`btn ${followDriver ? 'btn-primary' : 'btn-secondary'}`}
            style={{ padding: '6px 12px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            <Compass size={13} />
            <span>{followDriver ? 'Following Driver' : 'Follow Driver Mode'}</span>
          </button>

          <button
            onClick={() => setShowFullRoute(!showFullRoute)}
            className={`btn ${showFullRoute ? 'btn-secondary' : 'btn-secondary'}`}
            style={{ padding: '6px 12px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            <Route size={13} />
            <span>{showFullRoute ? 'Hide Route Polyline' : 'Show Full Route'}</span>
          </button>

          <button
            onClick={loadFleetData}
            title="Refresh fleet positions"
            className="btn btn-secondary"
            style={{ padding: '6px 10px', fontSize: '12px' }}
          >
            <RefreshCw size={13} />
          </button>
        </div>
      </div>

      {/* Mobile View Switcher Tabs (Visible on screens <= 860px) */}
      <div className="tracking-mobile-tabs">
        <button
          type="button"
          onClick={() => setMobileViewTab('list')}
          className={`tracking-mobile-tab-btn ${mobileViewTab === 'list' ? 'active' : ''}`}
        >
          <User size={14} />
          <span>Driver Roster ({filteredFleet.length})</span>
        </button>
        <button
          type="button"
          onClick={() => {
            setMobileViewTab('map');
            setTimeout(() => mapInstanceRef.current?.invalidateSize(), 200);
          }}
          className={`tracking-mobile-tab-btn ${mobileViewTab === 'map' ? 'active' : ''}`}
        >
          <Compass size={14} />
          <span>Live Fleet Map</span>
        </button>
      </div>

      {/* Main Split View: Drivers List on Left, Big Map on Right */}
      <div className="tracking-container">
        
        {/* Left Side: Searchable Driver List Pane */}
        <div className={`tracking-driver-list-pane ${mobileViewTab === 'map' ? 'tracking-pane-hidden-mobile' : ''}`}>
          
          {/* Search & Filter Header */}
          <div style={{ padding: '12px 14px', borderBottom: '1px solid var(--slate-200)', background: 'var(--slate-50)' }}>
            <div style={{ position: 'relative', marginBottom: '8px' }}>
              <input
                type="text"
                placeholder="Search driver, vehicle, trip ID..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="form-control"
                style={{ paddingLeft: '32px', fontSize: '12px', height: '36px' }}
              />
              <div style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: 'var(--slate-400)' }}>
                <Search size={14} />
              </div>
            </div>

            {/* Filter Pills */}
            <div style={{ display: 'flex', gap: '6px', overflowX: 'auto', paddingBottom: '2px' }}>
              <select
                value={activityFilter}
                onChange={(e) => setActivityFilter(e.target.value)}
                style={{
                  background: '#ffffff',
                  border: '1px solid var(--slate-300)',
                  borderRadius: '6px',
                  padding: '4px 8px',
                  fontSize: '11px',
                  color: 'var(--navy-800)',
                  fontWeight: 600
                }}
              >
                <option value="all">All Activities</option>
                <option value="driving">Driving</option>
                <option value="loading">Loading</option>
                <option value="unloading">Unloading</option>
                <option value="delayed">Delayed</option>
                <option value="idle">Idle / Standby</option>
              </select>

              <select
                value={freshnessFilter}
                onChange={(e) => setFreshnessFilter(e.target.value)}
                style={{
                  background: '#ffffff',
                  border: '1px solid var(--slate-300)',
                  borderRadius: '6px',
                  padding: '4px 8px',
                  fontSize: '11px',
                  color: 'var(--navy-800)',
                  fontWeight: 600
                }}
              >
                <option value="all">All Freshness</option>
                <option value="fresh">Fresh (&lt; 5m)</option>
                <option value="stale">Stale GPS</option>
                <option value="unavailable">Location Unavailable</option>
              </select>
            </div>
          </div>

          {/* Drivers List */}
          <div style={{ flex: 1, overflowY: 'auto', padding: '10px 12px' }}>
            {filteredFleet.length === 0 ? (
              <div style={{ padding: '30px 16px', textAlign: 'center', color: 'var(--slate-400)', fontSize: '13px' }}>
                No active drivers match the current filters.
              </div>
            ) : (
              filteredFleet.map(drv => {
                const isSelected = drv.id === selectedDriverId;
                const hasLocation = drv.currentLocation && drv.currentLocation.lat && drv.currentLocation.lng;
                const isFresh = drv.freshness === 'fresh';
                const displayName = drv.name || drv.id || 'Driver';
                const initialChar = displayName.charAt(0).toUpperCase();

                return (
                  <div
                    key={drv.id}
                    onClick={() => handleFocusDriver(drv)}
                    style={{
                      padding: '12px 14px',
                      borderRadius: '10px',
                      marginBottom: '10px',
                      background: isSelected ? 'var(--sky-blue-light)' : '#ffffff',
                      border: `1px solid ${isSelected ? 'var(--primary-blue)' : 'var(--slate-200)'}`,
                      boxShadow: isSelected ? '0 2px 8px rgba(2, 132, 199, 0.15)' : '0 1px 3px rgba(0,0,0,0.03)',
                      cursor: 'pointer',
                      transition: 'all 0.15s ease'
                    }}
                  >
                    {/* Driver & Status Header */}
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{
                          width: '32px',
                          height: '32px',
                          borderRadius: '50%',
                          background: 'var(--navy-800)',
                          color: '#ffffff',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontWeight: 800,
                          fontSize: '13px',
                          flexShrink: 0
                        }}>
                          {initialChar}
                        </div>
                        <div>
                          <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-800)', lineHeight: 1.2 }}>
                            {displayName}
                          </div>
                          <div style={{ fontSize: '11px', color: 'var(--slate-500)', fontFamily: 'var(--font-mono)' }}>
                            {drv.vehicleRegistration || 'Unassigned Vehicle'}
                          </div>
                        </div>
                      </div>

                      {/* Freshness Badge (Separated from connection status) */}
                      <span style={{
                        fontSize: '10px',
                        fontWeight: 800,
                        padding: '2px 8px',
                        borderRadius: '9999px',
                        textTransform: 'uppercase',
                        background: isFresh ? 'var(--status-emerald-light)' : (drv.freshness === 'stale' ? 'var(--status-amber-light)' : 'var(--slate-100)'),
                        color: isFresh ? 'var(--status-emerald-text)' : (drv.freshness === 'stale' ? 'var(--status-amber-text)' : 'var(--slate-500)'),
                        border: `1px solid ${isFresh ? 'rgba(16, 185, 129, 0.3)' : (drv.freshness === 'stale' ? 'rgba(245, 158, 11, 0.3)' : 'var(--slate-200)')}`
                      }}>
                        {drv.freshness === 'fresh' ? 'Fresh GPS' : (drv.freshness === 'stale' ? 'Stale Location' : 'Location Unavailable')}
                      </span>
                    </div>

                    {/* Operational Details Grid */}
                    <div style={{
                      display: 'grid',
                      gridTemplateColumns: '1fr 1fr',
                      gap: '6px',
                      fontSize: '11px',
                      background: isSelected ? '#ffffff' : 'var(--slate-50)',
                      padding: '8px 10px',
                      borderRadius: '8px',
                      border: '1px solid var(--slate-200)',
                      marginBottom: '8px'
                    }}>
                      <div>
                        <span style={{ color: 'var(--slate-400)' }}>Current Activity:</span>
                        <div style={{ fontWeight: 700, color: 'var(--navy-800)', textTransform: 'capitalize' }}>
                          {drv.currentActivity || 'Idle / Standby'}
                        </div>
                      </div>

                      <div>
                        <span style={{ color: 'var(--slate-400)' }}>Assigned Trip:</span>
                        <div style={{ fontWeight: 700, color: 'var(--primary-blue)', fontFamily: 'var(--font-mono)' }}>
                          {drv.assignedTripId || 'None'}
                        </div>
                      </div>

                      <div>
                        <span style={{ color: 'var(--slate-400)' }}>Next Stop:</span>
                        <div style={{ fontWeight: 700, color: 'var(--navy-800)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {drv.nextStop ? drv.nextStop.name : 'Completed'}
                        </div>
                      </div>

                      <div>
                        <span style={{ color: 'var(--slate-400)' }}>Deliveries Remaining:</span>
                        <div style={{ fontWeight: 700, color: 'var(--navy-800)' }}>
                          {drv.remainingDeliveries ?? 0} stops
                        </div>
                      </div>
                    </div>

                    {/* Location Coordinates & Freshness details */}
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '11px' }}>
                      <div style={{ color: 'var(--slate-500)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <MapPin size={12} color="var(--primary-blue)" />
                        {hasLocation ? (
                          <span>
                            {Number(drv.currentLocation.lat || 0).toFixed(4)}, {Number(drv.currentLocation.lng || 0).toFixed(4)}
                            {drv.currentLocation.accuracy ? ` (±${Math.round(drv.currentLocation.accuracy)}m)` : ''}
                          </span>
                        ) : (
                          <span style={{ color: 'var(--slate-400)', fontStyle: 'italic' }}>Location unavailable</span>
                        )}
                      </div>

                      <div style={{ color: 'var(--slate-400)', fontSize: '10px' }}>
                        Source: {drv.dataSource || 'N/A'}
                      </div>
                    </div>

                    {/* Action Links */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '8px', paddingTop: '6px', borderTop: '1px solid rgba(0,0,0,0.05)' }}>
                      {drv.phone && (
                        <a
                          href={`tel:${drv.phone}`}
                          onClick={(e) => e.stopPropagation()}
                          className="btn btn-secondary"
                          style={{ padding: '4px 8px', fontSize: '11px', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '4px' }}
                        >
                          <Phone size={11} />
                          <span>Call</span>
                        </a>
                      )}

                      {drv.nextStop && drv.nextStop.lat && drv.nextStop.lng && (
                        <a
                          href={`https://www.google.com/maps/dir/?api=1&destination=${drv.nextStop.lat},${drv.nextStop.lng}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          onClick={(e) => e.stopPropagation()}
                          className="btn btn-secondary"
                          style={{ padding: '4px 8px', fontSize: '11px', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '4px' }}
                        >
                          <ExternalLink size={11} />
                          <span>Directions</span>
                        </a>
                      )}

                      {drv.assignedTripId && onOpenTrip && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            onOpenTrip(drv.assignedTripId);
                          }}
                          className="btn btn-secondary"
                          style={{ padding: '4px 8px', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px', marginLeft: 'auto' }}
                        >
                          <Eye size={11} />
                          <span>Trip Details</span>
                        </button>
                      )}
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Right Side: Large Interactive Leaflet Map */}
        <div className={`tracking-map-pane ${mobileViewTab === 'list' ? 'tracking-pane-hidden-mobile' : ''}`}>
          <div ref={mapContainerRef} style={{ width: '100%', height: '100%', minHeight: '380px' }} />

          {/* Floating Map Mode Toggle (Street vs Satellite) on top-right */}
          <div style={{
            position: 'absolute',
            top: '12px',
            right: '12px',
            zIndex: 1000,
            display: 'flex',
            background: 'rgba(255, 255, 255, 0.96)',
            backdropFilter: 'blur(6px)',
            borderRadius: '8px',
            boxShadow: '0 2px 10px rgba(0,0,0,0.18)',
            border: '1px solid var(--slate-200)',
            padding: '3px',
            gap: '3px'
          }}>
            <button
              type="button"
              onClick={() => { setMapLayer('streets'); soundEffects.playActionClick(); }}
              style={{
                border: 'none',
                background: mapLayer === 'streets' ? 'var(--primary-blue)' : 'transparent',
                color: mapLayer === 'streets' ? '#ffffff' : 'var(--slate-700)',
                padding: '4px 10px',
                borderRadius: '6px',
                fontSize: '11px',
                fontWeight: 700,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
                transition: 'all 0.15s ease'
              }}
            >
              <span>Street</span>
            </button>
            <button
              type="button"
              onClick={() => { setMapLayer('satellite'); soundEffects.playActionClick(); }}
              style={{
                border: 'none',
                background: mapLayer === 'satellite' ? 'var(--primary-blue)' : 'transparent',
                color: mapLayer === 'satellite' ? '#ffffff' : 'var(--slate-700)',
                padding: '4px 10px',
                borderRadius: '6px',
                fontSize: '11px',
                fontWeight: 700,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
                transition: 'all 0.15s ease'
              }}
            >
              <Layers size={12} />
              <span>Satellite</span>
            </button>
          </div>

          {/* Mobile Back to List Button (Visible when in map tab on mobile) */}
          {mobileViewTab === 'map' && (
            <button
              type="button"
              onClick={() => setMobileViewTab('list')}
              className="btn btn-secondary"
              style={{
                position: 'absolute',
                top: '12px',
                left: '12px',
                zIndex: 1000,
                boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
                background: '#ffffff',
                fontWeight: 700,
                fontSize: '11px',
                padding: '6px 12px',
                display: 'flex',
                alignItems: 'center',
                gap: '6px'
              }}
            >
              <ArrowLeft size={13} />
              <span>Back to Driver List</span>
            </button>
          )}

          {/* Map Legend Overlay */}
          <div style={{
            position: 'absolute',
            bottom: '16px',
            right: '16px',
            background: 'rgba(15, 23, 42, 0.92)',
            color: '#ffffff',
            padding: '10px 14px',
            borderRadius: '10px',
            fontSize: '11px',
            backdropFilter: 'blur(4px)',
            border: '1px solid rgba(255,255,255,0.1)',
            zIndex: 1000,
            display: 'flex',
            flexDirection: 'column',
            gap: '6px'
          }}>
            <div style={{ fontWeight: 800, textTransform: 'uppercase', color: '#94a3b8', fontSize: '10px' }}>
              Telematics Legend
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#10b981' }} />
              <span>Driving (Fresh GPS)</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#0d9488' }} />
              <span>Loading / Unloading</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#f59e0b' }} />
              <span>Delayed / Stale GPS (&gt; 5m)</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <div style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#64748b' }} />
              <span>Standby / Location Unavailable</span>
            </div>
          </div>
        </div>

      </div>

    </div>
  );
}
