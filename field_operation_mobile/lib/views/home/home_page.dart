import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final SupabaseClient _supabase = Supabase.instance.client;

  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    InboxTugasPage(),
    ListLaporanPage(),
    ProfilPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],

      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- GLOBAL OFFLINE INDICATOR ---
          StreamBuilder<List<ConnectivityResult>>(
            stream: Connectivity().onConnectivityChanged,
            builder: (context, snapshot) {
              bool isOffline =
                  snapshot.data?.contains(ConnectivityResult.none) ?? false;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: isOffline ? 40 : 0,
                width: double.infinity,
                color: Colors.redAccent,
                child:
                    isOffline
                        ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              "Anda sedang OFFLINE. Data akan disimpan di HP.",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                        : const SizedBox.shrink(),
              );
            },
          ),

          // --- NAVIGATION BAR + BADGE ---
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('laporan_lapangan')
                .stream(primaryKey: ['id'])
                .eq('status_pengerjaan', 'Pending'),
            builder: (context, snapshot) {
              int unreadCount = 0;

              if (snapshot.hasData) {
                unreadCount =
                    snapshot.data!.where((data) {
                      final owner = data['id_pengawas'];
                      return owner == null || owner == "" || owner == "-";
                    }).length;
              }

              return NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected:
                    (idx) => setState(() => _selectedIndex = idx),
                height: 70,
                backgroundColor: Colors.white,
                indicatorColor: AppColors.accentLight,
                destinations: [
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: unreadCount > 0,
                      label: Text(unreadCount.toString()),
                      child: const Icon(Icons.mail_outline),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: unreadCount > 0,
                      label: Text(unreadCount.toString()),
                      child: const Icon(Icons.mail),
                    ),
                    label: 'Inbox',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.assignment_outlined),
                    selectedIcon: Icon(Icons.assignment),
                    label: 'Pekerjaan',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profil',
                  ),
                ],
              );
            },
          ),
        ],
      ),

      floatingActionButton:
          _selectedIndex == 1
              ? FloatingActionButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FormLaporanPage(),
                      ),
                    ),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null,
    );
  }
}
