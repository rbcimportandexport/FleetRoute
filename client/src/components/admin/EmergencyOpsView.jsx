import React, { useState, useEffect } from 'react';
import { 
  ShieldAlert, 
  MapPin, 
  CheckCircle2, 
  Clock, 
  Truck, 
  Hospital as HospitalIcon, 
  Volume2, 
  VolumeX, 
  Check, 
  UserCheck,
  Play,
  Siren,
  Activity,
  AlertTriangle,
  RotateCcw,
  Trash2
} from 'lucide-react';
import { api } from '../../utils/api';
import { soundEffects } from '../../utils/soundEffects';
import { useTranslation } from '../../hooks/useTranslation';

export default function EmergencyOpsView() {
  const { lang } = useTranslation();
  const [incidents, setIncidents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedIncident, setSelectedIncident] = useState(null);
  const [nearbyResponders, setNearbyResponders] = useState({ ambulances: [], hospitals: [] });
  const [loadingResponders, setLoadingResponders] = useState(false);
  const [isAlertMuted, setIsAlertMuted] = useState(false);
  const [timeline, setTimeline] = useState([]);
  const [deliveryAttempts, setDeliveryAttempts] = useState([]);

  // Assignment modal states
  const [selectedAmbulanceId, setSelectedAmbulanceId] = useState('');
  const [selectedHospitalId, setSelectedHospitalId] = useState('');
  const [dispatchNotes, setDispatchNotes] = useState('');
  const [actionSuccessMsg, setActionSuccessMsg] = useState('');
  const [isSimulating, setIsSimulating] = useState(false);

  // 1. Fetch emergencies list
  const fetchEmergencies = async () => {
    try {
      const data = await api.getEmergencies();
      const list = data?.incidents || [];
      setIncidents(list);
      if (list.length > 0 && !selectedIncident) {
        selectIncident(list[0]);
      }
    } catch (err) {
      console.error('[EmergencyOpsView] Failed to fetch incidents:', err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEmergencies();
    const interval = setInterval(fetchEmergencies, 5000);
    return () => clearInterval(interval);
  }, []);

  // Multilingual voice + siren alert loop when unacknowledged emergencies exist
  const unackCount = incidents.filter(i => i.status === 'sos_created' || i.status === 'alerting').length;
  useEffect(() => {
    if (unackCount > 0 && !isAlertMuted) {
      const stopLoop = soundEffects.playEmergencyAlarmLoop(lang);
      return () => {
        if (stopLoop) stopLoop();
      };
    }
  }, [unackCount, isAlertMuted, lang]);

  // 2. Select incident & fetch details
  const selectIncident = async (incident) => {
    setSelectedIncident(incident);
    setSelectedAmbulanceId(incident.assignedAmbulanceId || '');
    setSelectedHospitalId(incident.selectedHospitalId || '');
    setActionSuccessMsg('');

    try {
      const [tlRes, daRes] = await Promise.all([
        api.getEmergencyTimeline(incident.incidentId).catch(() => ({ timeline: [] })),
        api.getEmergencyDeliveryAttempts(incident.incidentId).catch(() => ({ deliveryAttempts: [] }))
      ]);
      setTimeline(tlRes?.timeline || []);
      setDeliveryAttempts(daRes?.deliveryAttempts || []);
    } catch {}

    if (incident.coordinates && incident.coordinates.lat && incident.coordinates.lng) {
      setLoadingResponders(true);
      try {
        const resp = await api.getNearbyResponders(incident.coordinates.lat, incident.coordinates.lng);
        setNearbyResponders({
          ambulances: resp?.ambulances || [],
          hospitals: resp?.hospitals || []
        });
      } catch (err) {
        console.error('Failed to fetch nearby responders:', err.message);
      } finally {
        setLoadingResponders(false);
      }
    }
  };

  // 3. Acknowledge emergency
  const handleAcknowledge = async () => {
    if (!selectedIncident) return;
    try {
      await api.acknowledgeEmergency(selectedIncident.incidentId);
      setActionSuccessMsg('Emergency acknowledged by dispatch operations.');
      if (soundEffects?.playSuccessChime) soundEffects.playSuccessChime();
      fetchEmergencies();
    } catch (err) {
      alert('Failed to acknowledge emergency: ' + err.message);
    }
  };

  // 4. Assign ambulance & hospital
  const handleAssignAmbulance = async (e) => {
    e.preventDefault();
    if (!selectedIncident || !selectedAmbulanceId) return;

    try {
      await api.assignAmbulance(selectedIncident.incidentId, {
        ambulanceId: selectedAmbulanceId,
        hospitalId: selectedHospitalId || undefined,
        notes: dispatchNotes
      });
      setActionSuccessMsg('Ambulance dispatched and incident updated.');
      if (soundEffects?.playSuccessChime) soundEffects.playSuccessChime();
      fetchEmergencies();
      selectIncident({
        ...selectedIncident,
        status: 'ambulance_assigned',
        assignedAmbulanceId: selectedAmbulanceId,
        selectedHospitalId
      });
    } catch (err) {
      alert('Dispatch failed: ' + err.message);
    }
  };

  // 5. Update status (e.g. resolved, hospital arrived)
  const handleStatusTransition = async (status, reason) => {
    if (!selectedIncident) return;
    try {
      await api.updateEmergencyStatus(selectedIncident.incidentId, { status, reason });
      setActionSuccessMsg(`Status updated to ${status}.`);
      if (soundEffects?.playActionClick) soundEffects.playActionClick();
      fetchEmergencies();
      selectIncident({ ...selectedIncident, status });
    } catch (err) {
      alert('Status transition failed: ' + err.message);
    }
  };

  // 6. Admin 1-Click Simulation Trigger
  const handleSimulateCrash = async () => {
    try {
      setIsSimulating(true);
      const testCoordinates = {
        lat: 21.17024 + (Math.random() - 0.5) * 0.04,
        lng: 72.83106 + (Math.random() - 0.5) * 0.04,
        accuracy: 4.5
      };
      
      const payload = {
        coordinates: testCoordinates,
        speedBeforeImpact: 64.5,
        gForcePeak: 5.2,
        severity: 'CRITICAL',
        triggerSource: 'sensor_fusion',
        vehiclePlate: 'MH-12-TR-9941',
        driverName: 'Ramesh Kumar (Simulation)',
        driverPhone: '+91 98765 43210'
      };

      const res = await api.detectEmergency(payload);
      setActionSuccessMsg(`Emergency Incident Created: ${res?.incident?.incidentId || 'Done'}`);
      if (soundEffects?.speakEmergencyVoice) {
        soundEffects.speakEmergencyVoice(lang);
      } else if (soundEffects?.playSOSAlert) {
        soundEffects.playSOSAlert();
      }
      await fetchEmergencies();
      if (res?.incident) {
        selectIncident(res.incident);
      }
    } catch (err) {
      alert('Simulation failed: ' + err.message);
    } finally {
      setIsSimulating(false);
    }
  };

  // 7. Clear All Test Incidents
  const [isClearing, setIsClearing] = useState(false);
  const handleClearAllIncidents = async () => {
    if (!window.confirm('Clear all test emergency incidents and reset ambulance units?')) return;
    try {
      setIsClearing(true);
      const res = await api.clearEmergencies();
      setActionSuccessMsg(res.message || 'All incidents cleared.');
      setSelectedIncident(null);
      await fetchEmergencies();
    } catch (err) {
      alert('Failed to clear incidents: ' + err.message);
    } finally {
      setIsClearing(false);
    }
  };

  const unacknowledgedCount = incidents.filter(i => i.status === 'sos_created' || i.status === 'alerting').length;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', paddingBottom: '30px' }}>
      
      {/* Top Banner / Header Bar */}
      <div style={{
        background: 'linear-gradient(135deg, #0b1120 0%, #1e293b 100%)',
        borderRadius: '16px',
        padding: '18px 20px',
        color: '#ffffff',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '16px',
        boxShadow: 'var(--shadow-card)',
        border: '1px solid var(--navy-700)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '14px', flex: '1 1 280px' }}>
          <div style={{
            width: '46px',
            height: '46px',
            borderRadius: '12px',
            background: 'rgba(239, 68, 68, 0.15)',
            border: '1px solid rgba(239, 68, 68, 0.35)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#ef4444',
            flexShrink: 0
          }}>
            <ShieldAlert size={26} />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
              <h1 style={{ fontSize: '18px', fontWeight: 800, color: '#ffffff', margin: 0, lineHeight: 1.3 }}>
                Emergency Dispatch & Incident Command
              </h1>
              {unacknowledgedCount > 0 && (
                <span style={{
                  padding: '2px 10px',
                  borderRadius: '9999px',
                  background: '#dc2626',
                  color: '#ffffff',
                  fontSize: '11px',
                  fontWeight: 900,
                  textTransform: 'uppercase',
                  letterSpacing: '0.04em'
                }}>
                  {unacknowledgedCount} UNACKNOWLEDGED
                </span>
              )}
            </div>
            <p style={{ fontSize: '12px', color: '#94a3b8', margin: '4px 0 0 0', lineHeight: 1.4 }}>
              Zero-touch telemetry sensor fusion, real-time hospital triage, and multi-channel partner dispatch.
            </p>
          </div>
        </div>

        {/* Action Controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap', width: '100%', maxWidth: '100%' }}>
          <button
            type="button"
            onClick={handleSimulateCrash}
            disabled={isSimulating}
            style={{
              padding: '10px 16px',
              borderRadius: '10px',
              background: '#dc2626',
              color: '#ffffff',
              border: 'none',
              fontSize: '12px',
              fontWeight: 800,
              cursor: isSimulating ? 'not-allowed' : 'pointer',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px',
              boxShadow: '0 4px 12px rgba(220, 38, 38, 0.35)',
              opacity: isSimulating ? 0.6 : 1,
              transition: 'all 0.15s ease',
              flex: '1 1 180px'
            }}
          >
            <Play size={14} fill="#ffffff" />
            <span>{isSimulating ? 'Simulating...' : 'Simulate Crash Incident'}</span>
          </button>

          <button
            type="button"
            onClick={handleClearAllIncidents}
            disabled={isClearing}
            style={{
              padding: '10px 14px',
              borderRadius: '10px',
              background: 'rgba(239, 68, 68, 0.15)',
              border: '1px solid rgba(239, 68, 68, 0.3)',
              color: '#fca5a5',
              fontSize: '12px',
              fontWeight: 700,
              cursor: isClearing ? 'not-allowed' : 'pointer',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              opacity: isClearing ? 0.6 : 1,
              transition: 'all 0.15s ease',
              flex: '1 1 140px'
            }}
            title="Clear all test emergency incidents from database"
          >
            <Trash2 size={14} />
            <span>{isClearing ? 'Clearing...' : 'Clear All Incidents'}</span>
          </button>

          <button
            type="button"
            onClick={() => {
              const next = !isAlertMuted;
              setIsAlertMuted(next);
              soundEffects.setMuted(next);
              if (next && typeof window !== 'undefined' && window.speechSynthesis) {
                window.speechSynthesis.cancel();
              }
            }}
            style={{
              padding: '10px 14px',
              borderRadius: '10px',
              background: '#1e293b',
              border: '1px solid #334155',
              color: '#e2e8f0',
              fontSize: '12px',
              fontWeight: 700,
              cursor: 'pointer',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              flex: '1 1 140px'
            }}
          >
            {isAlertMuted ? <VolumeX size={15} color="#f87171" /> : <Volume2 size={15} color="#34d399" />}
            <span>{isAlertMuted ? 'Muted Siren' : 'Audio Alarm Active'}</span>
          </button>
        </div>
      </div>

      {/* Success Notification Banner */}
      {actionSuccessMsg && (
        <div style={{
          padding: '12px 16px',
          borderRadius: '10px',
          background: 'var(--status-emerald-light)',
          border: '1px solid rgba(16, 185, 129, 0.3)',
          color: 'var(--status-emerald-text)',
          fontSize: '13px',
          fontWeight: 700,
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }}>
          <CheckCircle2 size={16} />
          <span>{actionSuccessMsg}</span>
        </div>
      )}

      {/* Main 2-Column Responsive Workspace */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
        gap: '20px',
        alignItems: 'start'
      }}>
        
        {/* Left Column: Incidents Queue */}
        <div style={{
          background: '#ffffff',
          borderRadius: '16px',
          border: '1px solid var(--slate-200)',
          boxShadow: 'var(--shadow-card)',
          overflow: 'hidden',
          display: 'flex',
          flexDirection: 'column'
        }}>
          <div style={{
            padding: '14px 18px',
            borderBottom: '1px solid var(--slate-100)',
            background: 'var(--slate-50)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between'
          }}>
            <span style={{ fontSize: '12px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--navy-800)', letterSpacing: '0.04em' }}>
              Emergency Incidents Queue ({incidents.length})
            </span>
            <button
              type="button"
              onClick={fetchEmergencies}
              style={{
                background: 'transparent',
                border: 'none',
                cursor: 'pointer',
                color: 'var(--primary-blue)',
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
                fontSize: '11px',
                fontWeight: 700
              }}
            >
              <RotateCcw size={12} />
              <span>Refresh</span>
            </button>
          </div>

          <div style={{ maxHeight: '640px', overflowY: 'auto' }}>
            {incidents.length === 0 ? (
              <div style={{ padding: '40px 20px', textAlign: 'center', color: 'var(--slate-400)', fontSize: '13px' }}>
                <CheckCircle2 size={36} color="var(--status-emerald)" style={{ margin: '0 auto 10px', opacity: 0.8 }} />
                <div>No active emergencies reported. Fleet is secure.</div>
              </div>
            ) : (
              incidents.map((inc) => {
                const isSelected = selectedIncident?.incidentId === inc.incidentId;
                const isCritical = inc.severity === 'CRITICAL' || inc.status === 'sos_created';

                return (
                  <div
                    key={inc.incidentId}
                    onClick={() => selectIncident(inc)}
                    style={{
                      padding: '14px 18px',
                      cursor: 'pointer',
                      borderBottom: '1px solid var(--slate-100)',
                      background: isSelected ? 'rgba(2, 132, 199, 0.08)' : '#ffffff',
                      borderLeft: isSelected ? '4px solid var(--primary-blue)' : '4px solid transparent',
                      transition: 'all 0.15s ease'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px', marginBottom: '6px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <span style={{
                          width: '9px',
                          height: '9px',
                          borderRadius: '50%',
                          background: isCritical ? '#dc2626' : '#f59e0b',
                          flexShrink: 0
                        }} />
                        <span style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)', fontFamily: 'var(--font-mono)' }}>
                          {inc.incidentId}
                        </span>
                      </div>
                      <span style={{
                        fontSize: '10px',
                        fontWeight: 900,
                        padding: '2px 8px',
                        borderRadius: '6px',
                        textTransform: 'uppercase',
                        background: inc.status === 'sos_created' ? 'var(--status-rose-light)' :
                                    inc.status === 'acknowledged' ? 'var(--status-amber-light)' :
                                    inc.status === 'resolved' ? 'var(--status-emerald-light)' : 'var(--sky-blue-light)',
                        color: inc.status === 'sos_created' ? 'var(--status-rose-text)' :
                               inc.status === 'acknowledged' ? 'var(--status-amber-text)' :
                               inc.status === 'resolved' ? 'var(--status-emerald-text)' : 'var(--primary-blue)'
                      }}>
                        {inc.status.replace(/_/g, ' ')}
                      </span>
                    </div>

                    <div style={{ fontSize: '12px', color: 'var(--slate-600)', display: 'flex', flexDirection: 'column', gap: '3px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <strong style={{ color: 'var(--navy-800)' }}>{inc.driverName || 'Driver Unassigned'}</strong>
                        <span style={{ fontSize: '11px', fontFamily: 'var(--font-mono)', color: 'var(--slate-500)' }}>
                          {inc.vehiclePlate || inc.vehicleRegistration || 'VEH-N/A'}
                        </span>
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: '5px', color: 'var(--slate-500)', fontSize: '11px' }}>
                        <MapPin size={12} color="var(--slate-400)" />
                        <span>{inc.coordinates?.lat?.toFixed(4)}, {inc.coordinates?.lng?.toFixed(4)}</span>
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '10px', color: 'var(--slate-400)', marginTop: '2px' }}>
                        <span>{inc.triggerSource || inc.detectionSource || 'SENSOR_FUSION'}</span>
                        <span>{new Date(inc.detectedAtServer || inc.createdAt || Date.now()).toLocaleTimeString()}</span>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Right Column: Selected Incident Console & Actions */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {selectedIncident ? (
            <>
              {/* Incident Header Card */}
              <div style={{
                background: '#ffffff',
                borderRadius: '16px',
                padding: '20px',
                border: '1px solid var(--slate-200)',
                boxShadow: 'var(--shadow-card)',
                display: 'flex',
                flexDirection: 'column',
                gap: '16px'
              }}>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                  gap: '12px',
                  borderBottom: '1px solid var(--slate-100)',
                  paddingBottom: '14px'
                }}>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                      <h2 style={{ fontSize: '18px', fontWeight: 800, color: 'var(--navy-900)', margin: 0, fontFamily: 'var(--font-mono)' }}>
                        {selectedIncident.incidentId}
                      </h2>
                      <span style={{
                        padding: '2px 8px',
                        borderRadius: '6px',
                        background: 'var(--status-rose-light)',
                        color: 'var(--status-rose-text)',
                        fontSize: '11px',
                        fontWeight: 800,
                        textTransform: 'uppercase'
                      }}>
                        {selectedIncident.severity || 'CRITICAL'}
                      </span>
                      <span style={{
                        padding: '2px 8px',
                        borderRadius: '6px',
                        background: 'var(--slate-100)',
                        color: 'var(--slate-600)',
                        fontSize: '11px',
                        fontWeight: 700
                      }}>
                        Confidence: {Math.round((selectedIncident.confidenceScore || 0.88) * 100)}%
                      </span>
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--slate-500)', marginTop: '4px' }}>
                      Source: <strong>{selectedIncident.triggerSource || selectedIncident.detectionSource || 'SENSOR_FUSION'}</strong> • Logged: {new Date(selectedIncident.detectedAtServer || selectedIncident.createdAt || Date.now()).toLocaleString()}
                    </div>
                  </div>

                  {/* Operational Transition Actions */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    {selectedIncident.status === 'sos_created' && (
                      <button
                        type="button"
                        onClick={handleAcknowledge}
                        style={{
                          padding: '8px 14px',
                          borderRadius: '8px',
                          background: 'var(--status-amber)',
                          color: '#ffffff',
                          border: 'none',
                          fontSize: '12px',
                          fontWeight: 800,
                          cursor: 'pointer',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '6px',
                          boxShadow: 'var(--shadow-subtle)'
                        }}
                      >
                        <UserCheck size={14} />
                        <span>Acknowledge</span>
                      </button>
                    )}
                    {selectedIncident.status !== 'resolved' && (
                      <button
                        type="button"
                        onClick={() => handleStatusTransition('resolved', 'Incident verified, patients transported, all units clear.')}
                        style={{
                          padding: '8px 14px',
                          borderRadius: '8px',
                          background: 'var(--status-emerald)',
                          color: '#ffffff',
                          border: 'none',
                          fontSize: '12px',
                          fontWeight: 800,
                          cursor: 'pointer',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '6px',
                          boxShadow: 'var(--shadow-subtle)'
                        }}
                      >
                        <Check size={14} />
                        <span>Resolve Incident</span>
                      </button>
                    )}
                  </div>
                </div>

                {/* Telemetry Evidence Grid */}
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))',
                  gap: '10px'
                }}>
                  <div style={{ background: 'var(--slate-50)', padding: '10px 12px', borderRadius: '10px', border: '1px solid var(--slate-100)' }}>
                    <span style={{ fontSize: '10px', fontWeight: 700, color: 'var(--slate-500)', textTransform: 'uppercase', display: 'block' }}>Impact Force Peak</span>
                    <strong style={{ fontSize: '16px', fontWeight: 900, color: 'var(--navy-900)', fontFamily: 'var(--font-mono)' }}>
                      {selectedIncident.estimatedImpactForce || selectedIncident.sensorSummary?.gForcePeak || 5.2} G
                    </strong>
                  </div>
                  <div style={{ background: 'var(--slate-50)', padding: '10px 12px', borderRadius: '10px', border: '1px solid var(--slate-100)' }}>
                    <span style={{ fontSize: '10px', fontWeight: 700, color: 'var(--slate-500)', textTransform: 'uppercase', display: 'block' }}>Pre-Impact Speed</span>
                    <strong style={{ fontSize: '16px', fontWeight: 900, color: 'var(--navy-900)', fontFamily: 'var(--font-mono)' }}>
                      {selectedIncident.speedBeforeImpact || 64.5} km/h
                    </strong>
                  </div>
                  <div style={{ background: 'var(--slate-50)', padding: '10px 12px', borderRadius: '10px', border: '1px solid var(--slate-100)' }}>
                    <span style={{ fontSize: '10px', fontWeight: 700, color: 'var(--slate-500)', textTransform: 'uppercase', display: 'block' }}>GPS Accuracy</span>
                    <strong style={{ fontSize: '16px', fontWeight: 900, color: 'var(--navy-900)', fontFamily: 'var(--font-mono)' }}>
                      ±{selectedIncident.locationAccuracy || 5}m
                    </strong>
                  </div>
                  <div style={{ background: 'var(--slate-50)', padding: '10px 12px', borderRadius: '10px', border: '1px solid var(--slate-100)' }}>
                    <span style={{ fontSize: '10px', fontWeight: 700, color: 'var(--slate-500)', textTransform: 'uppercase', display: 'block' }}>Blood Profile</span>
                    <strong style={{ fontSize: '16px', fontWeight: 900, color: '#dc2626', fontFamily: 'var(--font-mono)' }}>
                      {selectedIncident.medicalProfile?.bloodGroup || 'O+'}
                    </strong>
                  </div>
                </div>

                {/* Driver Identity & Contacts */}
                <div style={{
                  padding: '12px 14px',
                  borderRadius: '10px',
                  background: 'var(--sky-blue-light)',
                  border: '1px solid rgba(2, 132, 199, 0.2)',
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
                  gap: '12px',
                  fontSize: '12px'
                }}>
                  <div>
                    <span style={{ color: 'var(--slate-500)', fontSize: '11px', display: 'block', fontWeight: 600 }}>Driver Assigned</span>
                    <strong style={{ color: 'var(--navy-900)', fontSize: '13px' }}>{selectedIncident.driverName || 'Ramesh Kumar'}</strong>
                    <div style={{ color: 'var(--slate-600)', marginTop: '2px' }}>Phone: {selectedIncident.driverPhone || '+91 98765 43210'}</div>
                  </div>
                  <div>
                    <span style={{ color: 'var(--slate-500)', fontSize: '11px', display: 'block', fontWeight: 600 }}>Emergency Contact</span>
                    <strong style={{ color: 'var(--navy-900)', fontSize: '13px' }}>Operations Control</strong>
                    <div style={{ color: 'var(--slate-600)', marginTop: '2px' }}>Contact: +91 40 2360 7777</div>
                  </div>
                </div>
              </div>

              {/* Responder Selection & Dispatch Command Card */}
              <div style={{
                background: '#ffffff',
                borderRadius: '16px',
                padding: '20px',
                border: '1px solid var(--slate-200)',
                boxShadow: 'var(--shadow-card)',
                display: 'flex',
                flexDirection: 'column',
                gap: '14px'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Truck size={18} color="var(--primary-blue)" />
                  <h3 style={{ fontSize: '15px', fontWeight: 800, color: 'var(--navy-900)', margin: 0 }}>
                    Dispatch Partner Responders (Proximity Ranked)
                  </h3>
                </div>

                <form onSubmit={handleAssignAmbulance} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '12px' }}>
                    <div>
                      <label style={{ display: 'block', fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--slate-600)', marginBottom: '5px' }}>
                        Select Verified Ambulance Unit *
                      </label>
                      <select
                        value={selectedAmbulanceId}
                        onChange={(e) => setSelectedAmbulanceId(e.target.value)}
                        required
                        style={{
                          width: '100%',
                          padding: '9px 12px',
                          borderRadius: '8px',
                          border: '1px solid var(--slate-300)',
                          background: 'var(--slate-50)',
                          fontSize: '12px',
                          fontWeight: 600,
                          color: 'var(--navy-900)'
                        }}
                      >
                        <option value="">-- Choose Ambulance Unit --</option>
                        {nearbyResponders.ambulances.map((a) => (
                          <option key={a.id} value={a.id}>
                            {a.registrationNumber} ({a.vehicleType}) - {a.distanceKm} km (~{a.etaMinutes}m ETA) [{a.availability}]
                          </option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label style={{ display: 'block', fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--slate-600)', marginBottom: '5px' }}>
                        Select Target Hospital Facility
                      </label>
                      <select
                        value={selectedHospitalId}
                        onChange={(e) => setSelectedHospitalId(e.target.value)}
                        style={{
                          width: '100%',
                          padding: '9px 12px',
                          borderRadius: '8px',
                          border: '1px solid var(--slate-300)',
                          background: 'var(--slate-50)',
                          fontSize: '12px',
                          fontWeight: 600,
                          color: 'var(--navy-900)'
                        }}
                      >
                        <option value="">-- Choose Hospital Destination --</option>
                        {nearbyResponders.hospitals.map((h) => (
                          <option key={h.id} value={h.id}>
                            {h.legalName} - {h.distanceKm} km (~{h.etaMinutes}m ETA)
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '11px', fontWeight: 800, textTransform: 'uppercase', color: 'var(--slate-600)', marginBottom: '5px' }}>
                      Dispatch Directives &amp; Paramedic Notes
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. Suspected impact shock, dispatch trauma team immediately."
                      value={dispatchNotes}
                      onChange={(e) => setDispatchNotes(e.target.value)}
                      style={{
                        width: '100%',
                        padding: '9px 12px',
                        borderRadius: '8px',
                        border: '1px solid var(--slate-300)',
                        background: 'var(--slate-50)',
                        fontSize: '12px',
                        color: 'var(--navy-900)'
                      }}
                    />
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                    <button
                      type="submit"
                      disabled={!selectedAmbulanceId}
                      style={{
                        padding: '10px 18px',
                        borderRadius: '10px',
                        background: 'var(--primary-blue)',
                        color: '#ffffff',
                        border: 'none',
                        fontSize: '12px',
                        fontWeight: 800,
                        cursor: selectedAmbulanceId ? 'pointer' : 'not-allowed',
                        opacity: selectedAmbulanceId ? 1 : 0.5,
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '6px',
                        boxShadow: 'var(--shadow-blue)'
                      }}
                    >
                      <Truck size={15} />
                      <span>Dispatch Selected Ambulance Unit</span>
                    </button>
                  </div>
                </form>
              </div>

              {/* Immutable Timeline Audit */}
              <div style={{
                background: '#ffffff',
                borderRadius: '16px',
                padding: '20px',
                border: '1px solid var(--slate-200)',
                boxShadow: 'var(--shadow-card)'
              }}>
                <h3 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-900)', margin: '0 0 12px 0', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Clock size={16} color="var(--slate-500)" />
                  <span>Incident Immutable Audit Timeline ({timeline.length})</span>
                </h3>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {timeline.length === 0 ? (
                    <div style={{ fontSize: '12px', color: 'var(--slate-400)', fontStyle: 'italic' }}>
                      No lifecycle events logged for this incident yet.
                    </div>
                  ) : (
                    timeline.map((entry, idx) => (
                      <div
                        key={entry.id || idx}
                        style={{
                          padding: '10px 14px',
                          borderRadius: '8px',
                          background: 'var(--slate-50)',
                          border: '1px solid var(--slate-100)',
                          display: 'flex',
                          alignItems: 'start',
                          justifyContent: 'space-between',
                          gap: '10px',
                          fontSize: '12px'
                        }}
                      >
                        <div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <strong style={{ color: 'var(--navy-900)', textTransform: 'uppercase', fontSize: '11px' }}>
                              {entry.status ? entry.status.replace(/_/g, ' ') : 'EVENT'}
                            </strong>
                            <span style={{ color: 'var(--slate-400)' }}>• {entry.actor} ({entry.role})</span>
                          </div>
                          <p style={{ margin: '3px 0 0 0', color: 'var(--slate-600)' }}>{entry.reason}</p>
                        </div>
                        <span style={{ fontSize: '11px', fontFamily: 'var(--font-mono)', color: 'var(--slate-400)', flexShrink: 0 }}>
                          {new Date(entry.timestamp).toLocaleTimeString()}
                        </span>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </>
          ) : (
            <div style={{
              background: '#ffffff',
              borderRadius: '16px',
              padding: '48px 24px',
              border: '1px solid var(--slate-200)',
              textAlign: 'center',
              color: 'var(--slate-400)',
              fontSize: '13px'
            }}>
              Select an incident from the queue to view real-time telematics and initiate emergency dispatch.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
