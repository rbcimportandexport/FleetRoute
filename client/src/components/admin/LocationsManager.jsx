import React, { useState, useEffect, useRef } from 'react';
import L from 'leaflet';
import { 
  MapPin, 
  Search, 
  Navigation, 
  Plus, 
  Edit2, 
  Archive, 
  CheckCircle2, 
  AlertCircle, 
  Building, 
  Warehouse, 
  User, 
  Phone, 
  Crosshair,
  Compass,
  ArrowRight,
  Ruler,
  Route,
  Clock,
  Sparkles,
  RotateCcw,
  X,
  Layers,
  Check
} from 'lucide-react';
import { api } from '../../utils/api';
import { soundEffects } from '../../utils/soundEffects';

const LOCATION_TYPES = [
  { id: 'warehouse', label: 'Warehouse / Fulfilment (ગોદામ / वेयरहाउस)' },
  { id: 'pickup', label: 'Pickup Point / Vendor (પિકઅપ / वेंडर)' },
  { id: 'customer', label: 'Customer / Commercial Drop (ગ્રાહક ડિલિવરી)' },
  { id: 'delivery', label: 'Delivery Point (ડિલિવરી પોઈન્ટ)' },
  { id: 'driver_base', label: 'Driver Base / Yard (ડ્રાઈવર યાર્ડ)' },
  { id: 'depot', label: 'Hub / Transit Depot (ટ્રાન્ઝિટ ડેપો)' },
  { id: 'other', label: 'Other Site (અન્ય સ્થળ)' }
];

const QUICK_CITIES = [
  { name: 'Surat / Chalthan (સુરત / चलथान)', lat: '21.14600', lng: '72.95500' },
  { name: 'Delhi NCR (દિલ્હી / दिल्ली)', lat: '28.61390', lng: '77.20900' },
  { name: 'Mumbai (મુંબઈ / मुंबई)', lat: '19.07600', lng: '72.87770' },
  { name: 'Bengaluru (બેંગલુરુ / बेंगलुरु)', lat: '12.97160', lng: '77.59460' },
  { name: 'Ahmedabad (અમદાવાદ / अहमदाबाद)', lat: '23.02250', lng: '72.57140' },
  { name: 'Jaipur (જયપુર / जयपुर)', lat: '26.91240', lng: '75.78730' },
  { name: 'Kolkata (કોલકાતા / कोलकाता)', lat: '22.57260', lng: '88.36390' }
];

const LOCATION_NAME_PRESETS = [
  { label: 'Central Warehouse (વેરહાઉસ)', name: 'Central Warehouse Hub' },
  { label: 'Customer Retail Store (દુકાન)', name: 'Customer Retail Store' },
  { label: 'Transit Depot (ડેપો)', name: 'Transit Logistics Depot' },
  { label: 'Supply Yard (યાર્ડ)', name: 'Supply Yard' },
  { label: 'Vendor Pickup (પિકઅપ)', name: 'Vendor Pickup Site' },
  { label: 'Factory Plant (પ્લાન્ટ)', name: 'Manufacturing Plant' }
];

// Haversine straight-line distance, road estimate, and commercial transit time
function calculateHaversineGap(lat1, lon1, lat2, lon2) {
  const p1Lat = parseFloat(lat1);
  const p1Lon = parseFloat(lon1);
  const p2Lat = parseFloat(lat2);
  const p2Lon = parseFloat(lon2);
  if (isNaN(p1Lat) || isNaN(p1Lon) || isNaN(p2Lat) || isNaN(p2Lon)) {
    return { meters: 0, km: '0.00', roadKm: '0.00', etaMins: 0 };
  }
  const R = 6371e3; // meters
  const phi1 = (p1Lat * Math.PI) / 180;
  const phi2 = (p2Lat * Math.PI) / 180;
  const deltaPhi = ((p2Lat - p1Lat) * Math.PI) / 180;
  const deltaLambda = ((p2Lon - p1Lon) * Math.PI) / 180;
  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const meters = Math.round(R * c);
  const km = (meters / 1000).toFixed(2);
  const roadKm = ((meters * 1.25) / 1000).toFixed(2);
  const etaMins = Math.max(1, Math.round(((meters * 1.25) / 1000 / 42) * 60)); // ~42 km/h fleet speed
  return { meters, km, roadKm, etaMins };
}

// Custom Leaflet Pins with clean lettering and numbering (A / Pin 1 for Blue, B / Pin 2 for Red)
const createPin1Icon = (isActive = false) => L.divIcon({
  className: 'custom-pin-1',
  html: `
    <div style="
      position: relative;
      width: 42px;
      height: 42px;
      border-radius: 50% 50% 50% 0;
      background: #0284c7;
      transform: rotate(-45deg);
      border: 3px solid #ffffff;
      box-shadow: 0 4px 16px rgba(2, 132, 199, 0.8)${isActive ? ', 0 0 0 6px rgba(14, 165, 233, 0.45)' : ''};
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: grab;
      transition: all 0.2s ease;
    ">
      <div style="
        width: 22px;
        height: 22px;
        border-radius: 50%;
        background: #ffffff;
        color: #0284c7;
        font-weight: 900;
        font-size: 13px;
        font-family: system-ui, -apple-system, sans-serif;
        display: flex;
        align-items: center;
        justify-content: center;
        transform: rotate(45deg);
        letter-spacing: -0.5px;
      ">A</div>
    </div>
  `,
  iconSize: [42, 42],
  iconAnchor: [21, 42],
  popupAnchor: [0, -40]
});

const createPin2Icon = (isActive = false) => L.divIcon({
  className: 'custom-pin-2',
  html: `
    <div style="
      position: relative;
      width: 42px;
      height: 42px;
      border-radius: 50% 50% 50% 0;
      background: #dc2626;
      transform: rotate(-45deg);
      border: 3px solid #ffffff;
      box-shadow: 0 4px 16px rgba(220, 38, 38, 0.85)${isActive ? ', 0 0 0 6px rgba(239, 68, 68, 0.45)' : ''};
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: grab;
      transition: all 0.2s ease;
    ">
      <div style="
        width: 22px;
        height: 22px;
        border-radius: 50%;
        background: #ffffff;
        color: #dc2626;
        font-weight: 900;
        font-size: 13px;
        font-family: system-ui, -apple-system, sans-serif;
        display: flex;
        align-items: center;
        justify-content: center;
        transform: rotate(45deg);
        letter-spacing: -0.5px;
      ">B</div>
    </div>
  `,
  iconSize: [42, 42],
  iconAnchor: [21, 42],
  popupAnchor: [0, -40]
});

export default function LocationsManager({ locations = [], onLocationsUpdated }) {
  const [searchTerm, setSearchTerm] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [showArchived, setShowArchived] = useState(false);
  const [editingLocation, setEditingLocation] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [showAdvancedGps, setShowAdvancedGps] = useState(false);

  // Edit Location Modal State
  const [showEditModal, setShowEditModal] = useState(false);
  const [editModalData, setEditModalData] = useState(null);
  const [editModalError, setEditModalError] = useState('');

  // Primary Location State (Pin 1 / Blue Pin)
  const [formData, setFormData] = useState({
    name: 'सेंट्रल वेयरहाउस (Central Warehouse Hub)',
    type: 'warehouse',
    address: 'NH48, Chalthan, Surat, Gujarat',
    lat: '21.14600',
    lng: '72.95500',
    landmark: 'NH48 Junction Chalthan',
    contactPerson: '',
    contactNumber: '',
    arrivalRadiusMeters: '150',
    instructions: '',
    status: 'active'
  });

  // Secondary Benchmark / Destination State (Pin 2 / Red Pin)
  const [pin2Data, setPin2Data] = useState({
    lat: '21.17020',
    lng: '72.83110',
    name: 'सूरत सिटी डिलीवरी पॉइंट (Surat City Drop Point)',
    address: 'Ring Road, Surat, Gujarat'
  });

  // Active pin for map-clicking: 'pin1' (Blue) or 'pin2' (Red)
  const [activePinFocus, setActivePinFocus] = useState('pin1');
  const [mapLayer, setMapLayer] = useState('satellite'); // Default to high-res Satellite Hybrid map
  const [isAutoFilling, setIsAutoFilling] = useState(false);
  const [autoFillNotice, setAutoFillNotice] = useState('');

  // Geocoding search state
  const [geocodingQuery, setGeocodingQuery] = useState('');
  const [geocodingResults, setGeocodingResults] = useState([]);
  const [isSearchingGeocode, setIsSearchingGeocode] = useState(false);
  const [geocodeInfo, setGeocodeInfo] = useState('');

  // Leaflet map refs
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const streetTileLayerRef = useRef(null);
  const satelliteTileLayerRef = useRef(null);
  const markerRef = useRef(null); // Pin 1 (Blue)
  const pin2MarkerRef = useRef(null); // Pin 2 (Red)
  const gapPolylineRef = useRef(null); // Dashed connection line
  const radiusCircleRef = useRef(null);
  const activePinFocusRef = useRef(activePinFocus);

  useEffect(() => {
    activePinFocusRef.current = activePinFocus;
    if (markerRef.current && pin2MarkerRef.current) {
      markerRef.current.setIcon(createPin1Icon(activePinFocus === 'pin1'));
      pin2MarkerRef.current.setIcon(createPin2Icon(activePinFocus === 'pin2'));
    }
  }, [activePinFocus]);

  // Helper to ensure tile layers exist across hot reloads
  const ensureTileLayers = () => {
    if (!satelliteTileLayerRef.current) {
      satelliteTileLayerRef.current = L.tileLayer('https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', {
        maxZoom: 20,
        subdomains: ['0', '1', '2', '3']
      });
    }
    if (!streetTileLayerRef.current) {
      streetTileLayerRef.current = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19
      });
    }
  };

  // Dynamic switch between Satellite and Street views
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map) return;
    ensureTileLayers();
    if (mapLayer === 'satellite') {
      if (streetTileLayerRef.current && map.hasLayer(streetTileLayerRef.current)) {
        map.removeLayer(streetTileLayerRef.current);
      }
      if (satelliteTileLayerRef.current && !map.hasLayer(satelliteTileLayerRef.current)) {
        satelliteTileLayerRef.current.addTo(map);
      }
    } else {
      if (satelliteTileLayerRef.current && map.hasLayer(satelliteTileLayerRef.current)) {
        map.removeLayer(satelliteTileLayerRef.current);
      }
      if (streetTileLayerRef.current && !map.hasLayer(streetTileLayerRef.current)) {
        streetTileLayerRef.current.addTo(map);
      }
    }
  }, [mapLayer]);

  // Clean up Leaflet map on unmount
  useEffect(() => {
    return () => {
      if (mapInstanceRef.current) {
        try {
          mapInstanceRef.current.remove();
        } catch {
          // ignore cleanup error
        }
        mapInstanceRef.current = null;
        streetTileLayerRef.current = null;
        satelliteTileLayerRef.current = null;
      }
    };
  }, []);

  // Helper to update polyline and floating distance tooltip
  const updateGapLine = (p1, p2) => {
    if (!mapInstanceRef.current) return;
    const gap = calculateHaversineGap(p1.lat, p1.lng, p2.lat, p2.lng);
    const tooltipText = `Distance: ${gap.km} km (${gap.meters.toLocaleString()}m) | ~${gap.etaMins}m ETA`;

    if (gapPolylineRef.current) {
      gapPolylineRef.current.setLatLngs([[p1.lat, p1.lng], [p2.lat, p2.lng]]);
      gapPolylineRef.current.setTooltipContent(tooltipText);
    } else {
      const poly = L.polyline([[p1.lat, p1.lng], [p2.lat, p2.lng]], {
        color: '#dc2626',
        weight: 3.5,
        dashArray: '6, 6',
        opacity: 0.95,
        interactive: false
      }).addTo(mapInstanceRef.current);

      poly.bindTooltip(tooltipText, {
        permanent: true,
        direction: 'center',
        className: 'leaflet-gap-tooltip',
        interactive: false
      }).openTooltip();

      gapPolylineRef.current = poly;
    }
  };

  // Reverse geocode to auto-fill location name & address
  const autoFillAddressForCoords = async (lat, lng, target = 'pin1') => {
    setIsAutoFilling(true);
    try {
      const res = await api.reverseGeocode(lat, lng);
      if (res && res.address) {
        if (target === 'pin1') {
          setFormData(prev => ({
            ...prev,
            lat: Number(lat).toFixed(5),
            lng: Number(lng).toFixed(5),
            address: res.address,
            name: prev.name && !prev.name.startsWith('Site (') ? prev.name : (res.name || 'लोकेशन हब')
          }));
          setAutoFillNotice(`पिन 1 अपडेट: ${res.name || res.address.split(',')[0]}`);
        } else {
          setPin2Data(prev => ({
            ...prev,
            lat: Number(lat).toFixed(5),
            lng: Number(lng).toFixed(5),
            address: res.address,
            name: res.name || 'गंतव्य पॉइंट (Point B)'
          }));
          setAutoFillNotice(`पिन 2 अपडेट: ${res.name || res.address.split(',')[0]}`);
        }
      }
    } catch {
      // Graceful fallback
    } finally {
      setIsAutoFilling(false);
      setTimeout(() => setAutoFillNotice(''), 4000);
    }
  };

  // Initialize and update Leaflet dual-pin picker map
  useEffect(() => {
    if (!mapContainerRef.current) return;

    const p1Lat = parseFloat(formData.lat) || 21.146;
    const p1Lng = parseFloat(formData.lng) || 72.955;
    const p2Lat = parseFloat(pin2Data.lat) || (p1Lat + 0.035);
    const p2Lng = parseFloat(pin2Data.lng) || (p1Lng + 0.035);

    if (!mapInstanceRef.current) {
      const map = L.map(mapContainerRef.current, {
        attributionControl: false,
        zoomControl: true
      }).setView([p1Lat, p1Lng], 12);

      // OpenStreetMap clean street tile layer
      streetTileLayerRef.current = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19
      });

      // Google Satellite Hybrid (High-resolution aerial satellite imagery + roads + place labels)
      satelliteTileLayerRef.current = L.tileLayer('https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', {
        maxZoom: 20,
        subdomains: ['0', '1', '2', '3']
      });

      // Attach satellite by default
      if (mapLayer === 'satellite') {
        satelliteTileLayerRef.current.addTo(map);
      } else {
        streetTileLayerRef.current.addTo(map);
      }

      // Blue Pin 1 (Point A Origin)
      const marker1 = L.marker([p1Lat, p1Lng], {
        draggable: true,
        icon: createPin1Icon(),
        title: 'पिन 1 (Point A Primary Location)'
      }).addTo(map);

      // Red Pin 2 (Point B Destination)
      const marker2 = L.marker([p2Lat, p2Lng], {
        draggable: true,
        icon: createPin2Icon(),
        title: 'पिन 2 (Point B Destination Location)'
      }).addTo(map);

      // Arrival Radius Circle for Pin 1
      const radiusMeters = parseInt(formData.arrivalRadiusMeters, 10) || 150;
      const circle = L.circle([p1Lat, p1Lng], {
        radius: radiusMeters,
        color: '#0284c7',
        fillColor: '#38bdf8',
        fillOpacity: 0.15,
        weight: 2,
        dashArray: '4, 4',
        interactive: false
      }).addTo(map);

      // Dashed Polyline Connecting Pin 1 & Pin 2
      const gap = calculateHaversineGap(p1Lat, p1Lng, p2Lat, p2Lng);
      const poly = L.polyline([[p1Lat, p1Lng], [p2Lat, p2Lng]], {
        color: '#dc2626',
        weight: 3.5,
        dashArray: '6, 6',
        opacity: 0.95,
        interactive: false
      }).addTo(map);

      poly.bindTooltip(
        `Distance: ${gap.km} km (${gap.meters.toLocaleString()}m) | ~${gap.etaMins}m ETA`,
        { permanent: true, direction: 'center', interactive: false }
      ).openTooltip();

      // Pin 1 Click Event
      marker1.on('click', () => {
        setActivePinFocus('pin1');
        soundEffects.playActionClick();
      });

      // Pin 2 Click Event
      marker2.on('click', () => {
        setActivePinFocus('pin2');
        soundEffects.playActionClick();
      });

      // Pin 1 Drag Event
      marker1.on('dragend', (event) => {
        const { lat, lng } = event.target.getLatLng();
        setFormData(prev => ({
          ...prev,
          lat: lat.toFixed(5),
          lng: lng.toFixed(5)
        }));
        circle.setLatLng([lat, lng]);
        updateGapLine({ lat, lng }, marker2.getLatLng());
        autoFillAddressForCoords(lat, lng, 'pin1');
      });

      // Pin 2 Drag Event
      marker2.on('dragend', (event) => {
        const { lat, lng } = event.target.getLatLng();
        setPin2Data(prev => ({
          ...prev,
          lat: lat.toFixed(5),
          lng: lng.toFixed(5)
        }));
        updateGapLine(marker1.getLatLng(), { lat, lng });
        autoFillAddressForCoords(lat, lng, 'pin2');
      });

      // Map Click: updates currently focused pin (Point A or Point B)
      map.on('click', (event) => {
        const { lat, lng } = event.latlng;
        soundEffects.playActionClick();
        if (activePinFocusRef.current === 'pin2') {
          marker2.setLatLng([lat, lng]);
          setPin2Data(prev => ({
            ...prev,
            lat: lat.toFixed(5),
            lng: lng.toFixed(5)
          }));
          updateGapLine(marker1.getLatLng(), { lat, lng });
          autoFillAddressForCoords(lat, lng, 'pin2');
        } else {
          marker1.setLatLng([lat, lng]);
          setFormData(prev => ({
            ...prev,
            lat: lat.toFixed(5),
            lng: lng.toFixed(5)
          }));
          circle.setLatLng([lat, lng]);
          updateGapLine({ lat, lng }, marker2.getLatLng());
          autoFillAddressForCoords(lat, lng, 'pin1');
        }
      });

      markerRef.current = marker1;
      pin2MarkerRef.current = marker2;
      radiusCircleRef.current = circle;
      gapPolylineRef.current = poly;
      mapInstanceRef.current = map;
    } else {
      const marker1 = markerRef.current;
      const marker2 = pin2MarkerRef.current;
      const circle = radiusCircleRef.current;

      if (marker1 && marker2 && circle) {
        marker1.setLatLng([p1Lat, p1Lng]);
        marker2.setLatLng([p2Lat, p2Lng]);
        circle.setLatLng([p1Lat, p1Lng]);
        circle.setRadius(parseInt(formData.arrivalRadiusMeters, 10) || 150);
        updateGapLine({ lat: p1Lat, lng: p1Lng }, { lat: p2Lat, lng: p2Lng });
      }
    }
  }, [formData.lat, formData.lng, formData.arrivalRadiusMeters, pin2Data.lat, pin2Data.lng]);

  // Auto-recover if Pin 1 and Pin 2 collide at identical coordinates (fixes 0.00 km stuck state)
  useEffect(() => {
    if (formData.lat && formData.lng && pin2Data.lat && pin2Data.lng) {
      const p1Lat = parseFloat(formData.lat);
      const p1Lng = parseFloat(formData.lng);
      const p2Lat = parseFloat(pin2Data.lat);
      const p2Lng = parseFloat(pin2Data.lng);

      if (!isNaN(p1Lat) && !isNaN(p1Lng) && !isNaN(p2Lat) && !isNaN(p2Lng)) {
        const diffLat = Math.abs(p1Lat - p2Lat);
        const diffLng = Math.abs(p1Lng - p2Lng);

        // If identical or within 10 meters, auto-separate Pin 2 by ~4.5 km
        if (diffLat < 0.0001 && diffLng < 0.0001) {
          const newLat = (p1Lat + 0.038).toFixed(5);
          const newLng = (p1Lng + 0.032).toFixed(5);
          setPin2Data(prev => ({
            ...prev,
            lat: newLat,
            lng: newLng,
            name: prev.name && !prev.name.includes('Point B') ? `${prev.name} (Point B)` : 'सूरत डिलीवरी पॉइंट (Point B)',
            address: 'Surat Ring Road / Industrial Corridor, Gujarat'
          }));
          autoFillAddressForCoords(newLat, newLng, 'pin2');
        }
      }
    }
  }, [formData.lat, formData.lng]);

  // Handle Form Change
  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  // Device Geolocation
  const handleUseCurrentLocation = () => {
    if (!navigator.geolocation) {
      setErrorMsg('Geolocation is not supported by your browser.');
      return;
    }
    setErrorMsg('');
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const lat = position.coords.latitude.toFixed(5);
        const lng = position.coords.longitude.toFixed(5);
        setFormData(prev => ({
          ...prev,
          lat,
          lng
        }));
        soundEffects.playSuccessChime();
        setSuccessMsg(`Acquired device location accuracy: +/- ${Math.round(position.coords.accuracy)}m`);
        autoFillAddressForCoords(lat, lng, 'pin1');
        setTimeout(() => setSuccessMsg(''), 4000);
      },
      (err) => {
        setErrorMsg(`Geolocation error: ${err.message}. Please click on the map or enter coordinates.`);
      },
      { enableHighAccuracy: true, timeout: 8000 }
    );
  };

  // Geocoding search (Supports both direct array and object formats)
  const handleSearchGeocode = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    const query = geocodingQuery.trim();
    if (!query) return;
    setIsSearchingGeocode(true);
    setErrorMsg('');
    setGeocodeInfo('');
    try {
      const res = await api.searchAddress(query);
      const list = Array.isArray(res) ? res : (res?.results || []);
      if (list && list.length > 0) {
        setGeocodingResults(list);
        setGeocodeInfo(`"${query}" के लिए ${list.length} परिणाम मिले। (Click any result below to apply or edit)`);
        // Automatically apply the top result to map and form
        handleSelectGeocodeResult(list[0], false);
      } else {
        setGeocodingResults([]);
        setGeocodeInfo(`"${query}" के लिए कोई परिणाम नहीं मिला। कृपया सीधे मैप पर क्लिक करें या शहर बटन चुनें।`);
      }
    } catch {
      setGeocodeInfo('Geocoding provider query failed. Pin on map is always functional.');
    } finally {
      setIsSearchingGeocode(false);
    }
  };

  const handleSelectGeocodeResult = (item, clearResults = true) => {
    const lat = Number(item.lat).toFixed(5);
    const lng = Number(item.lng).toFixed(5);
    const shortName = item.name ? `${item.name.split(',')[0]} (Hub)` : 'नया लोकेशन हब';

    setFormData(prev => ({
      ...prev,
      name: shortName,
      address: item.address,
      lat,
      lng
    }));

    // Re-center Pin 2 near the newly searched city
    const cLat = parseFloat(lat);
    const cLng = parseFloat(lng);
    setPin2Data(prev => ({
      ...prev,
      lat: (cLat + 0.045).toFixed(5),
      lng: (cLng + 0.045).toFixed(5),
      name: `${item.name ? item.name.split(',')[0] : 'सिटी'} डिलीवरी पॉइंट (Point B)`
    }));

    if (mapInstanceRef.current) {
      mapInstanceRef.current.setView([cLat, cLng], 12);
      if (markerRef.current) markerRef.current.setLatLng([cLat, cLng]);
      if (radiusCircleRef.current) radiusCircleRef.current.setLatLng([cLat, cLng]);
    }

    if (clearResults) {
      setGeocodingResults([]);
      setGeocodingQuery('');
    }
    soundEffects.playActionClick();
  };

  const handleSelectQuickCity = (city) => {
    soundEffects.playActionClick();
    const cLat = parseFloat(city.lat);
    const cLng = parseFloat(city.lng);
    setFormData(prev => ({
      ...prev,
      lat: city.lat,
      lng: city.lng,
      name: `${city.name.split(' ')[0]} वेयरहाउस (Logistics Hub)`,
      address: `${city.name}, Main Transport Corridor`
    }));

    // Position Pin 2 nearby so the gap polyline is immediately noticeable
    setPin2Data(prev => ({
      ...prev,
      lat: (cLat + 0.045).toFixed(5),
      lng: (cLng + 0.045).toFixed(5),
      name: `${city.name.split(' ')[0]} डिलीवरी डिपो (Drop Site)`
    }));

    if (mapInstanceRef.current && markerRef.current) {
      mapInstanceRef.current.setView([cLat, cLng], 12);
      markerRef.current.setLatLng([cLat, cLng]);
      if (radiusCircleRef.current) radiusCircleRef.current.setLatLng([cLat, cLng]);
    }
  };

  // Swap Point A (Pin 1) & Point B (Pin 2)
  const handleSwapPins = () => {
    soundEffects.playActionClick();
    const tempLat = formData.lat;
    const tempLng = formData.lng;
    const tempName = formData.name;
    const tempAddr = formData.address;

    setFormData(prev => ({
      ...prev,
      lat: pin2Data.lat,
      lng: pin2Data.lng,
      name: pin2Data.name,
      address: pin2Data.address
    }));

    setPin2Data({
      lat: tempLat,
      lng: tempLng,
      name: tempName,
      address: tempAddr
    });

    if (mapInstanceRef.current) {
      mapInstanceRef.current.panTo([parseFloat(pin2Data.lat), parseFloat(pin2Data.lng)]);
    }
  };

  // Offset Pin 2 by specified kilometers
  const handleOffsetPin2 = (kmOffset = 5) => {
    soundEffects.playActionClick();
    const p1Lat = parseFloat(formData.lat);
    const p1Lng = parseFloat(formData.lng);
    const delta = (kmOffset / 111.0);
    const newLat = (p1Lat + delta).toFixed(5);
    const newLng = (p1Lng + delta * 0.9).toFixed(5);
    setPin2Data(prev => ({
      ...prev,
      lat: newLat,
      lng: newLng
    }));
    autoFillAddressForCoords(newLat, newLng, 'pin2');
  };

  // Save Pin 2 directly to MongoDB database without touching or overwriting Pin 1
  const handleSavePin2Directly = async () => {
    soundEffects.playActionClick();
    setIsSubmitting(true);
    setErrorMsg('');
    try {
      const p2Lat = parseFloat(pin2Data.lat);
      const p2Lng = parseFloat(pin2Data.lng);
      if (isNaN(p2Lat) || isNaN(p2Lng)) {
        throw new Error('पिन 2 के लिए मान्य अक्षांश/देशांतर आवश्यक हैं');
      }

      const payload = {
        name: (pin2Data.name || 'गंतव्य डिलीवरी पॉइंट (Point B Drop)').trim(),
        type: 'delivery',
        address: (pin2Data.address || `Point B Drop Site (${p2Lat.toFixed(4)}, ${p2Lng.toFixed(4)})`).trim(),
        lat: p2Lat,
        lng: p2Lng,
        landmark: 'Point B Route Destination',
        contactPerson: '',
        contactNumber: '',
        arrivalRadiusMeters: 150,
        instructions: 'Directly registered destination point from 2-Point Route Calculator',
        status: 'active'
      };

      await api.createLocation(payload);
      soundEffects.playSuccessChime();
      setSuccessMsg(`पिन 2 लोकेशन "${payload.name}" डेटाबेस में सफलतापूर्वक सेव हो गया! (पिन 1 सुरक्षित है)`);
      if (onLocationsUpdated) onLocationsUpdated();
      setTimeout(() => setSuccessMsg(''), 5000);
    } catch (err) {
      setErrorMsg(`पिन 2 सेव नहीं हो सका: ${err.message}`);
      setTimeout(() => setErrorMsg(''), 5000);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Optional: Copy Pin 2 to Form if user explicitly wants to edit its full form fields
  const handleCopyPin2ToForm = () => {
    soundEffects.playActionClick();
    setFormData(prev => ({
      ...prev,
      name: pin2Data.name || 'गंतव्य डिलीवरी पॉइंट (Drop Location B)',
      type: 'delivery',
      address: pin2Data.address || `Point B (${pin2Data.lat}, ${pin2Data.lng})`,
      lat: pin2Data.lat,
      lng: pin2Data.lng
    }));
    setSuccessMsg('पिन 2 डेटा को फॉर्म में लोड किया गया।');
    setTimeout(() => setSuccessMsg(''), 4000);
  };

  // Edit existing location (Opens dedicated edit modal)
  const handleStartEdit = (loc) => {
    setEditModalData({
      id: loc.id,
      name: loc.name || '',
      type: loc.type || 'warehouse',
      address: loc.address || '',
      lat: Number(loc.lat).toFixed(5),
      lng: Number(loc.lng).toFixed(5),
      landmark: loc.landmark || '',
      contactPerson: loc.contactPerson || loc.contactName || '',
      contactNumber: loc.contactNumber || loc.contactPhone || '',
      arrivalRadiusMeters: String(loc.arrivalRadiusMeters || 150),
      instructions: loc.instructions || '',
      status: loc.status || 'active'
    });
    setEditModalError('');
    setShowEditModal(true);
  };

  const handleEditModalSubmit = async (e) => {
    e.preventDefault();
    if (!editModalData) return;
    setEditModalError('');

    try {
      const payload = {
        name: editModalData.name.trim(),
        type: editModalData.type,
        address: editModalData.address.trim(),
        lat: parseFloat(editModalData.lat),
        lng: parseFloat(editModalData.lng),
        landmark: editModalData.landmark ? editModalData.landmark.trim() : '',
        contactPerson: editModalData.contactPerson ? editModalData.contactPerson.trim() : '',
        contactNumber: editModalData.contactNumber ? editModalData.contactNumber.trim() : '',
        arrivalRadiusMeters: parseInt(editModalData.arrivalRadiusMeters, 10) || 150,
        instructions: editModalData.instructions ? editModalData.instructions.trim() : '',
        status: editModalData.status
      };

      if (!payload.name) throw new Error('Location name is required');
      if (!payload.address) throw new Error('Physical address is required');
      if (isNaN(payload.lat) || payload.lat < -90 || payload.lat > 90) throw new Error('Latitude must be between -90 and 90');
      if (isNaN(payload.lng) || payload.lng < -180 || payload.lng > 180) throw new Error('Longitude must be between -180 and 180');

      await api.updateLocation(editModalData.id, payload);
      soundEffects.playSuccessChime();
      setSuccessMsg(`Successfully updated location "${payload.name}".`);
      setShowEditModal(false);
      setEditModalData(null);
      if (onLocationsUpdated) onLocationsUpdated();
    } catch (err) {
      setEditModalError(err.message || 'Failed to update location');
    }
  };

  const handleCancelEdit = () => {
    setEditingLocation(null);
    setFormData({
      name: '',
      type: 'warehouse',
      address: '',
      lat: '12.97160',
      lng: '77.59460',
      landmark: '',
      contactPerson: '',
      contactNumber: '',
      arrivalRadiusMeters: '150',
      instructions: '',
      status: 'active'
    });
    setErrorMsg('');
  };

  // Submit create or update
  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    setErrorMsg('');
    setSuccessMsg('');

    try {
      const payload = {
        name: formData.name.trim(),
        type: formData.type,
        address: formData.address.trim(),
        lat: parseFloat(formData.lat),
        lng: parseFloat(formData.lng),
        landmark: formData.landmark.trim(),
        contactPerson: formData.contactPerson.trim(),
        contactNumber: formData.contactNumber.trim(),
        arrivalRadiusMeters: parseInt(formData.arrivalRadiusMeters, 10) || 150,
        instructions: formData.instructions.trim(),
        status: formData.status
      };

      if (!payload.name) throw new Error('Location name is required');
      if (!payload.address) throw new Error('Physical address or description is required');
      if (isNaN(payload.lat) || payload.lat < -90 || payload.lat > 90) throw new Error('Latitude must be between -90 and 90');
      if (isNaN(payload.lng) || payload.lng < -180 || payload.lng > 180) throw new Error('Longitude must be between -180 and 180');

      if (editingLocation) {
        await api.updateLocation(editingLocation, payload);
        soundEffects.playSuccessChime();
        setSuccessMsg(`Successfully updated location "${payload.name}". Historical trip records remain preserved.`);
      } else {
        await api.createLocation(payload);
        soundEffects.playSuccessChime();
        setSuccessMsg(`Successfully registered new location "${payload.name}".`);
      }

      handleCancelEdit();
      if (onLocationsUpdated) onLocationsUpdated();
    } catch (err) {
      setErrorMsg(err.message || 'Failed to save location');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Archive location
  const handleArchive = async (id, name) => {
    if (!window.confirm(`Archive location "${name}"? Existing trips will retain full historical address snapshots.`)) return;
    try {
      await api.archiveLocation(id);
      soundEffects.playActionClick();
      setSuccessMsg(`Archived "${name}".`);
      if (onLocationsUpdated) onLocationsUpdated();
    } catch (err) {
      setErrorMsg(err.message || 'Failed to archive location');
    }
  };

  // Filter locations
  const filteredLocations = locations.filter(loc => {
    const matchesSearch = (loc.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
                          (loc.address || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
                          (loc.landmark || '').toLowerCase().includes(searchTerm.toLowerCase());
    const matchesType = typeFilter === 'all' || loc.type === typeFilter;
    const matchesArchived = showArchived ? true : loc.status !== 'archived';
    return matchesSearch && matchesType && matchesArchived;
  });

  const currentGap = calculateHaversineGap(formData.lat, formData.lng, pin2Data.lat, pin2Data.lng);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      
      {/* Top Banner & Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 800, color: 'var(--navy-800)', letterSpacing: '-0.02em' }}>
            Location Setup &amp; Geofences
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '2px' }}>
            Define warehouses, client delivery hubs, arrival check-in radiuses, and access instructions.
          </p>
        </div>
      </div>

      {/* Notifications */}
      {errorMsg && (
        <div style={{
          padding: '12px 16px',
          borderRadius: '8px',
          background: 'rgba(239, 68, 68, 0.1)',
          border: '1px solid rgba(239, 68, 68, 0.3)',
          color: '#b91c1c',
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          fontSize: '13px',
          fontWeight: 600
        }}>
          <AlertCircle size={18} />
          <span>{errorMsg}</span>
        </div>
      )}

      {successMsg && (
        <div style={{
          padding: '12px 16px',
          borderRadius: '8px',
          background: 'rgba(16, 185, 129, 0.1)',
          border: '1px solid rgba(16, 185, 129, 0.3)',
          color: '#065f46',
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          fontSize: '13px',
          fontWeight: 600
        }}>
          <CheckCircle2 size={18} />
          <span>{successMsg}</span>
        </div>
      )}

      {/* Location Setup Panel (Split Form + Map Verification) */}
      <div className="card" style={{ padding: '24px', border: '1px solid var(--slate-200)', borderRadius: '12px', background: '#ffffff' }}>
        <div style={{ borderBottom: '1px solid var(--slate-200)', paddingBottom: '14px', marginBottom: '20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '10px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{
              width: '32px',
              height: '32px',
              borderRadius: '8px',
              background: 'rgba(2, 132, 199, 0.12)',
              color: 'var(--primary-blue)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <MapPin size={18} />
            </div>
            <div>
              <h2 style={{ fontSize: '16px', fontWeight: 700, color: 'var(--navy-800)' }}>
                {editingLocation ? `Edit Location: ${formData.name}` : 'Create New Operational Location'}
              </h2>
              <div style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
                Drag pin or click map to calibrate precise delivery geofence coordinates.
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <button
              type="button"
              onClick={handleUseCurrentLocation}
              className="btn btn-secondary"
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px' }}
            >
              <Crosshair size={14} />
              <span>Use Device Location</span>
            </button>
            {editingLocation && (
              <button
                type="button"
                onClick={handleCancelEdit}
                className="btn btn-secondary"
                style={{ fontSize: '12px' }}
              >
                Cancel Edit
              </button>
            )}
          </div>
        </div>

        {/* Address Search Bar */}
        <form onSubmit={handleSearchGeocode} style={{ marginBottom: '20px' }}>
          <div style={{ display: 'flex', gap: '8px', maxWidth: '640px' }}>
            <div style={{ position: 'relative', flex: 1 }}>
              <input
                type="text"
                placeholder="Search address or landmark (e.g. Indiranagar, Electronic City, Whitefield)..."
                value={geocodingQuery}
                onChange={(e) => setGeocodingQuery(e.target.value)}
                style={{
                  width: '100%',
                  padding: '9px 12px 9px 36px',
                  borderRadius: '8px',
                  border: '1px solid var(--slate-300)',
                  fontSize: '13px'
                }}
              />
              <Search size={16} color="var(--slate-400)" style={{ position: 'absolute', left: '12px', top: '11px' }} />
            </div>
            <button
              type="submit"
              disabled={isSearchingGeocode}
              className="btn btn-primary"
              style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}
            >
              <span>{isSearchingGeocode ? 'Searching...' : 'Search Geocode'}</span>
            </button>
          </div>

          {geocodeInfo && (
            <div style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '6px' }}>
              {geocodeInfo}
            </div>
          )}

          {geocodingResults.length > 0 && (
            <div style={{
              marginTop: '10px',
              border: '1px solid var(--slate-200)',
              borderRadius: '8px',
              background: 'var(--slate-50)',
              padding: '6px'
            }}>
              <div style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--slate-400)', padding: '4px 8px' }}>
                Search Suggestions (Click to Apply)
              </div>
              {geocodingResults.map((r, i) => (
                <div
                  key={i}
                  onClick={() => handleSelectGeocodeResult(r)}
                  style={{
                    padding: '8px 12px',
                    borderRadius: '6px',
                    cursor: 'pointer',
                    background: '#ffffff',
                    border: '1px solid var(--slate-200)',
                    marginBottom: '4px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    fontSize: '13px'
                  }}
                >
                  <div>
                    <div style={{ fontWeight: 700, color: 'var(--navy-800)' }}>{r.name}</div>
                    <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>{r.address}</div>
                  </div>
                  <div style={{ fontSize: '11px', fontFamily: 'var(--font-mono)', color: 'var(--primary-blue)' }}>
                    {r.lat}, {r.lng}
                  </div>
                </div>
              ))}
            </div>
          )}
        </form>

        {/* Form and Map Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '20px' }}>
          
          {/* Inputs Column */}
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            
            {/* Quick City Buttons */}
            <div style={{ background: '#f8fafc', padding: '10px 12px', borderRadius: '10px', border: '1px solid var(--slate-200)' }}>
              <div style={{ fontSize: '11px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                Quick City Location (ઝડપી શહેર / त्वरित शहर):
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                {QUICK_CITIES.map(c => (
                  <button
                    key={c.name}
                    type="button"
                    onClick={() => handleSelectQuickCity(c)}
                    style={{
                      background: formData.lat === c.lat ? 'var(--primary-blue)' : '#ffffff',
                      color: formData.lat === c.lat ? '#ffffff' : 'var(--navy-800)',
                      border: '1px solid var(--slate-300)',
                      padding: '4px 8px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: 700,
                      cursor: 'pointer'
                    }}
                  >
                    {c.name}
                  </button>
                ))}
              </div>
            </div>

            {/* 1-Click Name Presets & Auto-Fill from Pin */}
            <div style={{ background: '#f8fafc', padding: '10px 12px', borderRadius: '10px', border: '1px solid var(--slate-200)' }}>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--slate-600)', marginBottom: '6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '6px' }}>
                <span>Quick Location Name (સ્થળનું નામ / नाम):</span>
                <button
                  type="button"
                  onClick={() => autoFillAddressForCoords(formData.lat, formData.lng, 'pin1')}
                  disabled={isAutoFilling}
                  style={{
                    background: 'rgba(2, 132, 199, 0.1)',
                    border: '1px solid rgba(2, 132, 199, 0.3)',
                    color: 'var(--primary-blue)',
                    cursor: 'pointer',
                    fontSize: '11px',
                    fontWeight: 700,
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    padding: '3px 8px',
                    borderRadius: '6px'
                  }}
                >
                  <Sparkles size={12} />
                  <span>{isAutoFilling ? 'Detecting Address...' : 'Auto-Fill from Pin 1 (ઓટો-નામ)'}</span>
                </button>
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                {LOCATION_NAME_PRESETS.map((p, idx) => (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => {
                      soundEffects.playActionClick();
                      setFormData(prev => ({ ...prev, name: p.name }));
                    }}
                    style={{
                      background: formData.name === p.name ? 'var(--primary-blue)' : '#ffffff',
                      color: formData.name === p.name ? '#ffffff' : 'var(--navy-800)',
                      border: '1px solid var(--slate-300)',
                      padding: '3px 8px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: 600,
                      cursor: 'pointer'
                    }}
                  >
                    {p.label}
                  </button>
                ))}
              </div>
            </div>

            <div className="trip-form-grid-2">
              <div>
                <label style={{ fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <span>Location Name (સ્થળનું નામ) *</span>
                  {autoFillNotice && (
                    <span style={{ fontSize: '10px', color: 'var(--primary-teal)', fontWeight: 700 }}>
                      {autoFillNotice}
                    </span>
                  )}
                </label>
                <input
                  type="text"
                  name="name"
                  required
                  placeholder="e.g. Central Warehouse or Customer Retail Store"
                  value={formData.name}
                  onChange={handleChange}
                  className="form-control"
                />
              </div>

              <div>
                <label style={{ fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px', display: 'block' }}>
                  Location Type (સ્થળનો પ્રકાર)
                </label>
                <select
                  name="type"
                  value={formData.type}
                  onChange={handleChange}
                  className="form-control"
                >
                  {LOCATION_TYPES.map(t => (
                    <option key={t.id} value={t.id}>{t.label}</option>
                  ))}
                </select>
              </div>
            </div>

            <div>
              <label style={{ fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px', display: 'block' }}>
                Full Address / City (સંપૂર્ણ સરનામું / शहर) *
              </label>
              <textarea
                name="address"
                required
                rows={2}
                placeholder="Plot, Road, Industrial Area, City or Pincode..."
                value={formData.address}
                onChange={handleChange}
                className="form-control"
                style={{ resize: 'vertical' }}
              />
            </div>

            <div className="trip-form-grid-2">
              <div>
                <label style={{ fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px', display: 'block' }}>
                  Contact Person (સંપર્ક વ્યક્તિ - Optional)
                </label>
                <input
                  type="text"
                  name="contactPerson"
                  placeholder="साइट सुपरवाइजर या मैनेजर"
                  value={formData.contactPerson}
                  onChange={handleChange}
                  className="form-control"
                />
              </div>

              <div>
                <label style={{ fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px', display: 'block' }}>
                  संपर्क फोन (Phone - Optional)
                </label>
                <input
                  type="text"
                  name="contactNumber"
                  placeholder="+91 98200..."
                  value={formData.contactNumber}
                  onChange={handleChange}
                  className="form-control"
                />
              </div>
            </div>

            {/* Live Point A & Point B Active Pin Status Card */}
            <div style={{
              background: '#f8fafc',
              border: '1px solid var(--slate-300)',
              borderRadius: '10px',
              padding: '10px 12px',
              display: 'flex',
              flexDirection: 'column',
              gap: '8px'
            }}>
              <div style={{ fontSize: '11px', fontWeight: 800, color: 'var(--navy-900)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span>मैप पर पिन स्थिति (Selected Pin Coordinates):</span>
                <span style={{ fontSize: '10px', color: 'var(--slate-500)' }}>क्लिक करके बदलें</span>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                <div
                  onClick={() => { setActivePinFocus('pin1'); soundEffects.playActionClick(); }}
                  style={{
                    background: activePinFocus === 'pin1' ? 'rgba(2, 132, 199, 0.08)' : '#ffffff',
                    border: `1.5px solid ${activePinFocus === 'pin1' ? '#0284c7' : 'var(--slate-200)'}`,
                    borderRadius: '8px',
                    padding: '8px',
                    cursor: 'pointer'
                  }}
                >
                  <div style={{ fontSize: '11px', fontWeight: 800, color: '#0284c7', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#0284c7' }}></span>
                    <span>Point A (Origin)</span>
                    {activePinFocus === 'pin1' && <span style={{ fontSize: '9px', background: '#0284c7', color: '#fff', padding: '1px 4px', borderRadius: '4px' }}>Active</span>}
                  </div>
                  <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--navy-800)', marginTop: '2px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {formData.name}
                  </div>
                  <div style={{ fontSize: '10px', fontFamily: 'var(--font-mono)', color: 'var(--slate-500)', marginTop: '1px' }}>
                    {formData.lat}, {formData.lng}
                  </div>
                </div>

                <div
                  onClick={() => { setActivePinFocus('pin2'); soundEffects.playActionClick(); }}
                  style={{
                    background: activePinFocus === 'pin2' ? 'rgba(220, 38, 38, 0.08)' : '#ffffff',
                    border: `1.5px solid ${activePinFocus === 'pin2' ? '#dc2626' : 'var(--slate-200)'}`,
                    borderRadius: '8px',
                    padding: '8px',
                    cursor: 'pointer'
                  }}
                >
                  <div style={{ fontSize: '11px', fontWeight: 800, color: '#dc2626', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#dc2626' }}></span>
                    <span>Point B (Drop)</span>
                    {activePinFocus === 'pin2' && <span style={{ fontSize: '9px', background: '#dc2626', color: '#fff', padding: '1px 4px', borderRadius: '4px' }}>Active</span>}
                  </div>
                  <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--navy-800)', marginTop: '2px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {pin2Data.name}
                  </div>
                  <div style={{ fontSize: '10px', fontFamily: 'var(--font-mono)', color: 'var(--slate-500)', marginTop: '1px' }}>
                    {pin2Data.lat}, {pin2Data.lng}
                  </div>
                </div>
              </div>
            </div>

            {/* Collapsible Advanced GPS Section */}
            <div style={{ border: '1px solid var(--slate-200)', borderRadius: '10px', overflow: 'hidden' }}>
              <button
                type="button"
                onClick={() => setShowAdvancedGps(!showAdvancedGps)}
                style={{
                  width: '100%',
                  padding: '10px 14px',
                  background: 'var(--slate-50)',
                  border: 'none',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  cursor: 'pointer',
                  fontSize: '12px',
                  fontWeight: 700,
                  color: 'var(--primary-blue)'
                }}
              >
                <span>उन्नत GPS सेटिंग्स (Coordinates &amp; Geofence - Optional)</span>
                <span style={{ fontSize: '11px', color: 'var(--slate-500)' }}>{showAdvancedGps ? 'छिपाएं ▲' : 'दिखाएं ▼'}</span>
              </button>

              {showAdvancedGps && (
                <div style={{ padding: '14px', display: 'flex', flexDirection: 'column', gap: '12px', background: '#ffffff' }}>
                  <div className="trip-form-grid-3">
                    <div>
                      <label style={{ fontSize: '11px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px', display: 'block' }}>
                        Latitude (अक्षांश) *
                      </label>
                      <input
                        type="number"
                        step="0.00001"
                        name="lat"
                        required
                        value={formData.lat}
                        onChange={handleChange}
                        className="form-control"
                        style={{ fontFamily: 'var(--font-mono)' }}
                      />
                    </div>

                    <div>
                      <label style={{ fontSize: '11px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px', display: 'block' }}>
                        Longitude (देशांतर) *
                      </label>
                      <input
                        type="number"
                        step="0.00001"
                        name="lng"
                        required
                        value={formData.lng}
                        onChange={handleChange}
                        className="form-control"
                        style={{ fontFamily: 'var(--font-mono)' }}
                      />
                    </div>

                    <div>
                      <label style={{ fontSize: '11px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px', display: 'block' }}>
                        Arrival Radius (मीटर)
                      </label>
                      <input
                        type="number"
                        name="arrivalRadiusMeters"
                        min="20"
                        max="5000"
                        value={formData.arrivalRadiusMeters}
                        onChange={handleChange}
                        className="form-control"
                      />
                    </div>
                  </div>

                  <div className="trip-form-grid-2">
                    <div>
                      <label style={{ fontSize: '11px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px', display: 'block' }}>
                        लैंडमार्क (Landmark)
                      </label>
                      <input
                        type="text"
                        name="landmark"
                        placeholder="उदा. मेन गेट के पास"
                        value={formData.landmark}
                        onChange={handleChange}
                        className="form-control"
                      />
                    </div>

                    <div>
                      <label style={{ fontSize: '11px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px', display: 'block' }}>
                        ड्राइवर निर्देश (Access Instructions)
                      </label>
                      <input
                        type="text"
                        name="instructions"
                        placeholder="उदा. गेट 2 से अंदर आएं"
                        value={formData.instructions}
                        onChange={handleChange}
                        className="form-control"
                      />
                    </div>
                  </div>
                </div>
              )}
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginTop: '6px' }}>
              <button
                type="submit"
                disabled={isSubmitting}
                className="btn btn-primary"
                style={{ padding: '10px 20px', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '8px' }}
              >
                <CheckCircle2 size={16} />
                <span>{editingLocation ? 'अपडेट करें (Update Location)' : 'लोकेशन सेव करें (Save Location)'}</span>
              </button>
              {editingLocation && (
                <button
                  type="button"
                  onClick={handleCancelEdit}
                  className="btn btn-secondary"
                  style={{ padding: '10px 16px', fontSize: '13px' }}
                >
                  रद्द करें (Cancel)
                </button>
              )}
            </div>

          </form>

          {/* Interactive Map Visualizer & Dual Pin Route Gap Column */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            
            {/* Map Header & Pin 1 / Pin 2 selector */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '8px' }}>
              <div>
                <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-800)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <MapPin size={16} color="var(--primary-blue)" />
                  <span>Visual Pin &amp; 2-Point Route Geofence</span>
                </div>
                <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                  नीला पिन 1 (Origin Hub) &amp; लाल पिन 2 (Destination Drop)
                </div>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                {/* Satellite vs Street Map Mode Toggle */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '3px', background: '#0f172a', padding: '3px', borderRadius: '8px', border: '1px solid var(--slate-700)' }}>
                  <button
                    type="button"
                    onClick={() => setMapLayer('satellite')}
                    style={{
                      padding: '4px 10px',
                      borderRadius: '6px',
                      border: 'none',
                      background: mapLayer === 'satellite' ? '#2563eb' : 'transparent',
                      color: '#ffffff',
                      fontSize: '11px',
                      fontWeight: 800,
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '5px'
                    }}
                  >
                    <Layers size={13} color="#93c5fd" />
                    <span>सैटेलाइट (Satellite)</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setMapLayer('streets')}
                    style={{
                      padding: '4px 10px',
                      borderRadius: '6px',
                      border: 'none',
                      background: mapLayer === 'streets' ? '#334155' : 'transparent',
                      color: mapLayer === 'streets' ? '#ffffff' : '#94a3b8',
                      fontSize: '11px',
                      fontWeight: 800,
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '5px'
                    }}
                  >
                    <Compass size={13} color="#94a3b8" />
                    <span>रोड मैप (Street)</span>
                  </button>
                </div>

                {/* Point A / Point B Mode Selector */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', background: '#e2e8f0', padding: '4px', borderRadius: '10px', border: '1px solid var(--slate-300)' }}>
                  <button
                    type="button"
                    onClick={() => { setActivePinFocus('pin1'); soundEffects.playActionClick(); }}
                    style={{
                      padding: '6px 14px',
                      borderRadius: '8px',
                      border: activePinFocus === 'pin1' ? '2px solid #0284c7' : '1px solid transparent',
                      background: activePinFocus === 'pin1' ? '#0284c7' : '#ffffff',
                      color: activePinFocus === 'pin1' ? '#ffffff' : 'var(--navy-900)',
                      fontSize: '12px',
                      fontWeight: 800,
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '7px',
                      boxShadow: activePinFocus === 'pin1' ? '0 2px 8px rgba(2, 132, 199, 0.4)' : 'none',
                      transition: 'all 0.15s ease'
                    }}
                  >
                    <span style={{
                      width: '18px',
                      height: '18px',
                      borderRadius: '50%',
                      background: activePinFocus === 'pin1' ? '#ffffff' : '#0284c7',
                      color: activePinFocus === 'pin1' ? '#0284c7' : '#ffffff',
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '11px',
                      fontWeight: 900
                    }}>A</span>
                    <span>Point A सेट करें (Origin Hub)</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => { setActivePinFocus('pin2'); soundEffects.playActionClick(); }}
                    style={{
                      padding: '6px 14px',
                      borderRadius: '8px',
                      border: activePinFocus === 'pin2' ? '2px solid #dc2626' : '1px solid transparent',
                      background: activePinFocus === 'pin2' ? '#dc2626' : '#ffffff',
                      color: activePinFocus === 'pin2' ? '#ffffff' : 'var(--navy-900)',
                      fontSize: '12px',
                      fontWeight: 800,
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '7px',
                      boxShadow: activePinFocus === 'pin2' ? '0 2px 8px rgba(220, 38, 38, 0.4)' : 'none',
                      transition: 'all 0.15s ease'
                    }}
                  >
                    <span style={{
                      width: '18px',
                      height: '18px',
                      borderRadius: '50%',
                      background: activePinFocus === 'pin2' ? '#ffffff' : '#dc2626',
                      color: activePinFocus === 'pin2' ? '#dc2626' : '#ffffff',
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '11px',
                      fontWeight: 900
                    }}>B</span>
                    <span>Point B सेट करें (Destination Drop)</span>
                  </button>
                </div>
              </div>
            </div>

            {/* Prominent Active Mode Guidance Banner */}
            <div style={{
              padding: '8px 14px',
              borderRadius: '8px',
              background: activePinFocus === 'pin1' ? 'rgba(2, 132, 199, 0.08)' : 'rgba(220, 38, 38, 0.08)',
              border: `1px solid ${activePinFocus === 'pin1' ? '#bae6fd' : '#fecaca'}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: '10px',
              fontSize: '12px',
              fontWeight: 600,
              color: activePinFocus === 'pin1' ? '#0369a1' : '#b91c1c'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={{
                  padding: '2px 8px',
                  borderRadius: '6px',
                  background: activePinFocus === 'pin1' ? '#0284c7' : '#dc2626',
                  color: '#ffffff',
                  fontSize: '10px',
                  fontWeight: 800,
                  letterSpacing: '0.04em'
                }}>
                  {activePinFocus === 'pin1' ? 'POINT A ACTIVE' : 'POINT B ACTIVE'}
                </span>
                <span>
                  {activePinFocus === 'pin1'
                    ? 'Click anywhere on map to pin Point A (Origin Hub) or drag marker.'
                    : 'Click anywhere on map to pin Point B (Destination Drop) or drag marker.'}
                </span>
              </div>
              <button
                type="button"
                onClick={() => {
                  setActivePinFocus(prev => prev === 'pin1' ? 'pin2' : 'pin1');
                  soundEffects.playActionClick();
                }}
                style={{
                  background: '#ffffff',
                  border: '1px solid currentColor',
                  borderRadius: '6px',
                  padding: '3px 10px',
                  fontSize: '11px',
                  fontWeight: 700,
                  color: 'inherit',
                  cursor: 'pointer',
                  flexShrink: 0
                }}
              >
                {activePinFocus === 'pin1' ? 'Switch to Point B' : 'Switch to Point A'}
              </button>
            </div>

            {/* Map Container with Floating Satellite Switcher */}
            <div
              style={{
                position: 'relative',
                width: '100%',
                height: '380px',
                borderRadius: '10px',
                border: '1px solid var(--slate-300)',
                boxShadow: 'inset 0 1px 3px rgba(0,0,0,0.1)',
                overflow: 'hidden'
              }}
            >
              <div
                ref={mapContainerRef}
                style={{
                  width: '100%',
                  height: '100%',
                  position: 'relative',
                  zIndex: 1,
                  cursor: 'crosshair'
                }}
              />

              {/* Floating Layer Badge (Top-Right of Map) */}
              <div
                style={{
                  position: 'absolute',
                  top: '10px',
                  right: '10px',
                  zIndex: 1000,
                  background: 'rgba(15, 23, 42, 0.88)',
                  backdropFilter: 'blur(8px)',
                  padding: '3px',
                  borderRadius: '8px',
                  border: '1px solid rgba(255, 255, 255, 0.25)',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.3)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '3px'
                }}
              >
                <button
                  type="button"
                  onClick={() => setMapLayer('satellite')}
                  title="हाई-रेजोल्यूशन गूगल सैटेलाइट हाइब्रिड मैप (Aerial Satellite Imagery)"
                  style={{
                    padding: '5px 10px',
                    borderRadius: '6px',
                    border: 'none',
                    background: mapLayer === 'satellite' ? '#2563eb' : 'transparent',
                    color: '#ffffff',
                    fontSize: '11px',
                    fontWeight: 800,
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px'
                  }}
                >
                  <Layers size={12} color="#93c5fd" />
                  <span>सैटेलाइट (Satellite)</span>
                </button>

                <button
                  type="button"
                  onClick={() => setMapLayer('streets')}
                  title="मानक ओपनस्ट्रीटमैप रोड मैप (Street Map)"
                  style={{
                    padding: '5px 10px',
                    borderRadius: '6px',
                    border: 'none',
                    background: mapLayer === 'streets' ? '#475569' : 'transparent',
                    color: mapLayer === 'streets' ? '#ffffff' : '#cbd5e1',
                    fontSize: '11px',
                    fontWeight: 800,
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px'
                  }}
                >
                  <Compass size={12} color="#cbd5e1" />
                  <span>रोड मैप (Street)</span>
                </button>
              </div>
            </div>

            <div style={{ fontSize: '11px', color: 'var(--slate-500)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '6px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <Compass size={13} color="var(--primary-blue)" />
                <span>Click map or drag either pin (A or B) to adjust. Distance updates automatically in real time.</span>
              </div>
              <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: 'var(--primary-blue)' }}>
                Geofence: {formData.arrivalRadiusMeters || 150}m
              </span>
            </div>

            {/* Real-Time Gap & Distance Matrix Card */}
            <div style={{
              marginTop: '4px',
              padding: '14px',
              borderRadius: '12px',
              background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
              border: '1px solid var(--slate-300)',
              boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
              display: 'flex',
              flexDirection: 'column',
              gap: '12px'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '8px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <div style={{
                    width: '30px',
                    height: '30px',
                    borderRadius: '8px',
                    background: 'rgba(220, 38, 38, 0.12)',
                    color: '#dc2626',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}>
                    <Ruler size={16} />
                  </div>
                  <div>
                    <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-800)' }}>
                      2-पॉइंट रूट दूरी व गैप कैलकुलेटर (Auto Distance Calculator)
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                      पिन 1 (नीला) और पिन 2 (लाल) के बीच का रीयल-टाइम अंतराल
                    </div>
                  </div>
                </div>

                {/* Quick Action Controls */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                  <button
                    type="button"
                    onClick={handleSwapPins}
                    title="पिन 1 और पिन 2 की स्थिति आपस में बदलें"
                    style={{
                      background: '#ffffff',
                      border: '1px solid var(--slate-300)',
                      padding: '4px 8px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: 700,
                      color: 'var(--navy-800)',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px'
                    }}
                  >
                    <RotateCcw size={12} />
                    <span>दिशा बदलें (Swap)</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => handleOffsetPin2(5)}
                    title="पिन 2 को पिन 1 के 5 किमी पास लाएं"
                    style={{
                      background: '#ffffff',
                      border: '1px solid var(--slate-300)',
                      padding: '4px 8px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: 700,
                      color: 'var(--navy-800)',
                      cursor: 'pointer'
                    }}
                  >
                    +5km Offset
                  </button>
                  {currentGap.meters < 100 && (
                    <button
                      type="button"
                      onClick={() => handleOffsetPin2(5)}
                      title="पिन 1 और 2 के बीच 5 किमी की दूरी बनाएं"
                      style={{
                        background: '#fef2f2',
                        border: '1px solid #f87171',
                        padding: '4px 8px',
                        borderRadius: '6px',
                        fontSize: '11px',
                        fontWeight: 700,
                        color: '#dc2626',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px'
                      }}
                    >
                      <Sparkles size={11} color="#dc2626" />
                      <span>फासला बनाएं (+5km Split)</span>
                    </button>
                  )}
                  <button
                    type="button"
                    onClick={handleCopyPin2ToForm}
                    title="पिन 2 को ऊपर मुख्य फॉर्म में लोड करें"
                    style={{
                      background: '#ffffff',
                      border: '1px solid var(--slate-300)',
                      padding: '4px 8px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: 700,
                      color: 'var(--navy-800)',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px'
                    }}
                  >
                    <ArrowRight size={11} />
                    <span>फॉर्म में लोड</span>
                  </button>
                  <button
                    type="button"
                    onClick={handleSavePin2Directly}
                    disabled={isSubmitting}
                    title="पिन 2 (Point B) को सीधे डेटाबेस में नया डिलीवरी लोकेशन बनाकर सेव करें (पिन 1 सुरक्षित रहेगा)"
                    style={{
                      background: '#dc2626',
                      border: 'none',
                      padding: '5px 12px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: 800,
                      color: '#ffffff',
                      cursor: isSubmitting ? 'not-allowed' : 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '5px',
                      boxShadow: '0 2px 5px rgba(220, 38, 38, 0.3)',
                      opacity: isSubmitting ? 0.7 : 1
                    }}
                  >
                    <Check size={13} />
                    <span>{isSubmitting ? 'सेव हो रहा है...' : 'पिन 2 सेव करें (Save B)'}</span>
                  </button>
                </div>
              </div>

              {/* Metric Highlights */}
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))',
                gap: '10px'
              }}>
                {/* Straight Line Gap */}
                <div style={{
                  background: '#ffffff',
                  padding: '10px 12px',
                  borderRadius: '8px',
                  border: '1px solid var(--slate-200)',
                  borderLeft: '4px solid #dc2626'
                }}>
                  <div style={{ fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--slate-500)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <Ruler size={11} color="#dc2626" />
                    <span>सीधी दूरी (Aerial Gap)</span>
                  </div>
                  <div style={{ fontSize: '18px', fontWeight: 900, color: '#dc2626', marginTop: '2px', fontFamily: 'var(--font-mono)' }}>
                    {currentGap.km} <span style={{ fontSize: '12px', fontWeight: 600 }}>km</span>
                  </div>
                  <div style={{ fontSize: '10px', color: 'var(--slate-500)', marginTop: '1px' }}>
                    ({currentGap.meters.toLocaleString()} मीटर)
                  </div>
                </div>

                {/* Estimated Road Transit Distance */}
                <div style={{
                  background: '#ffffff',
                  padding: '10px 12px',
                  borderRadius: '8px',
                  border: '1px solid var(--slate-200)',
                  borderLeft: '4px solid var(--primary-blue)'
                }}>
                  <div style={{ fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--slate-500)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <Route size={11} color="var(--primary-blue)" />
                    <span>सड़क मार्ग (Road Route)</span>
                  </div>
                  <div style={{ fontSize: '18px', fontWeight: 900, color: 'var(--navy-800)', marginTop: '2px', fontFamily: 'var(--font-mono)' }}>
                    ~{currentGap.roadKm} <span style={{ fontSize: '12px', fontWeight: 600 }}>km</span>
                  </div>
                  <div style={{ fontSize: '10px', color: 'var(--slate-500)', marginTop: '1px' }}>
                    (कमर्शियल रूट मल्टीप्लायर)
                  </div>
                </div>

                {/* Fleet Driving ETA */}
                <div style={{
                  background: '#ffffff',
                  padding: '10px 12px',
                  borderRadius: '8px',
                  border: '1px solid var(--slate-200)',
                  borderLeft: '4px solid var(--primary-teal)'
                }}>
                  <div style={{ fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', color: 'var(--slate-500)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <Clock size={11} color="var(--primary-teal)" />
                    <span>ड्राइविंग समय (Truck ETA)</span>
                  </div>
                  <div style={{ fontSize: '18px', fontWeight: 900, color: 'var(--navy-800)', marginTop: '2px', fontFamily: 'var(--font-mono)' }}>
                    ~{currentGap.etaMins} <span style={{ fontSize: '12px', fontWeight: 600 }}>मिनट</span>
                  </div>
                  <div style={{ fontSize: '10px', color: 'var(--slate-500)', marginTop: '1px' }}>
                    (@ 42 km/h फ्लीट स्पीड)
                  </div>
                </div>
              </div>

              {/* Points Summary Row */}
              <div style={{
                display: 'grid',
                gridTemplateColumns: '1fr 1fr',
                gap: '8px',
                background: '#ffffff',
                padding: '8px 12px',
                borderRadius: '8px',
                border: '1px solid var(--slate-200)',
                fontSize: '11px'
              }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                  <div style={{ fontWeight: 800, color: '#0284c7', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#0284c7' }}></span>
                    <span>पॉइंट 1 (नीला / Point A):</span>
                  </div>
                  <div style={{ fontWeight: 700, color: 'var(--navy-800)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {formData.name || 'सेंट्रल वेयरहाउस'}
                  </div>
                  <div style={{ color: 'var(--slate-500)', fontFamily: 'var(--font-mono)', fontSize: '10px' }}>
                    Lat: {formData.lat}, Lng: {formData.lng}
                  </div>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '2px', borderLeft: '1px solid var(--slate-200)', paddingLeft: '8px' }}>
                  <div style={{ fontWeight: 800, color: '#dc2626', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#dc2626' }}></span>
                    <span>पॉइंट 2 (लाल / Point B):</span>
                  </div>
                  <div style={{ fontWeight: 700, color: 'var(--navy-800)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {pin2Data.name || 'गंतव्य डिलीवरी पॉइंट'}
                  </div>
                  <div style={{ color: 'var(--slate-500)', fontFamily: 'var(--font-mono)', fontSize: '10px' }}>
                    Lat: {pin2Data.lat}, Lng: {pin2Data.lng}
                  </div>
                </div>
              </div>

            </div>
          </div>

        </div>
      </div>

      {/* Saved Locations List */}
      <div className="card" style={{ padding: '20px', border: '1px solid var(--slate-200)', borderRadius: '12px', background: '#ffffff' }}>
        
        {/* Filters Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px', marginBottom: '16px' }}>
          <div>
            <h3 style={{ fontSize: '16px', fontWeight: 700, color: 'var(--navy-800)' }}>
              Configured Fleet Locations ({filteredLocations.length})
            </h3>
            <p style={{ fontSize: '12px', color: 'var(--slate-500)' }}>
              Locations used for pickup, dispatch, and multi-stop deliveries across trips.
            </p>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
            {/* Search Input */}
            <div style={{ position: 'relative' }}>
              <input
                type="text"
                placeholder="Filter locations..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                style={{
                  padding: '7px 10px 7px 30px',
                  borderRadius: '6px',
                  border: '1px solid var(--slate-300)',
                  fontSize: '12px',
                  width: '180px'
                }}
              />
              <Search size={14} color="var(--slate-400)" style={{ position: 'absolute', left: '10px', top: '9px' }} />
            </div>

            {/* Type Filter */}
            <select
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value)}
              style={{
                padding: '7px 10px',
                borderRadius: '6px',
                border: '1px solid var(--slate-300)',
                fontSize: '12px'
              }}
            >
              <option value="all">All Types</option>
              {LOCATION_TYPES.map(t => (
                <option key={t.id} value={t.id}>{t.label}</option>
              ))}
            </select>

            {/* Show Archived Checkbox */}
            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--slate-600)', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={showArchived}
                onChange={(e) => setShowArchived(e.target.checked)}
              />
              <span>Show Archived</span>
            </label>
          </div>
        </div>

        {/* Table / Cards */}
        {filteredLocations.length === 0 ? (
          <div style={{ padding: '36px', textAlign: 'center', color: 'var(--slate-400)' }}>
            <MapPin size={32} style={{ margin: '0 auto 10px', opacity: 0.5 }} />
            <div style={{ fontSize: '14px', fontWeight: 600 }}>No locations found</div>
            <div style={{ fontSize: '12px', marginTop: '4px' }}>Add a location using the form above.</div>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '14px' }}>
            {filteredLocations.map(loc => {
              const isArchived = loc.status === 'archived';
              return (
                <div
                  key={loc.id}
                  style={{
                    border: '1px solid var(--slate-200)',
                    borderRadius: '8px',
                    padding: '14px',
                    background: isArchived ? 'var(--slate-50)' : '#ffffff',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    gap: '10px'
                  }}
                >
                  <div>
                    <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: '8px', marginBottom: '6px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{
                          width: '28px',
                          height: '28px',
                          borderRadius: '6px',
                          background: isArchived ? 'var(--slate-200)' : 'rgba(2, 132, 199, 0.1)',
                          color: isArchived ? 'var(--slate-500)' : 'var(--primary-blue)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          flexShrink: 0
                        }}>
                          {loc.type === 'warehouse' ? <Warehouse size={15} /> : <Building size={15} />}
                        </div>
                        <div>
                          <div style={{ fontSize: '14px', fontWeight: 700, color: 'var(--navy-800)' }}>
                            {loc.name}
                          </div>
                          <span style={{
                            fontSize: '10px',
                            fontWeight: 700,
                            padding: '1px 6px',
                            borderRadius: '4px',
                            textTransform: 'uppercase',
                            background: isArchived ? 'var(--slate-200)' : 'rgba(13, 148, 136, 0.1)',
                            color: isArchived ? 'var(--slate-600)' : 'var(--primary-teal)'
                          }}>
                            {loc.type.replace('_', ' ')}
                          </span>
                        </div>
                      </div>

                      {isArchived && (
                        <span style={{ fontSize: '10px', fontWeight: 700, color: '#dc2626', background: 'rgba(239, 68, 68, 0.1)', padding: '2px 6px', borderRadius: '4px' }}>
                          ARCHIVED
                        </span>
                      )}
                    </div>

                    <div style={{ fontSize: '12px', color: 'var(--slate-600)', marginBottom: '8px', lineHeight: 1.4 }}>
                      {loc.address}
                    </div>

                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', fontSize: '11px', color: 'var(--slate-500)', marginBottom: '8px' }}>
                      <div style={{ fontFamily: 'var(--font-mono)' }}>
                        Lat: {loc.lat}, Lng: {loc.lng}
                      </div>
                      <div>
                        Radius: <strong>{loc.arrivalRadiusMeters || 150}m</strong>
                      </div>
                      {loc.landmark && (
                        <div>
                          Landmark: <em>{loc.landmark}</em>
                        </div>
                      )}
                    </div>

                    {(loc.contactPerson || loc.contactNumber) && (
                      <div style={{ fontSize: '11px', color: 'var(--slate-600)', display: 'flex', alignItems: 'center', gap: '8px', borderTop: '1px dashed var(--slate-200)', paddingTop: '6px' }}>
                        {loc.contactPerson && (
                          <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                            <User size={12} color="var(--slate-400)" />
                            {loc.contactPerson}
                          </span>
                        )}
                        {loc.contactNumber && (
                          <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                            <Phone size={12} color="var(--slate-400)" />
                            {loc.contactNumber}
                          </span>
                        )}
                      </div>
                    )}

                    {loc.instructions && (
                      <div style={{ fontSize: '11px', color: 'var(--primary-blue)', background: 'rgba(2, 132, 199, 0.05)', padding: '4px 8px', borderRadius: '4px', marginTop: '6px' }}>
                        Notes: {loc.instructions}
                      </div>
                    )}
                  </div>

                  {/* Actions */}
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '8px', borderTop: '1px solid var(--slate-100)', paddingTop: '8px' }}>
                    <button
                      type="button"
                      onClick={() => handleStartEdit(loc)}
                      className="btn btn-secondary"
                      style={{ padding: '4px 8px', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px' }}
                    >
                      <Edit2 size={12} />
                      <span>Edit &amp; Adjust Pin</span>
                    </button>
                    {!isArchived && (
                      <button
                        type="button"
                        onClick={() => handleArchive(loc.id, loc.name)}
                        className="btn btn-secondary"
                        style={{ padding: '4px 8px', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '4px', color: '#b91c1c' }}
                      >
                        <Archive size={12} />
                        <span>Archive</span>
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Dedicated Edit Location & Adjust Pin Modal */}
      {showEditModal && editModalData && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(15, 23, 42, 0.65)',
          backdropFilter: 'blur(4px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1300,
          padding: '16px'
        }}>
          <div style={{
            background: '#ffffff',
            borderRadius: '16px',
            width: '100%',
            maxWidth: '640px',
            maxHeight: '90vh',
            boxShadow: 'var(--shadow-modal)',
            border: '1px solid var(--slate-200)',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden'
          }}>
            <div style={{
              padding: '16px 20px',
              borderBottom: '1px solid var(--slate-200)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              background: 'var(--slate-50)'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div style={{
                  width: '32px',
                  height: '32px',
                  borderRadius: '8px',
                  background: 'rgba(2, 132, 199, 0.12)',
                  color: 'var(--primary-blue)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center'
                }}>
                  <MapPin size={18} />
                </div>
                <div>
                  <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)' }}>
                    लोकेशन व पिन एडिट करें (Edit Location: {editModalData.name})
                  </h3>
                  <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                    पते, लैंडमार्क, संपर्क और जियोफेंस की सेटिंग्स अपडेट करें।
                  </div>
                </div>
              </div>

              <button
                type="button"
                onClick={() => {
                  setShowEditModal(false);
                  setEditModalData(null);
                }}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--slate-400)' }}
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleEditModalSubmit} style={{ padding: '20px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {editModalError && (
                <div style={{ padding: '8px 12px', borderRadius: '8px', background: 'var(--status-rose-light)', color: 'var(--status-rose-text)', fontSize: '12px' }}>
                  {editModalError}
                </div>
              )}

              {/* Quick City Buttons */}
              <div style={{ background: '#f8fafc', padding: '10px 12px', borderRadius: '10px', border: '1px solid var(--slate-200)' }}>
                <div style={{ fontSize: '11px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                  त्वरित शहर लोकेशन (1-Click City Relocate):
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                  {QUICK_CITIES.map(c => (
                    <button
                      key={c.name}
                      type="button"
                      onClick={() => setEditModalData({ ...editModalData, lat: c.lat, lng: c.lng })}
                      style={{
                        background: editModalData.lat === c.lat ? 'var(--primary-blue)' : '#ffffff',
                        color: editModalData.lat === c.lat ? '#ffffff' : 'var(--navy-800)',
                        border: '1px solid var(--slate-300)',
                        padding: '4px 8px',
                        borderRadius: '6px',
                        fontSize: '11px',
                        fontWeight: 700,
                        cursor: 'pointer'
                      }}
                    >
                      {c.name}
                    </button>
                  ))}
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    स्थान का नाम (Location Name) *
                  </label>
                  <input
                    type="text"
                    required
                    value={editModalData.name}
                    onChange={(e) => setEditModalData({ ...editModalData, name: e.target.value })}
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    प्रकार (Type)
                  </label>
                  <select
                    value={editModalData.type}
                    onChange={(e) => setEditModalData({ ...editModalData, type: e.target.value })}
                    className="form-control"
                  >
                    <option value="warehouse">Warehouse (गोदाम / वेयरहाउस)</option>
                    <option value="customer">Customer Retail (ग्राहक स्टोर)</option>
                    <option value="driver_base">Driver Base / Depot (डिपो)</option>
                    <option value="distribution_center">Distribution Hub (डिस्ट्रिब्यूशन सेंटर)</option>
                    <option value="delivery">Delivery Point (डिलीवरी पॉइंट)</option>
                  </select>
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  पूरा पता (Full Address) *
                </label>
                <input
                  type="text"
                  required
                  value={editModalData.address}
                  onChange={(e) => setEditModalData({ ...editModalData, address: e.target.value })}
                  className="form-control"
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  पहचान की जगह (Landmark)
                </label>
                <input
                  type="text"
                  value={editModalData.landmark}
                  onChange={(e) => setEditModalData({ ...editModalData, landmark: e.target.value })}
                  placeholder="उदा. मेट्रो पिलर के पास, सामने बड़ा गेट"
                  className="form-control"
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    अक्षांश (Latitude) *
                  </label>
                  <input
                    type="number"
                    step="0.00001"
                    required
                    value={editModalData.lat}
                    onChange={(e) => setEditModalData({ ...editModalData, lat: e.target.value })}
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    देशांतर (Longitude) *
                  </label>
                  <input
                    type="number"
                    step="0.00001"
                    required
                    value={editModalData.lng}
                    onChange={(e) => setEditModalData({ ...editModalData, lng: e.target.value })}
                    className="form-control"
                  />
                </div>
              </div>

              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '4px' }}>
                  <label style={{ fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)' }}>
                    पहुंच जियोफेंस रेडियस (Arrival Radius Meters)
                  </label>
                  <span style={{ fontSize: '12px', fontWeight: 800, color: 'var(--primary-blue)' }}>
                    {editModalData.arrivalRadiusMeters} meters
                  </span>
                </div>
                <input
                  type="range"
                  min="50"
                  max="1000"
                  step="25"
                  value={editModalData.arrivalRadiusMeters}
                  onChange={(e) => setEditModalData({ ...editModalData, arrivalRadiusMeters: e.target.value })}
                  style={{ width: '100%', accentColor: 'var(--primary-blue)' }}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    संपर्क व्यक्ति (Contact Person)
                  </label>
                  <input
                    type="text"
                    value={editModalData.contactPerson}
                    onChange={(e) => setEditModalData({ ...editModalData, contactPerson: e.target.value })}
                    placeholder="स्टोर मैनेजर / सुपरवाइजर"
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                    फोन नंबर (Contact Phone)
                  </label>
                  <input
                    type="text"
                    value={editModalData.contactNumber}
                    onChange={(e) => setEditModalData({ ...editModalData, contactNumber: e.target.value })}
                    placeholder="+91..."
                    className="form-control"
                  />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  ड्राइवर निर्देश / नोट्स (Instructions)
                </label>
                <textarea
                  rows="2"
                  value={editModalData.instructions}
                  onChange={(e) => setEditModalData({ ...editModalData, instructions: e.target.value })}
                  placeholder="उदा. बैक करके गेट 4 में गाड़ी लगाएं"
                  className="form-control"
                />
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '6px', borderTop: '1px solid var(--slate-100)', paddingTop: '14px' }}>
                <button
                  type="button"
                  onClick={() => {
                    setShowEditModal(false);
                    setEditModalData(null);
                  }}
                  className="btn btn-secondary"
                >
                  रद्द करें (Cancel)
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                >
                  बदलाव सेव करें (Save Changes)
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
