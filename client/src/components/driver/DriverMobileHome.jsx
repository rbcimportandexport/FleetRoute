import React, { useState, useEffect, useRef } from 'react';
import { 
  Truck, 
  MapPin, 
  Phone, 
  CheckCircle2, 
  Clock, 
  AlertTriangle, 
  Boxes, 
  Camera, 
  FileCheck, 
  ArrowRight, 
  Navigation, 
  ExternalLink, 
  ShieldCheck, 
  Shield,
  Radio, 
  Wifi, 
  WifiOff, 
  Fuel, 
  RotateCcw,
  Info,
  PenTool,
  AlertCircle,
  Zap,
  ShieldAlert,
  Activity,
  Heart,
  Volume2,
  PhoneCall
} from 'lucide-react';
import { soundEffects } from '../../utils/soundEffects';
import FleetMap from '../map/FleetMap';
import GateProofPhotosCard from '../common/GateProofPhotosCard';
import CrashCountdownModal from './CrashCountdownModal';
import { accidentDetectionService } from '../../utils/accidentDetectionService';
import { api } from '../../utils/api';

// Haversine formula to compute distance in meters
function getDistanceMeters(lat1, lon1, lat2, lon2) {
  if (!lat1 || !lon1 || !lat2 || !lon2) return 0;
  const R = 6371e3;
  const p1 = (lat1 * Math.PI) / 180;
  const p2 = (lat2 * Math.PI) / 180;
  const dp = ((lat2 - lat1) * Math.PI) / 180;
  const dl = ((lon2 - lon1) * Math.PI) / 180;
  const a = Math.sin(dp / 2) * Math.sin(dp / 2) + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) * Math.sin(dl / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

export default function DriverMobileHome({
  driver,
  trip,
  onAdvanceStop,
  onCargoAction,
  onRecordActivity,
  onOpenDelayModal,
  isOnline = true
}) {
  // POD form states
  const [deliveryRecipient, setDeliveryRecipient] = useState('');
  const [deliveredQty, setDeliveredQty] = useState('');
  const [damagedQty, setDamagedQty] = useState('0');
  const [rejectedQty, setRejectedQty] = useState('0');
  const [podNotes, setPodNotes] = useState('');
  const [podPhotoFile, setPodPhotoFile] = useState(null);
  const [podPhotoPreview, setPodPhotoPreview] = useState('');
  const photoInputRef = useRef(null);
  const [podSignature, setPodSignature] = useState('');

  // Location Sharing State
  const [isSharingLocation, setIsSharingLocation] = useState(false);
  const [permissionStatus, setPermissionStatus] = useState('prompt'); // 'prompt' | 'granted' | 'denied'
  const [currentCoords, setCurrentCoords] = useState(null);
  const [lastLocationUpdateTime, setLastLocationUpdateTime] = useState(null);
  const [locationAccuracy, setLocationAccuracy] = useState(null);
  const [locationError, setLocationError] = useState('');
  const locationWatchIdRef = useRef(null);

  // Manual Arrival Modal (when outside radius)
  const [showManualArrivalModal, setShowManualArrivalModal] = useState(false);
  const [manualArrivalDistance, setManualArrivalDistance] = useState(0);
  const [manualArrivalReason, setManualArrivalReason] = useState('');

  // Accident Detection & Zero-Touch SOS State
  const [isCrashCountdownOpen, setIsCrashCountdownOpen] = useState(false);
  const [activeCrashDetails, setActiveCrashDetails] = useState(null);
  const [activeEmergencyIncidentId, setActiveEmergencyIncidentId] = useState(null);
  const [sensorStatus, setSensorStatus] = useState({ gForce: 1.0, speedKmh: 0 });
  const [isTestingAlert, setIsTestingAlert] = useState(false);

  // Check geolocation permissions
  useEffect(() => {
    if (typeof navigator !== 'undefined' && navigator.permissions && navigator.permissions.query) {
      navigator.permissions.query({ name: 'geolocation' }).then(result => {
        setPermissionStatus(result.state);
        result.onchange = () => setPermissionStatus(result.state);
      }).catch(() => {});
    }
  }, []);

  // Automatic Accident Detection Foreground Service Binding
  useEffect(() => {
    if (!trip || trip.status === 'completed' || trip.status === 'planned') {
      accidentDetectionService.stop();
      return;
    }

    // Trip is active -> Start native foreground sensor monitoring
    accidentDetectionService.start(trip.id, driver?.id || 'DRIVER-1');

    // Subscribe to sensor update listener
    accidentDetectionService.onSensorUpdate = (telemetry) => {
      setSensorStatus({
        gForce: telemetry.gForce || 1.0,
        speedKmh: telemetry.speedKmh || 0
      });
    };

    // Subscribe to crash triggered listener
    accidentDetectionService.onEmergencyTriggered = (emergencyPayload) => {
      setActiveCrashDetails(emergencyPayload);
      setIsCrashCountdownOpen(true);
    };

    return () => {
      accidentDetectionService.stop();
    };
  }, [trip?.id, trip?.status, driver?.id]);

  // Zero-Touch Auto Expiry Handler (Driver is unconscious or unable to respond)
  const handleZeroTouchEmergencyCreated = async () => {
    setIsCrashCountdownOpen(false);
    if (!activeCrashDetails) return;

    if (isTestingAlert) {
      // Test Alert isolation: never trigger real emergency responders
      setIsTestingAlert(false);
      alert('Test alert completed successfully. No real emergency responders were contacted.');
      return;
    }

    try {
      const idempotencyKey = `EMG-${driver?.id}-${Date.now()}`;
      const payload = {
        ...activeCrashDetails,
        idempotencyKey,
        detectionSource: 'ZERO_TOUCH_AUTO_EXPIRY'
      };

      const res = await api.detectEmergency(payload);
      if (res && res.incident) {
        setActiveEmergencyIncidentId(res.incident.incidentId);
      }
    } catch (err) {
      console.error('[Driver] Emergency dispatch failed, queued offline:', err.message);
    }
  };

  // Immediate "Send SOS Now" button handler
  const handleImmediateSOS = async () => {
    setIsCrashCountdownOpen(false);
    if (isTestingAlert) {
      setIsTestingAlert(false);
      alert('Test alert verified. System alarm, vibration and countdown verified in safe isolation.');
      return;
    }

    try {
      const idempotencyKey = `EMG-MANUAL-${driver?.id}-${Date.now()}`;
      const payload = {
        tripId: trip?.id || null,
        driverId: driver?.id || 'DRIVER-1',
        coordinates: currentCoords || { lat: 17.4265, lng: 78.4116 },
        locationAccuracy: locationAccuracy || 5,
        severity: 'CRITICAL',
        confidenceScore: 1.0,
        speedBeforeImpact: sensorStatus.speedKmh || 0,
        estimatedImpactForce: sensorStatus.gForce || 1.0,
        idempotencyKey,
        detectionSource: 'DRIVER_MANUAL_SOS'
      };

      const res = await api.detectEmergency(payload);
      if (res && res.incident) {
        setActiveEmergencyIncidentId(res.incident.incidentId);
      }
    } catch (err) {
      console.error('[Driver] Manual SOS error:', err.message);
    }
  };

  // "I Am Safe" (Driver cancels countdown) -> Record false positive safety record
  const handleDriverSafeCancellation = async () => {
    setIsCrashCountdownOpen(false);
    if (isTestingAlert) {
      setIsTestingAlert(false);
      return;
    }

    try {
      if (activeEmergencyIncidentId) {
        await api.cancelEmergency(activeEmergencyIncidentId, {
          reason: 'Driver confirmed safe on countdown screen. False positive trigger.'
        });
        setActiveEmergencyIncidentId(null);
      }
    } catch (err) {
      console.error('[Driver] Cancel emergency error:', err.message);
    }
  };

  // Test Alert function (Strictly isolated from real emergency responders)
  const handleTriggerTestAlert = () => {
    setIsTestingAlert(true);
    setActiveCrashDetails({
      coordinates: currentCoords || { lat: 17.4265, lng: 78.4116, accuracy: 5 },
      speedBeforeImpact: 45,
      gForcePeak: 4.8,
      severity: 'TEST_DRILL',
      locationAccuracy: 5,
      lastKnownLocation: false
    });
    setIsCrashCountdownOpen(true);
  };

  // Location Watch handler
  const startLocationSharing = () => {
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      setLocationError('Geolocation is not supported by your browser.');
      return;
    }

    setLocationError('');
    setIsSharingLocation(true);
    soundEffects.playActionClick();

    const watchId = navigator.geolocation.watchPosition(
      async (pos) => {
        const { latitude, longitude, accuracy, speed, heading } = pos.coords;
        setCurrentCoords({ lat: latitude, lng: longitude });
        setLocationAccuracy(accuracy);
        setLastLocationUpdateTime(new Date());
        setPermissionStatus('granted');

        try {
          await api.sendLocationSample({
            latitude,
            longitude,
            accuracy,
            speed,
            heading,
            deviceTimestamp: new Date(pos.timestamp).toISOString(),
            tripId: trip?.id || null,
            source: 'live_gps'
          });
        } catch (err) {
          console.warn('Failed to post location sample:', err.message);
        }
      },
      (err) => {
        if (err.code === err.PERMISSION_DENIED) {
          setPermissionStatus('denied');
          setLocationError('Location permission denied. Please allow location access in your browser settings.');
        } else if (err.code === err.POSITION_UNAVAILABLE) {
          setLocationError('GPS position unavailable. Ensure device GPS is active.');
        } else {
          setLocationError('GPS signal timeout. Retrying...');
        }
        setIsSharingLocation(false);
      },
      {
        enableHighAccuracy: true,
        timeout: 12000,
        maximumAge: 4000
      }
    );

    locationWatchIdRef.current = watchId;
  };

  const stopLocationSharing = () => {
    if (locationWatchIdRef.current !== null && typeof navigator !== 'undefined') {
      navigator.geolocation.clearWatch(locationWatchIdRef.current);
      locationWatchIdRef.current = null;
    }
    setIsSharingLocation(false);
    soundEffects.playActionClick();
  };

  useEffect(() => {
    return () => {
      if (locationWatchIdRef.current !== null && typeof navigator !== 'undefined') {
        navigator.geolocation.clearWatch(locationWatchIdRef.current);
      }
    };
  }, []);

  if (!trip) {
    return (
      <div className="driver-mobile-container" style={{ padding: '24px 16px', textAlign: 'center' }}>
        <div style={{
          background: '#ffffff',
          borderRadius: '16px',
          padding: '40px 20px',
          boxShadow: 'var(--shadow-card)',
          border: '1px solid var(--slate-200)'
        }}>
          <div style={{
            width: '60px',
            height: '60px',
            borderRadius: '50%',
            background: 'var(--slate-100)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 16px',
            color: 'var(--slate-400)'
          }}>
            <Truck size={30} />
          </div>
          <h2 style={{ fontSize: '18px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '8px' }}>
            No Active Trip Assigned
          </h2>
          <p style={{ fontSize: '14px', color: 'var(--slate-500)', maxWidth: '300px', margin: '0 auto 20px' }}>
            Driver {driver?.name || 'User'} is currently on standby. The central dispatcher will assign your next multi-stop dispatch route.
          </p>
        </div>
      </div>
    );
  }

  const currentStopIndex = trip.currentStopIndex || 0;
  const currentStop = trip.stops?.[currentStopIndex];
  const isTripFinished = trip.status === 'completed';
  const isTripNotStarted = trip.status === 'planned';

  // Calculate onboard cargo total
  const totalOnboard = (trip.cargo || []).reduce((acc, c) => acc + (c.loadedQty - c.deliveredQty - c.damagedQty - c.rejectedQty), 0);

  // Stop Action Handler
  const handlePrimaryAction = () => {
    soundEffects.playActionClick();

    if (isTripNotStarted) {
      onAdvanceStop({ action: 'start_trip' });
      return;
    }

    if (!currentStop) return;

    if (currentStop.status === 'pending') {
      // Check arrival radius
      const targetRadius = currentStop.location?.arrivalRadiusMeters || 150;
      if (currentCoords && currentStop.location && currentStop.location.lat && currentStop.location.lng) {
        const dist = getDistanceMeters(
          currentCoords.lat,
          currentCoords.lng,
          currentStop.location.lat,
          currentStop.location.lng
        );
        if (dist > targetRadius) {
          setManualArrivalDistance(dist);
          setShowManualArrivalModal(true);
          return;
        }
      }

      // Mark arrived within radius
      onAdvanceStop({ 
        action: 'arrive_at_stop',
        driverLocation: currentCoords || undefined
      });
      return;
    }

    if (currentStop.status === 'arrived') {
      if (currentStop.type === 'pickup') {
        onAdvanceStop({ action: 'start_loading' });
      } else if (currentStop.type === 'delivery') {
        onAdvanceStop({ action: 'start_unloading' });
      } else if (currentStop.type === 'return') {
        onAdvanceStop({ action: 'finish_return' });
      }
      return;
    }

    if (currentStop.status === 'loading') {
      onAdvanceStop({ 
        action: 'finish_loading',
        cargoConfirmed: true 
      });
      soundEffects.playSuccessChime();
      return;
    }

    if (currentStop.status === 'unloading') {
      onAdvanceStop({
        action: 'finish_unloading',
        pod: {
          recipientName: deliveryRecipient.trim() || currentStop.recipientName || 'Authorized Signatory',
          notes: podNotes.trim(),
          hasPhoto: Boolean(podPhotoPreview || podPhotoFile),
          photoData: podPhotoPreview || undefined,
          hasSignature: Boolean(podSignature.trim()),
          signature: podSignature.trim() || 'Signatory verified onsite',
          deliveredQty: deliveredQty ? parseInt(deliveredQty, 10) : undefined,
          damagedQty: parseInt(damagedQty, 10) || 0,
          rejectedQty: parseInt(rejectedQty, 10) || 0
        }
      });
      soundEffects.playSuccessChime();
      setDeliveryRecipient('');
      setDeliveredQty('');
      setDamagedQty('0');
      setRejectedQty('0');
      setPodNotes('');
      setPodPhotoFile(null);
      setPodPhotoPreview('');
      setPodSignature('');
      return;
    }

    if (currentStop.status === 'completed') {
      onAdvanceStop({ action: 'next_stop' });
      return;
    }
  };

  const handleConfirmManualArrival = (e) => {
    e.preventDefault();
    if (!manualArrivalReason.trim()) return;

    soundEffects.playActionClick();
    onAdvanceStop({
      action: 'arrive_at_stop',
      driverLocation: currentCoords || undefined,
      manualArrivalReason: manualArrivalReason.trim()
    });
    setShowManualArrivalModal(false);
    setManualArrivalReason('');
  };

  // Label for the big primary touch button
  const getPrimaryActionLabel = () => {
    if (isTripFinished) return 'Trip Completed Successfully';
    if (isTripNotStarted) return 'Start Scheduled Trip';
    if (!currentStop) return 'Continue Workflow';

    switch (currentStop.status) {
      case 'pending':
        return `Report Arrival at Stop ${currentStopIndex + 1}`;
      case 'arrived':
        return currentStop.type === 'pickup' ? 'Start Cargo Loading' : (currentStop.type === 'return' ? 'Complete Depot Return' : 'Start Cargo Unloading');
      case 'loading':
        return 'Confirm Loaded Cargo & Finish Loading';
      case 'unloading':
        return 'Submit Delivery Proof & Finish Unloading';
      case 'completed':
        return currentStopIndex < trip.stops.length - 1 ? 'Depart to Next Stop' : 'Finalize Trip Completion';
      default:
        return 'Advance Workflow';
    }
  };

  return (
    <div className="driver-mobile-container" style={{ padding: '16px', maxWidth: '640px', margin: '0 auto' }}>
      
      {/* Driver & Assigned Vehicle Header */}
      <section style={{
        background: '#ffffff',
        borderRadius: '16px',
        padding: '16px 20px',
        boxShadow: 'var(--shadow-card)',
        border: '1px solid var(--slate-200)',
        marginBottom: '16px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              width: '46px',
              height: '46px',
              borderRadius: '50%',
              background: 'var(--navy-800)',
              color: '#ffffff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontWeight: 800,
              fontSize: '16px'
            }}>
              {driver?.name ? driver.name.charAt(0) : 'D'}
            </div>
            <div>
              <div style={{ fontSize: '16px', fontWeight: 800, color: 'var(--navy-800)' }}>
                {driver?.name || trip.driverName}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '2px' }}>
                <span style={{ fontSize: '12px', color: 'var(--slate-500)', fontFamily: 'var(--font-mono)', fontWeight: 600 }}>
                  {trip.vehicleRegistration}
                </span>
                <span style={{ color: 'var(--slate-300)' }}>|</span>
                <span style={{ fontSize: '12px', color: 'var(--slate-500)', fontFamily: 'var(--font-mono)' }}>
                  {trip.id}
                </span>
              </div>
            </div>
          </div>

          <span style={{
            display: 'inline-block',
            padding: '4px 10px',
            borderRadius: '9999px',
            fontSize: '11px',
            fontWeight: 700,
            textTransform: 'uppercase',
            background: trip.status === 'completed' ? 'var(--status-emerald-light)' : 'var(--sky-blue-light)',
            color: trip.status === 'completed' ? 'var(--status-emerald-text)' : 'var(--primary-blue)',
            border: `1px solid ${trip.status === 'completed' ? 'rgba(16, 185, 129, 0.3)' : 'rgba(2, 132, 199, 0.3)'}`
          }}>
            {trip.status.replace('_', ' ')}
          </span>
        </div>

        {/* Cargo Onboard & Current Activity */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: '10px',
          background: 'var(--slate-50)',
          borderRadius: '12px',
          padding: '12px',
          border: '1px solid var(--slate-200)'
        }}>
          <div>
            <div style={{ fontSize: '11px', textTransform: 'uppercase', color: 'var(--slate-500)', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '4px' }}>
              <Boxes size={14} color="var(--primary-blue)" />
              <span>Cargo Onboard</span>
            </div>
            <div style={{ fontSize: '20px', fontWeight: 800, color: 'var(--navy-800)', marginTop: '2px' }}>
              {totalOnboard} <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--slate-400)' }}>units</span>
            </div>
          </div>

          <div>
            <div style={{ fontSize: '11px', textTransform: 'uppercase', color: 'var(--slate-500)', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '4px' }}>
              <Clock size={14} color="var(--primary-teal)" />
              <span>Current Activity</span>
            </div>
            <div style={{ fontSize: '14px', fontWeight: 700, color: 'var(--primary-teal)', textTransform: 'capitalize', marginTop: '4px' }}>
              {trip.currentActivity || 'Driving'}
            </div>
          </div>
        </div>
      </section>

      {/* MANDATORY PRE-TRIP GATE PROOF INSPECTION CARD */}
      <GateProofPhotosCard
        trip={trip}
        onProofUpdated={() => {
          if (onCargoAction) onCargoAction({});
        }}
        depotName={trip.stops?.[0]?.location?.name || 'Depot 4'}
      />

      {/* REAL DRIVER LOCATION SHARING MODULE */}
      <section style={{
        background: '#ffffff',
        borderRadius: '16px',
        padding: '16px 20px',
        boxShadow: 'var(--shadow-card)',
        border: `1px solid ${isSharingLocation ? 'var(--primary-blue)' : 'var(--slate-200)'}`,
        marginBottom: '16px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Radio size={18} color={isSharingLocation ? 'var(--status-emerald)' : 'var(--slate-400)'} />
            <h3 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-800)' }}>
              Live Telematics Location Sharing
            </h3>
          </div>

          <span style={{
            fontSize: '10px',
            fontWeight: 800,
            padding: '2px 8px',
            borderRadius: '9999px',
            textTransform: 'uppercase',
            background: isSharingLocation ? 'var(--status-emerald-light)' : 'var(--slate-100)',
            color: isSharingLocation ? 'var(--status-emerald-text)' : 'var(--slate-500)'
          }}>
            {isSharingLocation ? 'Broadcasting GPS' : 'Sharing Paused'}
          </span>
        </div>

        {locationError && (
          <div style={{
            background: 'var(--status-rose-light)',
            border: '1px solid rgba(239, 68, 68, 0.3)',
            borderRadius: '8px',
            padding: '8px 12px',
            color: 'var(--status-rose-text)',
            fontSize: '12px',
            fontWeight: 600,
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            marginBottom: '10px'
          }}>
            <AlertCircle size={15} style={{ flexShrink: 0 }} />
            <span>{locationError}</span>
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px', fontSize: '11px', color: 'var(--slate-600)', marginBottom: '12px' }}>
          <div>
            Permission: <strong style={{ textTransform: 'capitalize' }}>{permissionStatus}</strong>
          </div>
          <div>
            Accuracy: <strong>{locationAccuracy ? `±${Math.round(locationAccuracy)}m` : 'Measuring...'}</strong>
          </div>
          <div>
            Last Sample: <strong>{lastLocationUpdateTime ? lastLocationUpdateTime.toLocaleTimeString() : 'No updates yet'}</strong>
          </div>
          <div>
            Sync: <strong style={{ color: isOnline ? 'var(--status-emerald-text)' : 'var(--status-rose-text)' }}>{isOnline ? 'Online Synced' : 'Offline Queued'}</strong>
          </div>
        </div>

        {/* Toggle Button */}
        <div style={{ display: 'flex', gap: '8px' }}>
          {!isSharingLocation ? (
            <button
              onClick={startLocationSharing}
              className="btn btn-primary"
              style={{ flex: 1, padding: '10px', fontSize: '13px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
            >
              <Navigation size={15} />
              <span>Start Location Sharing</span>
            </button>
          ) : (
            <button
              onClick={stopLocationSharing}
              className="btn btn-secondary"
              style={{ flex: 1, padding: '10px', fontSize: '13px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', color: 'var(--status-rose-text)' }}
            >
              <X size={15} />
              <span>Stop Location Sharing</span>
            </button>
          )}
        </div>

        <div style={{ fontSize: '10px', color: 'var(--slate-400)', marginTop: '8px', lineHeight: '1.4' }}>
          Browser GPS requires active application and HTTPS/localhost. Native Android service runs continuous background crash detection with the screen locked.
        </div>
      </section>

      {/* DRIVER SAFETY CENTER & ZERO-TOUCH SOS ENGINE */}
      <section style={{
        background: '#ffffff',
        borderRadius: '16px',
        padding: '18px 20px',
        boxShadow: 'var(--shadow-card)',
        border: '1px solid var(--slate-200)',
        marginBottom: '16px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '14px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <ShieldAlert size={20} color="var(--primary-blue)" />
            <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-800)' }}>
              Driver Safety & Crash Protection
            </h3>
          </div>
          <span style={{
            fontSize: '10px',
            fontWeight: 800,
            padding: '3px 8px',
            borderRadius: '9999px',
            textTransform: 'uppercase',
            background: trip.status === 'in_progress' ? 'var(--status-emerald-light)' : 'var(--slate-100)',
            color: trip.status === 'in_progress' ? 'var(--status-emerald-text)' : 'var(--slate-500)'
          }}>
            {trip.status === 'in_progress' ? 'Protection Active' : 'Trip Standby'}
          </span>
        </div>

        {/* Live Sensor & Permissions Telemetry Grid */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
          gap: '10px',
          background: 'var(--slate-50)',
          borderRadius: '12px',
          padding: '12px',
          marginBottom: '14px',
          fontSize: '12px'
        }}>
          <div>
            <span style={{ color: 'var(--slate-500)', fontSize: '11px', display: 'block', fontWeight: 600 }}>Accelerometer Force</span>
            <strong style={{ fontSize: '14px', color: 'var(--navy-800)' }}>{sensorStatus.gForce.toFixed(2)} G</strong>
          </div>
          <div>
            <span style={{ color: 'var(--slate-500)', fontSize: '11px', display: 'block', fontWeight: 600 }}>GPS Telematics Speed</span>
            <strong style={{ fontSize: '14px', color: 'var(--navy-800)' }}>{sensorStatus.speedKmh} km/h</strong>
          </div>
          <div>
            <span style={{ color: 'var(--slate-500)', fontSize: '11px', display: 'block', fontWeight: 600 }}>Crash Countdown</span>
            <strong style={{ color: 'var(--primary-blue)' }}>20s Zero-Touch</strong>
          </div>
          <div>
            <span style={{ color: 'var(--slate-500)', fontSize: '11px', display: 'block', fontWeight: 600 }}>Battery Optimization</span>
            <strong style={{ color: 'var(--status-emerald-text)' }}>Exempt (Foreground)</strong>
          </div>
        </div>

        {/* Action Buttons: Manual SOS & Isolated Test Alert */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
          <button
            onClick={handleImmediateSOS}
            className="btn"
            style={{
              background: '#dc2626',
              color: '#ffffff',
              padding: '12px',
              fontSize: '13px',
              fontWeight: 800,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              borderRadius: '10px',
              border: 'none',
              cursor: 'pointer'
            }}
          >
            <PhoneCall size={16} />
            <span>Manual SOS Now</span>
          </button>

          <button
            onClick={handleTriggerTestAlert}
            className="btn btn-secondary"
            style={{
              padding: '12px',
              fontSize: '13px',
              fontWeight: 700,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              borderRadius: '10px'
            }}
          >
            <Activity size={16} color="var(--primary-teal)" />
            <span>Test Safety Alert</span>
          </button>
        </div>

        <div style={{ fontSize: '11px', color: 'var(--slate-500)', marginTop: '10px', lineHeight: '1.4' }}>
          Test Alert function verifies alarm siren, vibration, GPS fix, and countdown screen in safe isolation without alerting live dispatch or emergency partners.
        </div>
      </section>

      {/* Full-Screen Zero-Touch Crash Countdown Modal */}
      <CrashCountdownModal
        isOpen={isCrashCountdownOpen}
        initialSeconds={20}
        emergencyDetails={activeCrashDetails}
        onSafe={handleDriverSafeCancellation}
        onSendSOSNow={handleImmediateSOS}
        onAutoExpiry={handleZeroTouchEmergencyCreated}
      />

      {/* Embedded Route Map */}
      <section style={{ marginBottom: '16px' }}>
        <FleetMap
          trip={trip}
          currentLocation={currentCoords || trip.currentLocation}
          speed={trip.currentSpeed || 0}
          height="220px"
          interactive={false}
        />
      </section>

      {/* ACTIVE DESTINATION STOP CARD */}
      {!isTripFinished && currentStop && (
        <section style={{
          background: '#ffffff',
          borderRadius: '16px',
          padding: '20px',
          boxShadow: 'var(--shadow-card)',
          border: '2px solid var(--primary-blue)',
          marginBottom: '16px'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
            <span style={{
              background: currentStop.type === 'pickup' ? 'var(--primary-teal)' : (currentStop.type === 'return' ? '#d97706' : 'var(--primary-blue)'),
              color: '#ffffff',
              fontSize: '12px',
              fontWeight: 800,
              padding: '3px 10px',
              borderRadius: '6px',
              textTransform: 'uppercase'
            }}>
              Stop {currentStopIndex + 1}: {currentStop.type}
            </span>

            <div style={{ fontSize: '12px', color: 'var(--slate-400)', fontWeight: 600 }}>
              {currentStopIndex + 1} of {trip.stops.length} Stops
            </div>
          </div>

          <h3 style={{ fontSize: '18px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '4px' }}>
            {currentStop.location?.name || 'Waypoint'}
          </h3>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginBottom: '14px' }}>
            {currentStop.location?.address || 'Destination coordinates'}
          </p>

          {/* Navigation Action to External App */}
          {currentStop.location && currentStop.location.lat && currentStop.location.lng && (
            <div style={{ marginBottom: '14px' }}>
              <a
                href={`https://www.google.com/maps/dir/?api=1&destination=${currentStop.location.lat},${currentStop.location.lng}`}
                target="_blank"
                rel="noopener noreferrer"
                className="btn btn-secondary"
                style={{
                  width: '100%',
                  padding: '10px 14px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                  textDecoration: 'none',
                  fontSize: '13px',
                  fontWeight: 700,
                  color: 'var(--primary-blue)'
                }}
              >
                <ExternalLink size={15} />
                <span>Navigate to Stop in Google Maps</span>
              </a>
            </div>
          )}

          {/* Contact Person Details */}
          {currentStop.recipientName && (
            <div style={{
              background: 'var(--slate-50)',
              padding: '10px 14px',
              borderRadius: '8px',
              border: '1px solid var(--slate-200)',
              marginBottom: '14px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <div>
                <div style={{ fontSize: '11px', color: 'var(--slate-400)', fontWeight: 600 }}>Contact Person</div>
                <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--navy-800)' }}>{currentStop.recipientName}</div>
              </div>
              {currentStop.recipientPhone && (
                <a
                  href={`tel:${currentStop.recipientPhone}`}
                  className="btn btn-secondary"
                  style={{ padding: '6px 12px', fontSize: '12px', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '6px' }}
                >
                  <Phone size={13} />
                  <span>Call Recipient</span>
                </a>
              )}
            </div>
          )}

          {/* Assigned Cargo Instructions */}
          {currentStop.cargoSummary && (
            <div style={{
              background: 'var(--sky-blue-light)',
              padding: '12px',
              borderRadius: '8px',
              border: '1px solid rgba(2, 132, 199, 0.2)',
              marginBottom: '16px'
            }}>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--primary-blue)', textTransform: 'uppercase', marginBottom: '4px' }}>
                Assigned Cargo Action
              </div>
              <div style={{ fontSize: '14px', fontWeight: 700, color: 'var(--navy-800)' }}>
                {currentStop.cargoSummary}
              </div>
            </div>
          )}

          {/* Proof of Delivery Form (During 'unloading' state) */}
          {currentStop.status === 'unloading' && (
            <div style={{
              background: 'var(--slate-50)',
              padding: '16px',
              borderRadius: '12px',
              border: '1px solid var(--slate-200)',
              marginBottom: '16px'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px', flexWrap: 'wrap', gap: '8px' }}>
                <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-800)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <FileCheck size={16} color="var(--primary-blue)" />
                  <span>Proof of Delivery (POD) Verification</span>
                </div>

                <button
                  type="button"
                  onClick={() => {
                    soundEffects.playActionClick();
                    setDeliveryRecipient(currentStop.recipientName || 'Authorized Signatory');
                    setPodSignature('Verified & Signed Onsite');
                    setDamagedQty('0');
                    setRejectedQty('0');
                    setPodNotes('Cargo unloaded safely in good condition');
                  }}
                  className="btn btn-secondary"
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    padding: '5px 10px',
                    fontSize: '11px',
                    fontWeight: 700,
                    background: 'var(--sky-blue-light)',
                    color: 'var(--primary-blue)',
                    border: '1px solid rgba(2, 132, 199, 0.25)',
                    borderRadius: '6px'
                  }}
                >
                  <Zap size={13} />
                  <span>1-Tap Fast-Fill (All Good)</span>
                </button>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginBottom: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-500)', marginBottom: '4px' }}>
                    Received By Name
                  </label>
                  <input
                    type="text"
                    value={deliveryRecipient}
                    onChange={(e) => setDeliveryRecipient(e.target.value)}
                    placeholder={currentStop.recipientName || 'Name'}
                    className="form-control"
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-500)', marginBottom: '4px' }}>
                    Signatory Signature Note
                  </label>
                  <input
                    type="text"
                    value={podSignature}
                    onChange={(e) => setPodSignature(e.target.value)}
                    placeholder="Signature captured"
                    className="form-control"
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginBottom: '12px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--status-rose)', marginBottom: '4px' }}>
                    Damaged Units (if any)
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={damagedQty}
                    onChange={(e) => setDamagedQty(e.target.value)}
                    className="form-control"
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--status-amber)', marginBottom: '4px' }}>
                    Rejected Units (if any)
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={rejectedQty}
                    onChange={(e) => setRejectedQty(e.target.value)}
                    className="form-control"
                  />
                </div>
              </div>

              <div style={{ marginBottom: '12px' }}>
                <input
                  type="file"
                  accept="image/*"
                  capture="environment"
                  ref={photoInputRef}
                  style={{ display: 'none' }}
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      setPodPhotoFile(file);
                      const reader = new FileReader();
                      reader.onload = () => setPodPhotoPreview(reader.result);
                      reader.readAsDataURL(file);
                    }
                  }}
                />
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
                  <button
                    type="button"
                    onClick={() => photoInputRef.current?.click()}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '8px 12px',
                      borderRadius: '8px',
                      border: `1px solid ${podPhotoPreview ? 'var(--status-emerald)' : 'var(--slate-300)'}`,
                      background: podPhotoPreview ? 'var(--status-emerald-light)' : '#ffffff',
                      color: podPhotoPreview ? 'var(--status-emerald-text)' : 'var(--slate-600)',
                      fontSize: '12px',
                      fontWeight: 600,
                      cursor: 'pointer'
                    }}
                  >
                    <Camera size={15} />
                    <span>{podPhotoPreview ? 'Change Delivery Photo' : 'Capture Delivery Photo'}</span>
                  </button>
                  {podPhotoFile && (
                    <span style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                      {podPhotoFile.name} ({(podPhotoFile.size / 1024).toFixed(1)} KB)
                    </span>
                  )}
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '11px', fontWeight: 600, color: 'var(--slate-500)', marginBottom: '4px' }}>
                  Delivery Notes / Gate Remarks
                </label>
                <input
                  type="text"
                  value={podNotes}
                  onChange={(e) => setPodNotes(e.target.value)}
                  placeholder="e.g. Delivered safely to customer desk"
                  className="form-control"
                />
              </div>
            </div>
          )}

          {/* Primary Action Button */}
          <button
            onClick={handlePrimaryAction}
            style={{
              width: '100%',
              padding: '14px 20px',
              borderRadius: '12px',
              background: 'var(--primary-blue)',
              color: '#ffffff',
              border: 'none',
              fontSize: '15px',
              fontWeight: 800,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '10px',
              boxShadow: 'var(--shadow-blue)'
            }}
          >
            <span>{getPrimaryActionLabel()}</span>
            <ArrowRight size={18} />
          </button>
        </section>
      )}

      {/* Manual Arrival Confirmation Dialog (When Outside Arrival Radius) */}
      {showManualArrivalModal && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(15, 23, 42, 0.65)',
          backdropFilter: 'blur(4px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '16px',
          zIndex: 9999
        }}>
          <div style={{
            background: '#ffffff',
            borderRadius: '16px',
            width: '100%',
            maxWidth: '440px',
            boxShadow: 'var(--shadow-modal)',
            overflow: 'hidden'
          }}>
            <div style={{
              background: '#d97706',
              color: '#ffffff',
              padding: '16px 20px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <AlertTriangle size={18} />
                <h3 style={{ fontSize: '15px', fontWeight: 800 }}>
                  Arrival Outside Configured Radius
                </h3>
              </div>
              <button
                onClick={() => setShowManualArrivalModal(false)}
                style={{ background: 'none', border: 'none', color: '#ffffff', cursor: 'pointer' }}
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleConfirmManualArrival} style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div style={{ background: 'var(--status-amber-light)', padding: '12px', borderRadius: '8px', fontSize: '12px', color: 'var(--status-amber-text)' }}>
                GPS position is <strong>{manualArrivalDistance}m away</strong> from destination (Configured radius: {currentStop.location?.arrivalRadiusMeters || 150}m).
                Work is not blocked, but an auditable reason is required.
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-800)', marginBottom: '4px' }}>
                  Manual Check-in Reason *
                </label>
                <textarea
                  required
                  rows="3"
                  value={manualArrivalReason}
                  onChange={(e) => setManualArrivalReason(e.target.value)}
                  placeholder="e.g. Parked outside commercial gate; pedestrian delivery inside complex."
                  className="form-control"
                />
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
                <button
                  type="button"
                  onClick={() => setShowManualArrivalModal(false)}
                  className="btn btn-secondary"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                  style={{ background: '#d97706', border: 'none' }}
                >
                  Confirm Manual Arrival
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Driver Operational Assistance Controls (Incident, Challan, Refuel, Delay) */}
      <section style={{
        background: '#ffffff',
        borderRadius: '16px',
        padding: '16px',
        boxShadow: 'var(--shadow-card)',
        border: '1px solid var(--slate-200)',
        marginBottom: '16px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
          <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)', textTransform: 'uppercase', letterSpacing: '0.03em' }}>
            ડ્રાઇવર સહાયતા અને ઘટના નિયંત્રણ (Driver Operational Controls)
          </div>
          <span style={{ fontSize: '10px', fontWeight: 800, color: 'var(--primary-teal)', textTransform: 'uppercase' }}>
            Instant Dispatch Sync
          </span>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
          {/* 1. Breakdown & Incident (Images 1 & 2) */}
          <button
            onClick={() => onOpenDelayModal('breakdown')}
            className="btn"
            style={{
              padding: '12px 10px',
              fontSize: '12px',
              fontWeight: 800,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'flex-start',
              gap: '6px',
              background: '#fef2f2',
              border: '1px solid #fecaca',
              color: '#991b1b',
              borderRadius: '10px',
              textAlign: 'left',
              cursor: 'pointer'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <AlertTriangle size={16} color="#dc2626" />
              <span style={{ fontSize: '12px', fontWeight: 800 }}>Breakdown / Incident</span>
            </div>
            <span style={{ fontSize: '10px', color: '#b91c1c', fontWeight: 600 }}>
              ખામી / અકસ્માત ફોટો &amp; વોઇસ
            </span>
          </button>

          {/* 2. Police / RTO Challan (Images 3, 4, 5) */}
          <button
            onClick={() => onOpenDelayModal('challan')}
            className="btn"
            style={{
              padding: '12px 10px',
              fontSize: '12px',
              fontWeight: 800,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'flex-start',
              gap: '6px',
              background: '#f8fafc',
              border: '1px solid #0f172a',
              color: '#0f172a',
              borderRadius: '10px',
              textAlign: 'left',
              cursor: 'pointer'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Shield size={16} color="#0f172a" />
              <span style={{ fontSize: '12px', fontWeight: 800 }}>Police / RTO Challan</span>
            </div>
            <span style={{ fontSize: '10px', color: '#475569', fontWeight: 600 }}>
              મેમો સ્કેન &amp; તુરંત UPI વળતર
            </span>
          </button>

          {/* 3. Refueling / Expense */}
          <button
            onClick={() => onOpenDelayModal('refueling')}
            className="btn"
            style={{
              padding: '12px 10px',
              fontSize: '12px',
              fontWeight: 800,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'flex-start',
              gap: '6px',
              background: '#fffbeb',
              border: '1px solid #fde68a',
              color: '#92400e',
              borderRadius: '10px',
              textAlign: 'left',
              cursor: 'pointer'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Fuel size={16} color="#d97706" />
              <span style={{ fontSize: '12px', fontWeight: 800 }}>Refueling &amp; Pump</span>
            </div>
            <span style={{ fontSize: '10px', color: '#b45309', fontWeight: 600 }}>
              ઈંધણ ખર્ચ &amp; ઓડોમીટર લોગ
            </span>
          </button>

          {/* 4. Traffic / Delay */}
          <button
            onClick={() => onOpenDelayModal('traffic')}
            className="btn"
            style={{
              padding: '12px 10px',
              fontSize: '12px',
              fontWeight: 800,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'flex-start',
              gap: '6px',
              background: '#f0f9ff',
              border: '1px solid #bae6fd',
              color: '#0369a1',
              borderRadius: '10px',
              textAlign: 'left',
              cursor: 'pointer'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Clock size={16} color="#0284c7" />
              <span style={{ fontSize: '12px', fontWeight: 800 }}>Traffic &amp; Rest Break</span>
            </div>
            <span style={{ fontSize: '10px', color: '#0284c7', fontWeight: 600 }}>
              ટોલ વિલંબ &amp; આરામ નોંધણી
            </span>
          </button>
        </div>
      </section>

      {/* Stop Manifest */}
      <section style={{
        background: '#ffffff',
        borderRadius: '16px',
        padding: '16px',
        boxShadow: 'var(--shadow-card)',
        border: '1px solid var(--slate-200)'
      }}>
        <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '12px' }}>
          Trip Stop Manifest ({trip.stops?.length || 0} Total)
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {trip.stops?.map((stop, idx) => {
            const isCompleted = stop.status === 'completed';
            const isCurrent = trip.currentStopIndex === idx && trip.status === 'in_progress';
            return (
              <div
                key={stop.id || idx}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '10px 12px',
                  borderRadius: '10px',
                  background: isCurrent ? 'var(--sky-blue-light)' : (isCompleted ? 'var(--slate-50)' : '#ffffff'),
                  border: `1px solid ${isCurrent ? 'var(--primary-blue)' : 'var(--slate-200)'}`
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div style={{
                    width: '26px',
                    height: '26px',
                    borderRadius: '50%',
                    background: isCompleted ? 'var(--status-emerald)' : (isCurrent ? 'var(--primary-blue)' : 'var(--slate-200)'),
                    color: isCompleted || isCurrent ? '#ffffff' : 'var(--slate-600)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '12px',
                    fontWeight: 800
                  }}>
                    {idx + 1}
                  </div>
                  <div>
                    <div style={{ fontSize: '13px', fontWeight: 700, color: 'var(--navy-800)' }}>
                      {stop.location?.name || 'Stop'}
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                      {stop.type.toUpperCase()} • {stop.status.replace('_', ' ')}
                    </div>
                  </div>
                </div>

                {isCompleted ? (
                  <CheckCircle2 size={16} color="var(--status-emerald)" />
                ) : (
                  <span style={{ fontSize: '11px', color: 'var(--slate-400)', fontWeight: 600 }}>
                    {stop.plannedArrival ? stop.plannedArrival.slice(11, 16) : 'Scheduled'}
                  </span>
                )}
              </div>
            );
          })}
        </div>
      </section>

    </div>
  );
}
