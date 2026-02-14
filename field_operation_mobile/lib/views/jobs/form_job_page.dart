import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../other/peta_picker.dart';
import '../../controllers/job_controller.dart';

class FormLaporanPage extends StatefulWidget {
  final String? idDokumen;
  final Map<String, dynamic>? dataAwal;
  const FormLaporanPage({super.key, this.idDokumen, this.dataAwal});
  @override
  State<FormLaporanPage> createState() => _FormLaporanPageState();
}

class _FormLaporanPageState extends State<FormLaporanPage> {
  final _formKey = GlobalKey<FormState>();
  final JobController _jobController = JobController();

  late TextEditingController _judulController;
  late TextEditingController _lokasiController;
  late TextEditingController _deskripsiController;

  String _jenisPekerjaan = 'CHRM';
  bool _isLoading = false;
  Uint8List? _fotoBytes;
  String? _fotoBase64Lama;
  final ImagePicker _picker = ImagePicker();
  double? _lokasiX;
  double? _lokasiY;

  final List<String> _listJenis = ['CHRM', 'Olah Data', 'Inspeksi', 'Perbaikan', 'Lainnya'];

  @override
  void initState() {
    super.initState();
    _judulController = TextEditingController(text: widget.dataAwal?['judul'] ?? '');
    _lokasiController = TextEditingController(text: widget.dataAwal?['lokasi_manual'] ?? '');
    _deskripsiController = TextEditingController(text: widget.dataAwal?['deskripsi'] ?? '');

    if (widget.dataAwal != null) {
      _jenisPekerjaan = widget.dataAwal!['jenis_pekerjaan'] ?? 'CHRM';
      _fotoBase64Lama = widget.dataAwal!['foto_base64'];
      if (widget.dataAwal!['lokasi_x'] != null) _lokasiX = (widget.dataAwal!['lokasi_x'] as num).toDouble();
      if (widget.dataAwal!['lokasi_y'] != null) _lokasiY = (widget.dataAwal!['lokasi_y'] as num).toDouble();
      if (!_listJenis.contains(_jenisPekerjaan)) _jenisPekerjaan = _listJenis[0];
    }
  }

  Future<void> _bukaPeta() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PetaPickerPage()));
    if (result != null) setState(() { _lokasiX = result['x']; _lokasiY = result['y']; });
  }

  void _showPilihanFoto() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) {
      return Container(padding: const EdgeInsets.all(20), height: 180, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text("Pilih Sumber Foto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_tombolSumber(Icons.camera_alt, "Kamera", ImageSource.camera), _tombolSumber(Icons.photo_library, "Galeri", ImageSource.gallery)]) ]));
    });
  }

  Widget _tombolSumber(IconData icon, String label, ImageSource source) {
    return GestureDetector(onTap: () { Navigator.pop(context); _ambilFoto(source); }, child: Column(children: [ CircleAvatar(radius: 30, backgroundColor: AppColors.surface, child: Icon(icon, color: AppColors.primary, size: 30)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w500)) ]));
  }

  Future<void> _ambilFoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 600,      // Dikecilkan dari 800 ke 600 (Masih jelas di HP)
          imageQuality: 50    // Kualitas 50% (Cukup untuk laporan lapangan)
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _fotoBytes = bytes);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengambil foto")));
    }
  }

  // --- FUNGSI KIRIM LAPORAN (DIPERBAIKI) ---
  Future<void> _kirimLaporan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? fotoBase64 = _fotoBase64Lama;
      if (_fotoBytes != null) fotoBase64 = base64Encode(_fotoBytes!);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User tidak ditemukan. Login ulang.";

      // 1. SIAPKAN DATA DEFAULT (Jaga-jaga jika offline total)
      String namaPengawas = user.displayName ?? "Pengawas";
      String jabatan = "-";
      String badge = "-";

      // 2. AMBIL DATA USER (PRIORITAS CACHE AGAR CEPAT)
      try {
        // Timeout 2 detik saja untuk ambil data user, kalau kelamaan pakai default
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache)); // <--- Pakai CACHE dulu

        if (userDoc.exists) {
          final userData = userDoc.data();
          namaPengawas = userData?['nama'] ?? namaPengawas;
          jabatan = userData?['jabatan'] ?? jabatan;
          badge = userData?['badge_id'] ?? badge;
        } else {
          // Kalau di cache kosong, coba server (dengan timeout)
          final serverDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 3));

          if(serverDoc.exists) {
            final d = serverDoc.data();
            namaPengawas = d?['nama'] ?? namaPengawas;
            jabatan = d?['jabatan'] ?? jabatan;
            badge = d?['badge_id'] ?? badge;
          }
        }
      } catch (e) {
        // Error ambil data user diabaikan, lanjut pakai data default
        debugPrint("Gagal ambil data user (Offline mode): $e");
      }

      // 3. SUSUN DATA LAPORAN
      final dataLaporan = {
        'judul': _judulController.text,
        'lokasi_manual': _lokasiController.text,
        'deskripsi': _deskripsiController.text,
        'jenis_pekerjaan': _jenisPekerjaan,
        'foto_base64': fotoBase64,
        'lokasi_x': _lokasiX ?? 0.5,
        'lokasi_y': _lokasiY ?? 0.5,
        'waktu_update': FieldValue.serverTimestamp()
      };

      if (widget.idDokumen == null) {
        // DATA BARU
        dataLaporan['status_pengerjaan'] = 'Sedang Dikerjakan';
        dataLaporan['urgency'] = 'Normal';
        dataLaporan['id_pengawas'] = user.uid;
        dataLaporan['nama_pengawas'] = namaPengawas;
        dataLaporan['jabatan_pengawas'] = jabatan;
        dataLaporan['badge_pengawas'] = badge;
        dataLaporan['waktu_dibuat'] = FieldValue.serverTimestamp();
        dataLaporan['created_via'] = 'mobile';

        // Simpan via Controller (Dengan Timeout agar tidak hang)
        String pesan = await _jobController.tambahLaporan(dataLaporan)
            .timeout(const Duration(seconds: 10), onTimeout: () => "Disimpan di HP (Sinyal Lemah)");

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(pesan),
              backgroundColor: pesan.contains("Offline") || pesan.contains("Lemah") ? Colors.orange : Colors.green
          ));
        }
      } else {
        // EDIT DATA
        await FirebaseFirestore.instance.collection('laporan_lapangan').doc(widget.idDokumen).update(dataLaporan)
            .timeout(const Duration(seconds: 10));

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data Terupdate!"), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(title: Text(widget.idDokumen == null ? "Laporan Baru" : "Edit Laporan",style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),backgroundColor: AppColors.primary,),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
        GestureDetector(onTap: _showPilihanFoto, child: Container(height: 180, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey)), child: _fotoBytes != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_fotoBytes!, fit: BoxFit.cover)) : (_fotoBase64Lama != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(_fotoBase64Lama!), fit: BoxFit.cover)) : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), SizedBox(height: 5), Text("Tap untuk Upload Foto")])))),
        const SizedBox(height: 20),
        TextFormField(controller: _judulController, decoration: const InputDecoration(labelText: 'Judul Pekerjaan', prefixIcon: Icon(Icons.title), border: OutlineInputBorder()), validator: (val) => val!.isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 15),
        TextFormField(controller: _lokasiController, decoration: const InputDecoration(labelText: 'Lokasi', prefixIcon: Icon(Icons.pin_drop), border: OutlineInputBorder(), hintText: "Contoh: Gedung A, Lt 2"), validator: (val) => val!.isEmpty ? 'Wajib diisi' : null),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(value: _jenisPekerjaan, decoration: const InputDecoration(labelText: 'Jenis', border: OutlineInputBorder()), items: _listJenis.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _jenisPekerjaan = val!)),
        const SizedBox(height: 15),
        InkWell(onTap: _bukaPeta, child: Container(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10), decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.primary), borderRadius: BorderRadius.circular(5)), child: Row(children: [const Icon(Icons.map, color: AppColors.primary), const SizedBox(width: 10), Expanded(child: Text(_lokasiX != null ? "Koordinat Terpilih (Siap Kirim)" : "Klik untuk menentukan Titik di Peta", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))), if (_lokasiX != null) const Icon(Icons.check_circle, color: Colors.green)]))),
        const SizedBox(height: 15),
        TextFormField(controller: _deskripsiController, maxLines: 3, decoration: const InputDecoration(labelText: 'Deskripsi', prefixIcon: Icon(Icons.description), border: OutlineInputBorder())),
        const SizedBox(height: 30),
        SizedBox(height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), onPressed: _isLoading ? null : _kirimLaporan, child: Text(_isLoading ? "Menyimpan..." : "SIMPAN DATA", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
      ])),
    );
  }
}