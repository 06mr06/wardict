importScripts("https://www.gstatic.com/firebasejs/9.15.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.15.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBXizglIJTCuJfR25OdbfKnVyr11cBaDj0",
  authDomain: "wardict-app.firebaseapp.com",
  projectId: "wardict-app",
  storageBucket: "wardict-app.firebasestorage.app",
  messagingSenderId: "241339661354",
  appId: "1:241339661354:web:7aae4ed632b4d4cfc75753",
  measurementId: "G-WWS6CZNLM0"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Arka plan bildirimi alındı: ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
