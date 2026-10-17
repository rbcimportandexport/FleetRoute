import { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import './routePlanner.css';

const AUTOCOMPLETE_URL = import.meta.env.VITE_AUTOCOMPLETE_URL || 'https://photon.komoot.io';
const ROUTING_URL = import.meta.env.VITE_ROUTING_URL || 'https://router.project-osrm.org';

function MapIcon({ name, size = 18 }) {
  const paths = {
    search: <><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></>,
    location: <><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/></>,
    swap: <><path d="m7 7 3-3 3 3M10 4v13M17 17l-3 3-3-3M14 20V7"/></>,
    route: <><circle cx="5" cy="18" r="2"/><circle cx="19" cy="6" r="2"/><path d="M7 18h2a3 3 0 0 0 3-3V9a3 3 0 0 1 3-3h5"/></>,
    clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
    distance: <><path d="M3 17h18M6 14v6M18 14v6M10 15.5V19M14 15.5V19"/></>,
    close: <path d="m6 6 12 12M18 6 6 18"/>,
    chevron: <path d="m9 18 6-6-6-6"/>,
    car: <><path d="m5 11 2-5h10l2 5M4 11h16v7H4z"/><circle cx="7" cy="18" r="1.5"/><circle cx="17" cy="18" r="1.5"/></>,
    layers: <><path d="m12 3 9 5-9 5-9-5z"/><path d="m3 12 9 5 9-5M3 16l9 5 9-5"/></>,
    pin: <><path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></>,
    play: <path d="m8 5 11 7-11 7z"/>,
    pause: <><path d="M9 5v14M15 5v14"/></>,
    replay: <><path d="M4 12a8 8 0 1 0 2.3-5.7L4 8.6M4 4v4.6h4.6"/></>,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name]}</svg>;
}

function formatDistance(meters) {
  if (meters < 1000) return `${Math.round(meters)} m`;
  return `${(meters / 1000).toFixed(meters < 10000 ? 1 : 0)} km`;
}

function formatDuration(seconds) {
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest ? `${hours} hr ${rest} min` : `${hours} hr`;
}

function instructionFor(step) {
  const road = step.name ? ` onto ${step.name}` : '';
  const modifier = step.maneuver?.modifier ? ` ${step.maneuver.modifier}` : '';
  const type = step.maneuver?.type;
  if (type === 'depart') return `Start${road}`;
  if (type === 'arrive') return 'Arrive at your destination';
  if (type === 'roundabout' || type === 'rotary') return `Enter the roundabout${road}`;
  if (type === 'merge') return `Merge${modifier}${road}`;
  if (type === 'fork') return `Keep${modifier}${road}`;
  if (type === 'continue' || type === 'new name') return `Continue${modifier}${road}`;
  return `Turn${modifier}${road}`;
}

function photonResult(feature, index) {
  const properties = feature.properties || {};
  const [lng, lat] = feature.geometry.coordinates;
  const primary = properties.name || properties.street || properties.city || properties.county || properties.country || 'Selected location';
  const parts = [
    properties.housenumber && properties.street ? `${properties.housenumber} ${properties.street}` : properties.street,
    properties.district,
    properties.city,
    properties.county,
    properties.state,
    properties.postcode,
    properties.country,
  ].filter(Boolean).filter((part, partIndex, values) => part !== primary && values.indexOf(part) === partIndex);
  return {
    id: `${properties.osm_type || 'place'}-${properties.osm_id || index}`,
    label: [primary, ...parts].join(', '),
    type: properties.type || properties.osm_value || 'place',
    point: { lat: Number(lat), lng: Number(lng) },
  };
}

function LocationInput({ type, label, value, point, onChange, onSearch, onLocate, busy }) {
  return (
    <div className="location-field">
      <span className={`location-node ${type}`} />
      <label htmlFor={`${type}-location`}>{label}</label>
      <div className={`location-input-wrap${point ? ' selected' : ''}`}>
        <input
          id={`${type}-location`}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              event.preventDefault();
              onSearch();
            }
          }}
          placeholder={type === 'origin' ? 'Choose starting location' : 'Choose destination'}
          autoComplete="off"
        />
        {type === 'origin' && (
          <button type="button" onClick={onLocate} aria-label="Use current location" title="Use current location">
            <MapIcon name="location" size={17} />
          </button>
        )}
        <button type="button" onClick={onSearch} disabled={busy || value.trim().length < 2} aria-label={`Search ${label.toLowerCase()}`}>
          <MapIcon name="search" size={17} />
        </button>
      </div>
    </div>
  );
}

export default function RoutePlanner() {
  const mapElement = useRef(null);
  const mapInstance = useRef(null);
  const routeLayers = useRef(null);
  const baseLayers = useRef(null);
  const movingMarker = useRef(null);
  const previewFrame = useRef(null);
  const previewProgress = useRef(0);
  const lastMapFollow = useRef(0);
  const suggestionTimer = useRef(null);
  const suggestionRequest = useRef(null);
  const [origin, setOrigin] = useState({ query: '', point: null });
  const [destination, setDestination] = useState({ query: '', point: null });
  const [results, setResults] = useState([]);
  const [activeField, setActiveField] = useState(null);
  const [searching, setSearching] = useState(false);
  const [routing, setRouting] = useState(false);
  const [route, setRoute] = useState(null);
  const [error, setError] = useState('');
  const [directionsOpen, setDirectionsOpen] = useState(false);
  const [mapStyle, setMapStyle] = useState('map');
  const [pinMode, setPinMode] = useState(false);
  const [previewRunning, setPreviewRunning] = useState(false);

  useEffect(() => {
    if (!mapElement.current || mapInstance.current) return undefined;
    const map = L.map(mapElement.current, { zoomControl: false, preferCanvas: true }).setView([22.9734, 78.6569], 5);
    const streets = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    });
    const satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 19,
      attribution: 'Imagery &copy; Esri, Vantor, Earthstar Geographics, and the GIS User Community',
    });
    const satelliteLabels = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 19,
      attribution: 'Labels &copy; Esri',
    });
    streets.addTo(map);
    baseLayers.current = { streets, satellite, satelliteLabels };
    L.control.zoom({ position: 'bottomright' }).addTo(map);
    routeLayers.current = L.layerGroup().addTo(map);
    mapInstance.current = map;
    window.setTimeout(() => map.invalidateSize(), 100);
    return () => {
      window.cancelAnimationFrame(previewFrame.current);
      window.clearTimeout(suggestionTimer.current);
      suggestionRequest.current?.abort();
      map.remove();
      mapInstance.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapInstance.current;
    const layers = baseLayers.current;
    if (!map || !layers) return;
    Object.values(layers).forEach((layer) => map.removeLayer(layer));
    if (mapStyle === 'satellite') {
      layers.satellite.addTo(map);
      layers.satelliteLabels.addTo(map);
    } else {
      layers.streets.addTo(map);
    }
  }, [mapStyle]);

  useEffect(() => {
    const map = mapInstance.current;
    const layers = routeLayers.current;
    if (!map || !layers) return;
    layers.clearLayers();
    movingMarker.current = null;

    const marker = (point, letter, className) => L.marker([point.lat, point.lng], {
      icon: L.divIcon({
        className: 'route-marker-wrap',
        html: `<span class="route-marker ${className}"><b>${letter}</b></span>`,
        iconSize: [34, 40],
        iconAnchor: [17, 38],
      }),
    }).addTo(layers);

    if (origin.point) marker(origin.point, 'A', 'start');
    if (destination.point) marker(destination.point, 'B', 'end');

    if (route?.geometry?.coordinates) {
      const points = route.geometry.coordinates.map(([lng, lat]) => [lat, lng]);
      L.polyline(points, { color: '#ffffff', weight: 9, opacity: .92 }).addTo(layers);
      const line = L.polyline(points, { color: '#1769e0', weight: 5, opacity: 1 }).addTo(layers);
      movingMarker.current = L.marker(points[0], {
        zIndexOffset: 1000,
        icon: L.divIcon({
          className: 'moving-vehicle-wrap',
          html: '<span class="moving-vehicle"><svg viewBox="0 0 24 24"><path d="m5 11 2-5h10l2 5M4 11h16v7H4z"/><circle cx="7" cy="18" r="1.5"/><circle cx="17" cy="18" r="1.5"/></svg></span>',
          iconSize: [42, 42],
          iconAnchor: [21, 21],
        }),
      }).addTo(layers);
      map.fitBounds(line.getBounds(), { padding: [55, 55], maxZoom: 15 });
    } else if (origin.point && destination.point) {
      map.fitBounds([[origin.point.lat, origin.point.lng], [destination.point.lat, destination.point.lng]], { padding: [55, 55], maxZoom: 14 });
    } else if ((origin.point || destination.point) && !pinMode) {
      const point = origin.point || destination.point;
      map.flyTo([point.lat, point.lng], 13);
    }
  }, [origin.point, destination.point, route, pinMode]);

  useEffect(() => {
    if (!route?.geometry?.coordinates || !previewRunning || !movingMarker.current || !mapInstance.current) return undefined;
    const points = route.geometry.coordinates.map(([lng, lat]) => [lat, lng]);
    const animationDuration = Math.min(60000, Math.max(18000, route.duration * 24));
    const startedAt = performance.now() - (previewProgress.current * animationDuration);
    lastMapFollow.current = 0;
    mapInstance.current.flyTo(points[Math.floor(previewProgress.current * (points.length - 1))], 16, { duration: .8 });

    const animate = (now) => {
      const progress = Math.min((now - startedAt) / animationDuration, 1);
      previewProgress.current = progress;
      const index = Math.min(Math.floor(progress * (points.length - 1)), points.length - 1);
      const position = points[index];
      movingMarker.current?.setLatLng(position);
      if (now - lastMapFollow.current > 500) {
        mapInstance.current?.panTo(position, { animate: true, duration: .45 });
        lastMapFollow.current = now;
      }
      if (progress < 1) {
        previewFrame.current = window.requestAnimationFrame(animate);
      } else {
        setPreviewRunning(false);
      }
    };

    previewFrame.current = window.requestAnimationFrame(animate);
    return () => window.cancelAnimationFrame(previewFrame.current);
  }, [route, previewRunning]);

  const loadSuggestions = async (type, query) => {
    const normalizedQuery = query.trim();
    if (normalizedQuery.length < 3) return;
    suggestionRequest.current?.abort();
    const controller = new AbortController();
    suggestionRequest.current = controller;
    setSearching(true);
    setError('');
    setActiveField(type);
    try {
      const params = new URLSearchParams({ q: normalizedQuery, limit: '5', lang: 'en' });
      const center = mapInstance.current?.getCenter();
      if (center) {
        params.set('lat', String(center.lat));
        params.set('lon', String(center.lng));
        params.set('zoom', String(mapInstance.current.getZoom()));
        params.set('location_bias_scale', '0.35');
      }
      const response = await fetch(`${AUTOCOMPLETE_URL}/api/?${params}`, { signal: controller.signal });
      if (!response.ok) throw new Error('Location search is unavailable.');
      const data = await response.json();
      const nextResults = (data.features || []).map(photonResult);
      setResults(nextResults);
      if (!nextResults.length) setError('No matching location found. Try a more specific address.');
    } catch (searchError) {
      if (searchError.name === 'AbortError') return;
      setResults([]);
      setError(searchError.message || 'Unable to search for that location.');
    } finally {
      if (suggestionRequest.current === controller) setSearching(false);
    }
  };

  const updateLocation = (type, query) => {
    const setter = type === 'origin' ? setOrigin : setDestination;
    setter({ query, point: null });
    setRoute(null);
    setPreviewRunning(false);
    previewProgress.current = 0;
    setResults([]);
    setActiveField(type);
    setError('');
    window.clearTimeout(suggestionTimer.current);
    suggestionRequest.current?.abort();
    if (query.trim().length < 3) {
      setSearching(false);
      return;
    }
    setSearching(true);
    suggestionTimer.current = window.setTimeout(() => loadSuggestions(type, query), 500);
  };

  const searchLocation = (type) => {
    const location = type === 'origin' ? origin : destination;
    window.clearTimeout(suggestionTimer.current);
    loadSuggestions(type, location.query);
  };

  const chooseResult = (result) => {
    const selectingOrigin = activeField === 'origin';
    const setter = selectingOrigin ? setOrigin : setDestination;
    setter({ query: result.label, point: result.point });
    setResults([]);
    setActiveField(null);
    setRoute(null);
    setError('');
    if (selectingOrigin && destination.point) calculateRoute(result.point, destination.point);
    if (!selectingOrigin && origin.point) calculateRoute(origin.point, result.point);
  };

  const useCurrentLocation = () => {
    setError('');
    if (!navigator.geolocation) {
      setError('Current location is not supported by this browser.');
      return;
    }
    setSearching(true);
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        setOrigin({ query: 'Current location', point: { lat: coords.latitude, lng: coords.longitude } });
        setRoute(null);
        setSearching(false);
      },
      () => {
        setError('Location permission was not available. Enter your starting point manually.');
        setSearching(false);
      },
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 30000 },
    );
  };

  const swapLocations = () => {
    setOrigin(destination);
    setDestination(origin);
    setRoute(null);
    setResults([]);
    setError('');
  };

  const calculateRoute = async (startPoint = origin.point, endPoint = destination.point) => {
    if (!startPoint || !endPoint) return;
    setRouting(true);
    setPreviewRunning(false);
    previewProgress.current = 0;
    setError('');
    setDirectionsOpen(false);
    try {
      const coordinates = `${startPoint.lng},${startPoint.lat};${endPoint.lng},${endPoint.lat}`;
      const params = new URLSearchParams({ overview: 'full', geometries: 'geojson', steps: 'true', alternatives: 'false' });
      const response = await fetch(`${ROUTING_URL}/route/v1/driving/${coordinates}?${params}`);
      if (!response.ok) throw new Error('Routing service is unavailable.');
      const data = await response.json();
      if (data.code !== 'Ok' || !data.routes?.length) throw new Error('No drivable route was found between these locations.');
      setRoute(data.routes[0]);
      setPreviewRunning(true);
    } catch (routeError) {
      setRoute(null);
      setPreviewRunning(false);
      setError(routeError.message || 'Unable to calculate this route.');
    } finally {
      setRouting(false);
    }
  };

  const clearRoute = () => {
    window.cancelAnimationFrame(previewFrame.current);
    previewProgress.current = 0;
    setPreviewRunning(false);
    setPinMode(false);
    setOrigin({ query: '', point: null });
    setDestination({ query: '', point: null });
    setRoute(null);
    setResults([]);
    setError('');
    mapInstance.current?.setView([22.9734, 78.6569], 5);
  };

  const beginPinning = () => {
    window.cancelAnimationFrame(previewFrame.current);
    previewProgress.current = 0;
    setPreviewRunning(false);
    setResults([]);
    setError('');
    setPinMode(true);
    if (origin.point && destination.point) {
      setOrigin({ query: '', point: null });
      setDestination({ query: '', point: null });
      setRoute(null);
    }
  };

  const togglePreview = () => {
    if (!route) return;
    if (previewProgress.current >= .999) {
      previewProgress.current = 0;
      const [lng, lat] = route.geometry.coordinates[0];
      movingMarker.current?.setLatLng([lat, lng]);
    }
    setPreviewRunning((running) => !running);
  };

  const replayPreview = () => {
    if (!route) return;
    window.cancelAnimationFrame(previewFrame.current);
    previewProgress.current = 0;
    const [lng, lat] = route.geometry.coordinates[0];
    movingMarker.current?.setLatLng([lat, lng]);
    setPreviewRunning(false);
    window.requestAnimationFrame(() => setPreviewRunning(true));
  };

  useEffect(() => {
    const map = mapInstance.current;
    if (!map || !pinMode) return undefined;
    const container = map.getContainer();
    container.classList.add('pin-mode');

    const handleMapClick = ({ latlng }) => {
      const point = { lat: Number(latlng.lat.toFixed(6)), lng: Number(latlng.lng.toFixed(6)) };
      const label = `Pinned point (${point.lat.toFixed(5)}, ${point.lng.toFixed(5)})`;
      setResults([]);
      setError('');
      setRoute(null);
      setPreviewRunning(false);
      previewProgress.current = 0;

      if (!origin.point) {
        setOrigin({ query: label, point });
        return;
      }

      setDestination({ query: label, point });
      setPinMode(false);
      calculateRoute(origin.point, point);
    };

    map.on('click', handleMapClick);
    return () => {
      container.classList.remove('pin-mode');
      map.off('click', handleMapClick);
    };
  }, [pinMode, origin.point]);

  const steps = route?.legs?.flatMap((leg) => leg.steps || []) || [];

  return (
    <section className="route-planner">
      <aside className="route-controls">
        <div className="route-heading">
          <div><p>Live navigation</p><h1>Route planner</h1></div>
          {(origin.query || destination.query) && <button type="button" onClick={clearRoute} aria-label="Clear route"><MapIcon name="close" /></button>}
        </div>

        <div className="travel-mode"><span><MapIcon name="car" size={17} /></span><div><strong>Driving</strong><small>Fastest available route</small></div></div>

        <div className="location-form">
          <div className="location-line" />
          <LocationInput type="origin" label="From" value={origin.query} point={origin.point} onChange={(value) => updateLocation('origin', value)} onSearch={() => searchLocation('origin')} onLocate={useCurrentLocation} busy={searching} />
          <button className="swap-button" type="button" onClick={swapLocations} aria-label="Swap locations"><MapIcon name="swap" size={17} /></button>
          <LocationInput type="destination" label="To" value={destination.query} point={destination.point} onChange={(value) => updateLocation('destination', value)} onSearch={() => searchLocation('destination')} busy={searching} />
        </div>

        {searching && activeField && <div className="search-state"><span className="route-loader" /> Finding location suggestions...</div>}
        {results.length > 0 && (
          <div className="place-results">
            <p>Location suggestions</p>
            {results.map((result) => (
              <button type="button" key={result.id} onClick={() => chooseResult(result)}>
                <span className="result-pin" />
                <span><strong>{result.label.split(',')[0]}</strong><small>{result.label.split(',').slice(1).join(',').trim()}</small></span>
                <MapIcon name="chevron" size={15} />
              </button>
            ))}
          </div>
        )}

        {error && <div className="route-error">{error}</div>}

        <button className="find-route-button" type="button" disabled={!origin.point || !destination.point || routing} onClick={() => calculateRoute()}>
          {routing ? <span className="route-loader light" /> : <MapIcon name="route" size={18} />}
          {routing ? 'Calculating route...' : 'Show route'}
        </button>

        {!route && !results.length && !searching && (
          <div className="route-help">
            <span><MapIcon name="route" size={21} /></span>
            <div><strong>Plan a live journey</strong><p>Search and select two real locations to calculate the driving route, distance, and estimated time.</p></div>
          </div>
        )}

        {route && (
          <div className="route-summary">
            <div className="route-summary-head"><div><p>Recommended route</p><strong>{formatDuration(route.duration)}</strong></div><span>Live</span></div>
            <div className="route-metrics">
              <div><MapIcon name="distance" /><span><small>Distance</small><strong>{formatDistance(route.distance)}</strong></span></div>
              <div><MapIcon name="clock" /><span><small>Est. time</small><strong>{formatDuration(route.duration)}</strong></span></div>
            </div>
            <button className="directions-toggle" type="button" onClick={() => setDirectionsOpen((open) => !open)}>
              Step-by-step directions <MapIcon name="chevron" size={16} />
            </button>
            {directionsOpen && (
              <ol className="directions-list">
                {steps.map((step, index) => (
                  <li key={`${step.maneuver.location.join('-')}-${index}`}>
                    <span>{index + 1}</span><div><strong>{instructionFor(step)}</strong><small>{formatDistance(step.distance)}</small></div>
                  </li>
                ))}
              </ol>
            )}
          </div>
        )}

        <p className="routing-credit">Suggestions by Photon · Data © OpenStreetMap contributors · Routing by OSRM</p>
      </aside>

      <div className="map-stage">
        <div ref={mapElement} className="live-map" aria-label="Interactive route map" />
        <div className="map-style-switch" role="group" aria-label="Map style">
          <span><MapIcon name="layers" size={15} /></span>
          <button type="button" className={mapStyle === 'map' ? 'active' : ''} aria-pressed={mapStyle === 'map'} onClick={() => setMapStyle('map')}>Map</button>
          <button type="button" className={mapStyle === 'satellite' ? 'active' : ''} aria-pressed={mapStyle === 'satellite'} onClick={() => setMapStyle('satellite')}>Satellite</button>
        </div>
        <button className={`pin-map-button${pinMode ? ' active' : ''}`} type="button" aria-pressed={pinMode} onClick={beginPinning}>
          <MapIcon name="pin" size={16} />
          {pinMode ? (origin.point ? 'Pin destination' : 'Pin starting point') : 'Pin locations'}
        </button>
        <div className="map-live-badge"><span /> Live map</div>
        {!route && <div className={`map-hint${pinMode ? ' pinning' : ''}`}><MapIcon name={pinMode ? 'pin' : 'route'} /><span>{pinMode ? (origin.point ? 'Click the map to pin destination B' : 'Click the map to pin starting point A') : 'Search locations or pin two points on the map'}</span></div>}
        {route && (
          <div className="route-playback">
            <span className={previewRunning ? 'running' : ''} />
            <div><strong>{previewRunning ? 'Following route' : 'Route preview paused'}</strong><small>Animated journey preview</small></div>
            <button type="button" onClick={togglePreview} aria-label={previewRunning ? 'Pause route preview' : 'Resume route preview'} title={previewRunning ? 'Pause' : 'Resume'}><MapIcon name={previewRunning ? 'pause' : 'play'} size={16} /></button>
            <button type="button" onClick={replayPreview} aria-label="Replay route preview" title="Replay"><MapIcon name="replay" size={16} /></button>
          </div>
        )}
      </div>
    </section>
  );
}
