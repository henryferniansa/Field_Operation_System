import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../controllers/auth_controller.dart'; // Import Controller

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _badgeController = TextEditingController();
  final _passController = TextEditingController();
  final AuthController _authController = AuthController(); // Panggil Controller
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // Panggil fungsi login dari Controller
      await _authController.login(_badgeController.text, _passController.text);
      // Jika sukses, StreamBuilder di main.dart akan otomatis mengarahkan ke Home
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login Gagal. Cek Badge ID/Password."), backgroundColor: Colors.red)
        );
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.engineering, size: 80, color: AppColors.primary),
                const SizedBox(height: 20),
                const Text("FIELD OPERATION", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 30),

                TextField(
                    controller: _badgeController,
                    decoration: const InputDecoration(labelText: "Badge ID", border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge))
                ),
                const SizedBox(height: 15),

                TextField(
                    controller: _passController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))
                ),
                const SizedBox(height: 20),

                SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: Text(_isLoading ? "Loading..." : "MASUK")
                    )
                )
              ]
          )
      ),
    );
  }
}