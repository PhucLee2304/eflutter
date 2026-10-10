importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBeLDixMeMegdpILsMDSfifldnd9yIHPrc',
  appId: '1:606864643626:web:12c9a30120fc96b0e19553',
  messagingSenderId: '606864643626',
  projectId: 'myego-6165a',
  authDomain: 'myego-6165a.firebaseapp.com',
  storageBucket: 'myego-6165a.firebasestorage.app'
});

firebase.messaging();
