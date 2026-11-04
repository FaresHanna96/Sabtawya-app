// Shows background push notifications (app closed or tab hidden).
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyASmWEC8FPkfXLRt1VLX4gj4mcRdOrE114',
  appId: '1:202734221696:web:ca324a1126e9e55d7b6965',
  messagingSenderId: '202734221696',
  projectId: 'sabtawya-a4907',
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

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(clients.openWindow('/'));
});
