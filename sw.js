const CACHE = 'md-viewer-v4';
const ASSETS = ['./', './index.html', './manifest.json', './icon.svg',
  './vendor/markdown-it.min.js', './vendor/marked.min.js', './vendor/purify.min.js',
  './vendor/highlight.min.js', './vendor/github.min.css'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || new URL(e.request.url).origin !== location.origin) return;
  e.respondWith(caches.match(e.request).then(hit => hit || fetch(e.request)));
});
