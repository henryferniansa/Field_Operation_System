import 'package:firebase_auth/firebase_auth.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fungsi Login
  Future<void> login(String badgeId, String password) async {
    try {
      // Format email sesuai aturan bisnis aplikasi (badge_id@fieldops.com)
      String email = "${badgeId.trim()}@fieldops.com";

      await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );
    } catch (e) {
      // Lempar error agar bisa ditangkap oleh UI (Login Page) untuk menampilkan Snackbar
      rethrow;
    }
  }

  // Fungsi Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Cek User saat ini
  User? get currentUser => _auth.currentUser;
}