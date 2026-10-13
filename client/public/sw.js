// client/public/sw.js
const CACHE_NAME = 'fleetroute-v2-prod';

self.addEventListener('install', (e) => {
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        })
      );
    }).then(() => clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  // Never cache or return stale authenticated operational API calls in ServiceWorker
  if (e.request.url.includes('/api/')) {
    return;
  }

  // Network first for static assets, fall back to cache when offline
  e.respondWith(
    fetch(e.request).catch(() => caches.match(e.request))
  );
});

