import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Import Core, Views, Controllers
import 'core/app_colors.dart';
import 'views/other/splash_screen.dart';
import 'views/auth/login_page.dart';
import 'views/other/admin_page.dart';
import 'views/home/home_page.dart';
import 'controllers/notif_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // AKTIFKAN OFFLINE PERSISTENCE
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, // Data tetap ada walau app ditutup/offline
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final NotifController _notifController = NotifController();

  @override
  void initState() {
    super.initState();
    _notifController.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field Operation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: AppColors.primaryMaterial,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.surface,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, surface: Colors.white),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, centerTitle: true),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
      ),
      home: const SplashScreen(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return const RoleCheckPage();
        return const LoginPage();
      },
    );
  }
}

class RoleCheckPage extends StatelessWidget {
  const RoleCheckPage({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) { FirebaseAuth.instance.signOut(); return const LoginPage(); }
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        return userData['role'] == 'admin' ? const AdminPage() : const HomePageUser();
      },
    );
  }
}