import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/app_colors.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _badgeController = TextEditingController();
  final _nameController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _tambahUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
      String emailPalsu = "${_badgeController.text.trim()}@fieldops.com";
      UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(email: emailPalsu, password: _passwordController.text);
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({ 'badge_id': _badgeController.text.trim(), 'nama': _nameController.text.trim(), 'jabatan': _jabatanController.text.trim(), 'password_text': _passwordController.text, 'role': 'user', 'dibuat_tgl': FieldValue.serverTimestamp() });
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Berhasil Dibuat!"), backgroundColor: Colors.green)); _badgeController.clear(); _nameController.clear(); _jabatanController.clear(); _passwordController.clear(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red)); } finally { await secondaryApp?.delete(); setState(() => _isLoading = false); }
  }

  Future<void> _hapusUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    } catch (e) {
      // Perbaikan: Menangani empty catch
      debugPrint("Gagal menghapus user: $e");
    }
  }

  void _showAddUserDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Tambah User Baru"), content: SingleChildScrollView(child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [ TextFormField(controller: _badgeController, decoration: const InputDecoration(labelText: "Badge ID"), validator: (v) => v!.isEmpty ? "Wajib diisi" : null), TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Nama Lengkap"), validator: (v) => v!.isEmpty ? "Wajib diisi" : null), TextFormField(controller: _jabatanController, decoration: const InputDecoration(labelText: "Jabatan"), validator: (v) => v!.isEmpty ? "Wajib diisi" : null), TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: "Password"), validator: (v) => v!.length < 6 ? "Min 6 karakter" : null) ]))), actions: [ TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), onPressed: _isLoading ? null : _tambahUser, child: Text(_isLoading ? "Proses..." : "Simpan")) ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel"), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())]),
      floatingActionButton: FloatingActionButton(onPressed: _showAddUserDialog, backgroundColor: AppColors.primary, child: const Icon(Icons.person_add, color: Colors.white)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('dibuat_tgl', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!.docs;
          return ListView.builder(itemCount: users.length, itemBuilder: (context, index) {
            var data = users[index].data() as Map<String, dynamic>;
            return Card(child: ListTile(leading: CircleAvatar(backgroundColor: AppColors.accentLight, child: Text(data['nama']?[0] ?? "U", style: const TextStyle(color: AppColors.primary))), title: Text("${data['nama']} (${data['badge_id']})"), subtitle: Text("${data['jabatan'] ?? '-'} | Pass: ${data['password_text']}"), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _hapusUser(users[index].id))));
          });
        },
      ),
    );
  }
}