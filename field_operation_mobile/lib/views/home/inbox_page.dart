import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../controllers/job_controller.dart';

class InboxTugasPage extends StatelessWidget {
  const InboxTugasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final jobController = JobController();

    final stream = supabase
        .from('inbox_pending')
        .stream(primaryKey: ['id']);

    Future<String?> getSignedUrl(String? path) async {
      if (path == null || path.isEmpty) return null;

      return await supabase.storage
          .from('laporan-foto')
          .createSignedUrl(path, 3600);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          "Tugas Masuk",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final docs = snapshot.data!;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 80,
                      color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text(
                    "Tidak ada tugas baru",
                    style: TextStyle(color: Colors.grey),
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
                top: 10, bottom: 20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              final docId = data['id'];

              return FutureBuilder<String?>(
                future: getSignedUrl(data['foto_url']),
                builder: (context, snap) {
                  Widget thumbnail;

                  if (snap.hasData &&
                      snap.data != null) {
                    thumbnail = Image.network(
                      snap.data!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    );
                  } else {
                    thumbnail = Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image),
                    );
                  }

                  return Card(
                    margin:
                    const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 6),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                          16),
                    ),
                    child: Padding(
                      padding:
                      const EdgeInsets.all(
                          16.0),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                    8),
                                child:
                                thumbnail,
                              ),
                              const SizedBox(
                                  width: 10),
                              Expanded(
                                child: Text(
                                  data['judul'] ??
                                      "Tanpa Judul",
                                  style:
                                  const TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                              height: 8),
                          Text(
                            data['deskripsi'] ??
                                "-",
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                          ),
                          const SizedBox(
                              height: 12),
                          Row(
                            children: [
                              const Icon(
                                  Icons.place,
                                  size: 16,
                                  color:
                                  Colors.grey),
                              const SizedBox(
                                  width: 4),
                              Expanded(
                                child: Text(
                                  data[
                                  'lokasi_manual'] ??
                                      "-",
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                              height: 24),
                          SizedBox(
                            width:
                            double.infinity,
                            height: 45,
                            child:
                            ElevatedButton
                                .icon(
                              style: ElevatedButton
                                  .styleFrom(
                                backgroundColor:
                                AppColors
                                    .primary,
                                foregroundColor:
                                Colors
                                    .white,
                              ),
                              onPressed:
                                  () async {
                                try {
                                  await jobController
                                      .ambilTugas(
                                      docId);

                                  if (context
                                      .mounted) {
                                    ScaffoldMessenger
                                        .of(
                                        context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                        Text(
                                            "Tugas berhasil diambil!"),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context
                                      .mounted) {
                                    ScaffoldMessenger
                                        .of(
                                        context)
                                        .showSnackBar(
                                      SnackBar(
                                          content:
                                          Text(
                                              "Error: $e")),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                  Icons
                                      .handshake),
                              label: const Text(
                                  "KERJAKAN SEKARANG"),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}