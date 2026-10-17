export const FLEET_NOTIFICATION_EVENT = 'fleet-notification';

export const INITIAL_NOTIFICATIONS = [];

export function playNotificationChime() {
  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;
    const ctx = new AudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(587.33, ctx.currentTime); // D5
    osc.frequency.setValueAtTime(880, ctx.currentTime + 0.08); // A5
    gain.gain.setValueAtTime(0.12, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.35);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.35);
  } catch { }
}

export function sendBrowserNotification(title, body) {
  if (typeof window === 'undefined' || !('Notification' in window)) return;
  if (window.Notification.permission === 'granted') {
    try {
      new window.Notification(title, {
        body,
        icon: '/favicon.ico',
      });
    } catch { }
  }
}

export function dispatchFleetNotification(notification) {
  if (typeof window === 'undefined') return;
  const event = new CustomEvent(FLEET_NOTIFICATION_EVENT, {
    detail: {
      id: `alert-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
      time: 'Just now',
      timestamp: Date.now(),
      read: false,
      resolved: false,
      ...notification,
    },
  });
  window.dispatchEvent(event);
}


