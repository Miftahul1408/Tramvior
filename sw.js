const CACHE = 'tramvior-v2';
const ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './img/logotramvior144.png',
  './img/logotramvior192.png',
  './img/logotramvior512.png',
  './img/on1.png',
  './img/on2.png',
  './img/on3.png'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(ASSETS)).catch(()=>{})
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE).map(k => caches.delete(k))
    ))
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;

  const sameOrigin = req.url.startsWith(self.location.origin);
  const isPage = req.mode === 'navigate' || req.destination === 'document';

  // Halaman HTML: network-first, supaya perubahan kode langsung terbaca.
  // Kalau offline, pakai cache.
  if (sameOrigin && isPage) {
    e.respondWith(
      fetch(req).then(res => {
        if (res && res.status === 200) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(req, clone));
        }
        return res;
      }).catch(() => caches.match(req).then(r => r || caches.match('./index.html')))
    );
    return;
  }

  // Aset lain (gambar, font, CDN): cache-first, update di belakang layar.
  e.respondWith(
    caches.match(req).then(cached => {
      const fetchPromise = fetch(req).then(res => {
        if (res && res.status === 200 && sameOrigin) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(req, clone));
        }
        return res;
      }).catch(() => cached);
      return cached || fetchPromise;
    })
  );
});