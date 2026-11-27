const CACHE_NAME = 'transport-one-cache-v1';

// Static resources needed to boot and run completely offline
const OFFLINE_CORE_ASSETS = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'google_maps_clean.js',
  'manifest.json',
  'favicon.png',
  'version.json'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(OFFLINE_CORE_ASSETS).catch((err) => {
        console.warn('[ServiceWorker] Pre-cache failed for some assets:', err);
      });
    })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Network-first with cache fallback strategy for real-time APIs,
// Cache-first / Stale-while-revalidate for static flutter scripts, styles, wasm, and fonts
self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // Ignore chrome extensions or non-http requests
  if (!url.protocol.startsWith('http')) return;

  // Realtime backend / Firestore / REST endpoints: Network first, don't break dynamic sync
  if (url.pathname.includes('/api/') || url.hostname.includes('firestore.googleapis.com')) {
    event.respondWith(
      fetch(req).catch(() => caches.match(req))
    );
    return;
  }

  // Application bundle, wasm, canvas, assets, HTML:
  // Serve from cache if available so app opens instantly with NO INTERNET, while updating in background
  event.respondWith(
    caches.match(req).then((cachedResponse) => {
      if (cachedResponse) {
        // Fetch fresh copy in background to keep cache updated
        fetch(req).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            caches.open(CACHE_NAME).then((cache) => cache.put(req, networkResponse));
          }
        }).catch(() => {});
        return cachedResponse;
      }

      // If not in cache, fetch from network and cache it
      return fetch(req).then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const resClone = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(req, resClone));
        }
        return networkResponse;
      }).catch(() => {
        // Fallback to index.html for navigation requests when totally offline
        if (req.mode === 'navigate') {
          return caches.match('./') || caches.match('index.html');
        }
      });
    })
  );
});

