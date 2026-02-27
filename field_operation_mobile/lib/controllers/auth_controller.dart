import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController {
  final SupabaseClient _supabase;

  AuthController({SupabaseClient? supabaseClient})
    : _supabase = supabaseClient ?? Supabase.instance.client;

  // --- LOGIN ---
  Future<void> login(String badgeId, String password) async {
    try {
      // Format email sesuai aturan bisnis (badge_id@fieldops.com)
      final email = "${badgeId.trim()}@fieldops.com";

      await _supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      // Tetap lempar error agar UI bisa tangkap dan tampilkan Snackbar
      rethrow;
    }
  }

  // --- LOGOUT ---
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // --- CURRENT USER ---
  User? get currentUser => _supabase.auth.currentUser;
}
