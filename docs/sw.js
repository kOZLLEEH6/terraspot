/* Macht das Schriftlabor offline lauffähig — vor allem für den Fall, dass es
   auf dem iPad als App auf dem Home-Bildschirm liegt und unterwegs kein Netz da ist.
   Die Seite selbst kommt zuerst aus dem Netz, damit Änderungen ankommen; nur wenn
   das scheitert, springt der Zwischenspeicher ein. Schriften umgekehrt: die ändern
   sich nie, also erst nachsehen, dann laden. */
const CACHE = 'schriftlabor-v1';
const KERN = ['./', './index.html'];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(KERN))
      .catch(() => {})
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(namen => Promise.all(namen.filter(n => n !== CACHE).map(n => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const istSchrift = /(^|\.)(googleapis|gstatic)\.com$/.test(url.hostname);

  if (istSchrift) {
    e.respondWith((async () => {
      const treffer = await caches.match(req);
      if (treffer) return treffer;
      try {
        const res = await fetch(req);
        if (res && (res.ok || res.type === 'opaque')) (await caches.open(CACHE)).put(req, res.clone());
        return res;
      } catch (err) {
        return new Response('', { status: 504, statusText: 'offline' });
      }
    })());
    return;
  }

  if (url.origin === location.origin) {
    e.respondWith((async () => {
      try {
        const res = await fetch(req);
        if (res && res.ok) (await caches.open(CACHE)).put(req, res.clone());
        return res;
      } catch (err) {
        return (await caches.match(req)) || (await caches.match('./index.html')) ||
               new Response('Offline und nicht im Zwischenspeicher.', { status: 503 });
      }
    })());
  }
});
