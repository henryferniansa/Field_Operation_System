import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotifController {
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

  // Setup saat aplikasi dibuka
  Future<void> init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Auto Request Permission
    NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      saveTokenToDatabase(); // Auto Save Token
    }

    // Channel Android
    if (!kIsWeb) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', 'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );
      await _localNotif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    }

    // Listener Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (!kIsWeb && notification != null && android != null) {
        _localNotif.show(
          notification.hashCode, notification.title, notification.body,
          NotificationDetails(android: AndroidNotificationDetails('high_importance_channel', 'High Importance', icon: 'launch_background')),
        );
      }
    });
  }

  // Fungsi Simpan Token (Bisa dipanggil manual dari tombol Profile)
  Future<void> saveTokenToDatabase({BuildContext? context}) async {
    try {
      if (context != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menghubungkan...")));

      // VAPID KEY ANDA
      String vapidKey = "BNYrECEUoBfj9se2yn87kX4-_EV_Ngg-OU7fUANxFIs4VnXB2w3giZJrYVDXH32RzSiapsiZbCRRuesmnvs_uts";
      String? token;

      if (kIsWeb) {
        token = await FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
      } else {
        token = await FirebaseMessaging.instance.getToken();
      }

      final user = FirebaseAuth.instance.currentUser;
      if (token != null && user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcm_token': token,
          'platform': kIsWeb ? 'web' : 'android/ios',
          'last_token_update': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (context != null && context.mounted) {
          showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Sukses!"), content: const Text("Notifikasi Aktif."), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
        }
      }
    } catch (e) {
      if (context != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }
}