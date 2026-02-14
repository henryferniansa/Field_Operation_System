importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

// --- KONFIGURASI FIREBASE WEB ---
firebase.initializeApp({
  apiKey: "AIzaSyBSHvmJCuC63cH4a7kLUSP2EOwnVk53-_w",
  authDomain: "field-operation-mobile.firebaseapp.com",
  databaseURL: "https://field-operation-mobile-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "field-operation-mobile",
  storageBucket: "field-operation-mobile.firebasestorage.app",
  messagingSenderId: "286545418200",
  appId: "1:286545418200:web:1a7c73a4cf4fac45a3c4ad"
});

const messaging = firebase.messaging();

// --- PERBAIKAN DOUBLE NOTIFIKASI ---
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Pesan Background Masuk:', payload);

  // KITA HAPUS BAGIAN 'showNotification' DI SINI.
  // Mengapa? Karena payload dari Python sudah mengandung 'notification' & 'webpush'.
  // Browser akan menampilkannya secara otomatis.
  // Jika kita panggil showNotification lagi di sini, notifikasi jadi ganda.

  // return self.registration.showNotification(...);  <-- INI PENYEBABNYA (JANGAN DIPAKAI)
});