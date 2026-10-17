import { useState, useRef, useEffect } from 'react';
import { playNotificationChime, sendBrowserNotification } from '../utils/notifications';

function AlertIcon({ severity, category, size = 16 }) {
  if (category === 'Speed') {
    return (
      <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="m12 14 3-3"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/><circle cx="12" cy="14" r="2"/>
      </svg>
    );
  }
  if (category === 'Traffic') {
    return (
      <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <rect x="6" y="2" width="12" height="20" rx="3"/><circle cx="12" cy="6" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="12" cy="18" r="2"/>
      </svg>
    );
  }
  if (category === 'Maintenance') {
    return (
      <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M14.7 6.3a4 4 0 0 0-5-5L12 3.6 9.6 6 7.3 3.7a4 4 0 0 0 5 5l-8.6 8.6a2.1 2.1 0 0 0 3 3z"/>
      </svg>
    );
  }
  if (category === 'Route' || category === 'Geofence') {
    return (
      <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="5" cy="18" r="2"/><circle cx="19" cy="6" r="2"/><path d="M7 18h2a3 3 0 0 0 3-3V9a3 3 0 0 1 3-3h5"/>
      </svg>
    );
  }
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>
    </svg>
  );
}

export default function NotificationCenter({
  notifications = [],
  onMarkRead,
  onMarkAllRead,
  onClearAll,
  onDeleteNotification,
  onSelectAlertsPage,
}) {
  const [open, setOpen] = useState(false);
  const [filter, setFilter] = useState('all');
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [browserPerm, setBrowserPerm] = useState(
    typeof window !== 'undefined' && 'Notification' in window ? window.Notification.permission : 'default'
  );
  const dropdownRef = useRef(null);

  const unreadCount = notifications.filter((n) => !n.read).length;

  useEffect(() => {
    function handleClickOutside(event) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setOpen(false);
      }
    }
    if (open) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [open]);

  const requestBrowserPermission = async () => {
    if (typeof window === 'undefined' || !('Notification' in window)) return;
    try {
      const result = await window.Notification.requestPermission();
      setBrowserPerm(result);
      if (result === 'granted') {
        sendBrowserNotification('Notifications Enabled', 'FleetRoute real-time alerts are now enabled.');
        if (soundEnabled) playNotificationChime();
      }
    } catch {}
  };

  const filteredNotifications = notifications.filter((item) => {
    if (filter === 'unread') return !item.read;
    if (filter === 'critical') return item.severity === 'critical';
    if (filter === 'traffic') return item.category === 'Traffic' || item.category === 'Speed';
    return true;
  });

  return (
    <div className="notification-center-wrap" ref={dropdownRef}>
      <button
        className={`icon-button notification-bell-button${open ? ' active' : ''}`}
        type="button"
        aria-label={`Notifications (${unreadCount} unread)`}
        aria-expanded={open}
        onClick={() => setOpen(!open)}
      >
        <svg className="icon" width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" />
        </svg>
        {unreadCount > 0 && (
          <span className="bell-badge" aria-hidden="true">
            {unreadCount > 9 ? '9+' : unreadCount}
          </span>
        )}
      </button>

      {open && (
        <div className="notifications-dropdown" role="dialog" aria-label="Fleet Notifications">
          <div className="notif-header">
            <div className="notif-title-row">
              <div className="notif-heading-left">
                <h3>Notifications</h3>
                {unreadCount > 0 && <span className="notif-count-pill">{unreadCount} unread</span>}
              </div>
              <div className="notif-header-actions">
                {unreadCount > 0 && (
                  <button type="button" className="notif-text-btn" onClick={onMarkAllRead}>
                    Mark all read
                  </button>
                )}
                {notifications.length > 0 && (
                  <button type="button" className="notif-text-btn" onClick={onClearAll}>
                    Clear
                  </button>
                )}
              </div>
            </div>

            <div className="notif-controls-row">
              <button
                type="button"
                className={`notif-toggle-btn${soundEnabled ? ' active' : ''}`}
                onClick={() => setSoundEnabled(!soundEnabled)}
                title="Toggle alert sound chime"
              >
                <span>Sound: {soundEnabled ? 'ON' : 'Muted'}</span>
              </button>

              <button
                type="button"
                className={`notif-toggle-btn${browserPerm === 'granted' ? ' active' : ''}`}
                onClick={requestBrowserPermission}
                title="Browser desktop notification permission"
              >
                <span>Desktop: {browserPerm === 'granted' ? 'Allowed' : 'Enable'}</span>
              </button>
            </div>

            <div className="notif-filter-tabs" role="tablist">
              <button
                type="button"
                role="tab"
                aria-selected={filter === 'all'}
                className={`notif-tab${filter === 'all' ? ' active' : ''}`}
                onClick={() => setFilter('all')}
              >
                All ({notifications.length})
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={filter === 'unread'}
                className={`notif-tab${filter === 'unread' ? ' active' : ''}`}
                onClick={() => setFilter('unread')}
              >
                Unread ({unreadCount})
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={filter === 'critical'}
                className={`notif-tab${filter === 'critical' ? ' active' : ''}`}
                onClick={() => setFilter('critical')}
              >
                Critical
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={filter === 'traffic'}
                className={`notif-tab${filter === 'traffic' ? ' active' : ''}`}
                onClick={() => setFilter('traffic')}
              >
                Speed & Traffic
              </button>
            </div>
          </div>

          <div className="notif-list">
            {filteredNotifications.length === 0 ? (
              <div className="notif-empty">
                <span className="notif-empty-icon">✓</span>
                <p>No {filter !== 'all' ? filter : ''} notifications</p>
                <small>You are caught up with all fleet alerts.</small>
              </div>
            ) : (
              filteredNotifications.map((notif) => (
                <div
                  key={notif.id}
                  className={`notif-item ${notif.severity}${notif.read ? ' read' : ' unread'}`}
                  onClick={() => onMarkRead(notif.id)}
                >
                  <div className={`notif-severity-icon ${notif.severity}`}>
                    <AlertIcon severity={notif.severity} category={notif.category} size={15} />
                  </div>
                  <div className="notif-content">
                    <div className="notif-top-line">
                      <strong className="notif-title">{notif.title}</strong>
                      <span className="notif-time">{notif.time}</span>
                    </div>
                    <p className="notif-msg">{notif.message}</p>
                    <div className="notif-meta">
                      <span className={`notif-badge ${notif.severity}`}>{notif.category}</span>
                      {notif.vehicleId && <span className="notif-vehicle">{notif.vehicleId}</span>}
                    </div>
                  </div>
                  <div className="notif-item-actions" onClick={(e) => e.stopPropagation()}>
                    <button
                      type="button"
                      className="notif-del-btn"
                      onClick={() => onDeleteNotification(notif.id)}
                      title="Dismiss notification"
                    >
                      ✕
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>

          <div className="notif-footer">
            <button
              type="button"
              className="notif-view-all-btn"
              onClick={() => {
                setOpen(false);
                onSelectAlertsPage();
              }}
            >
              Open Alerts & Operations Dashboard →
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export function NotificationToasts({ toasts = [], onDismissToast }) {
  return (
    <div className="notif-toast-container" aria-live="polite">
      {toasts.map((toast) => (
        <div key={toast.id} className={`notif-toast ${toast.severity || 'info'}`}>
          <div className={`notif-toast-icon ${toast.severity || 'info'}`}>
            <AlertIcon severity={toast.severity} category={toast.category} size={17} />
          </div>
          <div className="notif-toast-body">
            <strong>{toast.title}</strong>
            <p>{toast.message}</p>
          </div>
          <button
            type="button"
            className="notif-toast-close"
            onClick={() => onDismissToast(toast.id)}
            aria-label="Close alert"
          >
            ✕
          </button>
        </div>
      ))}
    </div>
  );
}
