import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../main.dart'; // Import AuthWrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () => setState(() => _opacity = 1.0));
    Timer(const Duration(seconds: 2), () => setState(() => _opacity = 0.0));
    Timer(const Duration(seconds: 3), () => _cekSesiLogin());
  }

  void _cekSesiLogin() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(pageBuilder: (_, __, ___) => const AuthWrapper(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c), transitionDuration: const Duration(milliseconds: 800)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: AnimatedOpacity(duration: const Duration(seconds: 1), opacity: _opacity, curve: Curves.easeInOut, child: Padding(padding: const EdgeInsets.all(40.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset('assets/logo.png', width: 250, fit: BoxFit.contain), // Pastikan logo.png ada
          const SizedBox(height: 20),
          const Text("PT. LINTAS KELOLA BERLABA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark, letterSpacing: 1.2), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.amber)),
        ]))),
      ),
    );
  }
}