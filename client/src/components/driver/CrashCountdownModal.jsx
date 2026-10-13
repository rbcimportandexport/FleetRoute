import React, { useState, useEffect } from 'react';
import { 
  ShieldAlert, 
  AlertTriangle, 
  MapPin, 
  PhoneCall, 
  CheckCircle2, 
  XOctagon, 
  Activity, 
  Volume2, 
  VolumeX,
  Clock,
  Radio
} from 'lucide-react';
import { soundEffects } from '../../utils/soundEffects';

export default function CrashCountdownModal({
  isOpen,
  initialSeconds = 20,
  emergencyDetails,
  onSafe, // () => void (Driver clicks I Am Safe)
  onSendSOSNow, // () => void (Driver clicks Send SOS Now)
  onAutoExpiry // () => void (Timer reached 0 -> Zero-touch auto-dispatch)
}) {
  const [secondsRemaining, setSecondsRemaining] = useState(initialSeconds);
  const [isMuted, setIsMuted] = useState(false);

  useEffect(() => {
    if (!isOpen) {
      setSecondsRemaining(initialSeconds);
      return;
    }

    setSecondsRemaining(initialSeconds);

    // Start loud repeating siren alarm and vibration
    const stopAlarm = soundEffects.playEmergencyAlarmLoop();

    const interval = setInterval(() => {
      setSecondsRemaining(prev => {
        if (prev <= 1) {
          clearInterval(interval);
          stopAlarm();
          // Trigger zero-touch automatic SOS dispatch without requiring user interaction
          if (onAutoExpiry) onAutoExpiry();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => {
      clearInterval(interval);
      stopAlarm();
    };
  }, [isOpen, initialSeconds]);

  if (!isOpen) return null;

  const lat = emergencyDetails?.coordinates?.lat?.toFixed(5) || '17.42650';
  const lng = emergencyDetails?.coordinates?.lng?.toFixed(5) || '78.41160';
  const speed = emergencyDetails?.speedBeforeImpact || 0;
  const gForce = emergencyDetails?.gForcePeak || emergencyDetails?.estimatedImpactForce || 4.8;
  const isHighSeverity = emergencyDetails?.severity === 'CRITICAL' || gForce >= 5;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/95 backdrop-blur-md animate-fade-in">
      <div className="w-full max-w-lg overflow-hidden bg-slate-900 border-2 border-red-500 rounded-2xl shadow-2xl text-slate-100 flex flex-col">
        {/* Urgent Header Banner */}
        <div className="bg-red-600 px-6 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-red-700/60 rounded-xl animate-pulse">
              <ShieldAlert className="w-8 h-8 text-white" />
            </div>
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-red-200">
                Crash Detection Sensor Fusion
              </span>
              <h2 className="text-xl font-extrabold text-white tracking-tight">
                POSSIBLE ACCIDENT DETECTED
              </h2>
            </div>
          </div>
          <button
            onClick={() => {
              const next = !isMuted;
              setIsMuted(next);
              soundEffects.setMuted(next);
            }}
            className="p-2 bg-red-700 hover:bg-red-800 rounded-lg text-white transition-colors"
            title={isMuted ? 'Unmute Alarm' : 'Mute Alarm'}
          >
            {isMuted ? <VolumeX className="w-5 h-5" /> : <Volume2 className="w-5 h-5 animate-bounce" />}
          </button>
        </div>

        {/* Large Countdown Display */}
        <div className="p-6 flex flex-col items-center justify-center bg-slate-900 border-b border-slate-800">
          <p className="text-xs font-semibold text-slate-400 uppercase tracking-widest mb-2">
            Zero-Touch Emergency Dispatch Countdown
          </p>
          <div className="relative flex items-center justify-center">
            <div className="w-32 h-32 rounded-full border-4 border-red-500/30 flex items-center justify-center bg-red-950/40 animate-pulse">
              <span className="text-6xl font-black text-red-400 tabular-nums">
                {secondsRemaining}
              </span>
            </div>
          </div>
          <p className="mt-3 text-xs text-center text-slate-300 max-w-xs">
            Emergency rescue and ambulance dispatch will be automatically triggered when the timer reaches zero if you cannot respond.
          </p>
        </div>

        {/* Impact Evidence & GPS Telemetry */}
        <div className="px-6 py-4 bg-slate-950/60 grid grid-cols-2 gap-3 text-xs">
          <div className="bg-slate-800/80 p-3 rounded-lg border border-slate-700 flex flex-col">
            <span className="text-slate-400 flex items-center gap-1.5 mb-1">
              <Activity className="w-3.5 h-3.5 text-red-400" />
              Peak Impact Force
            </span>
            <span className="text-base font-bold text-slate-100">{gForce} G</span>
            <span className="text-[10px] text-slate-400">Accelerometer Vector</span>
          </div>

          <div className="bg-slate-800/80 p-3 rounded-lg border border-slate-700 flex flex-col">
            <span className="text-slate-400 flex items-center gap-1.5 mb-1">
              <Clock className="w-3.5 h-3.5 text-amber-400" />
              Pre-Impact Speed
            </span>
            <span className="text-base font-bold text-slate-100">{speed} km/h</span>
            <span className="text-[10px] text-slate-400">Sudden Deceleration</span>
          </div>

          <div className="col-span-2 bg-slate-800/80 p-3 rounded-lg border border-slate-700 flex items-start gap-2.5">
            <MapPin className="w-4 h-4 text-emerald-400 mt-0.5 shrink-0" />
            <div className="flex-1 min-w-0">
              <span className="text-slate-400 font-semibold block text-[11px]">
                Impact GPS Coordinates
              </span>
              <span className="font-mono text-slate-200 text-xs truncate block">
                {lat}, {lng}
              </span>
              <span className="text-[10px] text-slate-400">
                Accuracy: {emergencyDetails?.locationAccuracy || 5}m ({emergencyDetails?.lastKnownLocation ? 'Last Known Location' : 'Live GPS Fix'})
              </span>
            </div>
          </div>
        </div>

        {/* Action Controls */}
        <div className="p-6 bg-slate-900 flex flex-col gap-3">
          <button
            onClick={onSendSOSNow}
            className="w-full py-4 px-6 bg-red-600 hover:bg-red-700 active:bg-red-800 text-white font-bold rounded-xl shadow-lg shadow-red-950/60 flex items-center justify-center gap-3 transition-all duration-150 transform hover:-translate-y-0.5 text-base"
          >
            <PhoneCall className="w-5 h-5 text-white" />
            SEND SOS NOW
          </button>

          <button
            onClick={onSafe}
            className="w-full py-3.5 px-6 bg-slate-800 hover:bg-slate-700 active:bg-slate-750 text-slate-200 font-semibold rounded-xl border border-slate-600 flex items-center justify-center gap-2.5 transition-colors text-sm"
          >
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
            I Am Safe (Cancel Alarm)
          </button>
        </div>
      </div>
    </div>
  );
}
