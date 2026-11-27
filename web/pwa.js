// What only the website needs from the browser: installing, keeping the screen
// on, vibration, files shared to the app and the fingerprint / Face ID lock.
// Loaded before the app so nothing the browser says early is missed. The Dart
// side is lib/core/services/web_pwa_web.dart.
window.sabtawyaPwa = (function () {
  var SHARED = 'sabtawya-shared';

  // ── how the app was opened ────────────────────────────────────────────────
  // An icon shortcut (?go=) or the share sheet (?shared=1). Taken out of the
  // address so a reload does not do it again.
  var params = new URLSearchParams(location.search);
  var go = params.get('go') || '';
  var shared = params.get('shared') === '1';
  if (params.has('go') || params.has('shared')) {
    params.delete('go');
    params.delete('shared');
    var query = params.toString();
    history.replaceState(null, '',
      location.pathname + (query ? '?' + query : '') + location.hash);
  }

  // ── installing ────────────────────────────────────────────────────────────
  var installEvent = null;
  var installListener = null;
  function tell() {
    if (installListener) installListener(installEvent !== null);
  }
  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    installEvent = event;
    tell();
  });
  window.addEventListener('appinstalled', function () {
    installEvent = null;
    tell();
  });

  // ── keeping the screen on ─────────────────────────────────────────────────
  var awake = false;
  var wakeLock = null;
  function holdScreen() {
    if (!awake || wakeLock || !navigator.wakeLock ||
        document.visibilityState !== 'visible') return;
    navigator.wakeLock.request('screen').then(function (lock) {
      if (!awake) return lock.release();
      wakeLock = lock;
      lock.addEventListener('release', function () { wakeLock = null; });
    }).catch(function () {});
  }
  // The browser lets go whenever the page is hidden.
  document.addEventListener('visibilitychange', holdScreen);

  // ── fingerprint / Face ID ─────────────────────────────────────────────────
  // A passkey kept by this device, used only to open the screen lock: nothing
  // is sent anywhere and nothing is checked by a server.
  function random(n) { return crypto.getRandomValues(new Uint8Array(n)); }
  function toText(buffer) {
    return btoa(String.fromCharCode.apply(null, new Uint8Array(buffer)));
  }
  function toBytes(text) {
    return Uint8Array.from(atob(text), function (c) { return c.charCodeAt(0); });
  }

  return {
    launchShortcut: function () { var g = go; go = ''; return g; },
    launchShared: function () { var s = shared; shared = false; return s; },

    onInstallChange: function (listener) {
      installListener = listener;
      tell();
    },
    install: function () {
      var event = installEvent;
      if (!event) return Promise.resolve(false);
      installEvent = null;
      tell();
      event.prompt();
      return event.userChoice.then(function (c) {
        return c.outcome === 'accepted';
      });
    },

    // Asks the browser not to clear the saved data (and unsent saves) when it
    // runs short of space. It may refuse.
    persist: function () {
      if (navigator.storage && navigator.storage.persist) {
        navigator.storage.persist().catch(function () {});
      }
    },

    vibrate: function (ms) {
      if (navigator.vibrate) {
        try { navigator.vibrate(ms); } catch (e) {}
      }
    },

    keepAwake: function (on) {
      awake = on;
      if (on) return holdScreen();
      if (wakeLock) wakeLock.release().catch(function () {});
      wakeLock = null;
    },

    // True the first time for a build, so a forced reload can never loop.
    firstReloadFor: function (build) {
      try {
        var key = 'sabtawya-reloaded-for';
        if (sessionStorage.getItem(key) === String(build)) return false;
        sessionStorage.setItem(key, String(build));
        return true;
      } catch (e) {
        return false;
      }
    },

    // The files app-sw.js kept from the share sheet, handed over once.
    takeShared: function () {
      if (!window.caches) return Promise.resolve([]);
      return caches.open(SHARED).then(function (cache) {
        return cache.keys().then(function (keys) {
          return Promise.all(keys.map(function (key) {
            return cache.match(key).then(function (response) {
              return response.blob().then(function (blob) {
                var name = decodeURIComponent(
                  response.headers.get('x-name') || 'file');
                return new File([blob], name, { type: blob.type });
              });
            });
          }));
        });
      }).then(function (files) {
        return caches.delete(SHARED).then(function () { return files; });
      });
    },
    clearShared: function () {
      return window.caches ? caches.delete(SHARED) : Promise.resolve(false);
    },

    passkeySupported: function () {
      var c = window.PublicKeyCredential;
      if (!c || !c.isUserVerifyingPlatformAuthenticatorAvailable) {
        return Promise.resolve(false);
      }
      return c.isUserVerifyingPlatformAuthenticatorAvailable()
        .catch(function () { return false; });
    },
    // The new passkey's id, or '' when the person cancelled.
    passkeyCreate: function (name) {
      return navigator.credentials.create({
        publicKey: {
          challenge: random(32),
          rp: { name: 'سبتاوية' },
          user: { id: random(16), name: name, displayName: name },
          pubKeyCredParams: [
            { type: 'public-key', alg: -7 },
            { type: 'public-key', alg: -257 },
          ],
          authenticatorSelection: {
            authenticatorAttachment: 'platform',
            userVerification: 'required',
          },
          timeout: 60000,
        },
      }).then(function (c) { return c ? toText(c.rawId) : ''; })
        .catch(function () { return ''; });
    },
    passkeyCheck: function (id) {
      return navigator.credentials.get({
        publicKey: {
          challenge: random(32),
          allowCredentials: [{ type: 'public-key', id: toBytes(id) }],
          userVerification: 'required',
          timeout: 60000,
        },
      }).then(function (c) { return c !== null; })
        .catch(function () { return false; });
    },
  };
})();
