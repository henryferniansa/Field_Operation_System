import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core, Views, Controllers
import 'core/app_colors.dart';
import 'views/other/splash_screen.dart';
import 'views/auth/login_page.dart';
import 'views/other/admin_page.dart';
import 'views/home/home_page.dart';
// import 'controllers/notif_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://figrasfxjghaygngaobu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZpZ3Jhc2Z4amdoYXlnbmdhb2J1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMzQsImV4cCI6MjA4NzM0NzMzNH0.EMEKBtLSUtYNuniVeGjAwD_YmqIS-knUSNQ1Ce1OwRI',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // final NotifController _notifController = NotifController();

  @override
  // void initState() {
  //   super.initState();
  //   _notifController.init();
  // }

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
       home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        print("Session: ${supabase.auth.currentSession}");
        if (session != null) {
          return const RoleCheckPage();
        }

        return const LoginPage();
      },
    );
  }
}

class RoleCheckPage extends StatelessWidget {
  const RoleCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const LoginPage();
    }

    return FutureBuilder(
      future: _loadUser(supabase, user.id),
      builder: (context, snapshot) {
        print("Snapshot state: ${snapshot.connectionState}");
        print("Snapshot data: ${snapshot.data}");
        print("Snapshot error: ${snapshot.error}");

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text("Error: ${snapshot.error}"),
            ),
          );
        }

        final userData = snapshot.data as Map<String, dynamic>?;

        if (userData == null) {
          supabase.auth.signOut();
          return const LoginPage();
        }

        return userData['role'] == 'admin'
            ? const AdminPage()
            : const HomePageUser();
      },
    );
  }

  Future<Map<String, dynamic>?> _loadUser(
      SupabaseClient supabase, String uid) async {
    final response = await supabase
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();

    print("QUERY RESULT: $response");

    return response;
  }
}
