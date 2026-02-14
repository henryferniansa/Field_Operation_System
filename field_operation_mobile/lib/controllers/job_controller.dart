import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class JobController {
  final CollectionReference _jobRef = FirebaseFirestore.instance.collection('laporan_lapangan');

  Future<bool> isOnline() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // --- TAMBAH LAPORAN ---
  Future<String> tambahLaporan(Map<String, dynamic> data) async {
    try {
      // Timeout 2.5 detik agar UI tidak hang
      try {
        await _jobRef.add(data).timeout(const Duration(milliseconds: 2500));
        return "Laporan Terkirim ke Server!";
      } on TimeoutException {
        return "Sinyal lambat. Disimpan di HP & dikirim otomatis nanti.";
      } catch (e) {
        return "Mode Offline. Disimpan di HP.";
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- AMBIL TUGAS ---
  Future<void> ambilTugas(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache));

      Map<String, dynamic> userData = userDoc.data() ?? {};

      if (userData.isEmpty) {
        final serverDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        userData = serverDoc.data() ?? {};
      }

      await _jobRef.doc(docId).update({
        'id_pengawas': user.uid,
        'nama_pengawas': userData['nama'] ?? "Petugas",
        'jabatan_pengawas': userData['jabatan'] ?? "Lapangan",
        'badge_pengawas': userData['badge_id'] ?? "-",
        'status_pengerjaan': 'Sedang Dikerjakan',
        'waktu_update': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // --- HAPUS LAPORAN (BARU) ---
  Future<void> hapusLaporan(String docId) async {
    try {
      await _jobRef.doc(docId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // --- SELESAIKAN PEKERJAAN (BARU) ---
  Future<void> selesaikanPekerjaan(String docId) async {
    try {
      await _jobRef.doc(docId).update({
        'status_pengerjaan': 'Selesai',
        'waktu_selesai': FieldValue.serverTimestamp()
      });
    } catch (e) {
      rethrow;
    }
  }
}