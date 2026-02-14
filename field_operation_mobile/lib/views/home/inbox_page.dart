import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';
import '../../controllers/job_controller.dart';

class InboxTugasPage extends StatelessWidget {
  const InboxTugasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final JobController jobController = JobController();

    return Scaffold(
      backgroundColor: AppColors.surface,

      appBar: AppBar(
        title: const Text("Tugas Masuk", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        // Actions dihapus karena indikator sudah ada di bawah (Global)
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('laporan_lapangan').where('status_pengerjaan', isEqualTo: 'Pending').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.where((doc) { final data = doc.data() as Map<String, dynamic>; final owner = data['id_pengawas']; return owner == null || owner == "" || owner == "-"; }).toList();
          docs.sort((a, b) { Timestamp tA = (a.data() as Map<String, dynamic>)['waktu_dibuat'] ?? Timestamp.now(); Timestamp tB = (b.data() as Map<String, dynamic>)['waktu_dibuat'] ?? Timestamp.now(); return tB.compareTo(tA); });

          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), const Text("Tidak ada tugas baru", style: TextStyle(color: Colors.grey))]));

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 20), itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index]; final data = doc.data() as Map<String, dynamic>;
              return Card(
                elevation: 0, margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6), color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.card, width: 1)),
                child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Icon(Icons.new_releases_outlined, color: AppColors.amber, size: 22), const SizedBox(width: 8), Expanded(child: Text(data['judul'] ?? "Tanpa Judul", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.amber.withValues(alpha: 0.2))), child: Text(data['urgency'] ?? 'Normal', style: const TextStyle(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.bold)))]),
                  const SizedBox(height: 8), Text(data['deskripsi'] ?? "-", style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12), Row(children: [const Icon(Icons.place, size: 16, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(data['lokasi_manual'] ?? "-", style: const TextStyle(fontSize: 13, color: Colors.black87)))]),
                  const Divider(height: 24), SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { try { await jobController.ambilTugas(doc.id); if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tugas berhasil diambil!"))); } catch (e) { if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); } }, icon: const Icon(Icons.handshake, size: 20), label: const Text("KERJAKAN SEKARANG", style: TextStyle(fontWeight: FontWeight.bold))))
                ])),
              );
            },
          );
        },
      ),
    );
  }
}