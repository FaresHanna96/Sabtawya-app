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

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(clients.openWindow('/'));
});
