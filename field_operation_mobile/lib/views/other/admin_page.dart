import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _badgeController = TextEditingController();
  final _nameController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  // ==============================
  // TAMBAH USER
  // ==============================
  Future<void> _tambahUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = "${_badgeController.text.trim()}@fieldops.com";

      // CREATE AUTH USER
      final response = await _supabase.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: _passwordController.text,
          emailConfirm: true,
        ),
      );

      final userId = response.user?.id;

      if (userId == null) {
        throw "Gagal membuat user auth";
      }

      // INSERT KE TABEL USERS
      await _supabase.from('users').insert({
        'id': userId,
        'badge_id': _badgeController.text.trim(),
        'nama': _nameController.text.trim(),
        'jabatan': _jabatanController.text.trim(),
        'password_text': _passwordController.text,
        'role': 'user',
        'dibuat_tgl': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User Berhasil Dibuat!"),
            backgroundColor: Colors.green,
          ),
        );
      }

      _badgeController.clear();
      _nameController.clear();
      _jabatanController.clear();
      _passwordController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ==============================
  // HAPUS USER
  // ==============================
  Future<void> _hapusUser(String uid) async {
    try {
      await _supabase.from('users').delete().eq('id', uid);

      // Hapus dari auth
      await _supabase.auth.admin.deleteUser(uid);
    } catch (e) {
      debugPrint("Gagal menghapus user: $e");
    }
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Tambah User Baru"),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _badgeController,
                      decoration: const InputDecoration(labelText: "Badge ID"),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Nama Lengkap",
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    TextFormField(
                      controller: _jabatanController,
                      decoration: const InputDecoration(labelText: "Jabatan"),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: "Password"),
                      validator: (v) => v!.length < 6 ? "Min 6 karakter" : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _tambahUser,
                child: Text(_isLoading ? "Proses..." : "Simpan"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _supabase.auth.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('users')
            .stream(primaryKey: ['id'])
            .order('dibuat_tgl', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var data = users[index];

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accentLight,
                    child: Text(
                      data['nama']?[0] ?? "U",
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
                  title: Text("${data['nama']} (${data['badge_id']})"),
                  subtitle: Text(
                    "${data['jabatan'] ?? '-'} | Pass: ${data['password_text']}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _hapusUser(data['id']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
