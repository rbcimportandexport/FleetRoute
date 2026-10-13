import React, { useState, useEffect, useRef } from 'react';
import L from 'leaflet';
import { Compass, Gauge, MapPin, Navigation, Layers } from 'lucide-react';

export default function FleetMap({ 
  trip, 
  currentLocation, 
  speed = 0, 
  height = '380px',
  interactive = true 
}) {
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const markersLayerRef = useRef(null);
  const routeLayerRef = useRef(null);
  const truckMarkerRef = useRef(null);
  const streetTileLayerRef = useRef(null);
  const satelliteTileLayerRef = useRef(null);
  const satelliteLabelsLayerRef = useRef(null);

  const [mapLayer, setMapLayer] = useState('streets'); // 'streets' | 'satellite'

  const hasLiveGps = Boolean(currentLocation && typeof currentLocation.lat === 'number' && typeof currentLocation.lng === 'number');

  // Automatic size recalculation to prevent blank map tiles
  useEffect(() => {
    if (!mapContainerRef.current) return;
    const observer = new ResizeObserver(() => {
      mapInstanceRef.current?.invalidateSize();
    });
    observer.observe(mapContainerRef.current);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!mapContainerRef.current) return;

    // Initialize map if not yet created
    if (!mapInstanceRef.current) {
      const defaultCenter = [19.0760, 72.8777]; // Default view on map
      const map = L.map(mapContainerRef.current, {
        zoomControl: false,
        attributionControl: false,
        dragging: interactive,
        touchZoom: interactive,
        scrollWheelZoom: interactive ? true : false
      }).setView(defaultCenter, 11);

      if (interactive) {
        L.control.zoom({ position: 'bottomright' }).addTo(map);
      }

      // OpenStreetMap clean tile layer
      streetTileLayerRef.current = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19
      });

      // Google Satellite Hybrid (High-resolution aerial satellite imagery + roads + place labels)
      satelliteTileLayerRef.current = L.tileLayer('https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', {
        maxZoom: 20,
        subdomains: ['0', '1', '2', '3']
      });

      // Start with selected layer
      if (mapLayer === 'satellite') {
        satelliteTileLayerRef.current.addTo(map);
      } else {
        streetTileLayerRef.current.addTo(map);
      }

      markersLayerRef.current = L.layerGroup().addTo(map);
      routeLayerRef.current = L.layerGroup().addTo(map);

      mapInstanceRef.current = map;
    }

    // Switch Tile Layer
    const map = mapInstanceRef.current;
    if (map && streetTileLayerRef.current && satelliteTileLayerRef.current) {
      if (mapLayer === 'satellite') {
        if (map.hasLayer(streetTileLayerRef.current)) map.removeLayer(streetTileLayerRef.current);
        if (!map.hasLayer(satelliteTileLayerRef.current)) satelliteTileLayerRef.current.addTo(map);
      } else {
        if (map.hasLayer(satelliteTileLayerRef.current)) map.removeLayer(satelliteTileLayerRef.current);
        if (!map.hasLayer(streetTileLayerRef.current)) streetTileLayerRef.current.addTo(map);
      }
    }

    markersLayerRef.current.clearLayers();
    routeLayerRef.current.clearLayers();
    truckMarkerRef.current = null;

    if (!trip || !trip.stops || trip.stops.length === 0) return;

    // Collect coordinates for polyline strictly from valid coordinates
    const routeCoords = [];

    // Render stops as styled markers with numbers
    trip.stops.forEach((stop, idx) => {
      const lat = stop.location?.lat;
      const lng = stop.location?.lng;
      if (typeof lat !== 'number' || typeof lng !== 'number') return;

      routeCoords.push([lat, lng]);

      const isCompleted = stop.status === 'completed';
      const isCurrent = trip.currentStopIndex === idx && trip.status === 'in_progress';
      
      let bgColor = '#0284c7'; // default blue
      if (stop.type === 'pickup') bgColor = '#0d9488'; // teal for pickup
      if (stop.type === 'delivery') bgColor = '#4f46e5'; // indigo for delivery
      if (stop.type === 'return') bgColor = '#d97706'; // amber for return depot
      if (isCompleted) bgColor = '#10b981'; // green for completed
      if (isCurrent) bgColor = '#ef4444'; // pulsing red for current active stop

      const customHtml = `
        <div style="
          width: 32px;
          height: 32px;
          border-radius: 50%;
          background: ${bgColor};
          border: 3px solid #ffffff;
          box-shadow: 0 3px 10px rgba(0,0,0,0.3);
          display: flex;
          align-items: center;
          justify-content: center;
          color: #ffffff;
          font-weight: 800;
          font-size: 13px;
          font-family: 'Plus Jakarta Sans', sans-serif;
          ${isCurrent ? 'animation: pulse 1.5s infinite;' : ''}
        ">
          ${idx + 1}
        </div>
      `;

      const icon = L.divIcon({
        className: 'custom-fleet-stop-marker',
        html: customHtml,
        iconSize: [32, 32],
        iconAnchor: [16, 16]
      });

      const marker = L.marker([lat, lng], { icon });
      const popupHtml = `
        <div style="font-family: sans-serif; font-size: 13px; min-width: 180px;">
          <div style="font-weight: 700; color: #0f172a; margin-bottom: 4px;">
            Stop ${idx + 1}: ${stop.location?.name || 'Stop'}
          </div>
          <div style="font-size: 11px; text-transform: uppercase; color: ${bgColor}; font-weight: 700; margin-bottom: 6px;">
            ${stop.type.toUpperCase()} • ${stop.status.replace('_', ' ').toUpperCase()}
          </div>
          <div style="font-size: 12px; color: #475569; margin-bottom: 4px;">
            ${stop.location?.address || 'Waypoint'}
          </div>
          ${stop.recipientName ? `<div style="font-size: 11px; color: #64748b;">Recipient: <strong>${stop.recipientName}</strong></div>` : ''}
          ${stop.cargoSummary ? `<div style="font-size: 11px; color: #0284c7; margin-top: 4px;">Cargo: ${stop.cargoSummary}</div>` : ''}
        </div>
      `;
      marker.bindPopup(popupHtml);
      markersLayerRef.current.addLayer(marker);
    });

    // Draw route polyline
    if (routeCoords.length > 1) {
      const polyline = L.polyline(routeCoords, {
        color: mapLayer === 'satellite' ? '#38bdf8' : '#0284c7',
        weight: 4,
        opacity: 0.9,
        dashArray: '6, 8',
        lineCap: 'round'
      });
      routeLayerRef.current.addLayer(polyline);
    }

    // Live vehicle position marker: ONLY render when authentic GPS is received
    if (hasLiveGps) {
      const truckLat = currentLocation.lat;
      const truckLng = currentLocation.lng;

      const truckIconHtml = `
        <div style="
          width: 38px;
          height: 38px;
          border-radius: 50%;
          background: #0f172a;
          border: 3px solid #10b981;
          box-shadow: 0 4px 14px rgba(16, 185, 129, 0.5);
          display: flex;
          align-items: center;
          justify-content: center;
          color: #38bdf8;
        ">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"/>
            <path d="M15 18H9"/>
            <path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.624l-3.48-4.35A1 1 0 0 0 17.52 8H14"/>
            <circle cx="17" cy="18" r="2"/>
            <circle cx="7" cy="18" r="2"/>
          </svg>
        </div>
      `;

      const truckIcon = L.divIcon({
        className: 'custom-fleet-truck-marker',
        html: truckIconHtml,
        iconSize: [38, 38],
        iconAnchor: [19, 19]
      });

      truckMarkerRef.current = L.marker([truckLat, truckLng], { icon: truckIcon }).addTo(markersLayerRef.current);

      truckMarkerRef.current.bindPopup(`
        <div style="font-family: sans-serif; font-size: 13px;">
          <div style="font-weight: 700; color: #0f172a;">${trip.vehicleRegistration || 'Vehicle'}</div>
          <div style="font-size: 12px; color: #64748b;">Driver: ${trip.driverName || 'Driver'}</div>
          <div style="font-size: 12px; color: #059669; font-weight: 600; margin-top: 4px;">
            Speed: ${speed} km/h • Authenticated GPS Telemetry
          </div>
          ${currentLocation.timestamp ? `<div style="font-size: 10px; color: #94a3b8; margin-top: 2px;">Recorded: ${new Date(currentLocation.timestamp).toLocaleTimeString()}</div>` : ''}
        </div>
      `);
    }

    // Fit bounds smoothly
    const allBoundsCoords = [...routeCoords];
    if (hasLiveGps) {
      allBoundsCoords.push([currentLocation.lat, currentLocation.lng]);
    }

    if (allBoundsCoords.length > 0) {
      const bounds = L.latLngBounds(allBoundsCoords);
      map.fitBounds(bounds, { padding: [40, 40], maxZoom: 15 });
    }

    // Invalidate size on initial mount
    setTimeout(() => {
      map.invalidateSize();
    }, 200);

  }, [trip, currentLocation, speed, hasLiveGps, interactive, mapLayer]);

  return (
    <div style={{ position: 'relative', width: '100%', height, borderRadius: '12px', overflow: 'hidden', border: '1px solid var(--slate-200)' }}>
      <div ref={mapContainerRef} style={{ width: '100%', height: '100%' }} />

      {/* Floating Top Bar: Layer Switcher & GPS Telemetry Badge (Non-Overlapping Flex Layout) */}
      <div style={{
        position: 'absolute',
        top: '10px',
        left: '10px',
        right: '10px',
        zIndex: 500,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '8px',
        pointerEvents: 'none'
      }}>
        {/* Layer Mode Toggle */}
        <div style={{
          pointerEvents: 'auto',
          display: 'flex',
          background: 'rgba(255, 255, 255, 0.96)',
          backdropFilter: 'blur(8px)',
          borderRadius: '8px',
          boxShadow: '0 2px 8px rgba(0,0,0,0.18)',
          border: '1px solid var(--slate-200)',
          padding: '3px',
          gap: '3px'
        }}>
          <button
            type="button"
            onClick={() => setMapLayer('streets')}
            style={{
              border: 'none',
              background: mapLayer === 'streets' ? 'var(--primary-blue)' : 'transparent',
              color: mapLayer === 'streets' ? '#ffffff' : 'var(--slate-700)',
              padding: '4px 8px',
              borderRadius: '6px',
              fontSize: '11px',
              fontWeight: 700,
              cursor: 'pointer'
            }}
          >
            Street
          </button>
          <button
            type="button"
            onClick={() => setMapLayer('satellite')}
            style={{
              border: 'none',
              background: mapLayer === 'satellite' ? 'var(--primary-blue)' : 'transparent',
              color: mapLayer === 'satellite' ? '#ffffff' : 'var(--slate-700)',
              padding: '4px 8px',
              borderRadius: '6px',
              fontSize: '11px',
              fontWeight: 700,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '3px'
            }}
          >
            <Layers size={11} />
            <span>Satellite</span>
          </button>
        </div>

        {/* GPS Telemetry Status Badge */}
        <div style={{
          pointerEvents: 'auto',
          background: 'rgba(15, 23, 42, 0.90)',
          backdropFilter: 'blur(8px)',
          color: '#ffffff',
          padding: '5px 10px',
          borderRadius: '8px',
          fontSize: '11px',
          fontWeight: 600,
          display: 'flex',
          alignItems: 'center',
          gap: '6px',
          border: '1px solid rgba(255, 255, 255, 0.1)',
          boxShadow: '0 4px 12px rgba(0, 0, 0, 0.2)',
          maxWidth: '100%'
        }}>
          <div style={{ width: '7px', height: '7px', borderRadius: '50%', background: hasLiveGps ? '#10b981' : '#64748b', flexShrink: 0 }} />
          <span style={{ whiteSpace: 'nowrap' }}>
            {hasLiveGps ? 'LIVE GPS TELEMETRY' : 'WAITING FOR GPS'}
          </span>
          {hasLiveGps && (
            <>
              <span style={{ color: '#94a3b8' }}>|</span>
              <span style={{ fontFamily: 'var(--font-mono)', color: '#38bdf8' }}>{speed} km/h</span>
            </>
          )}
        </div>
      </div>

      {/* Map Legend */}
      <div style={{
        position: 'absolute',
        bottom: '12px',
        left: '12px',
        zIndex: 500,
        background: 'rgba(255, 255, 255, 0.94)',
        backdropFilter: 'blur(8px)',
        padding: '6px 10px',
        borderRadius: '6px',
        fontSize: '11px',
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        border: '1px solid #cbd5e1',
        boxShadow: '0 2px 8px rgba(0,0,0,0.06)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#0d9488', display: 'inline-block' }}></span>
          <span style={{ color: '#334155', fontWeight: 600 }}>Pickup</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#4f46e5', display: 'inline-block' }}></span>
          <span style={{ color: '#334155', fontWeight: 600 }}>Delivery</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#10b981', display: 'inline-block' }}></span>
          <span style={{ color: '#334155', fontWeight: 600 }}>Done</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#ef4444', display: 'inline-block' }}></span>
          <span style={{ color: '#334155', fontWeight: 600 }}>Active</span>
        </div>
      </div>
    </div>
  );
}
