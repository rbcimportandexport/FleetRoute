import React, { useState, useRef, useEffect } from 'react';
import { 
  X, 
  Clock, 
  Fuel, 
  Wrench, 
  AlertTriangle, 
  Coffee, 
  Car, 
  Timer, 
  CheckCircle2,
  FileText,
  Camera,
  RotateCcw,
  Truck,
  AlertOctagon,
  HeartPulse,
  Shield,
  Scale,
  CreditCard,
  Plus
} from 'lucide-react';
import { soundEffects } from '../../utils/soundEffects';

export default function DelayModal({ 
  isOpen, 
  onClose, 
  tripId, 
  driver, 
  initialTab = 'breakdown', 
  onSaveActivity 
}) {
  const [activeTab, setActiveTab] = useState(initialTab);

  // Sync initial tab when modal opens
  useEffect(() => {
    if (isOpen && initialTab) {
      setActiveTab(initialTab);
    }
  }, [isOpen, initialTab]);

  // ==========================================
  // BREAKDOWN & INCIDENT STATE (Images 1 & 2)
  // ==========================================
  const [breakdownCategory, setBreakdownCategory] = useState('engine');
  const [incidentPhotos, setIncidentPhotos] = useState([]);
  const [breakdownNotes, setBreakdownNotes] = useState('');
  const photoInputRef = useRef(null);

  // ==========================================
  // POLICE / RTO CHALLAN STATE (Images 3, 4, 5)
  // ==========================================
  const [authority, setAuthority] = useState('traffic_police');
  const [stoppageReason, setStoppageReason] = useState('overload');
  const [challanNumber, setChallanNumber] = useState('');
  const [penaltyAmount, setPenaltyAmount] = useState('');
  const [challanSlipPhoto, setChallanSlipPhoto] = useState(null);
  const [weighmentSlipPhoto, setWeighmentSlipPhoto] = useState(null);
  const [settlementOption, setSettlementOption] = useState('cash_spot');

  const challanInputRef = useRef(null);
  const weighmentInputRef = useRef(null);

  // ==========================================
  // REFUELING & GENERAL DELAY STATE
  // ==========================================
  const [fuelLiters, setFuelLiters] = useState('');
  const [fuelCost, setFuelCost] = useState('');
  const [odometer, setOdometer] = useState('');
  const [fuelStation, setFuelStation] = useState('');
  const [delayDuration, setDelayDuration] = useState('20');
  const [delayNotes, setDelayNotes] = useState('');

  if (!isOpen) return null;

  const driverAccountLabel = driver?.name
    ? `Reimbursement account not configured for ${driver.name}`
    : 'Reimbursement account not configured';

  const handleAddIncidentPhoto = (e) => {
    const file = e.target.files?.[0];
    if (!file || incidentPhotos.length >= 3) return;

    const reader = new FileReader();
    reader.onload = () => {
      setIncidentPhotos((prev) => [...prev, reader.result]);
      soundEffects.playSuccessChime();
    };
    reader.readAsDataURL(file);
  };

  const handleQuickAddAmount = (addValue) => {
    soundEffects.playActionClick();
    const current = parseInt(penaltyAmount, 10) || 0;
    setPenaltyAmount(String(current + addValue));
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    soundEffects.playActionClick();

    let payload = {};

    if (activeTab === 'breakdown') {
      payload = {
        category: 'breakdown',
        notes: breakdownNotes || `Reported breakdown: ${breakdownCategory}`,
        durationMinutes: 45,
        details: {
          breakdownCategory,
          photosCount: incidentPhotos.length,
          photos: incidentPhotos,
          voiceNote: null
        }
      };
    } else if (activeTab === 'challan') {
      payload = {
        category: 'challan_stoppage',
        notes: `Authority Stoppage: ${authority} - Challan ${challanNumber} (₹${penaltyAmount})`,
        durationMinutes: 30,
        details: {
          authority,
          stoppageReason,
          challanNumber,
          penaltyAmount: parseInt(penaltyAmount, 10) || 0,
          challanSlipAttached: Boolean(challanSlipPhoto),
          weighmentSlipAttached: Boolean(weighmentSlipPhoto),
          settlementOption,
          reimbursementAccount: null
        }
      };
    } else if (activeTab === 'refueling') {
      payload = {
        category: 'refueling',
        notes: `Refueled ${fuelLiters}L at ${fuelStation}`,
        durationMinutes: 15,
        details: {
          fuelLiters: parseFloat(fuelLiters) || 0,
          fuelCost: parseFloat(fuelCost) || 0,
          odometer: parseInt(odometer, 10) || 0,
          fuelStation
        }
      };
    } else {
      payload = {
        category: 'traffic',
        notes: delayNotes || `Traffic delay reported (${delayDuration} mins)`,
        durationMinutes: parseInt(delayDuration, 10) || 20,
        details: {
          delayReason: delayNotes
        }
      };
    }

    if (onSaveActivity) {
      onSaveActivity(payload);
    }

    soundEffects.playSuccessChime();
    onClose();
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'rgba(15, 23, 42, 0.75)',
      backdropFilter: 'blur(5px)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 2000,
      padding: '16px'
    }}>
      {/* Hidden File Inputs */}
      <input
        type="file"
        accept="image/*"
        capture="environment"
        ref={photoInputRef}
        style={{ display: 'none' }}
        onChange={handleAddIncidentPhoto}
      />
      <input
        type="file"
        accept="image/*"
        capture="environment"
        ref={challanInputRef}
        style={{ display: 'none' }}
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) {
            const r = new FileReader();
            r.onload = () => setChallanSlipPhoto(r.result);
            r.readAsDataURL(f);
          }
        }}
      />
      <input
        type="file"
        accept="image/*"
        capture="environment"
        ref={weighmentInputRef}
        style={{ display: 'none' }}
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) {
            const r = new FileReader();
            r.onload = () => setWeighmentSlipPhoto(r.result);
            r.readAsDataURL(f);
          }
        }}
      />

      <div style={{
        background: '#ffffff',
        borderRadius: '16px',
        width: '100%',
        maxWidth: '560px',
        maxHeight: '92vh',
        overflowY: 'auto',
        boxShadow: '0 25px 50px -12px rgba(15, 23, 42, 0.35)',
        border: '1px solid var(--slate-200)',
        display: 'flex',
        flexDirection: 'column'
      }}>
        
        {/* Modal Top Bar */}
        <div style={{
          padding: '16px 20px',
          borderBottom: '1px solid var(--slate-200)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          background: '#ffffff',
          position: 'sticky',
          top: 0,
          zIndex: 10
        }}>
          <div>
            <h2 style={{ fontSize: '17px', fontWeight: 900, color: 'var(--navy-900)', margin: 0, letterSpacing: '0.02em' }}>
              ડ્રાઇવર સહાયતા અને ઘટના રિપોર્ટ (Operational Assist)
            </h2>
            <p style={{ fontSize: '11px', color: 'var(--slate-500)', margin: '2px 0 0 0' }}>
              Atomic event logging with dispatch sync &amp; legal audit evidence
            </p>
          </div>
          <button
            onClick={onClose}
            style={{
              background: 'transparent',
              border: 'none',
              cursor: 'pointer',
              color: 'var(--slate-400)',
              padding: '6px',
              borderRadius: '6px'
            }}
          >
            <X size={20} />
          </button>
        </div>

        {/* 4 Mode Navigation Tabs */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(4, 1fr)',
          borderBottom: '1px solid var(--slate-200)',
          background: '#f8fafc'
        }}>
          <button
            type="button"
            onClick={() => setActiveTab('breakdown')}
            style={{
              padding: '12px 6px',
              border: 'none',
              background: activeTab === 'breakdown' ? '#ffffff' : 'transparent',
              borderBottom: activeTab === 'breakdown' ? '3px solid #dc2626' : '3px solid transparent',
              color: activeTab === 'breakdown' ? '#dc2626' : 'var(--slate-600)',
              fontWeight: 800,
              fontSize: '11px',
              cursor: 'pointer',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '4px'
            }}
          >
            <AlertTriangle size={16} />
            <span>ખામી / Breakdown</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('challan')}
            style={{
              padding: '12px 6px',
              border: 'none',
              background: activeTab === 'challan' ? '#ffffff' : 'transparent',
              borderBottom: activeTab === 'challan' ? '3px solid #0f172a' : '3px solid transparent',
              color: activeTab === 'challan' ? '#0f172a' : 'var(--slate-600)',
              fontWeight: 800,
              fontSize: '11px',
              cursor: 'pointer',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '4px'
            }}
          >
            <Shield size={16} />
            <span>ચલણ / Police RTO</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('refueling')}
            style={{
              padding: '12px 6px',
              border: 'none',
              background: activeTab === 'refueling' ? '#ffffff' : 'transparent',
              borderBottom: activeTab === 'refueling' ? '3px solid #d97706' : '3px solid transparent',
              color: activeTab === 'refueling' ? '#d97706' : 'var(--slate-600)',
              fontWeight: 800,
              fontSize: '11px',
              cursor: 'pointer',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '4px'
            }}
          >
            <Fuel size={16} />
            <span>ઈંધણ / Fuel Log</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('traffic')}
            style={{
              padding: '12px 6px',
              border: 'none',
              background: activeTab === 'traffic' ? '#ffffff' : 'transparent',
              borderBottom: activeTab === 'traffic' ? '3px solid #0284c7' : '3px solid transparent',
              color: activeTab === 'traffic' ? '#0284c7' : 'var(--slate-600)',
              fontWeight: 800,
              fontSize: '11px',
              cursor: 'pointer',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '4px'
            }}
          >
            <Clock size={16} />
            <span>વિલંબ / Delay</span>
          </button>
        </div>

        {/* Modal Form Body */}
        <form onSubmit={handleSubmit} style={{ padding: '20px' }}>
          
          {/* ========================================================= */}
          {/* TAB 1: BREAKDOWN & INCIDENT REPORTING (IMAGES 1 & 2)      */}
          {/* ========================================================= */}
          {activeTab === 'breakdown' && (
            <div>
              {/* IMAGE 2: SELECT BREAKDOWN CATEGORY (2x3 GRID) */}
              <div style={{ marginBottom: '20px' }}>
                <h3 style={{
                  fontSize: '14px',
                  fontWeight: 900,
                  letterSpacing: '0.04em',
                  color: 'var(--navy-900)',
                  margin: '0 0 12px 0',
                  textTransform: 'uppercase'
                }}>
                  SELECT BREAKDOWN CATEGORY
                </h3>

                <div style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr 1fr',
                  gap: '12px'
                }}>
                  {/* Option 1: Engine / Mechanical */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setBreakdownCategory('engine'); }}
                    style={{
                      background: breakdownCategory === 'engine' ? '#eff6ff' : '#ffffff',
                      border: breakdownCategory === 'engine' ? '2px solid #0f172a' : '1px solid #cbd5e1',
                      borderRadius: '10px',
                      padding: '14px',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between',
                      minHeight: '84px'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <Wrench size={22} color="#0f172a" strokeWidth={2.4} />
                      <div style={{
                        width: '18px',
                        height: '18px',
                        borderRadius: '50%',
                        border: breakdownCategory === 'engine' ? '2px solid #0f172a' : '1.5px solid #94a3b8',
                        background: breakdownCategory === 'engine' ? '#0f172a' : 'transparent',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                      }}>
                        {breakdownCategory === 'engine' && (
                          <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#ffffff' }} />
                        )}
                      </div>
                    </div>
                    <div style={{ marginTop: '8px' }}>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Engine / Mechanical Failure
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-600)', marginTop: '2px', fontWeight: 600 }}>
                        એન્જિન / યાંત્રિક ખામી
                      </div>
                    </div>
                  </div>

                  {/* Option 2: Puncture / Tyre Burst */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setBreakdownCategory('puncture'); }}
                    style={{
                      background: breakdownCategory === 'puncture' ? '#eff6ff' : '#ffffff',
                      border: breakdownCategory === 'puncture' ? '2px solid #0f172a' : '1px solid #cbd5e1',
                      borderRadius: '10px',
                      padding: '14px',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between',
                      minHeight: '84px'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <RotateCcw size={22} color="#0f172a" strokeWidth={2.4} />
                      <div style={{
                        width: '18px',
                        height: '18px',
                        borderRadius: '50%',
                        border: breakdownCategory === 'puncture' ? '2px solid #0f172a' : '1.5px solid #94a3b8',
                        background: breakdownCategory === 'puncture' ? '#0f172a' : 'transparent',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                      }}>
                        {breakdownCategory === 'puncture' && (
                          <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#ffffff' }} />
                        )}
                      </div>
                    </div>
                    <div style={{ marginTop: '8px' }}>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Puncture / Tyre Burst
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-600)', marginTop: '2px', fontWeight: 600 }}>
                        ટાયર પંચર / બર્સ્ટ
                      </div>
                    </div>
                  </div>

                  {/* Option 3: Accident / Collision */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setBreakdownCategory('accident'); }}
                    style={{
                      background: breakdownCategory === 'accident' ? '#eff6ff' : '#ffffff',
                      border: breakdownCategory === 'accident' ? '2px solid #0f172a' : '1px solid #cbd5e1',
                      borderRadius: '10px',
                      padding: '14px',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between',
                      minHeight: '84px'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <Truck size={22} color="#dc2626" strokeWidth={2.4} />
                      <div style={{
                        width: '18px',
                        height: '18px',
                        borderRadius: '50%',
                        border: breakdownCategory === 'accident' ? '2px solid #0f172a' : '1.5px solid #94a3b8',
                        background: breakdownCategory === 'accident' ? '#0f172a' : 'transparent',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                      }}>
                        {breakdownCategory === 'accident' && (
                          <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#ffffff' }} />
                        )}
                      </div>
                    </div>
                    <div style={{ marginTop: '8px' }}>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Accident / Collision
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-600)', marginTop: '2px', fontWeight: 600 }}>
                        અકસ્માત / ટક્કર
                      </div>
                    </div>
                  </div>

                  {/* Option 4: Brake / Air Leakage */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setBreakdownCategory('brake'); }}
                    style={{
                      background: breakdownCategory === 'brake' ? '#eff6ff' : '#ffffff',
                      border: breakdownCategory === 'brake' ? '2px solid #0f172a' : '1px solid #cbd5e1',
                      borderRadius: '10px',
                      padding: '14px',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between',
                      minHeight: '84px'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <AlertOctagon size={22} color="#0f172a" strokeWidth={2.4} />
                      <div style={{
                        width: '18px',
                        height: '18px',
                        borderRadius: '50%',
                        border: breakdownCategory === 'brake' ? '2px solid #0f172a' : '1.5px solid #94a3b8',
                        background: breakdownCategory === 'brake' ? '#0f172a' : 'transparent',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                      }}>
                        {breakdownCategory === 'brake' && (
                          <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#ffffff' }} />
                        )}
                      </div>
                    </div>
                    <div style={{ marginTop: '8px' }}>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Brake / Air Leakage
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-600)', marginTop: '2px', fontWeight: 600 }}>
                        બ્રેક લીકેજ / એર ફોલ્ટ
                      </div>
                    </div>
                  </div>

                  {/* Option 5: Medical Emergency */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setBreakdownCategory('medical'); }}
                    style={{
                      background: breakdownCategory === 'medical' ? '#eff6ff' : '#ffffff',
                      border: breakdownCategory === 'medical' ? '2px solid #0f172a' : '1px solid #cbd5e1',
                      borderRadius: '10px',
                      padding: '14px',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between',
                      minHeight: '84px'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <HeartPulse size={22} color="#dc2626" strokeWidth={2.4} />
                      <div style={{
                        width: '18px',
                        height: '18px',
                        borderRadius: '50%',
                        border: breakdownCategory === 'medical' ? '2px solid #0f172a' : '1.5px solid #94a3b8',
                        background: breakdownCategory === 'medical' ? '#0f172a' : 'transparent',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                      }}>
                        {breakdownCategory === 'medical' && (
                          <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#ffffff' }} />
                        )}
                      </div>
                    </div>
                    <div style={{ marginTop: '8px' }}>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Medical Emergency
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-600)', marginTop: '2px', fontWeight: 600 }}>
                        તબીબી કટોકટી
                      </div>
                    </div>
                  </div>

                  {/* Option 6: Police / Robbery Issue */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setBreakdownCategory('police'); }}
                    style={{
                      background: breakdownCategory === 'police' ? '#eff6ff' : '#ffffff',
                      border: breakdownCategory === 'police' ? '2px solid #0f172a' : '1px solid #cbd5e1',
                      borderRadius: '10px',
                      padding: '14px',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'space-between',
                      minHeight: '84px'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <Shield size={22} color="#0f172a" strokeWidth={2.4} />
                      <div style={{
                        width: '18px',
                        height: '18px',
                        borderRadius: '50%',
                        border: breakdownCategory === 'police' ? '2px solid #0f172a' : '1.5px solid #94a3b8',
                        background: breakdownCategory === 'police' ? '#0f172a' : 'transparent',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                      }}>
                        {breakdownCategory === 'police' && (
                          <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#ffffff' }} />
                        )}
                      </div>
                    </div>
                    <div style={{ marginTop: '8px' }}>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                        Police / Robbery Issue
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--slate-600)', marginTop: '2px', fontWeight: 600 }}>
                        પોલીસ / સુરક્ષા પ્રશ્ન
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* IMAGE 1: INCIDENT EVIDENCE & VOICE NOTE */}
              <div style={{
                background: '#ffffff',
                border: '1px solid #e2e8f0',
                borderRadius: '14px',
                padding: '16px',
                marginBottom: '20px'
              }}>
                <h3 style={{
                  fontSize: '15px',
                  fontWeight: 900,
                  letterSpacing: '0.04em',
                  color: 'var(--navy-900)',
                  margin: '0 0 14px 0',
                  textTransform: 'uppercase'
                }}>
                  INCIDENT EVIDENCE &amp; VOICE NOTE
                </h3>

                <div style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr 1fr',
                  gap: '14px'
                }}>
                  {/* Left Card: Capture Breakdown / Damage Photo */}
                  <div
                    onClick={() => photoInputRef.current?.click()}
                    style={{
                      border: '2px dashed #94a3b8',
                      borderRadius: '12px',
                      background: '#f8fafc',
                      padding: '16px 12px',
                      textAlign: 'center',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      justifyContent: 'center',
                      minHeight: '120px'
                    }}
                  >
                    <Camera size={28} strokeWidth={2} color="#0f172a" style={{ marginBottom: '8px' }} />
                    <div style={{ fontSize: '13px', fontWeight: 800, color: '#0f172a', lineHeight: 1.3 }}>
                      Capture Breakdown / Damage Photo
                    </div>
                    <div style={{
                      fontSize: '11px',
                      fontWeight: 700,
                      color: '#64748b',
                      marginTop: '6px',
                      fontFamily: 'var(--font-mono)'
                    }}>
                      {incidentPhotos.length}/3 ATTACHED
                    </div>
                  </div>

                  {/* Right Card: Voice Note Recorded (Matching Image 1) */}
                  <div
                    style={{
                      border: '2px solid #0f172a',
                      borderRadius: '12px',
                      background: '#eff6ff',
                      padding: '16px 12px',
                      textAlign: 'center',
                      cursor: 'not-allowed',
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      justifyContent: 'center',
                      minHeight: '120px'
                    }}
                  >
                    <div style={{ fontSize: '13px', fontWeight: 800, color: '#0f172a', lineHeight: 1.3 }}>
                      Voice capture unavailable
                    </div>
                    
                    {/* Badge: 12s SAVED (બોલો) */}
                    <div style={{
                      background: '#000000',
                      color: '#ffffff',
                      borderRadius: '6px',
                      padding: '4px 10px',
                      fontSize: '12px',
                      fontWeight: 900,
                      letterSpacing: '0.04em',
                      marginTop: '8px',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px'
                    }}>
                      NOT CONFIGURED
                    </div>
                  </div>
                </div>

                {/* Photo Previews List (if any attached) */}
                {incidentPhotos.length > 0 && (
                  <div style={{ marginTop: '12px', display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    {incidentPhotos.map((img, idx) => (
                      <div key={idx} style={{ position: 'relative', width: '56px', height: '56px', borderRadius: '8px', overflow: 'hidden', border: '1px solid #cbd5e1' }}>
                        <img src={img} alt={`Proof ${idx + 1}`} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            setIncidentPhotos(prev => prev.filter((_, i) => i !== idx));
                          }}
                          style={{
                            position: 'absolute',
                            top: 2,
                            right: 2,
                            background: 'rgba(0,0,0,0.7)',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '50%',
                            width: '18px',
                            height: '18px',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            cursor: 'pointer'
                          }}
                        >
                          <X size={12} />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Additional Incident Notes */}
              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: 'var(--navy-900)', marginBottom: '6px' }}>
                  વિગતવાર વર્ણન (Operational Incident Notes)
                </label>
                <textarea
                  value={breakdownNotes}
                  onChange={(e) => setBreakdownNotes(e.target.value)}
                  placeholder="વધારાની વિગતો લખો: વ્હીલ બદલવું જરૂરી છે, વર્કશોપ સહાયતા જોઈતી છે..."
                  rows={2}
                  className="form-control"
                  style={{ width: '100%', fontSize: '13px' }}
                />
              </div>
            </div>
          )}

          {/* ========================================================= */}
          {/* TAB 2: POLICE / RTO CHALLAN & STOPPAGE (IMAGES 3, 4, 5)   */}
          {/* ========================================================= */}
          {activeTab === 'challan' && (
            <div>
              {/* IMAGE 4: AUTHORITY SELECTOR */}
              <div style={{ marginBottom: '16px' }}>
                <div style={{
                  fontSize: '11px',
                  fontWeight: 800,
                  color: 'var(--slate-500)',
                  marginBottom: '6px',
                  textTransform: 'uppercase'
                }}>
                  ચકાસણી ઓથોરિટી / ENFORCEMENT AUTHORITY
                </div>

                <div style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr 1fr',
                  gap: '8px'
                }}>
                  {/* Traffic Police */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setAuthority('traffic_police'); }}
                    style={{
                      background: authority === 'traffic_police' ? '#0f172a' : '#ffffff',
                      color: authority === 'traffic_police' ? '#ffffff' : '#0f172a',
                      border: '1px solid #cbd5e1',
                      borderRadius: '8px',
                      padding: '10px 12px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      fontWeight: 800,
                      fontSize: '13px'
                    }}
                  >
                    <span>Traffic Police</span>
                    <Shield size={18} color={authority === 'traffic_police' ? '#ffffff' : '#0f172a'} />
                  </div>

                  {/* RTO Transport Dept */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setAuthority('rto'); }}
                    style={{
                      background: authority === 'rto' ? '#0f172a' : '#ffffff',
                      color: authority === 'rto' ? '#ffffff' : '#0f172a',
                      border: '1px solid #cbd5e1',
                      borderRadius: '8px',
                      padding: '10px 12px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      fontWeight: 800,
                      fontSize: '13px'
                    }}
                  >
                    <span>RTO Transport Dept</span>
                    <Truck size={18} color={authority === 'rto' ? '#ffffff' : '#0f172a'} />
                  </div>

                  {/* NHAI Weighbridge */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setAuthority('nhai'); }}
                    style={{
                      background: authority === 'nhai' ? '#0f172a' : '#ffffff',
                      color: authority === 'nhai' ? '#ffffff' : '#0f172a',
                      border: '1px solid #cbd5e1',
                      borderRadius: '8px',
                      padding: '10px 12px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      fontWeight: 800,
                      fontSize: '13px'
                    }}
                  >
                    <span>NHAI Weighbridge</span>
                    <Scale size={18} color={authority === 'nhai' ? '#ffffff' : '#0f172a'} />
                  </div>

                  {/* Mining / State Check */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setAuthority('mining'); }}
                    style={{
                      background: authority === 'mining' ? '#0f172a' : '#ffffff',
                      color: authority === 'mining' ? '#ffffff' : '#0f172a',
                      border: '1px solid #cbd5e1',
                      borderRadius: '8px',
                      padding: '10px 12px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      fontWeight: 800,
                      fontSize: '13px'
                    }}
                  >
                    <span>Mining / State Check</span>
                    <CheckCircle2 size={18} color={authority === 'mining' ? '#ffffff' : '#0f172a'} />
                  </div>
                </div>
              </div>

              {/* IMAGE 5: NATURE OF STOPPAGE / દંડ નું કારણ */}
              <div style={{ marginBottom: '16px' }}>
                <div style={{
                  fontSize: '11px',
                  fontWeight: 900,
                  letterSpacing: '0.04em',
                  color: 'var(--navy-900)',
                  marginBottom: '8px',
                  textTransform: 'uppercase'
                }}>
                  NATURE OF STOPPAGE / દંડ નું કારણ
                </div>

                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                  {[
                    { id: 'overload', label: 'Overload / Weight Defect' },
                    { id: 'no_entry', label: 'No Entry Window' },
                    { id: 'eway_bill', label: 'E-Way Bill / Permit Query' },
                    { id: 'hazard_sign', label: 'Tyre / Tarpaulin / Hazard Sign' },
                    { id: 'puc_speed', label: 'PUC / Speed Governor Check' }
                  ].map((item) => (
                    <button
                      key={item.id}
                      type="button"
                      onClick={() => { soundEffects.playActionClick(); setStoppageReason(item.id); }}
                      style={{
                        padding: '6px 12px',
                        borderRadius: '6px',
                        fontSize: '12px',
                        fontWeight: stoppageReason === item.id ? 800 : 600,
                        border: stoppageReason === item.id ? '2px solid #0f172a' : '1px solid #cbd5e1',
                        background: '#ffffff',
                        color: stoppageReason === item.id ? '#0f172a' : '#475569',
                        cursor: 'pointer'
                      }}
                    >
                      {item.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* IMAGE 5: CHALLAN / MEMO / NOTICE NUMBER */}
              <div style={{ marginBottom: '16px' }}>
                <div style={{
                  fontSize: '11px',
                  fontWeight: 900,
                  letterSpacing: '0.04em',
                  color: 'var(--navy-900)',
                  marginBottom: '6px',
                  textTransform: 'uppercase'
                }}>
                  CHALLAN / MEMO / NOTICE NUMBER
                </div>

                <div style={{ display: 'flex', gap: '8px' }}>
                  <input
                    type="text"
                    value={challanNumber}
                    onChange={(e) => setChallanNumber(e.target.value)}
                    className="form-control"
                    style={{
                      flex: 1,
                      fontFamily: 'var(--font-mono)',
                      fontSize: '15px',
                      fontWeight: 800,
                      letterSpacing: '0.05em'
                    }}
                    required
                  />
                  <button
                    type="button"
                    disabled
                    title="OCR provider is not configured"
                    style={{
                      background: '#eff6ff',
                      color: '#0f172a',
                      border: '1px solid #bfdbfe',
                      borderRadius: '8px',
                      padding: '0 14px',
                      fontSize: '12px',
                      fontWeight: 800,
                      cursor: 'not-allowed',
                      opacity: 0.6,
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px'
                    }}
                  >
                    <Camera size={16} />
                    <span>OCR UNAVAILABLE</span>
                  </button>
                </div>
              </div>

              {/* IMAGE 5: PENALTY AMOUNT DEMANDED (₹) / રકમ */}
              <div style={{ marginBottom: '20px' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
                  <div style={{
                    fontSize: '11px',
                    fontWeight: 900,
                    letterSpacing: '0.04em',
                    color: 'var(--navy-900)',
                    textTransform: 'uppercase'
                  }}>
                    PENALTY AMOUNT DEMANDED (₹) / રકમ
                  </div>
                  <span style={{
                    background: '#fef3c7',
                    color: '#b45309',
                    fontSize: '10px',
                    fontWeight: 800,
                    padding: '2px 8px',
                    borderRadius: '4px',
                    letterSpacing: '0.04em'
                  }}>
                    VERIFY BEFORE PAYING
                  </span>
                </div>

                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  background: '#f8fafc',
                  border: '1px solid #cbd5e1',
                  borderRadius: '8px',
                  padding: '8px 14px',
                  marginBottom: '10px'
                }}>
                  <span style={{ fontSize: '20px', fontWeight: 800, color: '#0f172a', marginRight: '8px' }}>
                    ₹
                  </span>
                  <input
                    type="number"
                    value={penaltyAmount}
                    onChange={(e) => setPenaltyAmount(e.target.value)}
                    style={{
                      border: 'none',
                      background: 'transparent',
                      fontSize: '22px',
                      fontWeight: 900,
                      color: '#0f172a',
                      width: '100%',
                      outline: 'none'
                    }}
                    required
                  />
                </div>

                {/* Quick Add Buttons: +₹500, +₹1,000, +₹2,000, +₹5,000 */}
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px' }}>
                  {[500, 1000, 2000, 5000].map((val) => (
                    <button
                      key={val}
                      type="button"
                      onClick={() => handleQuickAddAmount(val)}
                      style={{
                        background: '#eff6ff',
                        border: '1px solid #bfdbfe',
                        borderRadius: '6px',
                        padding: '8px 0',
                        fontSize: '12px',
                        fontWeight: 800,
                        color: '#0f172a',
                        cursor: 'pointer',
                        textAlign: 'center'
                      }}
                    >
                      +₹{val.toLocaleString('en-IN')}
                    </button>
                  ))}
                </div>
              </div>

              {/* IMAGE 3: 2. PROOF DOCUMENTS CAPTURE / ફોટો પુરાવો */}
              <div style={{
                background: '#ffffff',
                border: '1px solid #e2e8f0',
                borderRadius: '12px',
                padding: '16px',
                marginBottom: '16px'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
                  <div style={{
                    fontSize: '12px',
                    fontWeight: 900,
                    letterSpacing: '0.04em',
                    color: 'var(--navy-900)',
                    textTransform: 'uppercase'
                  }}>
                    2. PROOF DOCUMENTS CAPTURE / ફોટો પુરાવો
                  </div>
                  <span style={{
                    background: '#eff6ff',
                    color: '#0284c7',
                    fontSize: '10px',
                    fontWeight: 800,
                    padding: '2px 8px',
                    borderRadius: '4px'
                  }}>
                    2 SLOTS AVAILABLE
                  </span>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  {/* Left: Challan / Police Memo */}
                  <div
                    onClick={() => challanInputRef.current?.click()}
                    style={{
                      border: '2px dashed #94a3b8',
                      borderRadius: '10px',
                      padding: '12px',
                      textAlign: 'center',
                      background: '#f8fafc',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      minHeight: '120px'
                    }}
                  >
                    <div style={{
                      width: '32px',
                      height: '32px',
                      background: '#000000',
                      borderRadius: '6px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      color: '#ffffff',
                      marginBottom: '6px'
                    }}>
                      <FileText size={18} />
                    </div>
                    <div style={{ fontSize: '12px', fontWeight: 800, color: '#0f172a' }}>
                      Challan / Police Memo
                    </div>
                    <div style={{ fontSize: '10px', color: '#64748b', marginTop: '2px' }}>
                      Required for Legal Audit
                    </div>
                    <button
                      type="button"
                      style={{
                        marginTop: '8px',
                        background: '#ffffff',
                        border: '1px solid #cbd5e1',
                        borderRadius: '6px',
                        padding: '5px 10px',
                        fontSize: '11px',
                        fontWeight: 800,
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px'
                      }}
                    >
                      <Camera size={13} />
                      <span>{challanSlipPhoto ? 'SLIP CAPTURED' : 'CAPTURE SLIP'}</span>
                    </button>
                  </div>

                  {/* Right: Weighment Slip / Memo */}
                  <div
                    onClick={() => weighmentInputRef.current?.click()}
                    style={{
                      border: '1px solid #cbd5e1',
                      borderRadius: '10px',
                      padding: '12px',
                      textAlign: 'center',
                      background: '#ffffff',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      minHeight: '120px'
                    }}
                  >
                    <div style={{
                      width: '32px',
                      height: '32px',
                      background: '#eff6ff',
                      borderRadius: '6px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      color: '#0284c7',
                      marginBottom: '6px'
                    }}>
                      <Scale size={18} />
                    </div>
                    <div style={{ fontSize: '12px', fontWeight: 800, color: '#0f172a' }}>
                      Weighment Slip / Memo
                    </div>
                    <div style={{ fontSize: '10px', color: '#64748b', marginTop: '2px' }}>
                      If Weight Discrepancy
                    </div>
                    <button
                      type="button"
                      style={{
                        marginTop: '8px',
                        background: '#ffffff',
                        border: '1px solid #cbd5e1',
                        borderRadius: '6px',
                        padding: '5px 10px',
                        fontSize: '11px',
                        fontWeight: 800,
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px'
                      }}
                    >
                      <Camera size={13} />
                      <span>{weighmentSlipPhoto ? 'SLIP ADDED' : 'ADD SLIP'}</span>
                    </button>
                  </div>
                </div>
              </div>

              {/* IMAGE 3: 3. SETTLEMENT & CASH REIMBURSEMENT */}
              <div style={{
                background: '#ffffff',
                border: '1px solid #e2e8f0',
                borderRadius: '12px',
                padding: '16px',
                marginBottom: '16px'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
                  <div style={{
                    fontSize: '12px',
                    fontWeight: 900,
                    letterSpacing: '0.04em',
                    color: 'var(--navy-900)',
                    textTransform: 'uppercase'
                  }}>
                    3. SETTLEMENT &amp; CASH REIMBURSEMENT
                  </div>
                  <span style={{
                    background: '#0f172a',
                    color: '#34d399',
                    fontSize: '10px',
                    fontWeight: 900,
                    padding: '2px 8px',
                    borderRadius: '4px',
                    letterSpacing: '0.05em'
                  }}>
                    DISPATCH SYNC
                  </span>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {/* Option 1: Driver Paid Cash on Spot */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setSettlementOption('cash_spot'); }}
                    style={{
                      border: settlementOption === 'cash_spot' ? '2px solid #0f172a' : '1px solid #cbd5e1',
                      borderRadius: '8px',
                      padding: '12px',
                      background: settlementOption === 'cash_spot' ? '#eff6ff' : '#ffffff',
                      cursor: 'pointer'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{
                          width: '16px',
                          height: '16px',
                          borderRadius: '50%',
                          border: settlementOption === 'cash_spot' ? '2px solid #0f172a' : '1.5px solid #94a3b8',
                          background: settlementOption === 'cash_spot' ? '#0f172a' : 'transparent',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center'
                        }}>
                          {settlementOption === 'cash_spot' && (
                            <div style={{ width: '5px', height: '5px', borderRadius: '50%', background: '#ffffff' }} />
                          )}
                        </div>
                        <span style={{ fontSize: '13px', fontWeight: 800, color: '#0f172a' }}>
                          Driver Paid Cash on Spot
                        </span>
                      </div>
                      <span style={{
                        background: '#ffedd5',
                        color: '#c2410c',
                        fontSize: '10px',
                        fontWeight: 800,
                        padding: '2px 6px',
                        borderRadius: '4px'
                      }}>
                        IMMEDIATE UPI
                      </span>
                    </div>
                    <div style={{ fontSize: '11px', color: '#64748b', marginTop: '4px', paddingLeft: '24px' }}>
                      Reimbursed to driver bank account within 15 minutes of receipt verification.
                    </div>
                  </div>

                  {/* Option 2: Company Pay via Parivahan e-Challan */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setSettlementOption('company_parivahan'); }}
                    style={{
                      border: settlementOption === 'company_parivahan' ? '2px solid #0f172a' : '1px solid #cbd5e1',
                      borderRadius: '8px',
                      padding: '12px',
                      background: settlementOption === 'company_parivahan' ? '#eff6ff' : '#ffffff',
                      cursor: 'pointer'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{
                          width: '16px',
                          height: '16px',
                          borderRadius: '50%',
                          border: settlementOption === 'company_parivahan' ? '2px solid #0f172a' : '1.5px solid #94a3b8',
                          background: settlementOption === 'company_parivahan' ? '#0f172a' : 'transparent',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center'
                        }}>
                          {settlementOption === 'company_parivahan' && (
                            <div style={{ width: '5px', height: '5px', borderRadius: '50%', background: '#ffffff' }} />
                          )}
                        </div>
                        <span style={{ fontSize: '13px', fontWeight: 800, color: '#0f172a' }}>
                          Company Pay via Parivahan e-Challan
                        </span>
                      </div>
                      <span style={{
                        background: '#e0f2fe',
                        color: '#0369a1',
                        fontSize: '10px',
                        fontWeight: 800,
                        padding: '2px 6px',
                        borderRadius: '4px'
                      }}>
                        PORTAL PAY
                      </span>
                    </div>
                    <div style={{ fontSize: '11px', color: '#64748b', marginTop: '4px', paddingLeft: '24px' }}>
                      Legal desk settles payment directly online using national vehicle portal.
                    </div>
                  </div>

                  {/* Option 3: RC / DL Seized by Officer */}
                  <div
                    onClick={() => { soundEffects.playActionClick(); setSettlementOption('rc_dl_seized'); }}
                    style={{
                      border: settlementOption === 'rc_dl_seized' ? '2px solid #0f172a' : '1px solid #cbd5e1',
                      borderRadius: '8px',
                      padding: '12px',
                      background: settlementOption === 'rc_dl_seized' ? '#eff6ff' : '#ffffff',
                      cursor: 'pointer'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{
                          width: '16px',
                          height: '16px',
                          borderRadius: '50%',
                          border: settlementOption === 'rc_dl_seized' ? '2px solid #0f172a' : '1.5px solid #94a3b8',
                          background: settlementOption === 'rc_dl_seized' ? '#0f172a' : 'transparent',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center'
                        }}>
                          {settlementOption === 'rc_dl_seized' && (
                            <div style={{ width: '5px', height: '5px', borderRadius: '50%', background: '#ffffff' }} />
                          )}
                        </div>
                        <span style={{ fontSize: '13px', fontWeight: 800, color: '#b91c1c' }}>
                          RC / DL Seized by Officer
                        </span>
                      </div>
                      <span style={{
                        background: '#fee2e2',
                        color: '#b91c1c',
                        fontSize: '10px',
                        fontWeight: 800,
                        padding: '2px 6px',
                        borderRadius: '4px'
                      }}>
                        ESCALATION
                      </span>
                    </div>
                    <div style={{ fontSize: '11px', color: '#64748b', marginTop: '4px', paddingLeft: '24px' }}>
                      Immediate call with Head of Regional Transport Operations required.
                    </div>
                  </div>
                </div>

                {/* Bottom Card: Linked Driver Bank Account (Matching Image 3) */}
                <div style={{
                  marginTop: '12px',
                  background: '#eff6ff',
                  border: '1px solid #bfdbfe',
                  borderRadius: '8px',
                  padding: '10px 14px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <CreditCard size={18} color="#0f172a" />
                    <span style={{ fontSize: '12px', fontWeight: 800, color: '#0f172a' }}>
                      {driverAccountLabel}
                    </span>
                  </div>
                  <span style={{
                    fontSize: '11px',
                    fontWeight: 900,
                    color: '#0f766e',
                    letterSpacing: '0.04em'
                  }}>
                    NOT CONFIGURED
                  </span>
                </div>
              </div>
            </div>
          )}

          {/* ========================================================= */}
          {/* TAB 3: REFUELING DETAILS                                  */}
          {/* ========================================================= */}
          {activeTab === 'refueling' && (
            <div style={{ background: '#f8fafc', padding: '16px', borderRadius: '12px', marginBottom: '16px', border: '1px solid #e2e8f0' }}>
              <h3 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-900)', margin: '0 0 12px 0' }}>
                ઈંધણ ભરવાની વિગતો (Refueling Fuel Log)
              </h3>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginBottom: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '11px', color: 'var(--slate-600)', marginBottom: '4px', fontWeight: 700 }}>
                    Fuel Quantity (Liters)
                  </label>
                  <input
                    type="number"
                    value={fuelLiters}
                    onChange={(e) => setFuelLiters(e.target.value)}
                    className="form-control"
                    required
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '11px', color: 'var(--slate-600)', marginBottom: '4px', fontWeight: 700 }}>
                    Total Cost (INR ₹)
                  </label>
                  <input
                    type="number"
                    value={fuelCost}
                    onChange={(e) => setFuelCost(e.target.value)}
                    className="form-control"
                    required
                  />
                </div>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '11px', color: 'var(--slate-600)', marginBottom: '4px', fontWeight: 700 }}>
                    Odometer at Pump (KM)
                  </label>
                  <input
                    type="number"
                    value={odometer}
                    onChange={(e) => setOdometer(e.target.value)}
                    className="form-control"
                    required
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '11px', color: 'var(--slate-600)', marginBottom: '4px', fontWeight: 700 }}>
                    Fuel Station / Location
                  </label>
                  <input
                    type="text"
                    value={fuelStation}
                    onChange={(e) => setFuelStation(e.target.value)}
                    className="form-control"
                    required
                  />
                </div>
              </div>
            </div>
          )}

          {/* ========================================================= */}
          {/* TAB 4: GENERAL DELAY & TRAFFIC                            */}
          {/* ========================================================= */}
          {activeTab === 'traffic' && (
            <div style={{ background: '#f8fafc', padding: '16px', borderRadius: '12px', marginBottom: '16px', border: '1px solid #e2e8f0' }}>
              <h3 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-900)', margin: '0 0 12px 0' }}>
                માર્ગ વિલંબ અને ટ્રાફિક (Traffic &amp; Route Delay)
              </h3>
              <div style={{ marginBottom: '12px' }}>
                <label style={{ display: 'block', fontSize: '11px', color: 'var(--slate-600)', marginBottom: '4px', fontWeight: 700 }}>
                  Estimated Delay (Minutes)
                </label>
                <input
                  type="number"
                  value={delayDuration}
                  onChange={(e) => setDelayDuration(e.target.value)}
                  className="form-control"
                  required
                />
              </div>
              <div>
                <label style={{ display: 'block', fontSize: '11px', color: 'var(--slate-600)', marginBottom: '4px', fontWeight: 700 }}>
                  Delay Reason / Highway Toll
                </label>
                <input
                  type="text"
                  value={delayNotes}
                  onChange={(e) => setDelayNotes(e.target.value)}
                  placeholder="e.g. Heavy congestion near expressway flyover toll plaza"
                  className="form-control"
                  required
                />
              </div>
            </div>
          )}

          {/* Submit Action Buttons */}
          <div style={{ display: 'flex', gap: '10px', marginTop: '16px' }}>
            <button
              type="button"
              onClick={onClose}
              className="btn btn-secondary"
              style={{ flex: 1, padding: '12px 0', fontSize: '13px', fontWeight: 700 }}
            >
              Cancel / રદ કરો
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              style={{
                flex: 2,
                padding: '12px 0',
                fontSize: '13px',
                fontWeight: 800,
                background: activeTab === 'breakdown' ? '#dc2626' : '#0f172a',
                border: 'none',
                color: '#ffffff',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px'
              }}
            >
              <CheckCircle2 size={16} />
              <span>
                {activeTab === 'breakdown' && 'સહાયતા વિનંતી મોકલો (Submit Incident to Dispatch)'}
                {activeTab === 'challan' && 'ચલણ વિગતો સેવ કરો (Record Challan &amp; Sync Dispatch)'}
                {activeTab === 'refueling' && 'ઈંધણ લોગ સેવ કરો (Save Fuel Log)'}
                {activeTab === 'traffic' && 'વિલંબ નોંધો (Record Route Delay)'}
              </span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
