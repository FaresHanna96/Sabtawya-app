// Shows background push notifications (app closed or tab hidden).
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyASmWEC8FPkfXLRt1VLX4gj4mcRdOrE114',
  appId: '1:202734221696:web:ca324a1126e9e55d7b6965',
  messagingSenderId: '202734221696',
  projectId: 'sabtawya-a4907',
});

// A tap opens what the notification is about: an open app is told through a
// message, a closed one is opened at /?n=<id>. Added before
// firebase.messaging(), so its own click handling does not also run.
self.addEventListener('notificationclick', function (event) {
  event.stopImmediatePropagation();
  event.notification.close();
  const fcm = event.notification.data && event.notification.data.FCM_MSG;
  const data = (fcm && fcm.data) || {};
  const url = data.notification_id
    ? '/?n=' + encodeURIComponent(data.notification_id)
    : '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      // The app itself, not the download or statistics pages.
      const app = list.find(function (c) {
        const path = new URL(c.url).pathname;
        return path === '/' || path === '/index.html';
      });
      if (!app) return clients.openWindow(url);
      const tap = Object.assign({}, data, {
        title: fcm && fcm.notification && fcm.notification.title,
        body: fcm && fcm.notification && fcm.notification.body,
      });
      app.postMessage({ sabtawyaTap: tap });
      return app.focus();
    }),
  );
});

// Messages carry a `notification` block, so the browser displays them itself.
firebase.messaging();

// Puts the unread count (sent with the push) on the home-screen icon, also
// while the app is closed. Ignored where the Badging API does not exist.
self.addEventListener('push', function (event) {
  try {
    const payload = event.data ? event.data.json() : null;
    const badge = parseInt((payload && payload.data && payload.data.badge) || '', 10);
    if (!isNaN(badge) && self.navigator && self.navigator.setAppBadge) {
      event.waitUntil(
        badge > 0 ? self.navigator.setAppBadge(badge) : self.navigator.clearAppBadge(),
      );
    }
  } catch (e) {
    // A badge is a nicety; never break the notification.
  }
});
