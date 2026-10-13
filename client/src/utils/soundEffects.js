// FleetRoute Web Audio Synthesizer
// Clean synthesized chimes and alerts without external audio file dependencies.
// STRICTLY ZERO EMOJIS.

class SoundEffectsManager {
  constructor() {
    this.ctx = null;
    this.muted = false;
  }

  init() {
    if (!this.ctx && typeof window !== 'undefined') {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
      }
    }
  }

  setMuted(muted) {
    this.muted = muted;
  }

  isMuted() {
    return this.muted;
  }

  playActionClick() {
    if (this.muted) return;
    try {
      this.init();
      if (!this.ctx) return;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(440, this.ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(880, this.ctx.currentTime + 0.05);
      gain.gain.setValueAtTime(0.08, this.ctx.currentTime);
      gain.gain.linearRampToValueAtTime(0.001, this.ctx.currentTime + 0.08);
      osc.connect(gain);
      gain.connect(this.ctx.destination);
      osc.start();
      osc.stop(this.ctx.currentTime + 0.08);
    } catch {
      // Audio autoplay policy fallback
    }
  }

  playSuccessChime() {
    if (this.muted) return;
    try {
      this.init();
      if (!this.ctx) return;
      const t = this.ctx.currentTime;
      [523.25, 659.25, 783.99].forEach((freq, idx) => {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(freq, t + idx * 0.08);
        gain.gain.setValueAtTime(0.09, t + idx * 0.08);
        gain.gain.linearRampToValueAtTime(0.001, t + idx * 0.08 + 0.2);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start(t + idx * 0.08);
        osc.stop(t + idx * 0.08 + 0.22);
      });
    } catch {
      // Audio context error fallback
    }
  }

  playOverspeedAlert() {
    if (this.muted) return;
    try {
      this.init();
      if (!this.ctx) return;
      const t = this.ctx.currentTime;
      for (let i = 0; i < 3; i++) {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(950, t + i * 0.12);
        gain.gain.setValueAtTime(0.12, t + i * 0.12);
        gain.gain.linearRampToValueAtTime(0.01, t + i * 0.12 + 0.09);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start(t + i * 0.12);
        osc.stop(t + i * 0.12 + 0.1);
      }
    } catch {
      // Audio context error fallback
    }
  }

  playSeatbeltWarning() {
    if (this.muted) return;
    try {
      this.init();
      if (!this.ctx) return;
      const t = this.ctx.currentTime;
      for (let i = 0; i < 2; i++) {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(600, t + i * 0.18);
        gain.gain.setValueAtTime(0.1, t + i * 0.18);
        gain.gain.linearRampToValueAtTime(0.01, t + i * 0.18 + 0.12);
        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start(t + i * 0.18);
        osc.stop(t + i * 0.18 + 0.14);
      }
    } catch {
      // audio fallback
    }
  }

  playSOSAlert() {
    if (this.muted) return;
    try {
      this.init();
      if (!this.ctx) return;
      const t = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(880, t);
      osc.frequency.linearRampToValueAtTime(1320, t + 0.2);
      osc.frequency.linearRampToValueAtTime(880, t + 0.4);
      gain.gain.setValueAtTime(0.18, t);
      gain.gain.linearRampToValueAtTime(0.01, t + 0.45);
      osc.connect(gain);
      gain.connect(this.ctx.destination);
      osc.start(t);
      osc.stop(t + 0.46);
    } catch {
      // Audio context error fallback
    }
  }

  /**
   * Multilingual Speech Synthesis for Emergency Incident Voice Alarms
   * Automatically adapts to 'gu', 'hi', or 'en'
   */
  speakEmergencyVoice(lang = 'en') {
    if (this.muted) return;
    if (typeof window === 'undefined' || !window.speechSynthesis) return;

    try {
      window.speechSynthesis.cancel(); // cancel any active queue

      const phrases = {
        gu: 'કટોકટી ચેતવણી! અકસ્માત જણાયો છે. એમ્બ્યુલન્સ અને કટોકટી સહાય મોકલવામાં આવી રહી છે.',
        hi: 'आपातकालीन चेतावनी! दुर्घटना का पता चला है। आपातकालीन सहायता और एम्बुलेंस भेजी जा रही है।',
        en: 'Emergency alert! Vehicle incident detected. Dispatching emergency response and ambulance immediately.'
      };

      const langCodes = {
        gu: 'gu-IN',
        hi: 'hi-IN',
        en: 'en-IN'
      };

      const text = phrases[lang] || phrases.en;
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = langCodes[lang] || 'en-US';
      utterance.rate = 0.95;
      utterance.pitch = 1.05;
      utterance.volume = 1.0;

      // Select matching voice if available
      const voices = window.speechSynthesis.getVoices() || [];
      const match = voices.find(v => v.lang === utterance.lang || v.lang.startsWith(lang));
      if (match) {
        utterance.voice = match;
      }

      window.speechSynthesis.speak(utterance);
    } catch {
      // Speech synthesis error fallback
    }
  }

  playEmergencyAlarmLoop(lang = 'en') {
    if (this.muted) return () => {};
    this.init();

    // Voice announcement immediately
    this.speakEmergencyVoice(lang);

    if (!this.ctx) return () => {};

    let isAlarmActive = true;
    let burstCount = 0;
    const playBurst = () => {
      if (!isAlarmActive || !this.ctx) return;
      try {
        const t = this.ctx.currentTime;
        // Two-tone high urgency siren (850Hz -> 1250Hz)
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(850, t);
        osc.frequency.linearRampToValueAtTime(1250, t + 0.25);
        osc.frequency.linearRampToValueAtTime(850, t + 0.5);

        gain.gain.setValueAtTime(0.2, t);
        gain.gain.linearRampToValueAtTime(0.01, t + 0.48);

        osc.connect(gain);
        gain.connect(this.ctx.destination);
        osc.start(t);
        osc.stop(t + 0.5);

        burstCount++;
        // Repeat voice announcement every 8 siren bursts (approx every 7 seconds)
        if (burstCount % 8 === 0) {
          this.speakEmergencyVoice(lang);
        }

        // Trigger device vibration if supported
        if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
          navigator.vibrate([400, 200, 400]);
        }
      } catch {
        // audio policy fallback
      }
    };

    playBurst();
    const interval = setInterval(playBurst, 850);

    return () => {
      isAlarmActive = false;
      clearInterval(interval);
      if (typeof window !== 'undefined' && window.speechSynthesis) {
        window.speechSynthesis.cancel();
      }
      if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
        navigator.vibrate(0); // stop vibration
      }
    };
  }
}

export const soundEffects = new SoundEffectsManager();
