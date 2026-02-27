import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class JobController {
  final SupabaseClient _supabase;
  final Connectivity _connectivity;

  JobController({SupabaseClient? supabaseClient, Connectivity? connectivity})
    : _supabase = supabaseClient ?? Supabase.instance.client,
      _connectivity = connectivity ?? Connectivity();

  // --- CHECK ONLINE ---
  Future<bool> isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // --- TAMBAH LAPORAN ---
  Future<String> tambahLaporan(Map<String, dynamic> data) async {
    try {
      await _supabase
          .from('laporan_lapangan')
          .insert(data)
          .timeout(const Duration(milliseconds: 2500));

      return "Laporan Terkirim ke Server!";
    } on TimeoutException {
      return "Sinyal lambat. Disimpan di HP & dikirim otomatis nanti.";
    } catch (_) {
      return "Mode Offline. Disimpan di HP.";
    }
  }

  // --- AMBIL TUGAS ---
  Future<void> ambilTugas(String docId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Ambil data user dari tabel users
      final response =
          await _supabase
              .from('users')
              .select()
              .eq('id', user.id)
              .maybeSingle();

      final userData = response ?? {};

      await _supabase
          .from('laporan_lapangan')
          .update({
            'id_pengawas': user.id,
            'nama_pengawas': userData['nama'] ?? "Petugas",
            'jabatan_pengawas': userData['jabatan'] ?? "Lapangan",
            'badge_pengawas': userData['badge_id'] ?? "-",
            'status_pengerjaan': 'Sedang Dikerjakan',
            'waktu_update': DateTime.now().toIso8601String(),
          })
          .eq('id', docId);
    } catch (e) {
      rethrow;
    }
  }

  // --- HAPUS LAPORAN ---
  Future<void> hapusLaporan(String docId) async {
    try {
      await _supabase.from('laporan_lapangan').delete().eq('id', docId);
    } catch (e) {
      rethrow;
    }
  }

  // --- SELESAIKAN PEKERJAAN ---
  Future<void> selesaikanPekerjaan(String docId) async {
    try {
      await _supabase
          .from('laporan_lapangan')
          .update({
            'status_pengerjaan': 'Selesai',
            'waktu_selesai': DateTime.now().toIso8601String(),
          })
          .eq('id', docId);
    } catch (e) {
      rethrow;
    }
  }
}
