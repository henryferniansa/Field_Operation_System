import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Import
import '../../core/app_colors.dart';
import 'inbox_page.dart';
import 'profile_page.dart';
import '../jobs/form_job_page.dart';
import '../jobs/list_job_page.dart';

class HomePageUser extends StatefulWidget {
  const HomePageUser({super.key});
  @override
  State<HomePageUser> createState() => _HomePageUserState();
}

class _HomePageUserState extends State<HomePageUser> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const InboxTugasPage(),
    const ListLaporanPage(),
    const ProfilPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body sesuai halaman yang dipilih
      body: _pages[_selectedIndex],

      // MENGGUNAKAN COLUMN UNTUK MENUMPUK ALERT DI ATAS NAVBAR
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Agar tidak memakan seluruh layar
        children: [
          // --- GLOBAL OFFLINE INDICATOR (ALERT BOX) ---
          StreamBuilder<List<ConnectivityResult>>(
            stream: Connectivity().onConnectivityChanged,
            builder: (context, snapshot) {
              bool isOffline = snapshot.data?.contains(ConnectivityResult.none) ?? false;

              // ANIMASI MUNCUL/HILANG
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: isOffline ? 40 : 0, // Tinggi 0 jika online (hilang)
                width: double.infinity,
                color: Colors.redAccent, // Warna Merah Warning
                child: isOffline
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                        "Anda sedang OFFLINE. Data akan disimpan di HP.",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                    ),
                  ],
                )
                    : const SizedBox.shrink(),
              );
            },
          ),

          // --- NAVIGATION BAR ASLI ---
          StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('laporan_lapangan').where('status_pengerjaan', isEqualTo: 'Pending').snapshots(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData) { unreadCount = snapshot.data!.docs.where((doc) { var data = doc.data() as Map<String, dynamic>; String? owner = data['id_pengawas']; return owner == null || owner == "" || owner == "-"; }).length; }
                return NavigationBar(
                  selectedIndex: _selectedIndex, onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  height: 70, backgroundColor: Colors.white, indicatorColor: AppColors.accentLight,
                  destinations: [
                    NavigationDestination(icon: Badge(isLabelVisible: unreadCount > 0, label: Text(unreadCount.toString()), child: const Icon(Icons.mail_outline)), selectedIcon: Badge(isLabelVisible: unreadCount > 0, label: Text(unreadCount.toString()), child: const Icon(Icons.mail)), label: 'Inbox'),
                    const NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Pekerjaan'),
                    const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
                  ],
                );
              }
          ),
        ],
      ),

      floatingActionButton: _selectedIndex == 1 ? FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FormLaporanPage())),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white)
      ) : null,
    );
  }
}