// Keeps a copy of the app on the phone so it opens without internet.
//
// Network first: online, every file comes from the site as before (so a new
// version arrives at once) and the copy is refreshed. The copy is only used
// when the network does not answer, or is too slow to wait for. Data from the
// server is never touched: the app has its own offline store for that.
//
// It also receives files shared to the installed app (manifest.json,
// share_target) and keeps them until the app picks them up (pwa.js).
const CACHE = 'sabtawya-app-v1';
const SHARED = 'sabtawya-shared';

// How long the network may take before the saved copy is used instead.
const SLOW_MS = 4000;

// Set while the app was opened from the saved copy: the rest of its files then
// come from it too, without waiting each time.
let slow = false;

// Always the live one, or nothing: the update check, the downloads and the
// public pages.
const LIVE_ONLY = /(version\.json|\.apk|apk\.html|stats\.html)$/;

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches
      .keys()
      .then(function (names) {
        return Promise.all(
          names
            .filter(function (n) {
              return n.startsWith('sabtawya-app-') && n !== CACHE;
            })
            .map(function (n) {
              return caches.delete(n);
            }),
        );
      })
      .then(function () {
        return self.clients.claim();
      }),
  );
});

// The page lists what it loaded before this worker was there: save the ones
// not saved yet.
self.addEventListener('message', function (event) {
  const list = event.data && event.data.save;
  if (!Array.isArray(list)) return;
  event.waitUntil(
    caches.open(CACHE).then(function (cache) {
      return Promise.all(
        list.map(function (item) {
          const url = new URL(item, self.location.origin);
          if (url.origin !== self.location.origin) return null;
          if (LIVE_ONLY.test(url.pathname)) return null;
          return cache.match(url.href).then(function (saved) {
            if (saved) return null;
            return cache.add(url.href).catch(function () {});
          });
        }),
      );
    }),
  );
});

self.addEventListener('fetch', function (event) {
  const request = event.request;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (request.method === 'POST' && url.pathname === '/share-target') {
    event.respondWith(keepShared(request));
    return;
  }
  if (request.method !== 'GET') return;
  if (LIVE_ONLY.test(url.pathname)) return;
  event.respondWith(answer(event, request));
});

async function answer(event, request) {
  const opening = request.mode === 'navigate';
  // Every way of opening the app ("/", "/?n=...") is the same page.
  const key = opening ? '/' : request;
  if (opening) slow = false;

  const network = fetch(request).then(function (response) {
    if (response.ok && response.type === 'basic') {
      const copy = response.clone();
      event.waitUntil(
        caches.open(CACHE).then(function (cache) {
          return cache.put(key, copy);
        }),
      );
    }
    return response;
  });

  const saved = await caches.match(key, { ignoreSearch: true });
  if (!saved) return network;

  // Still fetched when the copy answers first, so the next opening is newer.
  const arrived = network.catch(function () {
    return null;
  });
  event.waitUntil(arrived);
  if (slow) return saved;

  const first = await Promise.race([
    arrived,
    new Promise(function (resolve) {
      setTimeout(resolve, SLOW_MS, null);
    }),
  ]);
  if (first) return first;
  if (opening) slow = true;
  return saved;
}

// Photos and PDFs from the share sheet: kept, then the app is opened. Only the
// last share is kept.
async function keepShared(request) {
  try {
    const form = await request.formData();
    await caches.delete(SHARED);
    const cache = await caches.open(SHARED);
    const files = form.getAll('files').slice(0, 10);
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      await cache.put(
        '/shared/' + i,
        new Response(file, {
          headers: {
            'content-type': file.type || 'application/octet-stream',
            'x-name': encodeURIComponent(file.name || 'file'),
          },
        }),
      );
    }
  } catch (e) {
    // Open the app all the same; it then finds nothing to attach.
  }
  return Response.redirect('/?shared=1', 303);
}
