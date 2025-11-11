// firebase-messaging-sw.js

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker
firebase.initializeApp({
    apiKey: "AIzaSyBYG1ZBHasqzdp44GDmStLTRxjk9pIWXIU",
    authDomain: "feelings-d43f8.firebaseapp.com",
    projectId: "feelings-d43f8",
    storageBucket: "feelings-d43f8.firebasestorage.app",
    messagingSenderId: "378934878895",
    appId: "1:378934878895:web:9d4a464af6c658756eea5a",
    measurementId: "G-GFZLNQ1KLQ"
});

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();
