import React, { useState } from 'react';
import { 
  X, 
  User, 
  Lock, 
  ShieldCheck, 
  Phone, 
  Mail, 
  LogOut, 
  CheckCircle2, 
  AlertCircle,
  KeyRound,
  Volume2,
  VolumeX,
  CreditCard,
  Truck,
  Award,
  Headphones,
  Globe,
  ArrowRight,
  Eye,
  EyeOff,
  Bell,
  ExternalLink
} from 'lucide-react';
import { api } from '../../utils/api';
import { soundEffects } from '../../utils/soundEffects';
import useTranslation from '../../hooks/useTranslation';

export default function UserProfileModal({ 
  isOpen, 
  onClose, 
  user, 
  currentUser, 
  driver,
  driverTrip,
  assignedVehicle,
  onLogout, 
  onProfileUpdated 
}) {
  const activeUser = currentUser || user;
  const { lang, setLanguage, supportedLanguages } = useTranslation();

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isPasswordSectionOpen, setIsPasswordSectionOpen] = useState(false);

  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [isSoundMuted, setIsSoundMuted] = useState(soundEffects.isMuted());

  if (!isOpen || !activeUser) return null;

  const isDriver = activeUser.role === 'driver';

  const handleChangePassword = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');

    if (newPassword !== confirmPassword) {
      setErrorMsg('New password and confirmation do not match.');
      return;
    }

    if (newPassword.length < 6) {
      setErrorMsg('New password must be at least 6 characters long.');
      return;
    }

    setLoading(true);
    soundEffects.playActionClick();

    try {
      await api.changePassword(currentPassword, newPassword);
      soundEffects.playSuccessChime();
      setSuccessMsg('Password changed successfully.');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setTimeout(() => setIsPasswordSectionOpen(false), 2000);
    } catch (err) {
      setErrorMsg(err.message || 'Failed to change password. Verify your current password.');
    } finally {
      setLoading(false);
    }
  };

  const handleTestSound = () => {
    if (isSoundMuted) {
      soundEffects.setMuted(false);
      setIsSoundMuted(false);
    }
    soundEffects.playSuccessChime();
  };

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      background: 'rgba(15, 23, 42, 0.7)',
      backdropFilter: 'blur(5px)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '16px',
      zIndex: 9999
    }}>
      <div style={{
        background: '#ffffff',
        borderRadius: '20px',
        width: '100%',
        maxWidth: '520px',
        maxHeight: '92vh',
        overflowY: 'auto',
        boxShadow: '0 25px 50px -12px rgba(15, 23, 42, 0.35)',
        border: '1px solid var(--slate-200)',
        display: 'flex',
        flexDirection: 'column'
      }}>
        
        {/* Header */}
        <div style={{
          background: '#ffffff',
          color: 'var(--navy-900)',
          padding: '18px 20px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderBottom: '1px solid var(--slate-200)',
          position: 'sticky',
          top: 0,
          zIndex: 10
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              width: '42px',
              height: '42px',
              borderRadius: '12px',
              background: isDriver ? 'var(--primary-teal)' : 'var(--navy-900)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontWeight: 900,
              color: '#ffffff',
              fontSize: '18px',
              boxShadow: '0 2px 8px rgba(0,0,0,0.15)'
            }}>
              {activeUser.name ? activeUser.name.charAt(0).toUpperCase() : 'U'}
            </div>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <h2 style={{ fontSize: '17px', fontWeight: 900, color: 'var(--navy-900)', margin: 0 }}>
                  {activeUser.name}
                </h2>
                <span style={{
                  fontSize: '10px',
                  fontWeight: 800,
                  textTransform: 'uppercase',
                  padding: '2px 8px',
                  borderRadius: '9999px',
                  background: isDriver ? 'var(--status-emerald-light)' : 'var(--sky-blue-light)',
                  color: isDriver ? 'var(--status-emerald-text)' : 'var(--primary-blue)'
                }}>
                  {isDriver ? 'Driver (ઓન-ડ્યુટી)' : 'Admin Dispatcher'}
                </span>
              </div>
              <div style={{ fontSize: '12px', color: 'var(--slate-500)', marginTop: '2px' }}>
                {activeUser.email || activeUser.phone}
              </div>
            </div>
          </div>

          <button
            onClick={onClose}
            style={{
              background: '#f1f5f9',
              border: 'none',
              color: 'var(--slate-500)',
              cursor: 'pointer',
              padding: '6px',
              borderRadius: '8px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            <X size={18} />
          </button>
        </div>

        {/* Modal Scrollable Body */}
        <div style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '14px' }}>
          
          {/* Active Trip Launcher Banner (if driver has assigned trip) */}
          {driverTrip && (
            <div style={{
              background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)',
              borderRadius: '12px',
              padding: '14px 16px',
              color: '#ffffff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              boxShadow: '0 4px 12px rgba(15, 23, 42, 0.2)'
            }}>
              <div>
                <div style={{ fontSize: '10px', textTransform: 'uppercase', color: '#38bdf8', fontWeight: 800, letterSpacing: '0.05em' }}>
                  ACTIVE ASSIGNED TRIP
                </div>
                <div style={{ fontSize: '14px', fontWeight: 800, marginTop: '2px' }}>
                  {driverTrip.title || driverTrip.id}
                </div>
                <div style={{ fontSize: '11px', color: '#94a3b8', marginTop: '2px' }}>
                  Status: <span style={{ color: '#34d399', fontWeight: 700 }}>{driverTrip.status.replace('_', ' ')}</span>
                </div>
              </div>

              <button
                type="button"
                onClick={onClose}
                style={{
                  background: 'var(--primary-teal)',
                  color: '#ffffff',
                  border: 'none',
                  borderRadius: '8px',
                  padding: '8px 12px',
                  fontSize: '11px',
                  fontWeight: 800,
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px'
                }}
              >
                <span>Resume Route</span>
                <ArrowRight size={14} />
              </button>
            </div>
          )}

          {/* DRIVER IDENTITY & VEHICLE DETAILS CARD */}
          <div style={{
            background: 'var(--slate-50)',
            borderRadius: '14px',
            padding: '16px',
            border: '1px solid var(--slate-200)'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
              <div style={{ fontSize: '11px', fontWeight: 800, color: 'var(--slate-500)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                {isDriver ? 'Driver Personnel & License Info' : 'Admin Profile Identity'}
              </div>
              {driver?.safetyScore && (
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  background: '#dcfce7',
                  color: '#15803d',
                  padding: '2px 8px',
                  borderRadius: '6px',
                  fontSize: '11px',
                  fontWeight: 800
                }}>
                  <Award size={13} />
                  <span>Safety Score: {driver.safetyScore}/100</span>
                </div>
              )}
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div>
                <div style={{ fontSize: '11px', color: 'var(--slate-400)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <User size={12} /> Personnel ID
                </div>
                <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)', marginTop: '2px', fontFamily: 'var(--font-mono)' }}>
                  {activeUser.driverId || driver?.id || 'DISPATCH-01'}
                </div>
              </div>

              <div>
                <div style={{ fontSize: '11px', color: 'var(--slate-400)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <Phone size={12} /> Phone
                </div>
                <div style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)', marginTop: '2px' }}>
                  {activeUser.phone || driver?.phone || '+91 98210 44821'}
                </div>
              </div>

              {driver?.licenseNumber && (
                <div>
                  <div style={{ fontSize: '11px', color: 'var(--slate-400)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <ShieldCheck size={12} /> Driving License
                  </div>
                  <div style={{ fontSize: '12px', fontWeight: 800, color: 'var(--navy-900)', marginTop: '2px', fontFamily: 'var(--font-mono)' }}>
                    {driver.licenseNumber}
                  </div>
                </div>
              )}

              {(assignedVehicle || driver?.assignedVehicleId) && (
                <div>
                  <div style={{ fontSize: '11px', color: 'var(--slate-400)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <Truck size={12} /> Assigned Vehicle
                  </div>
                  <div style={{ fontSize: '12px', fontWeight: 800, color: 'var(--navy-900)', marginTop: '2px' }}>
                    {assignedVehicle?.registrationNumber || driver?.assignedVehicleId || 'VEH-201'}
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* VERIFIED BANK & SPOT UPI REIMBURSEMENT (SUPER USEFUL FOR DRIVERS!) */}
          <div style={{
            background: '#eff6ff',
            border: '1px solid #bfdbfe',
            borderRadius: '14px',
            padding: '14px 16px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <CreditCard size={18} color="#0284c7" />
                <div style={{ fontSize: '12px', fontWeight: 800, color: '#0f172a' }}>
                  Spot Cash &amp; UPI Reimbursement Account
                </div>
              </div>
              <span style={{
                background: '#dcfce7',
                color: '#15803d',
                fontSize: '10px',
                fontWeight: 900,
                padding: '2px 8px',
                borderRadius: '6px',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '4px'
              }}>
                <CheckCircle2 size={12} /> VERIFIED
              </span>
            </div>

            <div style={{ fontSize: '13px', fontWeight: 800, color: '#0f172a' }}>
              State Bank of India (SBI) •••• 4182 ({activeUser.name})
            </div>
            <div style={{ fontSize: '11px', color: '#0369a1', marginTop: '4px', lineHeight: 1.4 }}>
              Approved police challan payments and emergency repair expenses will be credited directly to this verified UPI account within 15 minutes.
            </div>
          </div>

          {/* EMERGENCY 24x7 DISPATCH SUPPORT & SOS */}
          <div style={{
            background: '#ffffff',
            border: '1px solid var(--slate-200)',
            borderRadius: '14px',
            padding: '14px 16px'
          }}>
            <div style={{ fontSize: '11px', fontWeight: 800, color: 'var(--slate-500)', textTransform: 'uppercase', marginBottom: '8px', letterSpacing: '0.04em' }}>
              Emergency Support &amp; Dispatch Hotline
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
              <a
                href="tel:18002004455"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  background: '#f8fafc',
                  border: '1px solid #cbd5e1',
                  borderRadius: '10px',
                  padding: '10px',
                  textDecoration: 'none',
                  color: 'var(--navy-900)'
                }}
              >
                <Headphones size={18} color="#0284c7" />
                <div>
                  <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>24x7 Control Desk</div>
                  <div style={{ fontSize: '12px', fontWeight: 800 }}>1800-200-4455</div>
                </div>
              </a>

              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                background: '#f8fafc',
                border: '1px solid #cbd5e1',
                borderRadius: '10px',
                padding: '10px'
              }}>
                <Phone size={18} color="#dc2626" />
                <div>
                  <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>Emergency Contact</div>
                  <div style={{ fontSize: '12px', fontWeight: 800, color: 'var(--navy-900)' }}>
                    {driver?.emergencyContact?.split(' ')?.[0] || 'Family Contact'}
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* LANGUAGE & AUDIO NOTIFICATIONS PREFERENCE */}
          <div style={{
            background: 'var(--slate-50)',
            borderRadius: '14px',
            padding: '14px 16px',
            border: '1px solid var(--slate-200)'
          }}>
            {/* Language Switcher */}
            <div style={{ marginBottom: '14px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '11px', fontWeight: 800, color: 'var(--slate-500)', textTransform: 'uppercase', marginBottom: '8px' }}>
                <Globe size={14} color="var(--primary-blue)" />
                <span>એપ ભાષા / App Language</span>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '8px' }}>
                {supportedLanguages.map((l) => (
                  <button
                    key={l.code}
                    type="button"
                    onClick={() => {
                      soundEffects.playActionClick();
                      setLanguage(l.code);
                    }}
                    style={{
                      padding: '8px 0',
                      borderRadius: '8px',
                      fontSize: '12px',
                      fontWeight: lang === l.code ? 800 : 600,
                      border: lang === l.code ? '2px solid #0f172a' : '1px solid #cbd5e1',
                      background: lang === l.code ? '#ffffff' : '#f8fafc',
                      color: lang === l.code ? '#0f172a' : 'var(--slate-600)',
                      cursor: 'pointer'
                    }}
                  >
                    {l.native}
                  </button>
                ))}
              </div>
            </div>

            {/* Audio Feedback Switcher */}
            <div style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              borderTop: '1px solid #e2e8f0',
              paddingTop: '12px'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <div style={{
                  width: '32px',
                  height: '32px',
                  borderRadius: '8px',
                  background: isSoundMuted ? '#e2e8f0' : '#e0f2fe',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: isSoundMuted ? '#64748b' : '#0284c7'
                }}>
                  {isSoundMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
                </div>
                <div>
                  <div style={{ fontSize: '12px', fontWeight: 800, color: 'var(--navy-900)' }}>
                    Audio Notifications &amp; Chimes
                  </div>
                  <div style={{ fontSize: '11px', color: 'var(--slate-500)' }}>
                    {isSoundMuted ? 'Muted (Silent Alerts)' : 'Active (Audible Alert Chimes)'}
                  </div>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '6px' }}>
                <button
                  type="button"
                  onClick={handleTestSound}
                  style={{
                    background: '#ffffff',
                    border: '1px solid #cbd5e1',
                    borderRadius: '6px',
                    padding: '5px 10px',
                    fontSize: '11px',
                    fontWeight: 700,
                    cursor: 'pointer'
                  }}
                >
                  Test Chime
                </button>
                <button
                  type="button"
                  onClick={() => {
                    const next = !isSoundMuted;
                    soundEffects.setMuted(next);
                    setIsSoundMuted(next);
                    if (!next) soundEffects.playActionClick();
                  }}
                  style={{
                    background: isSoundMuted ? '#e2e8f0' : 'var(--primary-blue)',
                    color: isSoundMuted ? '#475569' : '#ffffff',
                    border: 'none',
                    borderRadius: '6px',
                    padding: '5px 12px',
                    fontSize: '11px',
                    fontWeight: 800,
                    cursor: 'pointer'
                  }}
                >
                  {isSoundMuted ? 'Unmute' : 'Mute'}
                </button>
              </div>
            </div>
          </div>

          {/* COLLAPSIBLE SECURITY & PASSWORD UPDATE */}
          <div style={{
            background: '#ffffff',
            borderRadius: '14px',
            border: '1px solid var(--slate-200)',
            overflow: 'hidden'
          }}>
            <button
              type="button"
              onClick={() => setIsPasswordSectionOpen(!isPasswordSectionOpen)}
              style={{
                width: '100%',
                padding: '14px 16px',
                background: 'transparent',
                border: 'none',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                cursor: 'pointer',
                textAlign: 'left'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <KeyRound size={16} color="var(--primary-blue)" />
                <span style={{ fontSize: '13px', fontWeight: 800, color: 'var(--navy-900)' }}>
                  Security &amp; Password Management (પાસવર્ડ બદલો)
                </span>
              </div>
              <span style={{ fontSize: '11px', fontWeight: 700, color: 'var(--primary-blue)' }}>
                {isPasswordSectionOpen ? 'Collapse' : 'Update Password'}
              </span>
            </button>

            {isPasswordSectionOpen && (
              <div style={{ padding: '0 16px 16px 16px', borderTop: '1px solid #f1f5f9' }}>
                {errorMsg && (
                  <div style={{
                    background: '#fef2f2',
                    border: '1px solid #fecaca',
                    borderRadius: '8px',
                    padding: '8px 12px',
                    color: '#991b1b',
                    fontSize: '12px',
                    fontWeight: 600,
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    margin: '10px 0'
                  }}>
                    <AlertCircle size={15} style={{ flexShrink: 0 }} />
                    <span>{errorMsg}</span>
                  </div>
                )}

                {successMsg && (
                  <div style={{
                    background: '#dcfce7',
                    border: '1px solid #bbf7d0',
                    borderRadius: '8px',
                    padding: '8px 12px',
                    color: '#166534',
                    fontSize: '12px',
                    fontWeight: 700,
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    margin: '10px 0'
                  }}>
                    <CheckCircle2 size={15} style={{ flexShrink: 0 }} />
                    <span>{successMsg}</span>
                  </div>
                )}

                <form onSubmit={handleChangePassword} style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: '10px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '11px', fontWeight: 700, color: 'var(--slate-600)', marginBottom: '4px' }}>
                      Current Password
                    </label>
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      value={currentPassword}
                      onChange={(e) => setCurrentPassword(e.target.value)}
                      placeholder="Enter current password"
                      className="form-control"
                      style={{ fontSize: '13px' }}
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '11px', fontWeight: 700, color: 'var(--slate-600)', marginBottom: '4px' }}>
                      New Password (At least 6 characters)
                    </label>
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      value={newPassword}
                      onChange={(e) => setNewPassword(e.target.value)}
                      placeholder="Enter new secure password"
                      className="form-control"
                      style={{ fontSize: '13px' }}
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '11px', fontWeight: 700, color: 'var(--slate-600)', marginBottom: '4px' }}>
                      Confirm New Password
                    </label>
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      placeholder="Re-enter new password"
                      className="form-control"
                      style={{ fontSize: '13px' }}
                    />
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '4px' }}>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '11px', color: 'var(--slate-600)', cursor: 'pointer' }}>
                      <input
                        type="checkbox"
                        checked={showPassword}
                        onChange={(e) => setShowPassword(e.target.checked)}
                      />
                      <span>Show Password Characters</span>
                    </label>

                    <button
                      type="submit"
                      disabled={loading}
                      className="btn btn-primary"
                      style={{
                        padding: '8px 16px',
                        fontSize: '12px',
                        fontWeight: 800,
                        display: 'flex',
                        alignItems: 'center',
                        gap: '6px',
                        background: '#0f172a'
                      }}
                    >
                      <Lock size={13} />
                      <span>{loading ? 'Saving...' : 'Update Password'}</span>
                    </button>
                  </div>
                </form>
              </div>
            )}
          </div>

          {/* SIGN OUT BUTTON */}
          <div style={{ marginTop: '8px', paddingTop: '14px', borderTop: '1px solid var(--slate-200)' }}>
            <button
              onClick={() => {
                soundEffects.playActionClick();
                onLogout();
                onClose();
              }}
              style={{
                width: '100%',
                padding: '12px',
                borderRadius: '10px',
                border: '1px solid #fecaca',
                background: '#fef2f2',
                color: '#991b1b',
                fontSize: '13px',
                fontWeight: 800,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
                transition: 'all 0.15s ease'
              }}
            >
              <LogOut size={16} />
              <span>Sign Out of FleetRoute (લોગ આઉટ)</span>
            </button>
          </div>

        </div>
      </div>
    </div>
  );
}
