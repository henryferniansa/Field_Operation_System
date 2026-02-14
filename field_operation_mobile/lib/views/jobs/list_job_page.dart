import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_colors.dart';
import '../../controllers/job_controller.dart'; // Import Controller
import 'form_job_page.dart';

class ListLaporanPage extends StatefulWidget {
  const ListLaporanPage({super.key});
  @override
  State<ListLaporanPage> createState() => _ListLaporanPageState();
}

class _ListLaporanPageState extends State<ListLaporanPage> {
  // Panggil Controller
  final JobController _jobController = JobController();

  DateTime _filterTanggal = DateTime.now();

  Future<void> _pilihTanggal() async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _filterTanggal,
        firstDate: DateTime(2024),
        lastDate: DateTime(2030),
        helpText: "Pilih Tanggal Laporan"
    );
    if (picked != null && !_isSameDay(picked, _filterTanggal)) {
      setState(() => _filterTanggal = picked);
    }
  }

  void _resetKeHariIni() {
    if (!_isSameDay(_filterTanggal, DateTime.now())) {
      setState(() => _filterTanggal = DateTime.now());
    }
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  // --- LOGIKA HAPUS (VIA CONTROLLER) ---
  Future<void> _hapusLaporan(BuildContext context, String idDokumen) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Hapus Laporan"),
          content: const Text("Yakin hapus data ini?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text("Hapus", style: TextStyle(color: Colors.white))),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // PANGGIL CONTROLLER DI SINI
        await _jobController.hapusLaporan(idDokumen);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan berhasil dihapus")));
      } catch(e) {
        debugPrint("Gagal hapus: $e");
      }
    }
  }

  // --- LOGIKA SELESAI (VIA CONTROLLER) ---
  Future<void> _selesaikanPekerjaan(String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Selesaikan Pekerjaan"),
          content: const Text("Status akan berubah menjadi SELESAI."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), onPressed: () => Navigator.pop(ctx, true), child: const Text("Ya, Selesai", style: TextStyle(color: Colors.white))),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // PANGGIL CONTROLLER DI SINI
        await _jobController.selesaikanPekerjaan(docId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pekerjaan Selesai!"), backgroundColor: AppColors.primary));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  String _formatTanggal(Timestamp? timestamp) {
    if (timestamp == null) return "-";
    DateTime date = timestamp.toDate();
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatJam(Timestamp? timestamp) {
    if (timestamp == null) return "...";
    DateTime date = timestamp.toDate();
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  String _formatTanggalSimple(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}";
  }

  @override
  Widget build(BuildContext context) {
    final String myUid = FirebaseAuth.instance.currentUser!.uid;

    DateTime start = DateTime(_filterTanggal.year, _filterTanggal.month, _filterTanggal.day, 0, 0, 0);
    DateTime end = DateTime(_filterTanggal.year, _filterTanggal.month, _filterTanggal.day, 23, 59, 59);

    Query query = FirebaseFirestore.instance
        .collection('laporan_lapangan')
        .where('id_pengawas', isEqualTo: myUid)
        .where('waktu_dibuat', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('waktu_dibuat', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('waktu_dibuat', descending: true);

    bool isToday = _isSameDay(_filterTanggal, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text("Riwayat Laporan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              onPressed: _pilihTanggal
          ),
          if (!isToday)
            IconButton(
              icon: const Icon(Icons.today, color: Colors.amberAccent),
              onPressed: _resetKeHariIni,
              tooltip: "Kembali ke Hari Ini",
            ),
        ],
      ),
      body: Column(children: [
        Container(
            width: double.infinity,
            color: AppColors.card,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
            child: Row(children: [
              const Icon(Icons.filter_list, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                  isToday
                      ? "Menampilkan Data: HARI INI"
                      : "Menampilkan Data: ${_filterTanggal.day}/${_filterTanggal.month}/${_filterTanggal.year}",
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)
              )
            ])
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                String emptyText = isToday
                    ? "Tidak ada data hari ini"
                    : "Tidak ada data pada tanggal ${_formatTanggalSimple(_filterTanggal)}";

                return Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 70, color: Colors.grey[300]),
                          const SizedBox(height: 15),
                          Text(
                              emptyText,
                              style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500)
                          )
                        ]
                    )
                );
              }

              final dataLaporan = snapshot.data!.docs;
              return ListView.builder(padding: const EdgeInsets.fromLTRB(15, 15, 15, 80), itemCount: dataLaporan.length, itemBuilder: (context, index) {
                var document = dataLaporan[index];
                var data = document.data() as Map<String, dynamic>;
                return _buildJobCard(context, document.id, data);
              });
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildJobCard(BuildContext context, String docId, Map<String, dynamic> data) {
    String status = data['status_pengerjaan'] ?? 'Pending';
    bool isSelesai = status == 'Selesai';
    Color warnaStatus = isSelesai ? AppColors.primary : AppColors.amber;
    Color bgStatus = isSelesai ? AppColors.card : const Color(0xFFfffbeb);
    String tanggal = _formatTanggal(data['waktu_mulai'] ?? data['waktu_dibuat']);
    String jamMulai = _formatJam(data['waktu_mulai'] ?? data['waktu_dibuat']);
    String jamSelesai = isSelesai ? _formatJam(data['waktu_selesai']) : "...";

    Widget thumbnail = (data['foto_base64'] != null && data['foto_base64'].toString().isNotEmpty) ? Image.memory(base64Decode(data['foto_base64']), width: 80, height: 80, fit: BoxFit.cover) : Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey));

    return Card(
      elevation: 2, margin: const EdgeInsets.only(bottom: 15), color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: warnaStatus.withValues(alpha: 0.2), width: 1)),
      child: Column(children: [
        InkWell(
          onTap: () { if(!isSelesai) Navigator.push(context, MaterialPageRoute(builder: (context) => FormLaporanPage(idDokumen: docId, dataAwal: data))); },
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(padding: const EdgeInsets.all(16.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: thumbnail), const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(data['judul'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis)), if (!isSelesai) InkWell(onTap: () => _hapusLaporan(context, docId), child: const Icon(Icons.delete_outline, size: 22, color: Colors.grey))]),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.place, size: 16, color: Colors.grey), const SizedBox(width: 6), Expanded(child: Text(data['lokasi_manual'] ?? '-', style: const TextStyle(fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis))]),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.calendar_today, size: 14, color: Colors.grey), const SizedBox(width: 6), Text(tanggal, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(width: 12), const Icon(Icons.access_time, size: 14, color: Colors.grey), const SizedBox(width: 6), Text("$jamMulai - $jamSelesai", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]))])
            ]))
          ])),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFf1f5f9)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(color: Color(0xFFf8fafc), borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: bgStatus, borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(isSelesai ? Icons.check_circle : Icons.timelapse, size: 16, color: warnaStatus), const SizedBox(width: 6), Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: warnaStatus))])),
            const Spacer(),
            if (!isSelesai) ElevatedButton.icon(onPressed: () => _selesaikanPekerjaan(docId), icon: const Icon(Icons.check, size: 18), label: const Text("SELESAIKAN"), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))) else const Text("Tuntas", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
          ]),
        )
      ]),
    );
  }
}