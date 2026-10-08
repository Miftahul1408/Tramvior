const CACHE = 'tramvior-v3';

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

// Library dari CDN yang dibutuhkan agar tampilan tetap utuh saat offline
const CDN = [
  'https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css',
  'https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap',
  'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => Promise.allSettled([
      // satu file gagal tidak membatalkan yang lain
      ...ASSETS.map(u => c.add(u)),
      ...CDN.map(u =>
        fetch(new Request(u, { mode: 'no-cors' })).then(r => c.put(u, r))
      )
    ]))
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

const cacheable = res =>
  res && (res.ok || res.type === 'opaque');

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET' || !req.url.startsWith('http')) return;

  const sameOrigin = req.url.startsWith(self.location.origin);
  const isPage = req.mode === 'navigate' || req.destination === 'document';

  // Halaman HTML: network-first, offline pakai cache.
  if (sameOrigin && isPage) {
    e.respondWith(
      fetch(req).then(res => {
        if (cacheable(res)) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(req, clone));
        }
        return res;
      }).catch(() => caches.match(req).then(r => r || caches.match('./index.html')))
    );
    return;
  }

  // Aset lain (gambar, font, CDN): cache-first, diperbarui di belakang layar.
  e.respondWith(
    caches.match(req).then(cached => {
      const fetchPromise = fetch(req).then(res => {
        if (cacheable(res)) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(req, clone));
        }
        return res;
      }).catch(() => cached);
      return cached || fetchPromise;
    })
  );
});