import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../controllers/notif_controller.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});
  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final NotifController _notifController = NotifController();
  bool _isUploading = false;

  Future<void> _uploadFotoProfil() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300, imageQuality: 20);
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final Uint8List bytes = await image.readAsBytes();
        final String base64Image = base64Encode(bytes);
        await FirebaseFirestore.instance.collection('users').doc(_uid).update({'foto_base64': base64Image});
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto berhasil diupdate!")));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
      } finally { if(mounted) setState(() => _isUploading = false); }
    }
  }

  void _ubahPassword() {
    final TextEditingController passController = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Ganti Password"), content: TextField(controller: passController, decoration: const InputDecoration(labelText: "Password Baru", prefixIcon: Icon(Icons.lock_outline)), obscureText: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), onPressed: () async { if(passController.text.length < 6) return; Navigator.pop(ctx); try { await FirebaseAuth.instance.currentUser!.updatePassword(passController.text); await FirebaseFirestore.instance.collection('users').doc(_uid).update({'password_text': passController.text}); } catch(e) { /*Handle*/ } }, child: const Text("Simpan"))]));
  }

  Future<void> _hubungiCS() async {
    final Uri url = Uri.parse("https://wa.me/6281252830791?text=Halo%20Admin");
    try { if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw 'err'; } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membuka WhatsApp"))); }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var userData = snapshot.data!.data() as Map<String, dynamic>;

          ImageProvider? imageProvider;
          if (userData['foto_base64'] != null && userData['foto_base64'].toString().isNotEmpty) {
            try { imageProvider = MemoryImage(base64Decode(userData['foto_base64'])); } catch (_) {}
          } else if (userData['foto_url'] != null) { imageProvider = NetworkImage(userData['foto_url']); }

          return Scaffold(
            backgroundColor: AppColors.surface,
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Align(alignment: Alignment.centerLeft, child: Image.asset('assets/logo_perusahaan.png', height: 28)),
                    ),

                    const SizedBox(height: 30),

                    Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 50, left: 20, right: 20),
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
                          decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(30),boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                          child: Column(
                            children: [
                              Text(userData['nama'] ?? "Pengawas", textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                              const SizedBox(height: 4),
                              Text("${userData['jabatan'] ?? 'Lapangan'} • ${userData['badge_id'] ?? '-'}", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                // Perbaikan di sini (withValues)
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                                child: CircleAvatar(radius: 50, backgroundColor: AppColors.card, backgroundImage: imageProvider, child: _isUploading ? const CircularProgressIndicator() : (imageProvider == null ? const Text("U", style: TextStyle(fontSize: 32, color: AppColors.primary)) : null)),
                              ),
                              GestureDetector(onTap: _uploadFotoProfil, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.camera_alt, color: Colors.white, size: 16))),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Pengaturan Umum", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(height: 15),
                          _buildMenuItem(icon: Icons.lock_outline, color: AppColors.amber, title: "Ganti Password", subtitle: "Amankan akun anda", onTap: _ubahPassword),
                          _buildMenuItem(icon: Icons.headset_mic_outlined, color: AppColors.primary, title: "Bantuan CS", subtitle: "Hubungi via WhatsApp", onTap: _hubungiCS),

                          _buildMenuItem(
                              icon: Icons.notifications_active_outlined,
                              color: Colors.blue,
                              title: "Notifikasi",
                              subtitle: "Sinkronisasi Manual",
                              onTap: () => _notifController.saveTokenToDatabase(context: context)
                          ),

                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity, height: 55,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFfee2e2), foregroundColor: const Color(0xFFbe123c), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              onPressed: () => FirebaseAuth.instance.signOut(),
                              icon: const Icon(Icons.logout), label: const Text("Keluar Aplikasi", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Center(child: Text("App Version 1.0.0", style: TextStyle(color: Colors.grey, fontSize: 12))),
                          const SizedBox(height: 30),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }
    );
  }

  Widget _buildPill(String text, bool isActive, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      // Perbaikan di sini (withValues)
      decoration: BoxDecoration(color: isActive ? AppColors.primary : Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: isActive ? Colors.transparent : Colors.grey.shade300), boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : []),
      child: Row(children: [ if (isActive) Icon(icon, color: Colors.white, size: 18), if (isActive) const SizedBox(width: 6), Text(text, style: TextStyle(color: isActive ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600)) ]),
    );
  }

  Widget _buildMenuItem({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 2))]),
      child: ListTile(onTap: onTap, leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)), trailing: const Icon(Icons.chevron_right, color: Colors.grey)),
    );
  }
}