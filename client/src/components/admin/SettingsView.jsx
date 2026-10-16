import React, { useState, useEffect } from 'react';
import { 
  Sliders, 
  ShieldAlert, 
  MapPin, 
  CreditCard, 
  Clock, 
  Building2, 
  Database, 
  CheckCircle2, 
  Save, 
  RefreshCw, 
  ShieldCheck, 
  Truck, 
  Cpu, 
  Globe, 
  Lock,
  AlertTriangle,
  RotateCcw
} from 'lucide-react';
import { soundEffects } from '../../utils/soundEffects';
import { api } from '../../utils/api';

export default function SettingsView() {
  const [activeTab, setActiveTab] = useState('telematics');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [savedMessage, setSavedMessage] = useState('');

  // 1. Telematics & Speed Policy
  const [speedThresholdKmH, setSpeedThresholdKmH] = useState(80);
  const [minSustainedSeconds, setMinSustainedSeconds] = useState(15);
  const [highwayBufferKmH, setHighwayBufferKmH] = useState(10);
  const [autoDispatchSpeedAlert, setAutoDispatchSpeedAlert] = useState(true);
  const [mandatorySeatbeltSelfie, setMandatorySeatbeltSelfie] = useState(true);
  const [brakingSensitivity, setBrakingSensitivity] = useState('medium');

  // 2. Geofencing & POD Rules
  const [defaultArrivalRadiusMeters, setDefaultArrivalRadiusMeters] = useState(150);
  const [enforceProximityArrival, setEnforceProximityArrival] = useState(true);
  const [allowManualArrivalOverride, setAllowManualArrivalOverride] = useState(true);
  const [mandatoryPodPhoto, setMandatoryPodPhoto] = useState(true);
  const [requireCustomerSignature, setRequireCustomerSignature] = useState(true);
  const [autoDesignateDepotReturn, setAutoDesignateDepotReturn] = useState(true);

  // 3. Challan & Instant Driver UPI
  const [spotUpiSlaMinutes, setSpotUpiSlaMinutes] = useState(15);
  const [maxSpotReimbursementInr, setMaxSpotReimbursementInr] = useState(5000);
  const [escalateRcDlSeizure, setEscalateRcDlSeizure] = useState(true);
  const [parivahanPortalSync, setParivahanPortalSync] = useState(true);
  const [requireVerifiedBankAccount, setRequireVerifiedBankAccount] = useState(true);

  // 4. Driver Hours & Safety Rules
  const [maxContinuousDrivingHours, setMaxContinuousDrivingHours] = useState(4.5);
  const [mandatoryRestMinutes, setMandatoryRestMinutes] = useState(30);
  const [nightSpeedAdvisoryKmH, setNightSpeedAdvisoryKmH] = useState(60);
  const [maxDailyShiftHours, setMaxDailyShiftHours] = useState(10);

  // 5. Company & Localization
  const [companyName, setCompanyName] = useState('FleetRoute Freight & Supply Chain Logistics Pvt Ltd');
  const [headquartersAddress, setHeadquartersAddress] = useState('Transport Hub Bay 4, Okhla Phase-III, New Delhi 110020');
  const [dispatchHelpline, setDispatchHelpline] = useState('+91 1800 200 4455 (24x7 Control Desk)');
  const [emergencyEmail, setEmergencyEmail] = useState('dispatch.safety@fleetroute.com');
  const [currencySymbol, setCurrencySymbol] = useState('INR (₹)');
  const [timezone, setTimezone] = useState('Asia/Kolkata (IST, UTC+05:30)');
  const [defaultLanguage, setDefaultLanguage] = useState('en');

  // Load configuration from server/MongoDB
  useEffect(() => {
    let isMounted = true;
    api.getSettings()
      .then((cfg) => {
        if (!isMounted || !cfg) return;
        if (cfg.speedThresholdKmH !== undefined) setSpeedThresholdKmH(cfg.speedThresholdKmH);
        if (cfg.minSustainedSeconds !== undefined) setMinSustainedSeconds(cfg.minSustainedSeconds);
        if (cfg.highwayBufferKmH !== undefined) setHighwayBufferKmH(cfg.highwayBufferKmH);
        if (cfg.autoDispatchSpeedAlert !== undefined) setAutoDispatchSpeedAlert(cfg.autoDispatchSpeedAlert);
        if (cfg.mandatorySeatbeltSelfie !== undefined) setMandatorySeatbeltSelfie(cfg.mandatorySeatbeltSelfie);
        if (cfg.brakingSensitivity) setBrakingSensitivity(cfg.brakingSensitivity);

        if (cfg.defaultArrivalRadiusMeters !== undefined) setDefaultArrivalRadiusMeters(cfg.defaultArrivalRadiusMeters);
        if (cfg.enforceProximityArrival !== undefined) setEnforceProximityArrival(cfg.enforceProximityArrival);
        if (cfg.allowManualArrivalOverride !== undefined) setAllowManualArrivalOverride(cfg.allowManualArrivalOverride);
        if (cfg.mandatoryPodPhoto !== undefined) setMandatoryPodPhoto(cfg.mandatoryPodPhoto);
        if (cfg.requireCustomerSignature !== undefined) setRequireCustomerSignature(cfg.requireCustomerSignature);
        if (cfg.autoDesignateDepotReturn !== undefined) setAutoDesignateDepotReturn(cfg.autoDesignateDepotReturn);

        if (cfg.spotUpiSlaMinutes !== undefined) setSpotUpiSlaMinutes(cfg.spotUpiSlaMinutes);
        if (cfg.maxSpotReimbursementInr !== undefined) setMaxSpotReimbursementInr(cfg.maxSpotReimbursementInr);
        if (cfg.escalateRcDlSeizure !== undefined) setEscalateRcDlSeizure(cfg.escalateRcDlSeizure);
        if (cfg.parivahanPortalSync !== undefined) setParivahanPortalSync(cfg.parivahanPortalSync);
        if (cfg.requireVerifiedBankAccount !== undefined) setRequireVerifiedBankAccount(cfg.requireVerifiedBankAccount);

        if (cfg.maxContinuousDrivingHours !== undefined) setMaxContinuousDrivingHours(cfg.maxContinuousDrivingHours);
        if (cfg.mandatoryRestMinutes !== undefined) setMandatoryRestMinutes(cfg.mandatoryRestMinutes);
        if (cfg.nightSpeedAdvisoryKmH !== undefined) setNightSpeedAdvisoryKmH(cfg.nightSpeedAdvisoryKmH);
        if (cfg.maxDailyShiftHours !== undefined) setMaxDailyShiftHours(cfg.maxDailyShiftHours);

        if (cfg.companyName) setCompanyName(cfg.companyName);
        if (cfg.headquartersAddress) setHeadquartersAddress(cfg.headquartersAddress);
        if (cfg.dispatchHelpline) setDispatchHelpline(cfg.dispatchHelpline);
        if (cfg.emergencyEmail) setEmergencyEmail(cfg.emergencyEmail);
        if (cfg.currencySymbol) setCurrencySymbol(cfg.currencySymbol);
        if (cfg.timezone) setTimezone(cfg.timezone);
        if (cfg.defaultLanguage) setDefaultLanguage(cfg.defaultLanguage);
      })
      .catch((err) => {
        console.error('Failed to load settings:', err);
      })
      .finally(() => {
        if (isMounted) setLoading(false);
      });

    return () => { isMounted = false; };
  }, []);

  const handleSaveAll = async (e) => {
    e.preventDefault();
    soundEffects.playActionClick();
    setSaving(true);

    const payload = {
      speedThresholdKmH: parseInt(speedThresholdKmH, 10),
      minSustainedSeconds: parseInt(minSustainedSeconds, 10),
      highwayBufferKmH: parseInt(highwayBufferKmH, 10),
      autoDispatchSpeedAlert,
      mandatorySeatbeltSelfie,
      brakingSensitivity,

      defaultArrivalRadiusMeters: parseInt(defaultArrivalRadiusMeters, 10),
      enforceProximityArrival,
      allowManualArrivalOverride,
      mandatoryPodPhoto,
      requireCustomerSignature,
      autoDesignateDepotReturn,

      spotUpiSlaMinutes: parseInt(spotUpiSlaMinutes, 10),
      maxSpotReimbursementInr: parseInt(maxSpotReimbursementInr, 10),
      escalateRcDlSeizure,
      parivahanPortalSync,
      requireVerifiedBankAccount,

      maxContinuousDrivingHours: parseFloat(maxContinuousDrivingHours),
      mandatoryRestMinutes: parseInt(mandatoryRestMinutes, 10),
      nightSpeedAdvisoryKmH: parseInt(nightSpeedAdvisoryKmH, 10),
      maxDailyShiftHours: parseFloat(maxDailyShiftHours),

      companyName,
      headquartersAddress,
      dispatchHelpline,
      emergencyEmail,
      currencySymbol,
      timezone,
      defaultLanguage,
      updatedAt: new Date().toISOString()
    };

    try {
      await api.updateSettings(payload);
      soundEffects.playSuccessChime();
      setSavedMessage('સિસ્ટમ સેટિંગ્સ સફળતાપૂર્વક સાચવવામાં આવી છે (Settings Saved Successfully to MongoDB)');
      setTimeout(() => setSavedMessage(''), 3500);
    } catch (err) {
      console.error('Failed to save settings:', err);
      alert('Error updating system settings: ' + err.message);
    } finally {
      setSaving(false);
    }
  };

  const navItems = [
    { id: 'telematics', label: 'Speed & Telematics', sub: 'ઝડપ નીતિ', icon: ShieldAlert },
    { id: 'geofence', label: 'Geofence & POD Rules', sub: 'જિયોફેન્સ નિયમો', icon: MapPin },
    { id: 'challan', label: 'Challan & Instant UPI', sub: 'ચલણ નીતિ', icon: CreditCard },
    { id: 'safety', label: 'Driver Hours & Rest', sub: 'કાર્ય કલાકો', icon: Clock },
    { id: 'company', label: 'Company & Localization', sub: 'કંપની પ્રોફાઇલ', icon: Building2 },
    { id: 'telemetry', label: 'Database & Audit Status', sub: 'ડેટાબેઝ સ્થિતિ', icon: Database }
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', maxWidth: '1100px', margin: '0 auto' }}>
      
      {/* Top Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '24px', fontWeight: 900, color: 'var(--navy-900)', margin: 0, letterSpacing: '0.02em' }}>
            સિસ્ટમ અને સંચાલન સેટિંગ્સ (System &amp; Organization Settings)
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--slate-500)', marginTop: '4px' }}>
            Enterprise fleet telematics policies, geofence radius standards, challan settlements, and database governance
          </p>
        </div>

        <button
          onClick={handleSaveAll}
          disabled={saving}
          className="btn btn-primary"
          style={{
            padding: '10px 22px',
            fontSize: '13px',
            fontWeight: 800,
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            background: 'var(--navy-900)',
            color: '#ffffff',
            boxShadow: 'var(--shadow-card)'
          }}
        >
          <Save size={16} />
          <span>{saving ? 'સેવિંગ થઈ રહ્યું છે...' : 'બધા સેટિંગ્સ સેવ કરો (Save Configuration)'}</span>
        </button>
      </div>

      {/* Success Notification */}
      {savedMessage && (
        <div style={{
          background: 'var(--status-emerald-light)',
          border: '1px solid rgba(16, 185, 129, 0.4)',
          borderRadius: '12px',
          padding: '14px 18px',
          color: 'var(--status-emerald-text)',
          fontSize: '13px',
          fontWeight: 800,
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          boxShadow: '0 4px 12px rgba(16, 185, 129, 0.15)'
        }}>
          <CheckCircle2 size={20} strokeWidth={2.4} />
          <span>{savedMessage}</span>
        </div>
      )}

      {/* Main Settings Layout: Left Nav Tabs + Right Content Panels */}
      <div style={{ display: 'grid', gridTemplateColumns: '260px 1fr', gap: '20px', alignItems: 'start' }}>
        
        {/* Navigation Sidebar */}
        <div style={{
          background: '#ffffff',
          borderRadius: '16px',
          border: '1px solid var(--slate-200)',
          padding: '12px',
          boxShadow: 'var(--shadow-card)',
          display: 'flex',
          flexDirection: 'column',
          gap: '6px'
        }}>
          {navItems.map((item) => {
            const Icon = item.icon;
            const isSelected = activeTab === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => { soundEffects.playActionClick(); setActiveTab(item.id); }}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px',
                  padding: '12px 14px',
                  borderRadius: '10px',
                  border: isSelected ? '2px solid #0f172a' : '1px solid transparent',
                  background: isSelected ? '#eff6ff' : 'transparent',
                  color: isSelected ? '#0f172a' : 'var(--slate-600)',
                  fontWeight: isSelected ? 800 : 600,
                  fontSize: '13px',
                  textAlign: 'left',
                  cursor: 'pointer',
                  transition: 'all 0.15s ease'
                }}
              >
                <div style={{
                  width: '32px',
                  height: '32px',
                  borderRadius: '8px',
                  background: isSelected ? '#0f172a' : '#f1f5f9',
                  color: isSelected ? '#ffffff' : '#64748b',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center'
                }}>
                  <Icon size={16} />
                </div>
                <div>
                  <div style={{ fontWeight: 800 }}>{item.label}</div>
                  <div style={{ fontSize: '11px', color: isSelected ? '#0284c7' : '#94a3b8' }}>{item.sub}</div>
                </div>
              </button>
            );
          })}
        </div>

        {/* Content Panels Form */}
        <form onSubmit={handleSaveAll} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          
          {/* ========================================================= */}
          {/* 1. SPEED & FLEET TELEMATICS POLICY                        */}
          {/* ========================================================= */}
          {activeTab === 'telematics' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <section style={{
                background: '#ffffff',
                borderRadius: '16px',
                padding: '24px',
                boxShadow: 'var(--shadow-card)',
                border: '1px solid var(--slate-200)'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
                  <ShieldAlert size={20} color="#dc2626" />
                  <h3 style={{ fontSize: '17px', fontWeight: 900, color: 'var(--navy-900)', margin: 0 }}>
                    Fleet Speed Threshold &amp; Over-Speed Policy (ઝડપ નીતિ)
                  </h3>
                </div>
                <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginBottom: '20px' }}>
                  National commercial vehicle safety standards with automated telematics breach escalation.
                </p>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px', marginBottom: '18px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Commercial Speed Limit (km/h)
                    </label>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <input
                        type="range"
                        min="50"
                        max="100"
                        value={speedThresholdKmH}
                        onChange={(e) => setSpeedThresholdKmH(e.target.value)}
                        style={{ flex: 1, accentColor: '#dc2626' }}
                      />
                      <input
                        type="number"
                        min="40"
                        max="120"
                        value={speedThresholdKmH}
                        onChange={(e) => setSpeedThresholdKmH(e.target.value)}
                        className="form-control"
                        style={{ width: '80px', fontWeight: 800, textAlign: 'center' }}
                      />
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '4px' }}>
                      Standard highway limit: 80 km/h
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Minimum Sustained Duration (Seconds)
                    </label>
                    <input
                      type="number"
                      min="5"
                      max="60"
                      value={minSustainedSeconds}
                      onChange={(e) => setMinSustainedSeconds(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 800 }}
                    />
                    <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '4px' }}>
                      Telematics event recorded only after sustained breach
                    </div>
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px', marginBottom: '20px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Highway Overtaking Buffer (+ km/h)
                    </label>
                    <input
                      type="number"
                      min="0"
                      max="25"
                      value={highwayBufferKmH}
                      onChange={(e) => setHighwayBufferKmH(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 800 }}
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Telematics Braking &amp; Cornering Sensitivity
                    </label>
                    <select
                      value={brakingSensitivity}
                      onChange={(e) => setBrakingSensitivity(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 700 }}
                    >
                      <option value="low">Low (Heavy Long-Haul Freight)</option>
                      <option value="medium">Medium (Standard Multi-Axle Trucks)</option>
                      <option value="high">High (Strict Safety Compliance)</option>
                    </select>
                  </div>
                </div>

                {/* Toggles */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', borderTop: '1px solid #f1f5f9', paddingTop: '16px' }}>
                  <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Automated Speed Alert Dispatched to Safety Desk
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                        Immediately generates a pending safety audit record upon breach.
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={autoDispatchSpeedAlert}
                      onChange={(e) => setAutoDispatchSpeedAlert(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: 'var(--navy-900)' }}
                    />
                  </label>

                  <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Mandatory Pre-Trip Seatbelt Selfie &amp; Safe Speed Pledge
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                        Requires driver camera selfie behind wheel wearing seatbelt before trip departure.
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={mandatorySeatbeltSelfie}
                      onChange={(e) => setMandatorySeatbeltSelfie(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: 'var(--navy-900)' }}
                    />
                  </label>
                </div>
              </section>
            </div>
          )}

          {/* ========================================================= */}
          {/* 2. GEOFENCING & DELIVERY PROOF (POD) RULES                */}
          {/* ========================================================= */}
          {activeTab === 'geofence' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <section style={{
                background: '#ffffff',
                borderRadius: '16px',
                padding: '24px',
                boxShadow: 'var(--shadow-card)',
                border: '1px solid var(--slate-200)'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
                  <MapPin size={20} color="#0284c7" />
                  <h3 style={{ fontSize: '17px', fontWeight: 900, color: 'var(--navy-900)', margin: 0 }}>
                    Geofencing &amp; Proof of Delivery (POD) Protocols (જિયોફેન્સ નિયમો)
                  </h3>
                </div>
                <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginBottom: '20px' }}>
                  Arrival detection thresholds and chain-of-custody proof verification rules.
                </p>

                <div style={{ marginBottom: '20px' }}>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                    Default Arrival Detection Geofence Radius (Meters)
                  </label>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <input
                      type="range"
                      min="50"
                      max="500"
                      step="10"
                      value={defaultArrivalRadiusMeters}
                      onChange={(e) => setDefaultArrivalRadiusMeters(e.target.value)}
                      style={{ flex: 1, accentColor: '#0284c7' }}
                    />
                    <div style={{
                      padding: '6px 14px',
                      background: '#eff6ff',
                      color: '#0284c7',
                      borderRadius: '8px',
                      fontWeight: 800,
                      fontSize: '14px',
                      minWidth: '90px',
                      textAlign: 'center'
                    }}>
                      {defaultArrivalRadiusMeters} m
                    </div>
                  </div>
                  <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '4px' }}>
                    Individual locations can also override radius in Locations Manager.
                  </div>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', borderTop: '1px solid #f1f5f9', paddingTop: '16px' }}>
                  <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Enforce GPS Proximity for Stop Arrival
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                        Prevents premature arrival reporting unless driver is physically within the geofence radius.
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={enforceProximityArrival}
                      onChange={(e) => setEnforceProximityArrival(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: 'var(--navy-900)' }}
                    />
                  </label>

                  <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Allow Driver Manual Arrival Override with Mandatory Reason
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                        Allows manual check-in when satellite signal is degraded or parking outside gate.
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={allowManualArrivalOverride}
                      onChange={(e) => setAllowManualArrivalOverride(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: 'var(--navy-900)' }}
                    />
                  </label>

                  <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Mandatory Proof of Delivery Photo (POD) at Unloading Stops
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                        Driver must attach a clear photo of delivered cargo at customer site.
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={mandatoryPodPhoto}
                      onChange={(e) => setMandatoryPodPhoto(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: 'var(--navy-900)' }}
                    />
                  </label>

                  <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Digital Recipient Signature Handover Verification
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                        Requires receiver name and signature before finishing consignment handover.
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={requireCustomerSignature}
                      onChange={(e) => setRequireCustomerSignature(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: 'var(--navy-900)' }}
                    />
                  </label>

                  <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Auto-Designate Depot Return for Damaged or Rejected Units
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                        Automatically schedules return bay stop when damaged units are marked in manifest.
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={autoDesignateDepotReturn}
                      onChange={(e) => setAutoDesignateDepotReturn(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: 'var(--navy-900)' }}
                    />
                  </label>
                </div>
              </section>
            </div>
          )}

          {/* ========================================================= */}
          {/* 3. CHALLAN & INSTANT DRIVER UPI SETTLEMENT POLICY         */}
          {/* ========================================================= */}
          {activeTab === 'challan' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <section style={{
                background: '#ffffff',
                borderRadius: '16px',
                padding: '24px',
                boxShadow: 'var(--shadow-card)',
                border: '1px solid var(--slate-200)'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
                  <CreditCard size={20} color="#0f766e" />
                  <h3 style={{ fontSize: '17px', fontWeight: 900, color: 'var(--navy-900)', margin: 0 }}>
                    Challan Settlement &amp; Driver UPI Cash Reimbursement (ચલણ અને વળતર નીતિ)
                  </h3>
                </div>
                <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginBottom: '20px' }}>
                  Rules governing spot cash payments, Parivahan e-Challan portal settlement, and instant driver UPI reimbursement.
                </p>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px', marginBottom: '18px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Spot Cash Reimbursement SLA (Minutes)
                    </label>
                    <input
                      type="number"
                      min="5"
                      max="60"
                      value={spotUpiSlaMinutes}
                      onChange={(e) => setSpotUpiSlaMinutes(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 800 }}
                    />
                    <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '4px' }}>
                      Target reimbursement to driver bank account after slip upload (Default: 15 mins)
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Maximum Instant Spot Cash Limit (₹ INR)
                    </label>
                    <input
                      type="number"
                      step="500"
                      value={maxSpotReimbursementInr}
                      onChange={(e) => setMaxSpotReimbursementInr(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 800 }}
                    />
                    <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '4px' }}>
                      Demands exceeding this threshold require General Manager telephonic authorization
                    </div>
                  </div>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', borderTop: '1px solid #f1f5f9', paddingTop: '16px' }}>
                  <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Immediate Escalation on Vehicle RC / Driving License Seizure
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                        Alerts Regional Transport Operations Head with high-priority audio chime and SMS alert.
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={escalateRcDlSeizure}
                      onChange={(e) => setEscalateRcDlSeizure(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: 'var(--navy-900)' }}
                    />
                  </label>

                  <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        National Parivahan Portal e-Challan Gateway Integration
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                        Permits central finance desk to settle online notices directly using virtual court portal.
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={parivahanPortalSync}
                      onChange={(e) => setParivahanPortalSync(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: 'var(--navy-900)' }}
                    />
                  </label>

                  <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', cursor: 'pointer' }}>
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Mandatory Linked Bank Account for Cash Settlement
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                        Requires a separately configured and verified reimbursement account before payments can be processed.
                      </div>
                    </div>
                    <input
                      type="checkbox"
                      checked={requireVerifiedBankAccount}
                      onChange={(e) => setRequireVerifiedBankAccount(e.target.checked)}
                      style={{ width: '18px', height: '18px', accentColor: 'var(--navy-900)' }}
                    />
                  </label>
                </div>
              </section>
            </div>
          )}

          {/* ========================================================= */}
          {/* 4. DRIVER WORKING HOURS & SAFETY REGULATIONS              */}
          {/* ========================================================= */}
          {activeTab === 'safety' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <section style={{
                background: '#ffffff',
                borderRadius: '16px',
                padding: '24px',
                boxShadow: 'var(--shadow-card)',
                border: '1px solid var(--slate-200)'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
                  <Clock size={20} color="#7c3aed" />
                  <h3 style={{ fontSize: '17px', fontWeight: 900, color: 'var(--navy-900)', margin: 0 }}>
                    Working Hours, Rest Intervals &amp; Night Safety (કાર્ય કલાકો અને આરામ નીતિ)
                  </h3>
                </div>
                <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginBottom: '20px' }}>
                  Commercial driver fatigue management policies complying with national logistics guidelines.
                </p>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px', marginBottom: '18px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Maximum Continuous Driving Hours
                    </label>
                    <input
                      type="number"
                      step="0.5"
                      min="2"
                      max="8"
                      value={maxContinuousDrivingHours}
                      onChange={(e) => setMaxContinuousDrivingHours(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 800 }}
                    />
                    <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '4px' }}>
                      Driver receives rest break alert after 4.5 hours continuous transit
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Mandatory Rest Break Duration (Minutes)
                    </label>
                    <input
                      type="number"
                      min="15"
                      max="90"
                      value={mandatoryRestMinutes}
                      onChange={(e) => setMandatoryRestMinutes(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 800 }}
                    />
                    <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '4px' }}>
                      Standard mandatory break: 30 minutes
                    </div>
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Night Driving Speed Advisory (km/h)
                    </label>
                    <input
                      type="number"
                      min="40"
                      max="80"
                      value={nightSpeedAdvisoryKmH}
                      onChange={(e) => setNightSpeedAdvisoryKmH(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 800 }}
                    />
                    <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '4px' }}>
                      Reduced advisory limit active between 11:00 PM and 05:00 AM
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Maximum Daily Shift Working Hours
                    </label>
                    <input
                      type="number"
                      step="0.5"
                      min="6"
                      max="14"
                      value={maxDailyShiftHours}
                      onChange={(e) => setMaxDailyShiftHours(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 800 }}
                    />
                    <div style={{ fontSize: '11px', color: 'var(--slate-400)', marginTop: '4px' }}>
                      Maximum daily on-duty shift ceiling before mandatory 8h off-duty
                    </div>
                  </div>
                </div>
              </section>
            </div>
          )}

          {/* ========================================================= */}
          {/* 5. COMPANY PROFILE & LOCALIZATION                         */}
          {/* ========================================================= */}
          {activeTab === 'company' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <section style={{
                background: '#ffffff',
                borderRadius: '16px',
                padding: '24px',
                boxShadow: 'var(--shadow-card)',
                border: '1px solid var(--slate-200)'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
                  <Building2 size={20} color="#0f172a" />
                  <h3 style={{ fontSize: '17px', fontWeight: 900, color: 'var(--navy-900)', margin: 0 }}>
                    Logistics Operating Entity &amp; Contact Desk (કંપની પ્રોફાઇલ)
                  </h3>
                </div>
                <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginBottom: '20px' }}>
                  Public identity, emergency helpline numbers, and regional display localization.
                </p>

                <div style={{ marginBottom: '14px' }}>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                    Company / Organization Name
                  </label>
                  <input
                    type="text"
                    value={companyName}
                    onChange={(e) => setCompanyName(e.target.value)}
                    className="form-control"
                    style={{ fontWeight: 800 }}
                  />
                </div>

                <div style={{ marginBottom: '14px' }}>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                    Central Headquarters &amp; Operations Hub Address
                  </label>
                  <input
                    type="text"
                    value={headquartersAddress}
                    onChange={(e) => setHeadquartersAddress(e.target.value)}
                    className="form-control"
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px', marginBottom: '18px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      24x7 Central Dispatch Helpline
                    </label>
                    <input
                      type="text"
                      value={dispatchHelpline}
                      onChange={(e) => setDispatchHelpline(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 700 }}
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Emergency Operations Email
                    </label>
                    <input
                      type="email"
                      value={emergencyEmail}
                      onChange={(e) => setEmergencyEmail(e.target.value)}
                      className="form-control"
                      style={{ fontWeight: 700 }}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Operational Timezone
                    </label>
                    <div style={{
                      background: '#f8fafc',
                      padding: '10px 14px',
                      borderRadius: '8px',
                      border: '1px solid #e2e8f0',
                      fontSize: '13px',
                      fontWeight: 700,
                      color: '#0f172a'
                    }}>
                      {timezone}
                    </div>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 800, color: 'var(--navy-800)', marginBottom: '6px' }}>
                      Accounting Currency Standard
                    </label>
                    <div style={{
                      background: '#f8fafc',
                      padding: '10px 14px',
                      borderRadius: '8px',
                      border: '1px solid #e2e8f0',
                      fontSize: '13px',
                      fontWeight: 700,
                      color: '#0f172a'
                    }}>
                      {currencySymbol}
                    </div>
                  </div>
                </div>
              </section>
            </div>
          )}

          {/* ========================================================= */}
          {/* 6. DATABASE & AUDIT TELEMETRY STATUS                      */}
          {/* ========================================================= */}
          {activeTab === 'telemetry' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <section style={{
                background: '#ffffff',
                borderRadius: '16px',
                padding: '24px',
                boxShadow: 'var(--shadow-card)',
                border: '1px solid var(--slate-200)'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
                  <Database size={20} color="#0284c7" />
                  <h3 style={{ fontSize: '17px', fontWeight: 900, color: 'var(--navy-900)', margin: 0 }}>
                    Persistent Storage Engine &amp; Audit Telemetry (ડેટાબેઝ સ્થિતિ)
                  </h3>
                </div>
                <p style={{ fontSize: '12px', color: 'var(--slate-500)', marginBottom: '20px' }}>
                  Production database health, storage engine verification, and offline data synchronization integrity.
                </p>

                <div style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(3, 1fr)',
                  gap: '14px',
                  marginBottom: '20px'
                }}>
                  <div style={{ background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '10px', padding: '14px' }}>
                    <div style={{ fontSize: '11px', color: '#166534', fontWeight: 800, textTransform: 'uppercase' }}>
                      Database Engine
                    </div>
                    <div style={{ fontSize: '16px', fontWeight: 900, color: '#14532d', marginTop: '4px' }}>
                      MongoDB Persistent
                    </div>
                    <div style={{ fontSize: '11px', color: '#15803d', marginTop: '2px', fontFamily: 'var(--font-mono)' }}>
                      Port 27017 • Real Persistence
                    </div>
                  </div>

                  <div style={{ background: '#eff6ff', border: '1px solid #bfdbfe', borderRadius: '10px', padding: '14px' }}>
                    <div style={{ fontSize: '11px', color: '#1e40af', fontWeight: 800, textTransform: 'uppercase' }}>
                      Sync Strategy
                    </div>
                    <div style={{ fontSize: '16px', fontWeight: 900, color: '#1e3a8a', marginTop: '4px' }}>
                      Zero Data-Loss Queue
                    </div>
                    <div style={{ fontSize: '11px', color: '#2563eb', marginTop: '2px' }}>
                      Automatic Offline Flush
                    </div>
                  </div>

                  <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '10px', padding: '14px' }}>
                    <div style={{ fontSize: '11px', color: '#475569', fontWeight: 800, textTransform: 'uppercase' }}>
                      Design Standard
                    </div>
                    <div style={{ fontSize: '16px', fontWeight: 900, color: '#0f172a', marginTop: '4px' }}>
                      Zero Emoji Compliance
                    </div>
                    <div style={{ fontSize: '11px', color: '#64748b', marginTop: '2px' }}>
                      Lucide Vector Icons Only
                    </div>
                  </div>
                </div>

                <div style={{
                  background: 'var(--slate-50)',
                  border: '1px solid var(--slate-200)',
                  borderRadius: '10px',
                  padding: '14px',
                  fontSize: '12px',
                  color: 'var(--slate-600)',
                  lineHeight: 1.6
                }}>
                  <div style={{ fontWeight: 800, color: 'var(--navy-900)', marginBottom: '4px' }}>
                    Active MongoDB Collections:
                  </div>
                  <code>trips</code>, <code>drivers</code>, <code>vehicles</code>, <code>locations</code>, <code>products</code>, <code>users</code>, <code>safetyEvents</code>, <code>deliveryProofs</code>, <code>settings</code>
                </div>
              </section>
            </div>
          )}

          {/* Bottom Action Footer */}
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
            <button
              type="submit"
              disabled={saving}
              className="btn btn-primary"
              style={{
                padding: '12px 28px',
                fontSize: '14px',
                fontWeight: 800,
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                background: 'var(--navy-900)',
                color: '#ffffff'
              }}
            >
              <Save size={16} />
              <span>{saving ? 'સેવિંગ...' : 'સેટિંગ્સ સેવ કરો (Save Settings)'}</span>
            </button>
          </div>

        </form>

      </div>
    </div>
  );
}
