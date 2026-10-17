import { useEffect, useMemo, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import './routePlanner.css';
import { calculateGoogleRoute, googleSuggestions, resolveGoogleSuggestion, useGoogleMaps, GOOGLE_AUTH_ERROR_EVENT } from './maps/googleMaps';
import { createGoogleMapView } from './maps/googleMapView';

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
    bike: <><circle cx="5.5" cy="17.5" r="3.5"/><circle cx="18.5" cy="17.5" r="3.5"/><path d="M15 6h-3l-2.5 6.5h6zM5.5 17.5l4-8h5l4 8M12 10.5l-3 7"/></>,
    truck: <><rect x="1" y="5" width="14" height="11" rx="1"/><path d="M15 9h4l3 3.5V16h-7z"/><circle cx="5.5" cy="18.5" r="2.5"/><circle cx="17.5" cy="18.5" r="2.5"/></>,
    traffic: <><rect x="6" y="2" width="12" height="20" rx="3"/><circle cx="12" cy="6" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="12" cy="18" r="2"/></>,
    gauge: <><path d="m12 14 3-3"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/><circle cx="12" cy="14" r="2"/></>,
    layers: <><path d="m12 3 9 5-9 5-9-5z"/><path d="m3 12 9 5 9-5M3 16l9 5 9-5"/></>,
    pin: <><path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></>,
    play: <path d="m8 5 11 7-11 7z"/>,
    stop: <rect x="6" y="6" width="12" height="12" rx="2"/>,
    user: <><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></>,
    send: <><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></>,
    check: <path d="M20 6 9 17l-5-5"/>,
    plus: <><path d="M12 5v14M5 12h14"/></>,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name] || paths.route}</svg>;
}

const VEHICLE_CATEGORIES = [
  { id: 'bike', label: 'Bike', sublabel: 'Two-Wheeler', icon: 'bike', maxSpeed: 70, defaultSpeed: 45, speedFactor: 0.95, googleMode: 'TWO_WHEELER' },
  { id: 'car', label: 'Car', sublabel: 'Passenger / Light', icon: 'car', maxSpeed: 85, defaultSpeed: 60, speedFactor: 1.0, googleMode: 'DRIVING' },
  { id: 'truck', label: 'Truck', sublabel: 'Commercial Fleet', icon: 'truck', maxSpeed: 55, defaultSpeed: 45, speedFactor: 1.3, googleMode: 'DRIVING', hasModels: true },
];

const TRUCK_MODELS = [
  {
    id: 'tata-ace',
    label: 'Tata Ace (Chota Hathi)',
    type: 'LCV (Light Commercial)',
    wheels: 4,
    payload: '0.75 - 1.2 Ton',
    maxSpeed: 65,
    defaultSpeed: 50,
    speedFactor: 1.15,
    badge: 'LCV 1T',
    description: 'City intra-delivery & narrow commercial lanes',
  },
  {
    id: 'eicher-6w',
    label: '6-Wheeler MCV (Eicher 11.10)',
    type: 'Medium Goods Carrier',
    wheels: 6,
    payload: '7.5 Ton',
    maxSpeed: 55,
    defaultSpeed: 44,
    speedFactor: 1.28,
    badge: 'MCV 6W',
    description: 'State highway & regional freight logistics',
  },
  {
    id: 'heavy-10w',
    label: '10-12 Wheeler HCV (Signa / 2823)',
    type: 'Heavy Commercial Vehicle',
    wheels: 10,
    payload: '20 Ton',
    maxSpeed: 48,
    defaultSpeed: 38,
    speedFactor: 1.45,
    badge: 'HCV 10W',
    description: 'Interstate heavy freight & bulk goods',
  },
  {
    id: 'trailer-multi',
    label: 'Multi-Axle Trailer (40ft Container)',
    type: 'Heavy Long-Haul Haulage',
    wheels: 18,
    payload: '38 Ton',
    maxSpeed: 40,
    defaultSpeed: 30,
    speedFactor: 1.65,
    badge: 'TRAILER',
    description: 'Port container & heavy industrial transport',
  },
];

function formatDistance(meters) {
  if (!Number.isFinite(meters) || meters <= 0) return '0 km';
  if (meters < 1000) return `${Math.round(meters)} m`;
  return `${(meters / 1000).toFixed(meters < 10000 ? 1 : 0)} km`;
}

function formatDuration(seconds) {
  if (!Number.isFinite(seconds) || seconds <= 0) return '0 min';
  const minutes = Math.round(seconds / 60);
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest ? `${hours} hr ${rest} min` : `${hours} hr`;
}

function distanceBetweenCoords(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function instructionFor(step) {
  if (step.instruction) return step.instruction;
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
    primary,
  };
}

const LOCAL_KNOWN_PLACES = [
  {
    id: 'local-jolva',
    label: 'Jolva, Palsana Taluka, Surat, Gujarat (Jolva GIDC)',
    primary: 'Jolva (Palsana)',
    showOnMap: true,
    keywords: ['jolva', 'jolwa', 'jolvas', 'gidc jolva', 'chalthan jolva', 'jolva gam', 'jolva palsana'],
    point: { lat: 21.1610, lng: 73.0070 },
  },
  {
    id: 'local-rbc',
    label: 'RBC Import & Export / RBC Salon Furniture (Haldharu-Mota Road, Surat)',
    primary: 'RBC Import & Export (Head Office)',
    showOnMap: true,
    keywords: ['rbc', 'rbc import', 'rbc salon', 'ramdev beauty', 'rbc warehouse'],
    point: { lat: 21.1732, lng: 72.9618 },
  },
  {
    id: 'local-umbhel',
    label: 'Umbhel, Kamrej Taluka, Surat, Gujarat',
    primary: 'Umbhel (Kamrej)',
    showOnMap: false,
    keywords: ['umbhel', 'umbel', 'umbhel kamrej', 'umbhel garden'],
    point: { lat: 21.1896, lng: 72.9682 },
  },
  {
    id: 'local-kadodara',
    label: 'Kadodara, Surat, Gujarat',
    primary: 'Kadodara',
    showOnMap: false,
    keywords: ['kadodara', 'kadodra'],
    point: { lat: 21.1722, lng: 72.9600 },
  },
  {
    id: 'local-chalthan',
    label: 'Chalthan, Surat, Gujarat',
    primary: 'Chalthan',
    showOnMap: false,
    keywords: ['chalthan', 'chaltan'],
    point: { lat: 21.1680, lng: 72.9840 },
  },
  {
    id: 'local-palsana',
    label: 'Palsana, Surat, Gujarat',
    primary: 'Palsana',
    showOnMap: false,
    keywords: ['palsana'],
    point: { lat: 21.0855, lng: 72.9960 },
  },
];

function normalizeSearchText(value) {
  return value
    .toLocaleLowerCase('en-IN')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function rankSuggestion(result, query) {
  const label = normalizeSearchText(result.label);
  const primary = normalizeSearchText(result.primary);
  const tokens = [...new Set(normalizeSearchText(query).split(' ').filter(Boolean))];
  const firstToken = tokens[0] || '';
  const matchedTokens = tokens.filter((token) => label.includes(token)).length;
  let score = matchedTokens * 20;

  if (firstToken && primary === firstToken) score += 120;
  else if (firstToken && primary.startsWith(firstToken)) score += 80;
  else if (firstToken && label.split(' ').includes(firstToken)) score += 45;
  if (tokens.length && matchedTokens === tokens.length) score += 60;

  return score;
}

function LocationInput({ type, label, value, point, onChange, onSearch, onLocate, busy, disabled }) {
  return (
    <div className="location-field">
      <span className={`location-node ${type}`} />
      <label htmlFor={`${type}-location`}>{label}</label>
      <div className={`location-input-wrap${point ? ' selected' : ''}`}>
        <input
          id={`${type}-location`}
          value={value}
          disabled={disabled}
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
          <button type="button" onClick={onLocate} disabled={disabled} aria-label="Use current location" title="Use current location">
            <MapIcon name="location" size={17} />
          </button>
        )}
        <button type="button" onClick={onSearch} disabled={disabled || busy || value.trim().length < 3} aria-label={`Search ${label.toLowerCase()}`}>
          <MapIcon name="search" size={17} />
        </button>
      </div>
    </div>
  );
}

export default function RoutePlanner({
  drivers = [],
  onAssignTrip,
  onAddDriver,
  preselectedDriverId,
}) {
  const mapElement = useRef(null);
  const mapInstance = useRef(null);
  const routeLayers = useRef(null);
  const baseLayers = useRef(null);
  const movingMarker = useRef(null);
  const locationWatch = useRef(null);
  const currentLookupWatch = useRef(null);
  const currentLookupTimer = useRef(null);
  const suggestionTimer = useRef(null);
  const suggestionRequest = useRef(null);
  const routeRequest = useRef(null);
  const googleSearchSessions = useRef({ origin: {}, destination: {} });
  const [mapReady, setMapReady] = useState(false);
  const [mapError, setMapError] = useState('');
  const [origin, setOrigin] = useState({ query: '', point: null });
  const [destination, setDestination] = useState({ query: '', point: null });
  const [results, setResults] = useState([]);
  const [activeField, setActiveField] = useState(null);
  const [searching, setSearching] = useState(false);
  const [routing, setRouting] = useState(false);
  const [route, setRoute] = useState(null);
  const [error, setError] = useState('');
  const [directionsOpen, setDirectionsOpen] = useState(false);
  const [mapStyle, setMapStyle] = useState(useGoogleMaps ? 'satellite' : 'map');
  const [pinMode, setPinMode] = useState(false);
  const [tracking, setTracking] = useState(false);
  const [requestingLocation, setRequestingLocation] = useState(false);
  const [vehicleCategory, setVehicleCategory] = useState('truck');
  const [truckModel, setTruckModel] = useState('eicher-6w');
  const [trafficEnabled, setTrafficEnabled] = useState(true);
  const [currentSpeed, setCurrentSpeed] = useState(0);
  const [simulating, setSimulating] = useState(false);
  const [simProgressStep, setSimProgressStep] = useState(0);
  const [gpsProgressStep, setGpsProgressStep] = useState(0);
  const simulationTimer = useRef(null);
  const simStepRef = useRef(0);
  const overspeedAlertSent = useRef(false);
  const arrivalAlertSent = useRef(false);

  // Live GPS calibration for desktop Wi-Fi / IP offset correction
  const [calibratingGps, setCalibratingGps] = useState(false);
  const [calibrationOffset, setCalibrationOffset] = useState({ lat: 0, lng: 0 });
  const calibrationOffsetRef = useRef({ lat: 0, lng: 0 });
  const [lastRawGps, setLastRawGps] = useState(null);
  const [gpsAccuracy, setGpsAccuracy] = useState(null);

  // Driver Assignment & Remark State
  const [selectedDriverId, setSelectedDriverId] = useState('');
  const [tripCargo, setTripCargo] = useState('Commercial Goods / Freight');
  const [tripRemark, setTripRemark] = useState('');
  const [dispatchNotice, setDispatchNotice] = useState('');
  const [showDriverRoster, setShowDriverRoster] = useState(false);
  const [addDriverModalOpen, setAddDriverModalOpen] = useState(false);

  // Quick driver registration form fields
  const [quickDriverName, setQuickDriverName] = useState('');
  const [quickDriverPhone, setQuickDriverPhone] = useState('');
  const [quickDriverEmail, setQuickDriverEmail] = useState('');
  const [quickDriverPassword, setQuickDriverPassword] = useState('');
  const [quickDriverPin, setQuickDriverPin] = useState('');
  const [quickDriverPlate, setQuickDriverPlate] = useState('GJ-05-');
  const [quickVehicleModel, setQuickVehicleModel] = useState('6-Wheeler MCV (Eicher 11.10)');
  const [quickDriverHub, setQuickDriverHub] = useState('Surat Central Depot');

  const selectDriverForTrip = (driver) => {
    if (!driver) return;
    setSelectedDriverId(driver.id);
    if (driver.vehicle?.category === 'bike') {
      setVehicleCategory('bike');
    } else if (driver.vehicle?.category === 'car') {
      setVehicleCategory('car');
    } else {
      setVehicleCategory('truck');
      const mod = driver.vehicle?.model || '';
      if (mod.includes('Tata Ace')) setTruckModel('tata-ace');
      else if (mod.includes('Eicher')) setTruckModel('eicher-6w');
      else if (mod.includes('Signa') || mod.includes('HCV')) setTruckModel('heavy-10w');
      else if (mod.includes('Trailer')) setTruckModel('trailer-multi');
    }
    if (driver.baseHub) {
      setOrigin({ query: driver.baseHub, point: null });
    }
    setError('');
  };

  useEffect(() => {
    if (preselectedDriverId && drivers.length > 0) {
      const target = drivers.find((d) => d.id === preselectedDriverId);
      if (target) {
        selectDriverForTrip(target);
        setShowDriverRoster(true);
      }
    }
  }, [preselectedDriverId, drivers]);

  const handleDispatchTrip = (e) => {
    e?.preventDefault();
    if (!origin.query || !destination.query) {
      setError('Please choose both starting location (From) and destination (To) to dispatch trip.');
      return;
    }
    if (!selectedDriverId) {
      setError('Please select a commercial driver from the fleet roster to assign this trip.');
      return;
    }
    const targetDriver = drivers.find((d) => d.id === selectedDriverId);
    if (!targetDriver) {
      setError('Selected driver was not found.');
      return;
    }

    if (onAssignTrip) {
      onAssignTrip({
        driverId: selectedDriverId,
        origin: origin.query,
        destination: destination.query,
        cargo: tripCargo.trim() || 'General Commercial Freight',
        distance: route ? formatDistance(route.distance) : 'Calculated Route',
        eta: route ? formatDuration(adjustedDuration) : 'On Schedule',
        remark: tripRemark.trim(),
      });
    }

    playNotificationChime();
    setDispatchNotice(`Trip successfully assigned to ${targetDriver.name} (${targetDriver.vehicle.plate})!`);
    setError('');
    setTimeout(() => {
      setDispatchNotice('');
    }, 7000);
  };

  const handleQuickAddDriver = (e) => {
    e.preventDefault();
    if (!quickDriverName.trim() || !quickDriverPhone.trim()) return;

    const emailValue = quickDriverEmail.trim() || `${quickDriverName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '.')}@fleetroute.in`;
    const passwordValue = quickDriverPassword.trim() || 'Driver@123';
    const pinValue = quickDriverPin.trim() || String(Math.floor(1000 + Math.random() * 9000));

    const newDriver = {
      id: `driver-${Date.now()}`,
      name: quickDriverName.trim(),
      phone: quickDriverPhone.trim(),
      email: emailValue,
      license: `GJ05-${new Date().getFullYear()}-00${Math.floor(1000 + Math.random() * 9000)}`,
      experience: '5 Years',
      rating: '4.8',
      status: 'available',
      baseHub: quickDriverHub,
      loginCredentials: {
        username: emailValue,
        password: passwordValue,
        pin: pinValue,
        loginEnabled: true,
      },
      vehicle: {
        model: quickVehicleModel,
        plate: quickDriverPlate.trim().toUpperCase() || `GJ-05-XX-${Math.floor(1000 + Math.random() * 9000)}`,
        category: quickVehicleModel.toLowerCase().includes('bike') ? 'bike' : quickVehicleModel.toLowerCase().includes('car') ? 'car' : 'truck',
        type: quickVehicleModel,
        maxSpeed: quickVehicleModel.includes('Trailer') ? 40 : quickVehicleModel.includes('HCV') ? 48 : quickVehicleModel.includes('Tata Ace') ? 65 : 55,
        capacity: quickVehicleModel.includes('Trailer') ? '38 Ton' : quickVehicleModel.includes('Signa') ? '20 Ton' : '7.5 Ton',
      },
      currentTrip: null,
      lastTrip: null,
      recentTrips: [],
      alertHistory: [],
    };

    if (onAddDriver) {
      onAddDriver(newDriver);
    }
    setSelectedDriverId(newDriver.id);
    playNotificationChime();
    setQuickDriverName('');
    setQuickDriverPhone('');
    setQuickDriverEmail('');
    setQuickDriverPassword('');
    setQuickDriverPin('');
    setAddDriverModalOpen(false);
  };

  const selectedDriver = drivers.find((d) => d.id === selectedDriverId);

  const activeVehicle = vehicleCategory === 'truck'
    ? {
        category: 'truck',
        ...(TRUCK_MODELS.find((m) => m.id === truckModel) || TRUCK_MODELS[0]),
      }
    : {
        category: vehicleCategory,
        ...(VEHICLE_CATEGORIES.find((c) => c.id === vehicleCategory) || VEHICLE_CATEGORIES[1]),
        payload: vehicleCategory === 'bike' ? 'Personal / 20 kg' : 'Passenger / 400 kg',
        wheels: vehicleCategory === 'bike' ? 2 : 4,
      };

  useEffect(() => {
    if (!mapElement.current || mapInstance.current) return undefined;
    if (useGoogleMaps) {
      const controller = new AbortController();
      const authenticationFailed = () => {
        setMapError('Google Maps could not authorize this website. Check the key, enabled APIs, billing and website restrictions in Google Cloud.');
        setMapReady(false);
      };
      window.addEventListener(GOOGLE_AUTH_ERROR_EVENT, authenticationFailed);
      createGoogleMapView(mapElement.current, controller.signal).then((map) => {
        if (controller.signal.aborted) { map.remove(); return; }
        mapInstance.current = map;
        setMapReady(true);
      }).catch((loadError) => {
        if (!controller.signal.aborted) setMapError(loadError.message);
      });
      return () => {
        controller.abort();
        window.removeEventListener(GOOGLE_AUTH_ERROR_EVENT, authenticationFailed);
        mapInstance.current?.remove();
        mapInstance.current = null;
      };
    }
    const map = L.map(mapElement.current, {
      zoomControl: false,
      preferCanvas: true,
      minZoom: 3,
      maxZoom: 22,
      scrollWheelZoom: true,
      doubleClickZoom: true,
      touchZoom: true,
      boxZoom: true,
      zoomSnap: 0.5,
      zoomDelta: 1,
      wheelPxPerZoomLevel: 50,
    }).setView([22.9734, 78.6569], 5);
    map.createPane('hybridRoads');
    map.getPane('hybridRoads').style.zIndex = '340';
    map.getPane('hybridRoads').style.pointerEvents = 'none';
    map.createPane('hybridLabels');
    map.getPane('hybridLabels').style.zIndex = '360';
    map.getPane('hybridLabels').style.pointerEvents = 'none';
    const streets = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxNativeZoom: 19,
      maxZoom: 22,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    });
    const satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
      maxNativeZoom: 19,
      maxZoom: 22,
      attribution: 'Imagery &copy; Esri, Earthstar Geographics',
    });
    const hybridTransportation = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}', {
      maxNativeZoom: 19,
      maxZoom: 22,
      pane: 'hybridRoads',
      opacity: 0.95,
    });
    const hybridReference = L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}{r}.png', {
      subdomains: 'abcd',
      maxNativeZoom: 19,
      maxZoom: 22,
      pane: 'hybridLabels',
      opacity: 1,
      className: 'esri-hybrid-labels',
      attribution: 'Labels &copy; OpenStreetMap contributors &copy; CARTO',
    });
    streets.addTo(map);
    baseLayers.current = { streets, satellite, hybridTransportation, hybridReference };
    L.control.zoom({ position: 'bottomright' }).addTo(map);
    routeLayers.current = L.layerGroup().addTo(map);
    mapInstance.current = map;
    setMapReady(true);
    const resizeTimer = window.setTimeout(() => map.invalidateSize(), 100);
    return () => {
      window.clearTimeout(resizeTimer);
      map.remove();
      mapInstance.current = null;
    };
  }, []);

  useEffect(() => () => {
    if (locationWatch.current !== null) navigator.geolocation.clearWatch(locationWatch.current);
    if (currentLookupWatch.current !== null) navigator.geolocation.clearWatch(currentLookupWatch.current);
    if (simulationTimer.current) clearInterval(simulationTimer.current);
    window.clearTimeout(currentLookupTimer.current);
    window.clearTimeout(suggestionTimer.current);
    suggestionRequest.current?.abort();
    routeRequest.current?.abort();
  }, []);

  useEffect(() => {
    const map = mapInstance.current;
    if (map?.provider === 'google') { map.setStyle(mapStyle); return; }
    const layers = baseLayers.current;
    if (!map || !layers) return;
    Object.values(layers).forEach((layer) => map.removeLayer(layer));
    if (mapStyle === 'satellite') {
      layers.satellite.addTo(map);
      layers.hybridTransportation.addTo(map);
      layers.hybridReference.addTo(map);
    } else {
      layers.streets.addTo(map);
    }
  }, [mapStyle, mapReady]);

  useEffect(() => {
    const map = mapInstance.current;
    if (map?.provider === 'google') {
      map.drawRoute(origin, destination, route, pinMode);
      return;
    }
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

    if (origin.point?.accuracy) {
      L.circle([origin.point.lat, origin.point.lng], {
        radius: origin.point.accuracy,
        color: '#1769e0',
        weight: 1.5,
        opacity: .8,
        fillColor: '#2d7be5',
        fillOpacity: .12,
      }).bindTooltip(`Location accuracy: ±${Math.round(origin.point.accuracy)} m`).addTo(layers);
    }
    if (origin.point) marker(origin.point, 'A', 'start');
    if (destination.point) marker(destination.point, 'B', 'end');

    if (route?.geometry?.coordinates) {
      const points = route.geometry.coordinates.map(([lng, lat]) => [lat, lng]);
      L.polyline(points, { color: '#ffffff', weight: 9, opacity: .92 }).addTo(layers);
      const line = L.polyline(points, { color: '#1769e0', weight: 5, opacity: 1 }).addTo(layers);
      map.fitBounds(line.getBounds(), { padding: [55, 55], maxZoom: 15 });
    } else if (origin.point && destination.point) {
      map.fitBounds([[origin.point.lat, origin.point.lng], [destination.point.lat, destination.point.lng]], { padding: [55, 55], maxZoom: 14 });
    } else if ((origin.point || destination.point) && !pinMode) {
      const point = origin.point || destination.point;
      map.flyTo([point.lat, point.lng], 17, { duration: .8 });
    }
  }, [origin.point, destination.point, route, pinMode, mapReady]);

  const stopNavigation = () => {
    if (locationWatch.current !== null) {
      navigator.geolocation.clearWatch(locationWatch.current);
      locationWatch.current = null;
    }
    movingMarker.current?.remove();
    movingMarker.current = null;
    setTracking(false);
    setCalibratingGps(false);
    setGpsProgressStep(0);
    setRequestingLocation(false);
    setCurrentSpeed(0);
    overspeedAlertSent.current = false;
    arrivalAlertSent.current = false;
  };

  const stopSimulation = () => {
    if (simulationTimer.current) {
      clearInterval(simulationTimer.current);
      simulationTimer.current = null;
    }
    setSimulating(false);
    setSimProgressStep(0);
    simStepRef.current = 0;
    setCurrentSpeed(0);
    overspeedAlertSent.current = false;
    arrivalAlertSent.current = false;
    movingMarker.current?.remove();
    movingMarker.current = null;
  };

  const startSimulation = () => {
    if (!route?.geometry?.coordinates?.length) return;
    stopNavigation();
    stopSimulation();
    setSimulating(true);
    setSimProgressStep(0);
    simStepRef.current = 0;
    overspeedAlertSent.current = false;
    arrivalAlertSent.current = false;

    const path = route.geometry.coordinates;
    const initialPos = [path[0][1], path[0][0]];

    if (!movingMarker.current) {
      movingMarker.current = useGoogleMaps
        ? mapInstance.current.createLiveMarker(initialPos, activeVehicle.category)
        : L.marker(initialPos, {
            zIndexOffset: 1000,
            icon: L.divIcon({
              className: 'moving-vehicle-wrap',
              html: `<span class="moving-vehicle vehicle-${activeVehicle.category}"><svg viewBox="0 0 24 24"><path d="m5 11 2-5h10l2 5M4 11h16v7H4z"/><circle cx="7" cy="18" r="1.5"/><circle cx="17" cy="18" r="1.5"/></svg></span>`,
              iconSize: [42, 42],
              iconAnchor: [21, 21],
            }),
          }).addTo(routeLayers.current);
    } else {
      movingMarker.current.setLatLng(initialPos);
    }

    mapInstance.current?.flyTo(initialPos, 16, { duration: 0.5 });

    const totalSteps = path.length;
    // Step forward dynamically so test drive travels smoothly
    const stepIncrement = Math.max(1, Math.round(totalSteps / 110));

    simulationTimer.current = setInterval(() => {
      simStepRef.current += stepIncrement;
      if (simStepRef.current >= totalSteps - 1) {
        simStepRef.current = totalSteps - 1;
      }

      setSimProgressStep(simStepRef.current);

      const [lng, lat] = path[simStepRef.current];
      const pos = [lat, lng];
      movingMarker.current?.setLatLng(pos);

      const maxSpd = Number(activeVehicle.maxSpeed) || 55;
      const defSpd = Number(activeVehicle.defaultSpeed) || Math.round(maxSpd * 0.82);
      const baseSpeed = Math.min(defSpd, maxSpd);

      let speed;
      if (simStepRef.current >= totalSteps - 1) {
        speed = 0;
      } else {
        const wave = Math.sin(simStepRef.current / 3) * 4;
        speed = Math.min(maxSpd, Math.max(15, Math.round(baseSpeed + wave)));
      }
      setCurrentSpeed(Number.isFinite(speed) ? speed : baseSpeed);

      if (simStepRef.current % 4 === 0) {
        mapInstance.current?.flyTo(pos, mapInstance.current.getZoom(), { duration: 0.3 });
      }

      if (simStepRef.current >= totalSteps - 1) {
        if (simulationTimer.current) {
          clearInterval(simulationTimer.current);
          simulationTimer.current = null;
        }
      }
    }, 380);
  };

  const stopCurrentLocationLookup = () => {
    if (currentLookupWatch.current !== null) {
      navigator.geolocation.clearWatch(currentLookupWatch.current);
      currentLookupWatch.current = null;
    }
    window.clearTimeout(currentLookupTimer.current);
    currentLookupTimer.current = null;
  };

  const startNavigation = () => {
    if (!mapReady || !route || requestingLocation || tracking) return;
    if (!navigator.geolocation) {
      setError('Live navigation is not supported by this browser.');
      return;
    }

    stopSimulation();
    setError('');
    setRequestingLocation(true);
    overspeedAlertSent.current = false;
    arrivalAlertSent.current = false;

    locationWatch.current = navigator.geolocation.watchPosition(
      ({ coords }) => {
        const rawLat = coords.latitude;
        const rawLng = coords.longitude;
        setLastRawGps({ lat: rawLat, lng: rawLng });
        if (coords.accuracy) {
          setGpsAccuracy(Math.round(coords.accuracy));
        }

        const effectiveLat = rawLat + (calibrationOffsetRef.current?.lat || 0);
        const effectiveLng = rawLng + (calibrationOffsetRef.current?.lng || 0);
        const position = [effectiveLat, effectiveLng];

        const speedKmh = Number.isFinite(coords.speed) && coords.speed !== null
          ? Math.max(0, Math.round(coords.speed * 3.6))
          : 0;
        setCurrentSpeed(speedKmh);

        const path = route?.geometry?.coordinates;
        if (path && path.length > 1) {
          let bestIdx = 0;
          let bestDist = Infinity;
          for (let i = 0; i < path.length; i++) {
            const d = distanceBetweenCoords(effectiveLat, effectiveLng, path[i][1], path[i][0]);
            if (d < bestDist) {
              bestDist = d;
              bestIdx = i;
            }
          }
          setGpsProgressStep(bestIdx);
        }

        if (!movingMarker.current) {
          movingMarker.current = useGoogleMaps
            ? mapInstance.current.createLiveMarker(position, activeVehicle.category)
            : L.marker(position, {
            zIndexOffset: 1000,
            icon: L.divIcon({
              className: 'moving-vehicle-wrap',
              html: `<span class="moving-vehicle vehicle-${activeVehicle.category}"><svg viewBox="0 0 24 24"><path d="m5 11 2-5h10l2 5M4 11h16v7H4z"/><circle cx="7" cy="18" r="1.5"/><circle cx="17" cy="18" r="1.5"/></svg></span>`,
              iconSize: [42, 42],
              iconAnchor: [21, 21],
            }),
          }).addTo(routeLayers.current);
        } else {
          movingMarker.current.setLatLng(position);
        }
        setRequestingLocation(false);
        setTracking(true);
        mapInstance.current?.flyTo(position, Math.max(mapInstance.current.getZoom(), 16), { duration: .6 });
      },
      (locationError) => {
        if (locationWatch.current !== null) navigator.geolocation.clearWatch(locationWatch.current);
        locationWatch.current = null;
        setRequestingLocation(false);
        setTracking(false);
        setCalibratingGps(false);
        if (locationError.code === 1) setError('Location permission was denied. Allow location access to start live navigation.');
        else if (locationError.code === 2) setError('Your current GPS location is unavailable.');
        else setError('Location request timed out. Please try again.');
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 3000 },
    );
  };

  const loadSuggestions = async (type, query) => {
    const normalizedQuery = query.trim();
    if (!mapReady || normalizedQuery.length < 3) return;
    suggestionRequest.current?.abort();
    const controller = new AbortController();
    suggestionRequest.current = controller;
    setSearching(true);
    setError('');
    setActiveField(type);
    try {
      if (useGoogleMaps) {
        const nextResults = await googleSuggestions(normalizedQuery, mapInstance.current?.getCenter(), googleSearchSessions.current[type]);
        if (controller.signal.aborted) return;
        setResults(nextResults);
        if (!nextResults.length) setError('No matching place found. Add the city or state, or pin the location.');
        return;
      }
      const queryTokens = normalizeSearchText(normalizedQuery).split(' ').filter(Boolean);
      const queryVariants = [normalizedQuery];
      if (queryTokens.length > 1) {
        queryVariants.push(queryTokens[0]);
        queryVariants.push(`${queryTokens[0]} ${queryTokens.at(-1)}`);
      }
      const nominatimPromise = fetch(`https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(normalizedQuery)}&format=json&countrycodes=in&limit=6&addressdetails=1`, {
        signal: controller.signal,
        headers: { 'Accept-Language': 'en' },
      }).then(async (res) => {
        if (!res.ok) return [];
        const items = await res.json();
        return (items || []).map((item) => ({
          id: `nom-${item.place_id}`,
          label: item.display_name,
          primary: item.name || item.display_name.split(',')[0],
          point: { lat: parseFloat(item.lat), lng: parseFloat(item.lon) },
        }));
      }).catch(() => []);

      const [responses, nominatimResults] = await Promise.all([
        Promise.all([...new Set(queryVariants)].map(async (searchQuery, variantIndex) => {
          const params = new URLSearchParams({ q: searchQuery, limit: '12', lang: 'en' });
          if (center && queryTokens.length === 1 && variantIndex === 0) {
            params.set('lat', String(center.lat));
            params.set('lon', String(center.lng));
            params.set('zoom', String(mapInstance.current.getZoom()));
            params.set('location_bias_scale', '0.2');
          }
          const response = await fetch(`${AUTOCOMPLETE_URL}/api/?${params}`, { signal: controller.signal });
          if (!response.ok) return [];
          const data = await response.json();
          return data.features || [];
        })),
        nominatimPromise,
      ]);
      const uniqueResults = new Map();
      const queryLower = normalizedQuery.toLowerCase();
      LOCAL_KNOWN_PLACES.forEach((local) => {
        if (local.keywords.some((kw) => kw.includes(queryLower) || queryLower.includes(kw))
          || local.label.toLowerCase().includes(queryLower)) {
          uniqueResults.set(local.id, local);
        }
      });
      (nominatimResults || []).forEach((nom) => {
        if (!uniqueResults.has(nom.id)) uniqueResults.set(nom.id, nom);
      });
      responses.flat().forEach((feature, index) => {
        const result = photonResult(feature, index);
        if (!uniqueResults.has(result.id)) uniqueResults.set(result.id, result);
      });
      const nextResults = [...uniqueResults.values()]
        .sort((a, b) => rankSuggestion(b, normalizedQuery) - rankSuggestion(a, normalizedQuery))
        .slice(0, 6);
      if (controller.signal.aborted) return;
      setResults(nextResults);
      if (!nextResults.length) setError('No matching location found. Try a more specific address.');
    } catch (searchError) {
      if (controller.signal.aborted || searchError.name === 'AbortError') return;
      setResults([]);
      setError(useGoogleMaps ? 'Google place search is unavailable. Check Places API (New), billing and key restrictions, then try again.' : searchError.message || 'Unable to search for that location.');
    } finally {
      if (suggestionRequest.current === controller) setSearching(false);
    }
  };

  const updateLocation = (type, query) => {
    stopCurrentLocationLookup();
    routeRequest.current?.abort();
    setRouting(false);
    const setter = type === 'origin' ? setOrigin : setDestination;
    setter({ query, point: null });
    stopNavigation();
    setRoute(null);
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

  const chooseResult = async (result) => {
    const field = activeField;
    if (!field) return;
    window.clearTimeout(suggestionTimer.current);
    suggestionRequest.current?.abort();
    routeRequest.current?.abort();
    stopCurrentLocationLookup();
    stopNavigation();
    const controller = new AbortController();
    suggestionRequest.current = controller;
    const selectingOrigin = field === 'origin';
    const setter = selectingOrigin ? setOrigin : setDestination;
    setResults([]);
    setSearching(true);
    setRoute(null);
    setError('');
    try {
      const resolvedResult = result.provider === 'google' ? await resolveGoogleSuggestion(result) : result;
      if (controller.signal.aborted) return;
      if (!Number.isFinite(resolvedResult.point?.lat) || !Number.isFinite(resolvedResult.point?.lng)) {
        throw new Error('This result has no valid coordinates. Choose another result or pin the location.');
      }
      setter({ query: resolvedResult.label, point: resolvedResult.point });
      googleSearchSessions.current[field] = {};
      setActiveField(null);
      if (selectingOrigin && destination.point) calculateRoute(resolvedResult.point, destination.point);
      if (!selectingOrigin && origin.point) calculateRoute(origin.point, resolvedResult.point);
    } catch {
      if (!controller.signal.aborted) setError(useGoogleMaps ? 'Could not load the selected place. Check Places API (New) access, then try again.' : 'Could not load the selected place. Try another result or pin it on the map.');
    } finally {
      if (suggestionRequest.current === controller) setSearching(false);
    }
  };

  const useCurrentLocation = () => {
    cancelPendingRequests();
    stopNavigation();
    stopCurrentLocationLookup();
    setError('');
    if (!navigator.geolocation) {
      setError('Current location is not supported by this browser.');
      return;
    }
    setSearching(true);
    setOrigin({ query: 'Getting accurate location...', point: null });
    setRoute(null);
    let bestPosition = null;

    const finishLookup = () => {
      stopCurrentLocationLookup();
      setSearching(false);
      if (!bestPosition) {
        setOrigin({ query: '', point: null });
        setError('A fresh location could not be detected. Turn on Windows Location Services or pin the location manually.');
        return;
      }

      const accuracy = Number(bestPosition.coords.accuracy);
      if (!Number.isFinite(accuracy) || accuracy > 250) {
        const readableAccuracy = Number.isFinite(accuracy)
          ? (accuracy >= 1000 ? `${(accuracy / 1000).toFixed(1)} km` : `${Math.round(accuracy)} m`)
          : 'unknown';
        setOrigin({ query: '', point: null });
        setError(`Browser location is too imprecise (±${readableAccuracy}), so no marker was placed. Enable device GPS or search/pin your exact location.`);
        return;
      }

      setOrigin({
        query: `Current location (±${Math.ceil(accuracy)} m)`,
        point: {
          lat: bestPosition.coords.latitude,
          lng: bestPosition.coords.longitude,
          accuracy,
        },
      });
    };

    currentLookupWatch.current = navigator.geolocation.watchPosition(
      (position) => {
        if (!bestPosition || position.coords.accuracy < bestPosition.coords.accuracy) bestPosition = position;
        if (position.coords.accuracy <= 80) finishLookup();
      },
      (locationError) => {
        if (locationError.code === 1) {
          stopCurrentLocationLookup();
          setSearching(false);
          setOrigin({ query: '', point: null });
          setError('Location permission was denied. Allow it in the browser, or search/pin your exact location.');
        }
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 },
    );
    currentLookupTimer.current = window.setTimeout(finishLookup, 12000);
  };

  const swapLocations = () => {
    cancelPendingRequests();
    stopCurrentLocationLookup();
    stopNavigation();
    setOrigin(destination);
    setDestination(origin);
    setRoute(null);
    setResults([]);
    setError('');
  };

  const calculateRoute = async (startPoint = origin.point, endPoint = destination.point, requestedCat = vehicleCategory) => {
    if (!mapReady || !startPoint || !endPoint) return;
    routeRequest.current?.abort();
    const controller = new AbortController();
    routeRequest.current = controller;
    stopNavigation();
    stopSimulation();
    setRouting(true);
    setRoute(null);
    setError('');
    setDirectionsOpen(false);
    try {
      if (useGoogleMaps) {
        const cat = VEHICLE_CATEGORIES.find((c) => c.id === requestedCat) || VEHICLE_CATEGORIES[1];
        const googleMode = cat.googleMode || 'DRIVING';
        let googleRoute;
        try {
          googleRoute = await calculateGoogleRoute(startPoint, endPoint, {
            travelMode: googleMode,
            routingPreference: 'TRAFFIC_AWARE',
          });
        } catch {
          googleRoute = await calculateGoogleRoute(startPoint, endPoint, {
            travelMode: googleMode,
            routingPreference: 'TRAFFIC_UNAWARE',
          });
        }
        if (!controller.signal.aborted) {
          setRoute(googleRoute);
        }
        return;
      }
      const coordinates = `${startPoint.lng},${startPoint.lat};${endPoint.lng},${endPoint.lat}`;
      const params = new URLSearchParams({ overview: 'full', geometries: 'geojson', steps: 'true', alternatives: 'false' });
      const response = await fetch(`${ROUTING_URL}/route/v1/driving/${coordinates}?${params}`, { signal: controller.signal });
      if (!response.ok) throw new Error('Routing service is unavailable.');
      const data = await response.json();
      if (data.code !== 'Ok' || !data.routes?.length) throw new Error('No drivable route was found between these locations.');
      if (!controller.signal.aborted) {
        setRoute(data.routes[0]);
      }
    } catch (routeError) {
      if (controller.signal.aborted) return;
      setRoute(null);
      setError(useGoogleMaps ? 'Google could not calculate this route. Check Routes API access, or choose different endpoints.' : routeError.message || 'Unable to calculate this route.');
    } finally {
      if (routeRequest.current === controller) setRouting(false);
    }
  };

  const selectVehicleCategory = (catId) => {
    setVehicleCategory(catId);
    if (origin.point && destination.point) {
      calculateRoute(origin.point, destination.point, catId);
    }
  };

  const selectTruckModel = (modelId) => {
    setTruckModel(modelId);
  };

  const toggleTrafficLayer = () => {
    if (mapInstance.current?.toggleTraffic) {
      const next = mapInstance.current.toggleTraffic();
      setTrafficEnabled(next);
    } else {
      setTrafficEnabled((prev) => !prev);
    }
  };

  const cancelPendingRequests = () => {
    window.clearTimeout(suggestionTimer.current);
    suggestionRequest.current?.abort();
    routeRequest.current?.abort();
    googleSearchSessions.current = { origin: {}, destination: {} };
    setSearching(false);
    setRouting(false);
    setResults([]);
    setActiveField(null);
  };

  const clearRoute = () => {
    cancelPendingRequests();
    stopNavigation();
    stopSimulation();
    stopCurrentLocationLookup();
    setPinMode(false);
    setOrigin({ query: '', point: null });
    setDestination({ query: '', point: null });
    setRoute(null);
    setResults([]);
    setError('');
    mapInstance.current?.setView([22.9734, 78.6569], 5);
  };

  const beginPinning = () => {
    cancelPendingRequests();
    stopCurrentLocationLookup();
    stopNavigation();
    setResults([]);
    setError('');
    setPinMode(true);
    if (origin.point && destination.point) {
      setOrigin({ query: '', point: null });
      setDestination({ query: '', point: null });
      setRoute(null);
    }
  };

  useEffect(() => {
    const map = mapInstance.current;
    if (!map) return undefined;
    const container = map.getContainer();

    if (calibratingGps) {
      container.classList.add('pin-mode');

      const handleCalibrateClick = ({ latlng }) => {
        const clickedLat = Number(latlng.lat);
        const clickedLng = Number(latlng.lng);
        const baseLat = lastRawGps?.lat ?? clickedLat;
        const baseLng = lastRawGps?.lng ?? clickedLng;
        const offset = {
          lat: clickedLat - baseLat,
          lng: clickedLng - baseLng,
        };
        setCalibrationOffset(offset);
        calibrationOffsetRef.current = offset;
        setCalibratingGps(false);

        const calibratedPos = [clickedLat, clickedLng];
        if (movingMarker.current) {
          movingMarker.current.setLatLng(calibratedPos);
        }
        map.flyTo(calibratedPos, Math.max(map.getZoom(), 17));

        const path = route?.geometry?.coordinates;
        if (path && path.length > 1) {
          let bestIdx = 0;
          let bestDist = Infinity;
          for (let i = 0; i < path.length; i++) {
            const d = distanceBetweenCoords(clickedLat, clickedLng, path[i][1], path[i][0]);
            if (d < bestDist) {
              bestDist = d;
              bestIdx = i;
            }
          }
          setGpsProgressStep(bestIdx);
        }
      };

      map.on('click', handleCalibrateClick);
      return () => {
        container.classList.remove('pin-mode');
        map.off('click', handleCalibrateClick);
      };
    }

    if (!pinMode) return undefined;
    container.classList.add('pin-mode');

    const handleMapClick = ({ latlng }) => {
      const point = { lat: Number(latlng.lat.toFixed(6)), lng: Number(latlng.lng.toFixed(6)) };
      const label = `Pinned point (${point.lat.toFixed(5)}, ${point.lng.toFixed(5)})`;
      setResults([]);
      setError('');
      stopNavigation();
      setRoute(null);

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
  }, [pinMode, calibratingGps, lastRawGps, origin.point, mapReady, route]);

  const steps = route?.legs?.flatMap((leg) => leg.steps || []) || [];
  const mapAvailable = mapReady && !mapError;

  const rawDuration = route?.duration || 0;
  const adjustedDuration = Math.round(rawDuration * (activeVehicle.speedFactor || 1.0));
  const trafficDelaySeconds = route?.trafficDelaySeconds || 0;
  const trafficDelayMinutes = Math.round(trafficDelaySeconds / 60);

  // Precompute cumulative distances along path coordinates for accurate physical distance countdown
  const cumulativeDistances = useMemo(() => {
    if (!route?.geometry?.coordinates?.length) return { cum: [], total: 0 };
    const coords = route.geometry.coordinates;
    const cum = [0];
    let total = 0;
    for (let i = 1; i < coords.length; i++) {
      const d = distanceBetweenCoords(coords[i - 1][1], coords[i - 1][0], coords[i][1], coords[i][0]);
      total += d;
      cum.push(total);
    }
    return { cum, total };
  }, [route]);

  const activeStep = simulating ? simProgressStep : tracking ? gpsProgressStep : 0;
  const totalCoords = route?.geometry?.coordinates?.length || 0;

  const {
    effectiveDistance,
    effectiveDuration,
    coveredDistance,
    progressPercent,
  } = useMemo(() => {
    if (!route || !route.distance || totalCoords < 2) {
      return {
        effectiveDistance: route?.distance || 0,
        effectiveDuration: adjustedDuration,
        coveredDistance: 0,
        progressPercent: 0,
      };
    }

    if (!simulating && !tracking) {
      return {
        effectiveDistance: route.distance,
        effectiveDuration: adjustedDuration,
        coveredDistance: 0,
        progressPercent: 0,
      };
    }

    const { cum, total } = cumulativeDistances;
    let fraction = 0;
    if (total && total > 0 && cum && cum[activeStep] !== undefined) {
      fraction = Math.min(1, Math.max(0, cum[activeStep] / total));
    } else {
      fraction = Math.min(1, Math.max(0, activeStep / (totalCoords - 1)));
    }

    const covered = Math.round(fraction * route.distance);
    const remainingDist = Math.max(0, route.distance - covered);
    const remainingDur = Math.max(0, Math.round((1 - fraction) * adjustedDuration));
    const pct = Math.min(100, Math.max(0, Math.round(fraction * 100)));

    return {
      effectiveDistance: remainingDist,
      effectiveDuration: remainingDur,
      coveredDistance: covered,
      progressPercent: pct,
    };
  }, [route, totalCoords, simulating, tracking, cumulativeDistances, activeStep, adjustedDuration]);

  let trafficStatus = {
    badge: 'Clear Flow',
    title: 'Smooth Traffic Ahead',
    subtext: 'Roads are clear with normal driving speed.',
    class: 'traffic-clear',
  };
  if (trafficDelayMinutes >= 7) {
    trafficStatus = {
      badge: `+${trafficDelayMinutes} min delay`,
      title: 'Heavy Traffic Congestion Ahead',
      subtext: `Expect significant delays due to heavy traffic (+${trafficDelayMinutes} min).`,
      class: 'traffic-heavy',
    };
  } else if (trafficDelayMinutes >= 2) {
    trafficStatus = {
      badge: `+${trafficDelayMinutes} min delay`,
      title: 'Moderate Traffic Delay Ahead',
      subtext: `Expect minor slowdowns due to traffic (+${trafficDelayMinutes} min).`,
      class: 'traffic-moderate',
    };
  }

  return (
    <section className="route-planner">
      <aside className="route-controls">
        <div className="route-heading">
          <div><p>Live navigation</p><h1>Route planner</h1></div>
          {(origin.query || destination.query) && <button type="button" onClick={clearRoute} aria-label="Clear route"><MapIcon name="close" /></button>}
        </div>

        {/* Fleet Drivers Roster Bar */}
        <div className="planner-driver-roster-bar">
          <button
            type="button"
            className={`planner-roster-toggle-btn ${showDriverRoster ? 'active' : ''}`}
            onClick={() => setShowDriverRoster(!showDriverRoster)}
            title="Toggle Fleet Drivers Roster"
          >
            <MapIcon name="user" size={15} />
            <span className="roster-title-text">Drivers List ({drivers.length})</span>
            <span className="roster-avail-pill">
              {drivers.filter((d) => d.status === 'available').length} Ready
            </span>
            <span className={`roster-chevron ${showDriverRoster ? 'open' : ''}`}>
              <MapIcon name="chevron" size={13} />
            </span>
          </button>

          <button
            type="button"
            className="planner-quick-add-btn"
            onClick={() => setAddDriverModalOpen(true)}
            title="Register new commercial driver"
          >
            <MapIcon name="plus" size={13} /> <span>Driver</span>
          </button>
        </div>

        {/* Expandable Driver List */}
        {showDriverRoster && (
          <div className="planner-driver-roster-drawer">
            {drivers.length === 0 ? (
              <div className="planner-roster-empty">
                <p>No commercial drivers registered in fleet.</p>
                <button
                  type="button"
                  className="quick-register-btn"
                  onClick={() => setAddDriverModalOpen(true)}
                >
                  <MapIcon name="plus" size={13} /> Register First Driver
                </button>
              </div>
            ) : (
              drivers.map((d) => {
                const isSelected = selectedDriverId === d.id;
                const initials = d.name.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase();
                return (
                  <div key={d.id} className={`planner-roster-card ${isSelected ? 'selected' : ''}`}>
                    <div className="planner-roster-avatar">{initials}</div>
                    <div className="planner-roster-info">
                      <div className="planner-roster-name-row">
                        <strong>{d.name}</strong>
                        <span className={`planner-status-tag ${d.status}`}>
                          {d.status === 'available' ? 'Available' : d.status === 'on_trip' ? 'On Trip' : 'Off Duty'}
                        </span>
                      </div>
                      <span className="planner-roster-sub">{d.phone}</span>
                      <span className="planner-roster-plate">{d.vehicle.plate} • {d.vehicle.model}</span>
                      {d.currentTrip && (
                        <span className="planner-roster-active-trip">
                          Trip: {d.currentTrip.origin.split(',')[0]} → {d.currentTrip.destination.split(',')[0]}
                        </span>
                      )}
                    </div>
                    <button
                      type="button"
                      className={`planner-assign-driver-btn ${isSelected ? 'active' : ''}`}
                      onClick={() => selectDriverForTrip(d)}
                      title="Select this driver for route"
                    >
                      {isSelected ? 'Selected' : 'Assign'}
                    </button>
                  </div>
                );
              })
            )}
          </div>
        )}

        {dispatchNotice && !route && (
          <div className="dispatch-success-banner" role="status">
            <MapIcon name="check" size={16} />
            <span>{dispatchNotice}</span>
          </div>
        )}

        {/* Vehicle Category & Truck Models Selector */}
        <div className="vehicle-selection-panel">
          <div className="vehicle-section-header">
            <span>Vehicle Type</span>
            <small>Select Profile</small>
          </div>
          <div className="vehicle-tabs" role="tablist" aria-label="Vehicle types">
            {VEHICLE_CATEGORIES.map((cat) => {
              const active = vehicleCategory === cat.id;
              return (
                <button
                  key={cat.id}
                  type="button"
                  role="tab"
                  aria-selected={active}
                  className={`vehicle-tab${active ? ' active' : ''}`}
                  onClick={() => selectVehicleCategory(cat.id)}
                >
                  <span className="vehicle-tab-icon"><MapIcon name={cat.icon} size={17} /></span>
                  <div className="vehicle-tab-text">
                    <strong>{cat.label}</strong>
                    <small>{cat.sublabel}</small>
                  </div>
                </button>
              );
            })}
          </div>

          {vehicleCategory === 'truck' && (
            <div className="truck-models-wrapper">
              <div className="vehicle-section-header sub">
                <span>Truck Models & Payload</span>
                <small>Select Model</small>
              </div>
              <div className="truck-models-grid">
                {TRUCK_MODELS.map((model) => {
                  const active = truckModel === model.id;
                  return (
                    <button
                      key={model.id}
                      type="button"
                      className={`truck-model-card${active ? ' active' : ''}`}
                      onClick={() => selectTruckModel(model.id)}
                    >
                      <div className="truck-model-top">
                        <span className="truck-badge">{model.badge}</span>
                        <span className="truck-speed-cap">Max {model.maxSpeed} km/h</span>
                      </div>
                      <strong className="truck-model-name">{model.label}</strong>
                      <div className="truck-model-specs">
                        <span>{model.wheels} Wheels</span>
                        <span>·</span>
                        <span>Cap: {model.payload}</span>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        <div className="location-form">
          <div className="location-line" />
          <LocationInput type="origin" label="From" value={origin.query} point={origin.point} onChange={(value) => updateLocation('origin', value)} onSearch={() => searchLocation('origin')} onLocate={useCurrentLocation} busy={searching} disabled={!mapAvailable} />
          <button className="swap-button" type="button" onClick={swapLocations} disabled={!mapAvailable} aria-label="Swap locations"><MapIcon name="swap" size={17} /></button>
          <LocationInput type="destination" label="To" value={destination.query} point={destination.point} onChange={(value) => updateLocation('destination', value)} onSearch={() => searchLocation('destination')} busy={searching} disabled={!mapAvailable} />
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

        {error && <div className="route-error" role="alert">{error}</div>}

        <button className="find-route-button" type="button" disabled={!mapAvailable || !origin.point || !destination.point || routing} onClick={() => calculateRoute()}>
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
            <div className="route-summary-head">
              <div>
                <p>
                  {(simulating || tracking) ? 'Live Route Progress' : 'Recommended route'} ({activeVehicle.label || activeVehicle.displayName})
                </p>
                <strong className={(simulating || tracking) ? 'live-duration-text' : ''}>
                  {formatDuration(effectiveDuration)}
                </strong>
                {(simulating || tracking) && (
                  <span className="live-eta-sub">Remaining Time to Destination</span>
                )}
              </div>
              <span className={(simulating || tracking) ? 'in-transit-badge' : 'ready-badge'}>
                {simulating ? `In Transit (${progressPercent}%)` : tracking ? 'Live Navigating' : 'Ready'}
              </span>
            </div>

            <div className="route-metrics">
              <div>
                <MapIcon name="distance" />
                <span>
                  <small>{(simulating || tracking) ? 'Remaining Distance' : 'Total Distance'}</small>
                  <strong>{formatDistance(effectiveDistance)}</strong>
                  {(simulating || tracking) && (
                    <span className="sub-metric">of {formatDistance(route.distance)}</span>
                  )}
                </span>
              </div>
              <div>
                <MapIcon name="clock" />
                <span>
                  <small>{(simulating || tracking) ? 'Remaining Time (ETA)' : 'Vehicle ETA'}</small>
                  <strong>{formatDuration(effectiveDuration)}</strong>
                  {(simulating || tracking) && (
                    <span className="sub-metric">Original: {formatDuration(adjustedDuration)}</span>
                  )}
                </span>
              </div>
            </div>

            {(simulating || tracking) && (
              <div className="transit-progress-container">
                <div className="transit-progress-header">
                  <span>Covered: {formatDistance(coveredDistance)}</span>
                  <span className="transit-pct-tag">{progressPercent}% Completed</span>
                </div>
                <div className="transit-progress-track">
                  <div className="transit-progress-bar" style={{ width: `${progressPercent}%` }} />
                </div>
              </div>
            )}

            {/* Traffic Conditions Ahead Widget */}
            <div className={`traffic-ahead-card ${trafficStatus.class}`}>
              <div className="traffic-ahead-header">
                <div className="traffic-ahead-title">
                  <MapIcon name="traffic" size={17} />
                  <strong>Traffic Conditions Ahead</strong>
                </div>
                <span className="traffic-delay-badge">{trafficStatus.badge}</span>
              </div>
              <p className="traffic-ahead-desc">{trafficStatus.title}</p>
              <p className="traffic-ahead-subtext">{trafficStatus.subtext}</p>
              {useGoogleMaps && (
                <div className="traffic-live-indicator">
                  <span className="traffic-dot live" />
                  <span>Google Real-Time Traffic Layer Active</span>
                </div>
              )}
            </div>

            <p className="route-estimate-note">
              {activeVehicle.speedFactor > 1.0
                ? `Commercial ${activeVehicle.wheels}-wheeler speed profile applied (Speed limit: ${activeVehicle.maxSpeed} km/h).`
                : 'Standard passenger speed profile with live road traffic conditions.'}
            </p>
            {route.warnings?.map((warning, index) => <p className="route-error" key={index}>{warning}</p>)}
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

            {/* Assign Route & Dispatch Trip Panel */}
            <div className="planner-assignment-card">
              <div className="planner-assignment-header">
                <div className="planner-assignment-title">
                  <MapIcon name="send" size={16} />
                  <strong>Assign Route & Dispatch Trip</strong>
                </div>
                <span className="planner-assignment-badge">Admin Dispatch</span>
              </div>

              {dispatchNotice && (
                <div className="dispatch-success-banner" role="status">
                  <MapIcon name="check" size={16} />
                  <span>{dispatchNotice}</span>
                </div>
              )}

              <form onSubmit={handleDispatchTrip} className="planner-assignment-form">
                <div className="planner-form-field">
                  <label htmlFor="planner-driver-select">
                    <MapIcon name="user" size={14} /> Assign Commercial Driver
                  </label>
                  <select
                    id="planner-driver-select"
                    value={selectedDriverId}
                    onChange={(e) => {
                      const d = drivers.find((drv) => drv.id === e.target.value);
                      if (d) selectDriverForTrip(d);
                      else setSelectedDriverId(e.target.value);
                    }}
                    className="planner-select-input"
                  >
                    <option value="">-- Choose Driver from Fleet ({drivers.length}) --</option>
                    {drivers.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name} ({d.vehicle.plate} • {d.vehicle.model}) [{d.status === 'available' ? 'Available' : d.status === 'on_trip' ? 'On Trip' : 'Off Duty'}]
                      </option>
                    ))}
                  </select>

                  {selectedDriver && (
                    <div className="planner-driver-snippet">
                      <div className="planner-driver-snippet-row">
                        <span>Vehicle: <strong>{selectedDriver.vehicle.plate}</strong> ({selectedDriver.vehicle.model})</span>
                        <span className={`planner-status-tag ${selectedDriver.status}`}>
                          {selectedDriver.status === 'available' ? 'Available' : selectedDriver.status === 'on_trip' ? 'On Trip' : 'Off Duty'}
                        </span>
                      </div>
                      <div className="planner-driver-snippet-row sub">
                        <span>Phone: {selectedDriver.phone}</span>
                        <span>Depot Hub: {selectedDriver.baseHub}</span>
                      </div>
                    </div>
                  )}

                  {drivers.length === 0 && (
                    <button
                      type="button"
                      className="planner-link-add-driver"
                      onClick={() => setAddDriverModalOpen(true)}
                    >
                      <MapIcon name="plus" size={13} /> Register First Commercial Driver
                    </button>
                  )}
                </div>

                <div className="planner-form-field">
                  <label htmlFor="planner-cargo-input">
                    <MapIcon name="truck" size={14} /> Cargo / Freight Details
                  </label>
                  <input
                    id="planner-cargo-input"
                    type="text"
                    placeholder="e.g. 10 Ton Steel Coils, FMCG Goods, Express Parcel"
                    value={tripCargo}
                    onChange={(e) => setTripCargo(e.target.value)}
                    className="planner-text-input"
                  />
                </div>

                <div className="planner-form-field">
                  <label htmlFor="planner-remark-input">
                    <MapIcon name="route" size={14} /> Admin Remark / Instructions
                  </label>
                  <textarea
                    id="planner-remark-input"
                    rows={2}
                    placeholder="e.g. Avoid toll bypass, handle with care, urgent delivery before 6 PM, collect weighbridge receipt"
                    value={tripRemark}
                    onChange={(e) => setTripRemark(e.target.value)}
                    className="planner-textarea-input"
                  />
                </div>

                <button
                  type="submit"
                  className="dispatch-route-btn"
                  disabled={!selectedDriverId || !origin.query || !destination.query}
                  title={!selectedDriverId ? 'Please choose a commercial driver to assign' : 'Dispatch this route to assigned driver'}
                >
                  <MapIcon name="send" size={15} />
                  <span>Assign & Dispatch Trip Now</span>
                </button>
              </form>
            </div>
          </div>
        )}

        <p className="routing-credit">{useGoogleMaps ? 'Map, places and routes by Google Maps' : 'Search by Photon · Data © OpenStreetMap contributors · Routing by OSRM'}</p>
      </aside>

      <div className="map-stage">
        <div ref={mapElement} className="live-map" aria-label="Interactive route map" />
        {calibratingGps && (
          <div
            className="calibration-prompt-banner"
            style={{
              position: 'absolute',
              top: '16px',
              left: '50%',
              transform: 'translateX(-50%)',
              zIndex: 1000,
              background: '#0f172a',
              color: '#f8fafc',
              padding: '10px 18px',
              borderRadius: '8px',
              boxShadow: '0 4px 14px rgba(0,0,0,0.3)',
              fontSize: '13px',
              fontWeight: '500',
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
            }}
          >
            <span>Click your exact building on the map (e.g. RBC Import & Export) to snap the live marker.</span>
            <button
              type="button"
              onClick={() => setCalibratingGps(false)}
              style={{
                background: '#334155',
                border: 'none',
                color: '#fff',
                padding: '4px 8px',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '12px',
              }}
            >
              Cancel
            </button>
          </div>
        )}
        {!mapAvailable && (
          <div className="map-setup-state" role={mapError ? 'alert' : 'status'}>
            <div>
              <MapIcon name="layers" size={25} />
              <h2>{mapError ? 'Google Maps needs setup' : 'Loading map'}</h2>
              <p>{mapError || 'Connecting to the map provider...'}</p>
              {mapError && <button type="button" onClick={() => window.location.reload()}>Retry Google Maps</button>}
            </div>
          </div>
        )}
        <div className="map-style-switch" role="group" aria-label="Map style">
          <span><MapIcon name="layers" size={15} /></span>
          <button type="button" className={mapStyle === 'map' ? 'active' : ''} disabled={!mapAvailable} aria-pressed={mapStyle === 'map'} onClick={() => setMapStyle('map')}>Map</button>
          <button type="button" className={mapStyle === 'satellite' ? 'active' : ''} disabled={!mapAvailable} aria-pressed={mapStyle === 'satellite'} onClick={() => setMapStyle('satellite')}>Satellite</button>
        </div>

        <button
          className={`traffic-toggle-button${trafficEnabled ? ' active' : ''}`}
          type="button"
          disabled={!mapAvailable}
          aria-pressed={trafficEnabled}
          onClick={toggleTrafficLayer}
          title="Toggle Google Maps Live Traffic Overlay"
        >
          <MapIcon name="traffic" size={15} />
          <span>Traffic {trafficEnabled ? 'ON' : 'OFF'}</span>
        </button>

        <button className={`pin-map-button${pinMode ? ' active' : ''}`} type="button" disabled={!mapAvailable} aria-pressed={pinMode} onClick={beginPinning}>
          <MapIcon name="pin" size={16} />
          {pinMode ? (origin.point ? 'Pin destination' : 'Pin starting point') : 'Pin locations'}
        </button>
        {mapAvailable && <div className="map-live-badge"><span /> {useGoogleMaps ? 'Google Maps' : 'Open map'}</div>}
        {mapAvailable && !route && <div className={`map-hint${pinMode ? ' pinning' : ''}`}><MapIcon name={pinMode ? 'pin' : 'route'} /><span>{pinMode ? (origin.point ? 'Click the map to pin destination B' : 'Click the map to pin starting point A') : 'Search locations or pin two points on the map'}</span></div>}
        {mapAvailable && route && (
          <div className="route-playback">
            <div className="playback-hud">
              <div className="playback-speed-gauge">
                <div className="speedometer-box">
                  <MapIcon name="gauge" size={20} />
                  <div className="speed-readout">
                    <span className="speed-val">{Number.isFinite(currentSpeed) ? currentSpeed : 0}</span>
                    <span className="speed-unit">km/h</span>
                  </div>
                </div>
                <div className="speed-limit-tag">
                  <small>Max Limit</small>
                  <strong>{activeVehicle.maxSpeed} km/h</strong>
                </div>
              </div>

              <div className="playback-vehicle-status">
                <div className="vehicle-name-row">
                  <span className={`vehicle-indicator-dot ${(tracking || simulating) ? 'active' : ''}`} />
                  <strong>{activeVehicle.label || activeVehicle.displayName}</strong>
                </div>
                <small className="vehicle-specs-sub">
                  {currentSpeed > activeVehicle.maxSpeed ? (
                    <span className="text-warning">Over-speeding Alert (Limit: {activeVehicle.maxSpeed} km/h)</span>
                  ) : simulating ? (
                    <span className="text-simulating">Test Drive Active ({Number.isFinite(currentSpeed) ? currentSpeed : 0} km/h)</span>
                  ) : tracking ? (
                    (calibrationOffset.lat !== 0 || calibrationOffset.lng !== 0) ? (
                      <span style={{ color: '#16a34a', fontWeight: '600' }}>Calibrated to exact building</span>
                    ) : gpsAccuracy ? (
                      `Device GPS (±${gpsAccuracy} m Wi-Fi variance)`
                    ) : (
                      'Following Device GPS'
                    )
                  ) : (
                    `${activeVehicle.wheels} Wheels · Max ${activeVehicle.maxSpeed} km/h`
                  )}
                </small>
              </div>

              {/* Dynamic Live Distance & Time Decrement in HUD */}
              <div className="playback-live-metrics">
                <div className="hud-metric-card">
                  <span className="hud-metric-label">Remaining Dist</span>
                  <strong className="hud-metric-val">{formatDistance(effectiveDistance)}</strong>
                </div>
                <div className="hud-metric-card">
                  <span className="hud-metric-label">Remaining Time</span>
                  <strong className="hud-metric-val">{formatDuration(effectiveDuration)}</strong>
                </div>
                <div className="hud-metric-card progress">
                  <span className="hud-metric-label">Progress</span>
                  <strong className="hud-metric-val highlight">{progressPercent}%</strong>
                </div>
              </div>
            </div>

            <div className="playback-buttons">
              <button
                className={`demo-btn${simulating ? ' active' : ''}`}
                type="button"
                onClick={simulating ? stopSimulation : startSimulation}
                title={simulating ? 'Stop test drive' : 'Simulate drive along route to test dynamic distance and time countdown'}
              >
                <MapIcon name={simulating ? 'stop' : 'play'} size={15} />
                <span>{simulating ? 'Stop Drive' : 'Test Drive'}</span>
              </button>

              <button
                className="navigation-action"
                type="button"
                disabled={requestingLocation}
                onClick={tracking ? stopNavigation : startNavigation}
                aria-label={tracking ? 'Stop live navigation' : 'Start live navigation'}
                title={tracking ? 'Stop live GPS navigation' : 'Start live GPS navigation'}
              >
                <MapIcon name={tracking ? 'stop' : 'location'} size={16} />
                <span>{tracking ? 'Stop GPS' : requestingLocation ? 'Waiting...' : 'Live GPS'}</span>
              </button>

              {tracking && (
                <button
                  type="button"
                  className={`navigation-action calibrate-btn${calibratingGps ? ' active' : ''}`}
                  onClick={() => setCalibratingGps((prev) => !prev)}
                  style={{
                    background: calibratingGps ? '#15803d' : '#047857',
                    borderColor: calibratingGps ? '#166534' : '#059669',
                  }}
                  title="Click your exact building on the map (e.g. RBC Import & Export) to snap the live GPS marker directly to it"
                >
                  <MapIcon name="location" size={15} />
                  <span>{calibratingGps ? 'Click Map...' : (calibrationOffset.lat !== 0 ? 'Re-calibrate' : 'Calibrate Spot')}</span>
                </button>
              )}

              {tracking && (calibrationOffset.lat !== 0 || calibrationOffset.lng !== 0) && (
                <button
                  type="button"
                  className="demo-btn"
                  onClick={() => {
                    setCalibrationOffset({ lat: 0, lng: 0 });
                    calibrationOffsetRef.current = { lat: 0, lng: 0 };
                    if (lastRawGps && movingMarker.current) {
                      movingMarker.current.setLatLng([lastRawGps.lat, lastRawGps.lng]);
                      mapInstance.current?.flyTo([lastRawGps.lat, lastRawGps.lng], 16);
                    }
                  }}
                  title="Reset calibration offset to original device GPS"
                >
                  <span>Reset</span>
                </button>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Quick Add Commercial Driver Modal */}
      {addDriverModalOpen && (
        <div className="planner-modal-backdrop" onClick={() => setAddDriverModalOpen(false)}>
          <div className="planner-modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="planner-modal-header">
              <div>
                <h3>Register Commercial Driver</h3>
                <p>Add a new driver to your fleet roster for instant route dispatch.</p>
              </div>
              <button
                type="button"
                className="planner-modal-close"
                onClick={() => setAddDriverModalOpen(false)}
                aria-label="Close dialog"
              >
                <MapIcon name="close" size={16} />
              </button>
            </div>

            <form onSubmit={handleQuickAddDriver} className="planner-modal-form">
              <div className="planner-modal-field">
                <label>Driver Full Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Ramesh Kumar"
                  value={quickDriverName}
                  onChange={(e) => setQuickDriverName(e.target.value)}
                />
              </div>

              <div className="planner-modal-field">
                <label>Phone Number *</label>
                <input
                  type="tel"
                  required
                  placeholder="+91 98765 43210"
                  value={quickDriverPhone}
                  onChange={(e) => setQuickDriverPhone(e.target.value)}
                />
              </div>

              <div className="planner-modal-field">
                <label>Driver Login Email ID *</label>
                <input
                  type="email"
                  placeholder="e.g. driver.ramesh@fleetroute.in"
                  value={quickDriverEmail}
                  onChange={(e) => setQuickDriverEmail(e.target.value)}
                />
              </div>

              <div className="planner-modal-field">
                <label>Mobile App PIN / Password</label>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <input
                    type="text"
                    placeholder="PIN (e.g. 4821)"
                    value={quickDriverPin}
                    onChange={(e) => setQuickDriverPin(e.target.value)}
                    style={{ flex: 1 }}
                  />
                  <input
                    type="text"
                    placeholder="Password (e.g. Driver@123)"
                    value={quickDriverPassword}
                    onChange={(e) => setQuickDriverPassword(e.target.value)}
                    style={{ flex: 1 }}
                  />
                </div>
              </div>

              <div className="planner-modal-field">
                <label>Vehicle Model & Profile</label>
                <select
                  value={quickVehicleModel}
                  onChange={(e) => setQuickVehicleModel(e.target.value)}
                >
                  <option value="Tata Ace (Chota Hathi) - 4 Wheeler (LCV 1.2 Ton)">Tata Ace (LCV 1.2 Ton)</option>
                  <option value="6-Wheeler MCV (Eicher 11.10) - 6 Wheeler (7.5 Ton)">6-Wheeler MCV (Eicher 7.5 Ton)</option>
                  <option value="10-12 Wheeler HCV (Signa / 2823) - 10 Wheeler (20 Ton)">10-12 Wheeler HCV (Signa 20 Ton)</option>
                  <option value="Multi-Axle Trailer (40ft Container) - 16 Wheeler (38 Ton)">Multi-Axle Trailer (38 Ton)</option>
                  <option value="Passenger Car (Sedan / SUV)">Passenger Car</option>
                  <option value="Cargo Delivery Bike">Cargo Delivery Bike</option>
                </select>
              </div>

              <div className="planner-modal-field">
                <label>Vehicle Plate Number</label>
                <input
                  type="text"
                  placeholder="e.g. GJ-05-TR-4421"
                  value={quickDriverPlate}
                  onChange={(e) => setQuickDriverPlate(e.target.value)}
                />
              </div>

              <div className="planner-modal-actions">
                <button
                  type="button"
                  className="planner-modal-cancel-btn"
                  onClick={() => setAddDriverModalOpen(false)}
                >
                  Cancel
                </button>
                <button type="submit" className="planner-modal-submit-btn">
                  <MapIcon name="plus" size={14} /> Add & Select Driver
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </section>
  );
}
