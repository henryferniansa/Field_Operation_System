import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../controllers/notif_controller.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final _supabase = Supabase.instance.client;
  final _notifController = NotifController();
  final _picker = ImagePicker();

  bool _isUploading = false;

  Future<void> _uploadFotoProfil() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      imageQuality: 60,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final Uint8List bytes = await image.readAsBytes();
      final path = "${user.id}.jpg";

      await _supabase.storage.from('profile-foto').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/jpeg',
        ),
      );

      await _supabase
          .from('users')
          .update({'foto_url': path}).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto berhasil diupdate!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String?> _getSignedUrl(String? path) async {
    if (path == null || path.isEmpty) return null;

    return await _supabase.storage
        .from('profile-foto')
        .createSignedUrl(path, 3600);
  }

  void _ubahPassword() {
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ganti Password"),
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration:
          const InputDecoration(labelText: "Password Baru"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (passController.text.length < 6) return;

              Navigator.pop(ctx);

              try {
                await _supabase.auth.updateUser(
                  UserAttributes(password: passController.text),
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Password berhasil diubah")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text("$e")));
                }
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  Future<void> _hubungiCS() async {
    final Uri url =
    Uri.parse("https://wa.me/6281252830791?text=Halo%20Admin");

    try {
      if (!await launchUrl(url,
          mode: LaunchMode.externalApplication)) {
        throw "error";
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal membuka WhatsApp")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const Center(child: Text("User tidak login"));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.first;

        return FutureBuilder<String?>(
          future: _getSignedUrl(userData['foto_url']),
          builder: (context, snap) {
            ImageProvider? imageProvider;

            if (snap.hasData && snap.data != null) {
              imageProvider = NetworkImage(snap.data!);
            }

            return Scaffold(
              backgroundColor: AppColors.surface,
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: AppColors.card,
                            backgroundImage: imageProvider,
                            child: imageProvider == null
                                ? const Icon(Icons.person,
                                size: 40,
                                color: AppColors.primary)
                                : null,
                          ),
                          GestureDetector(
                            onTap: _uploadFotoProfil,
                            child: const CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.amber,
                              child: Icon(Icons.camera_alt,
                                  size: 18,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        userData['nama'] ?? "User",
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${userData['jabatan']} • ${userData['badge_id']}",
                      ),
                      const SizedBox(height: 30),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text("Ganti Password"),
                        onTap: _ubahPassword,
                      ),
                      ListTile(
                        leading:
                        const Icon(Icons.headset_mic_outlined),
                        title: const Text("Bantuan CS"),
                        onTap: _hubungiCS,
                      ),
                      ListTile(
                        leading:
                        const Icon(Icons.notifications),
                        title: const Text("Sinkronisasi Notifikasi"),
                        onTap: () =>
                            _notifController.saveTokenToDatabase(
                                context: context),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFFfee2e2),
                          foregroundColor:
                          const Color(0xFFbe123c),
                        ),
                        onPressed: () =>
                            _supabase.auth.signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text("Keluar Aplikasi"),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}