import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import 'form_job_page.dart';

class ListLaporanPage extends StatefulWidget {
  const ListLaporanPage({super.key});

  @override
  State<ListLaporanPage> createState() => _ListLaporanPageState();
}

class _ListLaporanPageState extends State<ListLaporanPage> {
  final supabase = Supabase.instance.client;
  DateTime _filterTanggal = DateTime.now();

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year &&
          d1.month == d2.month &&
          d1.day == d2.day;

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterTanggal,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() => _filterTanggal = picked);
    }
  }

  void _resetKeHariIni() {
    setState(() => _filterTanggal = DateTime.now());
  }

  String _formatTanggal(String? iso) {
    if (iso == null) return "-";
    final date = DateTime.parse(iso).toLocal();
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  String _formatJam(String? iso) {
    if (iso == null) return "...";
    final date = DateTime.parse(iso).toLocal();
    return "${date.hour.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')}";
  }

  String? _getPublicUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return supabase.storage.from('laporan-foto').getPublicUrl(path);
  }

  Future<void> _hapusLaporan(BuildContext context, String id) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Laporan"),
        content: const Text("Yakin hapus data ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal",
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase
          .from('laporan_lapangan')
          .delete()
          .eq('id', id);
    }
  }

  Future<void> _selesaikanPekerjaan(String id) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Selesaikan Pekerjaan"),
        content: const Text("Status akan berubah menjadi SELESAI."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal",
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ya, Selesai",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.from('laporan_lapangan').update({
        'status_pengerjaan': 'Selesai',
        'waktu_selesai':
        DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = supabase.auth.currentUser!.id;
    final isToday =
    _isSameDay(_filterTanggal, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          "Riwayat Laporan",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
              icon: const Icon(Icons.calendar_month,
                  color: Colors.white),
              onPressed: _pilihTanggal),
          if (!isToday)
            IconButton(
              icon: const Icon(Icons.today,
                  color: Colors.amberAccent),
              onPressed: _resetKeHariIni,
            ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('laporan_lapangan')
            .stream(primaryKey: ['id'])
            .eq('id_pengawas', myUid)
            .order('waktu_dibuat', ascending: false)
            .map((data) {
          final start = DateTime(
            _filterTanggal.year,
            _filterTanggal.month,
            _filterTanggal.day,
          );
          final end = DateTime(
            _filterTanggal.year,
            _filterTanggal.month,
            _filterTanggal.day,
            23,
            59,
            59,
          );

          return data.where((e) {
            final waktu =
            DateTime.parse(e['waktu_dibuat']).toLocal();

            return waktu.isAfter(
                start.subtract(const Duration(seconds: 1))) &&
                waktu.isBefore(
                    end.add(const Duration(seconds: 1)));
          }).toList();
        }),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final dataLaporan = snapshot.data!;

          if (dataLaporan.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 70,
                      color: Colors.grey[300]),
                  const SizedBox(height: 15),
                  Text(
                    isToday
                        ? "Tidak ada data hari ini"
                        : "Tidak ada data",
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w500),
                  )
                ],
              ),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: ListView.builder(
              key: ValueKey(dataLaporan.length),
              padding:
              const EdgeInsets.fromLTRB(15, 15, 15, 80),
              itemCount: dataLaporan.length,
              itemBuilder: (context, index) {
                return _buildJobCard(
                    context, dataLaporan[index]);
              },
            ),
          );
        },
      ),
    );
  }

  // ======================
  // UI TIDAK DIUBAH
  // ======================
  Widget _buildJobCard(
      BuildContext context,
      Map<String, dynamic> data) {
    String status =
        data['status_pengerjaan'] ?? 'Pending';
    bool isSelesai =
        status == 'Selesai';

    String tanggal =
    _formatTanggal(data['waktu_dibuat']);
    String jamMulai =
    _formatJam(data['waktu_dibuat']);
    String jamSelesai =
    isSelesai
        ? _formatJam(data['waktu_selesai'])
        : "...";

    final imageUrl = _getPublicUrl(data['foto_path']);

    Widget thumbnail;

    if (imageUrl != null) {
      thumbnail = Image.network(
        imageUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey[200],
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey[200],
            child: const Icon(Icons.image, color: Colors.grey),
          );
        },
      );
    } else {
      thumbnail = Container(
        width: 80,
        height: 80,
        color: Colors.grey[200],
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              if (!isSelesai) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FormLaporanPage(
                          idDokumen: data['id'],
                          dataAwal: data,
                        ),
                  ),
                );
              }
            },
            child: Padding(
              padding:
              const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                      borderRadius:
                      BorderRadius.circular(
                          12),
                      child: thumbnail),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                data['judul'] ??
                                    '-',
                                style: const TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                    fontSize: 16,
                                    color: AppColors
                                        .textDark),
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                              ),
                            ),
                            if (!isSelesai)
                              InkWell(
                                onTap: () =>
                                    _hapusLaporan(
                                        context,
                                        data[
                                        'id']),
                                child: const Icon(
                                  Icons
                                      .delete_outline,
                                  size: 22,
                                  color:
                                  Colors.grey,
                                ),
                              )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                                Icons.place,
                                size: 16,
                                color:
                                Colors.grey),
                            const SizedBox(
                                width: 6),
                            Expanded(
                              child: Text(
                                data['lokasi_manual'] ??
                                    '-',
                                style:
                                const TextStyle(
                                    fontSize:
                                    13,
                                    color: Colors
                                        .black87),
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color:
                                Colors.grey),
                            const SizedBox(
                                width: 6),
                            Text(
                              tanggal,
                              style:
                              const TextStyle(
                                  fontSize:
                                  12,
                                  color: Colors
                                      .grey),
                            ),
                            const SizedBox(
                                width: 12),
                            const Icon(
                                Icons.access_time,
                                size: 14,
                                color:
                                Colors.grey),
                            const SizedBox(
                                width: 6),
                            Text(
                              "$jamMulai - $jamSelesai",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                  color: Colors
                                      .grey[700]),
                            )
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFf1f5f9)),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12),
            decoration:
            const BoxDecoration(
                color: Color(0xFFf8fafc),
                borderRadius:
                BorderRadius.vertical(
                    bottom:
                    Radius.circular(
                        16))),
            child: Row(
              children: [
                Text(status.toUpperCase()),
                const Spacer(),
                if (!isSelesai)
                  ElevatedButton.icon(
                    onPressed: () =>
                        _selesaikanPekerjaan(
                            data['id']),
                    icon: const Icon(
                        Icons.check,
                        size: 18),
                    label: const Text(
                        "SELESAIKAN"),
                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      AppColors.primary,
                      foregroundColor:
                      Colors.white,
                      elevation: 0,
                      padding:
                      const EdgeInsets
                          .symmetric(
                          horizontal:
                          16,
                          vertical:
                          10),
                      visualDensity:
                      VisualDensity
                          .compact,
                      textStyle:
                      const TextStyle(
                          fontSize: 12,
                          fontWeight:
                          FontWeight
                              .bold),
                    ),
                  )
                else
                  const Text(
                    "Tuntas",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontStyle:
                        FontStyle.italic),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}