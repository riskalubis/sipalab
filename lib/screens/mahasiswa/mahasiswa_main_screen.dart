import 'package:flutter/material.dart';

import 'mahasiswa_home_screen.dart';
import 'daftar_alat_screen.dart';
import 'peminjaman_saya_screen.dart';
import 'profil_mahasiswa_screen.dart';
import 'package:flutter/services.dart';

class MahasiswaMainScreen extends StatefulWidget {
  const MahasiswaMainScreen({super.key});

  @override
  State<MahasiswaMainScreen> createState() => _MahasiswaMainScreenState();
}

class _MahasiswaMainScreenState extends State<MahasiswaMainScreen> {
  int currentIndex = 0;

  // Key untuk memaksa PeminjamanSayaScreen refresh
  final GlobalKey<PeminjamanSayaScreenState> _peminjamanKey =
      GlobalKey<PeminjamanSayaScreenState>();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      const MahasiswaHomeScreen(),
      const DaftarAlatScreen(),
      PeminjamanSayaScreen(key: _peminjamanKey),
      const ProfilMahasiswaScreen(),
    ];
  }

  void _ubahTab(int index) {
    // Tutup keyboard dan lepaskan fokus dari TextField
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    setState(() {
      currentIndex = index;
    });

    if (index == 2) {
      _peminjamanKey.currentState?.refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: _pages),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF087F72),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 14,
        unselectedFontSize: 14,
        onTap: _ubahTab,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_outlined),
            activeIcon: Icon(Icons.build),
            label: 'Alat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Peminjaman',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
