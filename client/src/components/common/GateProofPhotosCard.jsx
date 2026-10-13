import React, { useState, useRef } from 'react';
import { Camera, Check, ShieldCheck, Zap, RotateCcw, AlertTriangle, Eye, Upload } from 'lucide-react';
import { soundEffects } from '../../utils/soundEffects';
import { api } from '../../utils/api';
import { useTranslation } from '../../hooks/useTranslation';

const DEFAULT_ODOMETER = '/images/gate-proofs/odometer-cluster.jpg';
const DEFAULT_WALKAROUND = '/images/gate-proofs/walkaround-front.jpg';
const DEFAULT_SELFIE = '/images/gate-proofs/driver-seatbelt-selfie.jpg';

export default function GateProofPhotosCard({
  trip,
  onProofUpdated,
  readOnly = false,
  depotName = 'Depot 4'
}) {
  const { t } = useTranslation();
  const existingProofs = trip?.gateProofs || {};

  const [odometerPhoto, setOdometerPhoto] = useState(existingProofs.odometerPhoto || DEFAULT_ODOMETER);
  const [odometerTime, setOdometerTime] = useState(existingProofs.odometerTimestamp ? new Date(existingProofs.odometerTimestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '10:14 AM');
  
  const [walkaroundPhoto, setWalkaroundPhoto] = useState(existingProofs.walkaroundPhoto || DEFAULT_WALKAROUND);
  const [walkaroundTime, setWalkaroundTime] = useState(existingProofs.walkaroundTimestamp ? new Date(existingProofs.walkaroundTimestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '10:17 AM');
  
  const [selfiePhoto, setSelfiePhoto] = useState(existingProofs.driverSeatbeltPhoto || DEFAULT_SELFIE);
  const [selfieTime, setSelfieTime] = useState(existingProofs.driverSeatbeltTimestamp ? new Date(existingProofs.driverSeatbeltTimestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '10:19 AM');

  const [seatbeltVerified, setSeatbeltVerified] = useState(existingProofs.seatbeltVerified !== undefined ? existingProofs.seatbeltVerified : true);
  const [overspeedingPledge, setOverspeedingPledge] = useState(existingProofs.overspeedingPledge !== undefined ? existingProofs.overspeedingPledge : true);

  const [activeModalImg, setActiveModalImg] = useState(null);
  const [isSaving, setIsSaving] = useState(false);

  const odoInputRef = useRef(null);
  const walkInputRef = useRef(null);
  const selfieInputRef = useRef(null);

  const displayDepot = existingProofs.depotLocationName || depotName || 'Depot 4';

  // Count done items (3 max)
  const isOdoDone = Boolean(odometerPhoto);
  const isWalkDone = Boolean(walkaroundPhoto);
  const isSelfieDone = Boolean(selfiePhoto && seatbeltVerified && overspeedingPledge);
  const completedCount = (isOdoDone ? 1 : 0) + (isWalkDone ? 1 : 0) + (isSelfieDone ? 1 : 0);

  const syncProofsToServer = async (updates) => {
    if (!trip?.id) return;
    setIsSaving(true);
    try {
      const payload = {
        odometerPhoto: updates.odometerPhoto !== undefined ? updates.odometerPhoto : odometerPhoto,
        walkaroundPhoto: updates.walkaroundPhoto !== undefined ? updates.walkaroundPhoto : walkaroundPhoto,
        driverSeatbeltPhoto: updates.selfiePhoto !== undefined ? updates.selfiePhoto : selfiePhoto,
        seatbeltVerified: updates.seatbeltVerified !== undefined ? updates.seatbeltVerified : seatbeltVerified,
        overspeedingPledge: updates.overspeedingPledge !== undefined ? updates.overspeedingPledge : overspeedingPledge,
        depotLocationName: displayDepot
      };
      const res = await api.updateTripGateProofs(trip.id, payload);
      soundEffects.playSuccessChime();
      if (onProofUpdated) onProofUpdated(res.trip);
    } catch (err) {
      console.error('Failed to save gate proof photos:', err);
    } finally {
      setIsSaving(false);
    }
  };

  const handleFileUpload = (e, type) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = () => {
      const resultData = reader.result;
      const nowStr = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

      if (type === 'odometer') {
        setOdometerPhoto(resultData);
        setOdometerTime(nowStr);
        syncProofsToServer({ odometerPhoto: resultData });
      } else if (type === 'walkaround') {
        setWalkaroundPhoto(resultData);
        setWalkaroundTime(nowStr);
        syncProofsToServer({ walkaroundPhoto: resultData });
      } else if (type === 'selfie') {
        setSelfiePhoto(resultData);
        setSelfieTime(nowStr);
        syncProofsToServer({ selfiePhoto: resultData });
      }
    };
    reader.readAsDataURL(file);
  };

  return (
    <div style={{
      background: '#ffffff',
      borderRadius: '16px',
      border: '1px solid var(--slate-200)',
      padding: '20px',
      boxShadow: 'var(--shadow-card)',
      marginBottom: '16px'
    }}>
      {/* Hidden file inputs for real camera/file clicks */}
      <input
        type="file"
        accept="image/*"
        capture="environment"
        ref={odoInputRef}
        style={{ display: 'none' }}
        onChange={(e) => handleFileUpload(e, 'odometer')}
      />
      <input
        type="file"
        accept="image/*"
        capture="environment"
        ref={walkInputRef}
        style={{ display: 'none' }}
        onChange={(e) => handleFileUpload(e, 'walkaround')}
      />
      <input
        type="file"
        accept="image/*"
        capture="user"
        ref={selfieInputRef}
        style={{ display: 'none' }}
        onChange={(e) => handleFileUpload(e, 'selfie')}
      />

      {/* Header matching Image 3 */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: '18px',
        paddingBottom: '14px',
        borderBottom: '1px solid var(--slate-100)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '38px',
            height: '38px',
            borderRadius: '8px',
            border: '2px solid var(--navy-800)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'var(--navy-800)',
            background: '#ffffff'
          }}>
            <Camera size={20} strokeWidth={2.4} />
          </div>
          <div>
            <h3 style={{
              fontSize: '17px',
              fontWeight: 900,
              letterSpacing: '0.03em',
              color: 'var(--navy-900)',
              margin: 0,
              textTransform: 'uppercase'
            }}>
              {t('gateProofTitle')}
            </h3>
            <div style={{ fontSize: '11px', color: 'var(--slate-500)', marginTop: '2px' }}>
              {t('gateProofSub')}
            </div>
          </div>
        </div>

        <div style={{ textAlign: 'right' }}>
          <div style={{
            fontSize: '17px',
            fontWeight: 900,
            color: completedCount === 3 ? 'var(--status-emerald-text)' : 'var(--navy-900)',
            letterSpacing: '0.05em'
          }}>
            {completedCount}/3
          </div>
          <div style={{
            fontSize: '11px',
            fontWeight: 800,
            color: completedCount === 3 ? 'var(--status-emerald-text)' : 'var(--slate-500)',
            letterSpacing: '0.05em',
            textTransform: 'uppercase'
          }}>
            {completedCount === 3 ? 'DONE' : 'INCOMPLETE'}
          </div>
        </div>
      </div>

      {/* 3 Proof Photo Cards Grid */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
        gap: '16px',
        marginBottom: '16px'
      }}>
        
        {/* CARD 1: ODOMETER & CLUSTER */}
        <div style={{
          background: '#f8fafc',
          borderRadius: '12px',
          border: '1px solid var(--slate-200)',
          padding: '10px',
          display: 'flex',
          flexDirection: 'column',
          position: 'relative'
        }}>
          {/* Photo Preview Thumbnail */}
          <div style={{
            position: 'relative',
            borderRadius: '10px',
            overflow: 'hidden',
            aspectRatio: '4/3',
            background: 'var(--slate-200)',
            marginBottom: '10px'
          }}>
            <img
              src={odometerPhoto}
              alt="Odometer & Cluster"
              style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
              onClick={() => setActiveModalImg(odometerPhoto)}
            />
            {/* Pill Badge matching Image 3 */}
            <div style={{
              position: 'absolute',
              bottom: '8px',
              right: '8px',
              background: '#0f172a',
              color: '#ffffff',
              padding: '4px 10px',
              borderRadius: '6px',
              fontSize: '11px',
              fontWeight: 800,
              letterSpacing: '0.05em',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
              boxShadow: '0 2px 6px rgba(0,0,0,0.3)'
            }}>
              <Check size={13} strokeWidth={3} />
              <span>VERIFIED</span>
            </div>
          </div>

          {/* Details */}
          <div style={{ marginBottom: '10px' }}>
            <h4 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-900)', margin: '0 0 2px 0' }}>
              {t('gateProofOdometer')}
            </h4>
            <div style={{ fontSize: '11px', color: 'var(--slate-500)', fontWeight: 600 }}>
              {odometerTime} @ {displayDepot}
            </div>
          </div>

          {/* Retake Button */}
          {!readOnly && (
            <button
              type="button"
              onClick={() => odoInputRef.current?.click()}
              className="btn btn-secondary"
              style={{
                marginTop: 'auto',
                width: '100%',
                padding: '7px 0',
                background: '#ffffff',
                border: '1px solid var(--slate-300)',
                color: 'var(--navy-900)',
                fontSize: '12px',
                fontWeight: 800,
                letterSpacing: '0.05em',
                borderRadius: '6px',
                textAlign: 'center',
                textTransform: 'uppercase'
              }}
            >
              RETAKE
            </button>
          )}
        </div>

        {/* CARD 2: WALKAROUND FRONT FACE */}
        <div style={{
          background: '#f8fafc',
          borderRadius: '12px',
          border: '1px solid var(--slate-200)',
          padding: '10px',
          display: 'flex',
          flexDirection: 'column',
          position: 'relative'
        }}>
          {/* Photo Preview Thumbnail */}
          <div style={{
            position: 'relative',
            borderRadius: '10px',
            overflow: 'hidden',
            aspectRatio: '4/3',
            background: 'var(--slate-200)',
            marginBottom: '10px'
          }}>
            <img
              src={walkaroundPhoto}
              alt="Walkaround Front Face"
              style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
              onClick={() => setActiveModalImg(walkaroundPhoto)}
            />
            {/* Pill Badge matching Image 3 */}
            <div style={{
              position: 'absolute',
              bottom: '8px',
              right: '8px',
              background: '#0f172a',
              color: '#ffffff',
              padding: '4px 10px',
              borderRadius: '6px',
              fontSize: '11px',
              fontWeight: 800,
              letterSpacing: '0.05em',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
              boxShadow: '0 2px 6px rgba(0,0,0,0.3)'
            }}>
              <Check size={13} strokeWidth={3} />
              <span>CAPTURED</span>
            </div>
          </div>

          {/* Details */}
          <div style={{ marginBottom: '10px' }}>
            <h4 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-900)', margin: '0 0 2px 0' }}>
              {t('gateProofWalkaround')}
            </h4>
            <div style={{ fontSize: '11px', color: 'var(--slate-500)', fontWeight: 600 }}>
              {walkaroundTime} @ {displayDepot}
            </div>
          </div>

          {/* Retake Button */}
          {!readOnly && (
            <button
              type="button"
              onClick={() => walkInputRef.current?.click()}
              className="btn btn-secondary"
              style={{
                marginTop: 'auto',
                width: '100%',
                padding: '7px 0',
                background: '#ffffff',
                border: '1px solid var(--slate-300)',
                color: 'var(--navy-900)',
                fontSize: '12px',
                fontWeight: 800,
                letterSpacing: '0.05em',
                borderRadius: '6px',
                textAlign: 'center',
                textTransform: 'uppercase'
              }}
            >
              RETAKE
            </button>
          )}
        </div>

        {/* CARD 3: DRIVER SEATED WITH SEATBELT (REQUESTED BY USER) */}
        <div style={{
          background: '#f8fafc',
          borderRadius: '12px',
          border: '2px solid var(--primary-blue)',
          padding: '10px',
          display: 'flex',
          flexDirection: 'column',
          position: 'relative'
        }}>
          {/* Photo Preview Thumbnail */}
          <div style={{
            position: 'relative',
            borderRadius: '10px',
            overflow: 'hidden',
            aspectRatio: '4/3',
            background: 'var(--slate-200)',
            marginBottom: '10px'
          }}>
            <img
              src={selfiePhoto}
              alt="Driver Seated with Fastened Seatbelt"
              style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
              onClick={() => setActiveModalImg(selfiePhoto)}
            />
            {/* Pill Badge matching Image 3 */}
            <div style={{
              position: 'absolute',
              bottom: '8px',
              right: '8px',
              background: '#0f172a',
              color: '#ffffff',
              padding: '4px 10px',
              borderRadius: '6px',
              fontSize: '11px',
              fontWeight: 800,
              letterSpacing: '0.05em',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
              boxShadow: '0 2px 6px rgba(0,0,0,0.3)'
            }}>
              <Check size={13} strokeWidth={3} />
              <span>VERIFIED</span>
            </div>
          </div>

          {/* Details */}
          <div style={{ marginBottom: '10px' }}>
            <h4 style={{ fontSize: '14px', fontWeight: 800, color: 'var(--navy-900)', margin: '0 0 2px 0' }}>
              {t('gateProofSelfie')}
            </h4>
            <div style={{ fontSize: '11px', color: 'var(--slate-500)', fontWeight: 600 }}>
              {selfieTime} @ {displayDepot}
            </div>
          </div>

          {/* Retake Button */}
          {!readOnly && (
            <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <button
                type="button"
                onClick={() => selfieInputRef.current?.click()}
                className="btn btn-secondary"
                style={{
                  width: '100%',
                  padding: '7px 0',
                  background: '#ffffff',
                  border: '1px solid var(--slate-300)',
                  color: 'var(--navy-900)',
                  fontSize: '12px',
                  fontWeight: 800,
                  letterSpacing: '0.05em',
                  borderRadius: '6px',
                  textAlign: 'center',
                  textTransform: 'uppercase'
                }}
              >
                RETAKE / TAKE SELFIE
              </button>
            </div>
          )}
        </div>

      </div>

      {/* Safety Compliance & No Overspeeding Commitment Badge */}
      <div style={{
        background: 'rgba(2, 132, 199, 0.05)',
        border: '1px solid rgba(2, 132, 199, 0.25)',
        borderRadius: '10px',
        padding: '12px 14px',
        display: 'flex',
        flexDirection: 'column',
        gap: '8px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '8px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <ShieldCheck size={18} color="var(--primary-teal)" />
            <div style={{ fontSize: '12px', fontWeight: 800, color: 'var(--navy-900)' }}>
              {t('gateProofComplianceTitle')}
            </div>
          </div>
          <span style={{
            fontSize: '10px',
            fontWeight: 800,
            textTransform: 'uppercase',
            padding: '2px 8px',
            borderRadius: '9999px',
            background: seatbeltVerified && overspeedingPledge ? 'var(--status-emerald-light)' : 'var(--status-amber-light)',
            color: seatbeltVerified && overspeedingPledge ? 'var(--status-emerald-text)' : 'var(--status-amber-text)'
          }}>
            {seatbeltVerified && overspeedingPledge ? 'SAFETY COMPLIANT' : 'PLEDGE REQUIRED'}
          </span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: readOnly ? 'default' : 'pointer', fontSize: '12px', color: 'var(--navy-800)', fontWeight: 600 }}>
            <input
              type="checkbox"
              disabled={readOnly}
              checked={seatbeltVerified}
              onChange={(e) => {
                const nextVal = e.target.checked;
                setSeatbeltVerified(nextVal);
                syncProofsToServer({ seatbeltVerified: nextVal });
              }}
              style={{ width: '15px', height: '15px', accentColor: 'var(--primary-teal)' }}
            />
            <span>{t('gateProofSeatbeltCheck')}</span>
          </label>

          <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: readOnly ? 'default' : 'pointer', fontSize: '12px', color: 'var(--navy-800)', fontWeight: 600 }}>
            <input
              type="checkbox"
              disabled={readOnly}
              checked={overspeedingPledge}
              onChange={(e) => {
                const nextVal = e.target.checked;
                setOverspeedingPledge(nextVal);
                syncProofsToServer({ overspeedingPledge: nextVal });
              }}
              style={{ width: '15px', height: '15px', accentColor: 'var(--primary-teal)' }}
            />
            <span>{t('gateProofSpeedPledge')}</span>
          </label>
        </div>
      </div>

      {/* Full-view Modal when clicking thumbnail */}
      {activeModalImg && (
        <div
          onClick={() => setActiveModalImg(null)}
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0,0,0,0.85)',
            backdropFilter: 'blur(4px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1400,
            padding: '20px',
            cursor: 'pointer'
          }}
        >
          <div style={{ maxWidth: '640px', width: '100%', borderRadius: '12px', overflow: 'hidden' }}>
            <img src={activeModalImg} alt="Enlarged Proof" style={{ width: '100%', height: 'auto', display: 'block' }} />
            <div style={{ textAlign: 'center', color: '#ffffff', fontSize: '12px', padding: '10px' }}>
              Click anywhere to close full preview
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
