import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_colors.dart';
import '../other/peta_picker.dart';

class FormLaporanPage extends StatefulWidget {
  final String? idDokumen;
  final Map<String, dynamic>? dataAwal;

  const FormLaporanPage({super.key, this.idDokumen, this.dataAwal});

  @override
  State<FormLaporanPage> createState() => _FormLaporanPageState();
}

class _FormLaporanPageState extends State<FormLaporanPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  late TextEditingController _judulController;
  late TextEditingController _lokasiController;
  late TextEditingController _deskripsiController;

  final ImagePicker _picker = ImagePicker();

  String _jenisPekerjaan = 'Cut Fill Work';
  bool _isLoading = false;
  Uint8List? _fotoBytes;
  String? _fotoPathLama;

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

    _judulController = TextEditingController(
      text: widget.dataAwal?['judul'] ?? '',
    );
    _lokasiController = TextEditingController(
      text: widget.dataAwal?['lokasi_manual'] ?? '',
    );
    _deskripsiController = TextEditingController(
      text: widget.dataAwal?['deskripsi'] ?? '',
    );

    if (widget.dataAwal != null) {
      _jenisPekerjaan = widget.dataAwal!['jenis_pekerjaan'] ?? 'Cut Fill Work';
      _fotoPathLama = widget.dataAwal!['foto_path'];
      _lokasiX = (widget.dataAwal!['lokasi_x'] as num?)?.toDouble();
      _lokasiY = (widget.dataAwal!['lokasi_y'] as num?)?.toDouble();
    }
  }

  void _showJenisPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Pilih Jenis Pekerjaan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemBuilder: (context, index) {
                    final item = _listJenis[index];
                    final isSelected = item == _jenisPekerjaan;
                    return ListTile(
                      title: Text(
                        item,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : Colors.black,
                        ),
                      ),
                      trailing:
                          isSelected
                              ? const Icon(
                                Icons.check,
                                color: AppColors.primary,
                              )
                              : null,
                      onTap: () {
                        _jenisPekerjaan = item;
                      },
                    );
                    Navigator.pop(context);
                  },
                  itemCount: _listJenis.length,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================
  // DETECT SEGMENT
  // ============================
  String _detectSegment(double percentX) {
    if (percentX <= 0.16) return "JAB I-E";
    if (percentX <= 0.32) return "JAB D-E";
    if (percentX <= 0.48) return "JAB C-D";
    if (percentX <= 0.68) return "JAB B-C";
    if (percentX <= 0.88) return "JAB A-B";
    return "JAB 3";
  }

  // ============================
  // OPEN MAP
  // ============================
  Future<void> _openImageMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PetaPickerPage()),
    );

    if (result != null) {
      final x = result['x'];
      final y = result['y'];

      setState(() {
        _lokasiX = x;
        _lokasiY = y;
        _lokasiController.text = _detectSegment(x);
      });
    }
  }

  // ============================
  // AMBIL FOTO
  // ============================
  Future<void> _ambilFoto(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 600,
      imageQuality: 50,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _fotoBytes = bytes);
    }
  }

  void _showPilihanFoto() {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => Container(
            padding: const EdgeInsets.all(20),
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _tombolSumber(Icons.camera_alt, "Kamera", ImageSource.camera),
                _tombolSumber(
                  Icons.photo_library,
                  "Galeri",
                  ImageSource.gallery,
                ),
              ],
            ),
          ),
    );
  }

  Widget _tombolSumber(IconData icon, String label, ImageSource source) {
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
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  // ============================
  // UPLOAD FOTO KE STORAGE
  // ============================
  Future<String?> _uploadFoto(String jobId) async {
    if (_fotoBytes == null) return _fotoPathLama;

    final user = supabase.auth.currentUser!;
    final filePath = "${user.id}/$jobId.jpg";

    await supabase.storage
        .from('laporan-foto')
        .uploadBinary(
          filePath,
          _fotoBytes!,
          fileOptions: const FileOptions(upsert: true),
        );

    return filePath;
  }

  // ============================
  // KIRIM LAPORAN
  // ============================
  Future<void> _kirimLaporan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser!;
      final jobId = widget.idDokumen ?? const Uuid().v4();

      final fotoPath = await _uploadFoto(jobId);

      final data = {
        'judul': _judulController.text,
        'lokasi_manual': _lokasiController.text,
        'deskripsi': _deskripsiController.text,
        'jenis_pekerjaan': _jenisPekerjaan,
        'lokasi_x': _lokasiX ?? 0.5,
        'lokasi_y': _lokasiY ?? 0.5,
        'foto_path': fotoPath,
        'waktu_update': DateTime.now().toUtc().toIso8601String(),
      };

      if (widget.idDokumen == null) {
        // 🔥 JANGAN KIRIM waktu_dibuat
        await supabase.from('laporan_lapangan').insert({
          ...data,
          'id': jobId,
          'id_pengawas': user.id,
          'status_pengerjaan': 'Sedang Dikerjakan',
        });
      } else {
        await supabase.from('laporan_lapangan').update(data).eq('id', jobId);
      }

      if (mounted) {
        Navigator.pop(context, true); // 🔥 kirim signal refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data berhasil disimpan"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================
  // UI LAMA (TIDAK DIUBAH)
  // ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.idDokumen == null ? "Laporan Baru" : "Edit Laporan",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey),
                ),
                child:
                    _fotoBytes != null
                        ? Image.memory(_fotoBytes!, fit: BoxFit.cover)
                        : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 5),
                            Text("Tap untuk Upload Foto"),
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
              validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
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
              validator: (val) => val!.isEmpty ? 'Wajib pilih lokasi' : null,
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: _showJenisPicker,
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Jenis',
                   border: OutlineInputBorder(),
                   suffixIcon: Icon(Icons.keyboard_arrow_down),
                  ),
                  controller: TextEditingController(text: _jenisPekerjaan,),
                  validator: (val) =>
                  val == null || val.isEmpty ? 'Pilih Pekerjaan' : null,
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _deskripsiController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: _isLoading ? null : _kirimLaporan,
                child: Text(
                  _isLoading ? "Menyimpan..." : "SIMPAN DATA",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
