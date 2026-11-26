// Keeps a copy of the app on the phone so it opens without internet.
//
// Network first: online, every file comes from the site as before (so a new
// version arrives at once) and the copy is refreshed. The copy is only used
// when the network does not answer. Data from the server is never touched: the
// app has its own offline store for that.
const CACHE = 'sabtawya-app-v1';

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
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (LIVE_ONLY.test(url.pathname)) return;

  // Every way of opening the app ("/", "/?n=...") is the same page.
  const key = request.mode === 'navigate' ? '/' : request;

  event.respondWith(
    fetch(request)
      .then(function (response) {
        if (response.ok && response.type === 'basic') {
          const copy = response.clone();
          event.waitUntil(
            caches.open(CACHE).then(function (cache) {
              return cache.put(key, copy);
            }),
          );
        }
        return response;
      })
      .catch(function (error) {
        return caches
          .match(key, { ignoreSearch: true })
          .then(function (saved) {
            if (saved) return saved;
            throw error;
          });
      }),
  );
});
