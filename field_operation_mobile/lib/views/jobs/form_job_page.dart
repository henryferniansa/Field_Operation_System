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

  String _jenisPekerjaan = 'Cut Fill Work';
  bool _isLoading = false;
  Uint8List? _fotoBytes;
  String? _fotoBase64Lama;
  final ImagePicker _picker = ImagePicker();
  double? _lokasiX;
  double? _lokasiY;

  final List<String> _listJenis = [
    'Cut Fill Work',
    'Surfacing Work',
    'CHRM Work',
    'CSP Work',
    'Levelling Road Grade Work',
    'Construct Bundwall',
    'QC Work Test',
    'Slope Protection Work by Geomate',
    'Base Road Treatment Work by Geotex & Geogrid',
    'Weekly Safety Briefing',
    'PTO',
    'Install Traffic Sign',
  ];

  @override
  void initState() {
    super.initState();
    _judulController =
        TextEditingController(text: widget.dataAwal?['judul'] ?? '');
    _lokasiController =
        TextEditingController(text: widget.dataAwal?['lokasi_manual'] ?? '');
    _deskripsiController =
        TextEditingController(text: widget.dataAwal?['deskripsi'] ?? '');

    if (widget.dataAwal != null) {
      _jenisPekerjaan =
          widget.dataAwal!['jenis_pekerjaan'] ?? 'Cut Fill Work';
      _fotoBase64Lama = widget.dataAwal!['foto_base64'];

      if (widget.dataAwal!['lokasi_x'] != null) {
        _lokasiX =
            (widget.dataAwal!['lokasi_x'] as num).toDouble();
      }

      if (widget.dataAwal!['lokasi_y'] != null) {
        _lokasiY =
            (widget.dataAwal!['lokasi_y'] as num).toDouble();
      }

      if (!_listJenis.contains(_jenisPekerjaan)) {
        _jenisPekerjaan = _listJenis[0];
      }
    }
  }

  // ==============================
  // DETEKSI SEGMENT (1280 x 720)
  // ==============================
  String _detectSegment(double x, double y) {
    final percentX = x / 1280;

    if (percentX >= 0.00 && percentX <= 0.15) return "JAB I-E";
    if (percentX > 0.15 && percentX <= 0.30) return "JAB D-E";
    if (percentX > 0.30 && percentX <= 0.45) return "JAB C-D";
    if (percentX > 0.45 && percentX <= 0.65) return "JAB B-C";
    if (percentX > 0.65 && percentX <= 0.85) return "JAB A-B";
    if (percentX > 0.85) return "JAB 3";

    return "Unknown";
  }

  // ==============================
  // BUKA MAP (KEMBALI SEPERTI DULU)
  // ==============================
  Future<void> _openImageMap() async {

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PetaPickerPage(),

      ),
    );

    if (result != null) {
      final double x = result['x'];
      final double y = result['y'];
      print("X: $x");
      print("Y: $y");
      final segment = _detectSegment(x, y);

      setState(() {
        _lokasiX = x;
        _lokasiY = y;
        _lokasiController.text = segment;
      });
    }
  }

  Future<void> _ambilFoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        imageQuality: 50,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _fotoBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mengambil foto")),
        );
      }
    }
  }

  void _showPilihanFoto() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 180,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Pilih Sumber Foto",
                style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceAround,
                children: [
                  _tombolSumber(Icons.camera_alt,
                      "Kamera", ImageSource.camera),
                  _tombolSumber(Icons.photo_library,
                      "Galeri", ImageSource.gallery),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tombolSumber(
      IconData icon, String label, ImageSource source) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _ambilFoto(source);
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.surface,
            child:
            Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
              const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ==============================
  // KIRIM LAPORAN (TIDAK DIUBAH)
  // ==============================
  Future<void> _kirimLaporan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? fotoBase64 = _fotoBase64Lama;
      if (_fotoBytes != null) {
        fotoBase64 = base64Encode(_fotoBytes!);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw "User tidak ditemukan. Login ulang.";
      }

      String namaPengawas = user.displayName ?? "Pengawas";
      String jabatan = "-";
      String badge = "-";

      try {
        final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache));

        if (userDoc.exists) {
          final userData = userDoc.data();
          namaPengawas =
              userData?['nama'] ?? namaPengawas;
          jabatan =
              userData?['jabatan'] ?? jabatan;
          badge =
              userData?['badge_id'] ?? badge;
        }
      } catch (_) {}

      final dataLaporan = {
        'judul': _judulController.text,
        'lokasi_manual': _lokasiController.text,
        'deskripsi': _deskripsiController.text,
        'jenis_pekerjaan': _jenisPekerjaan,
        'foto_base64': fotoBase64,
        'lokasi_x': _lokasiX ?? 0.5,
        'lokasi_y': _lokasiY ?? 0.5,
        'waktu_update': FieldValue.serverTimestamp(),
      };

      if (widget.idDokumen == null) {
        dataLaporan['status_pengerjaan'] =
        'Sedang Dikerjakan';
        dataLaporan['urgency'] = 'Normal';
        dataLaporan['id_pengawas'] = user.uid;
        dataLaporan['nama_pengawas'] = namaPengawas;
        dataLaporan['jabatan_pengawas'] = jabatan;
        dataLaporan['badge_pengawas'] = badge;
        dataLaporan['waktu_dibuat'] =
            FieldValue.serverTimestamp();
        dataLaporan['created_via'] = 'mobile';

        String pesan =
        await _jobController.tambahLaporan(dataLaporan);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(pesan),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('laporan_lapangan')
            .doc(widget.idDokumen)
            .update(dataLaporan);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(
            content: Text("Data Terupdate!"),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(content: Text("Gagal: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.idDokumen == null
              ? "Laporan Baru"
              : "Edit Laporan",
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: _showPilihanFoto,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius:
                  BorderRadius.circular(10),
                  border:
                  Border.all(color: Colors.grey),
                ),
                child: _fotoBytes != null
                    ? Image.memory(_fotoBytes!,
                    fit: BoxFit.cover)
                    : const Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo,
                        size: 40,
                        color: Colors.grey),
                    SizedBox(height: 5),
                    Text(
                        "Tap untuk Upload Foto"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _judulController,
              decoration: const InputDecoration(
                labelText: 'Judul Pekerjaan',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
              val!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _lokasiController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Lokasi',
                prefixIcon: IconButton(
                  icon: const Icon(
                    Icons.location_pin,
                    color: AppColors.primary,
                  ),
                  onPressed: _openImageMap,
                ),
                border: const OutlineInputBorder(),
              ),
              onTap: _openImageMap,
              validator: (val) =>
              val!.isEmpty
                  ? 'Wajib pilih lokasi di peta'
                  : null,
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _jenisPekerjaan,
              isExpanded: true,
              decoration:
              const InputDecoration(
                labelText: 'Jenis',
                border: OutlineInputBorder(),
              ),
              items: _listJenis
                  .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    overflow:
                    TextOverflow.ellipsis,
                  )))
                  .toList(),
              onChanged: (val) =>
                  setState(() =>
                  _jenisPekerjaan = val!),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _deskripsiController,
              maxLines: 3,
              decoration:
              const InputDecoration(
                labelText: 'Deskripsi',
                prefixIcon:
                Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  AppColors.primary,
                ),
                onPressed:
                _isLoading ? null : _kirimLaporan,
                child: Text(
                  _isLoading
                      ? "Menyimpan..."
                      : "SIMPAN DATA",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight:
                      FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
