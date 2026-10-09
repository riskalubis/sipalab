import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'detail_peminjaman_admin_screen.dart';
import 'kelola_alat_screen.dart';
import 'transaksi_admin_screen.dart';
import 'profil_admin_screen.dart';
import 'laporan_screen.dart';
import 'pengembalian_admin_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  bool _isLoading = true;

  int _totalAlat = 0;
  int _stokTersedia = 0;
  int _dipinjam = 0;
  int _menunggu = 0;

  List<Map<String, dynamic>> _peminjamanTerbaru = [];
  int _jumlahNotifikasi = 0;

  final Set<String> _notifikasiTerbaca = {};

  /// Kunci penyimpanan status notifikasi terbaca (per HP, per role).
  static const String _storageKey = 'notifikasi_terbaca_admin';

  /// Timer sinkronisasi otomatis dashboard (fresh saat ada aktivitas baru).
  Timer? _dashboardTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDashboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dashboardTimer?.cancel();
    super.dispose();
  }

  /// Saat aplikasi kembali aktif, dashboard langsung disegarkan agar
  /// sinkron dengan transaksi yang terjadi di perangkat lain.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDashboard();
    }
  }

  Future<void> _initDashboard() async {
    await _muatNotifikasiTerbaca();

    _dashboardTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadDashboard();
    });

    if (mounted) await _loadDashboard();
  }

  // =========================================================
  // AMBIL DATA DASHBOARD DARI API
  // =========================================================

  Future<void> _loadDashboard() async {
    try {
      // Endpoint /home/admin mengembalikan seluruh data yang
      // dibutuhkan dashboard, lengkap dengan daftar notifikasi
      // peminjaman & pengembalian yang masih menunggu.
      // Versi *Fresh* dipakai supaya selalu sama dengan data terbaru.
      final payload = (await ApiService.getMapFresh('/home/admin')) ?? {};

      final totalAlat =
          int.tryParse(payload['total_alat']?.toString() ?? '0') ?? 0;

      final stokTersedia =
          int.tryParse(payload['stok_tersedia']?.toString() ?? '0') ?? 0;

      final dipinjam =
          int.tryParse(payload['dipinjam']?.toString() ?? '0') ?? 0;

      final menunggu =
          int.tryParse(payload['menunggu']?.toString() ?? '0') ?? 0;

      final terbaru = (payload['peminjaman_terbaru'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final notifikasiPeminjaman =
          (payload['notifikasi_peminjaman'] as List? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

      final notifikasiPengembalian =
          (payload['notifikasi_pengembalian'] as List? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

      int jumlahNotifikasi = 0;

      for (final row in notifikasiPeminjaman) {
        final key = 'peminjaman_pending_${row['id']}';

        if (!_notifikasiTerbaca.contains(key)) {
          jumlahNotifikasi++;
        }
      }

      for (final row in notifikasiPengembalian) {
        final key = 'pengembalian_pending_${row['id']}';

        if (!_notifikasiTerbaca.contains(key)) {
          jumlahNotifikasi++;
        }
      }

      if (!mounted) return;

      setState(() {
        _totalAlat = totalAlat;
        _stokTersedia = stokTersedia;
        _dipinjam = dipinjam;
        _menunggu = menunggu;
        _peminjamanTerbaru = terbaru;
        _jumlahNotifikasi = jumlahNotifikasi;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat dashboard: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // NOTIFIKASI SUDAH DIBACA (DISIMPAN PERSISTEN PER HP)
  //
  // Status terbaca (notifikasi_terbaca) disimpan lewat
  // SharedPreferences sehingga tetap teringat walau aplikasi
  // ditutup & dibuka lagi. Tidak perlu disimpan di server.
  // =========================================================

  void _tandaiNotifikasiTerbaca(String key) {
    if (_notifikasiTerbaca.contains(key)) return;
    _notifikasiTerbaca.add(key);
    _persistNotifikasiTerbaca();
  }

  Future<void> _muatNotifikasiTerbaca() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tersimpan = prefs.getStringList(_storageKey) ?? const [];
      _notifikasiTerbaca.addAll(tersimpan);
    } catch (_) {
      // Bila gagal membaca, mulai dari set kosong (perilaku lama).
    }
  }

  Future<void> _persistNotifikasiTerbaca() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _notifikasiTerbaca.toList());
    } catch (_) {
      // Penyimpanan tidak tersedia → abaikan.
    }
  }

  // =========================================================
  // NOTIFIKASI
  //
  // Mengikuti pola notifikasi mahasiswa: saat dibuka,
  // semua notifikasi langsung dianggap sudah dibaca dan
  // hilang ketika ditutup.
  // =========================================================

  Future<void> _showNotifications() async {
    // Ambil data notifikasi terbaru dari API (selalu fresh, tanpa
    // cache) supaya segar saat tombol lonceng diklik.
    final payload = (await ApiService.getMapFresh('/home/admin')) ?? {};

    final notifPeminjaman = (payload['notifikasi_peminjaman'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final notifPengembalian =
        (payload['notifikasi_pengembalian'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

    final pending = <Map<String, dynamic>>[];

    // Notifikasi yang sudah dibaca (persisten di HP) tidak
    // ditampilkan lagi walau aplikasi ditutup & dibuka kembali.
    for (final row in notifPeminjaman) {
      final key = 'peminjaman_pending_${row['id']}';

      if (_notifikasiTerbaca.contains(key)) continue;

      pending.add({
        'jenis': 'Peminjaman',
        'nama': row['nama']?.toString() ?? '-',
        'riwayat_id': row['id'],
      });
    }

    for (final row in notifPengembalian) {
      final key = 'pengembalian_pending_${row['id']}';

      if (_notifikasiTerbaca.contains(key)) continue;

      pending.add({
        'jenis': 'Pengembalian',
        'nama': row['nama']?.toString() ?? '-',
        'riwayat_id': row['id'],
      });
    }

    // ==========================================================
    // SIMPAN DULU NOTIFIKASI YANG MAU DITAMPILKAN
    // ==========================================================

    final notifikasiDitampilkan = List<Map<String, dynamic>>.from(pending);

    // ==========================================================
    // TANDAI SEMUA SEBAGAI SUDAH DIBACA
    // ==========================================================

    for (final item in notifikasiDitampilkan) {
      final jenis = item['jenis']?.toString();

      final id = item['riwayat_id'];

      final keyPrefix = jenis == 'Pengembalian'
          ? 'pengembalian_pending'
          : 'peminjaman_pending';

      if (id != null) {
        _tandaiNotifikasiTerbaca('${keyPrefix}_$id');
      }
    }

    if (!mounted) return;

    // ==========================================================
    // KOSONGKAN BADGE NOTIFIKASI
    // ==========================================================

    setState(() {
      _jumlahNotifikasi = 0;
    });

    // ==========================================================
    // TAMPILKAN BOTTOM SHEET DENGAN DATA SEBELUM DIHAPUS
    // ==========================================================

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F8FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Column(
              children: [
                // ==============================================
                // HEADER (PUTIH)
                // ==============================================
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF1F4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_rounded,
                          color: Color(0xFF0F8A7D),
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifikasi',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Pengajuan yang menunggu tindakan admin.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // ==============================================
                // DAFTAR NOTIFIKASI
                // ==============================================
                Expanded(
                  child: notifikasiDitampilkan.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 52,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Tidak ada notifikasi baru.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                          children: [
                            Text(
                              'Ketuk notifikasi untuk membuka '
                              'pengajuan terkait.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final item in notifikasiDitampilkan) ...[
                              _buildNotifikasiItem(
                                item,
                                onTap: () =>
                                    _aksiNotifikasi(item, sheetContext),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================
  // AKSI SAAT NOTIFIKASI DIKETUK
  // =========================================================

  Future<void> _aksiNotifikasi(
    Map<String, dynamic> item,
    BuildContext sheetContext,
  ) async {
    if (sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }

    final jenis = item['jenis']?.toString() ?? '';

    final id = item['riwayat_id'];

    // -------------------------------------------------------
    // PENGEMBALIAN → BUKA HALAMAN KELOLA PENGEMBALIAN
    // -------------------------------------------------------

    if (jenis == 'Pengembalian') {
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PengembalianAdminScreen(),
        ),
      );

      if (mounted) await _loadDashboard();
      return;
    }

    // -------------------------------------------------------
    // PEMINJAMAN → AMBIL DATA LENGKAP LALU BUKA DETAIL
    // -------------------------------------------------------

    if (id == null) return;

    try {
      // Ambil detail peminjaman lengkap (termasuk nama mahasiswa
      // dan NIM) dari API. Bila tidak ditemukan, backend
      // mengembalikan respons error dan getMap melempar.
      final data = await ApiService.getMap('/peminjaman/$id/detail');

      if (data == null || data.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data peminjaman tidak ditemukan.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailPeminjamanAdminScreen(peminjaman: data),
        ),
      );

      if (mounted) await _loadDashboard();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka detail: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // KARTU NOTIFIKASI
  // =========================================================

  Widget _buildNotifikasiItem(
    Map<String, dynamic> item, {
    required VoidCallback onTap,
  }) {
    final jenis = item['jenis']?.toString() ?? '';

    final nama = item['nama']?.toString() ?? '-';

    final isPeminjaman = jenis == 'Peminjaman';

    final warna = isPeminjaman ? Colors.orange : Colors.teal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: warna.withValues(alpha: 0.18)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPeminjaman ? Icons.outbox_outlined : Icons.inbox_outlined,
                  color: warna,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPeminjaman ? 'Peminjaman Baru' : 'Pengembalian Baru',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isPeminjaman
                          ? '$nama mengajukan peminjaman alat.'
                          : '$nama mengajukan pengembalian alat.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTransaksi() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransaksiAdminScreen()),
    );

    if (mounted) {
      setState(() {
        _selectedIndex = 0;
      });
      await _loadDashboard();
    }
  }

  void _onBottomNavTap(int index) async {
    // -------------------------------------------------------
    // HOME
    // -------------------------------------------------------

    if (index == 0) {
      setState(() {
        _selectedIndex = 0;
      });

      await _loadDashboard();
      return;
    }

    // -------------------------------------------------------
    // ALAT
    // -------------------------------------------------------

    if (index == 1) {
      setState(() {
        _selectedIndex = 1;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const KelolaAlatScreen()),
      );

      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }

      await _loadDashboard();
      return;
    }

    // -------------------------------------------------------
    // TRANSAKSI
    // -------------------------------------------------------

    if (index == 2) {
      setState(() {
        _selectedIndex = 2;
      });
      await _openTransaksi();
      return;
    }

    // -------------------------------------------------------
    // -------------------------------------------------------
    // LAPORAN
    // -------------------------------------------------------

    if (index == 3) {
      setState(() {
        _selectedIndex = 3;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LaporanAdminScreen()),
      );

      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }

      await _loadDashboard();
      return;
    }

    // -------------------------------------------------------
    // PROFIL
    // -------------------------------------------------------

    if (index == 4) {
      setState(() {
        _selectedIndex = 4;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfilAdminScreen()),
      );

      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }

      await _loadDashboard();
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),

      // =====================================================
      // APP BAR
      // =====================================================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Dashboard Admin',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showNotifications,
            icon: Badge(
              isLabelVisible: _jumlahNotifikasi > 0,
              label: Text('$_jumlahNotifikasi'),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.black87,
                size: 27,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // =====================================================
      // BODY
      // =====================================================
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =================================================
                    // SAPAAN
                    // =================================================
                    const Text(
                      'Selamat datang, Admin',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // =================================================
                    // STATISTIK BARIS 1
                    // =================================================
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            count: '$_totalAlat',
                            title: 'Total Alat',
                            icon: Icons.inventory_2_outlined,
                            color: const Color(0xFF0F8A7D),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            count: '$_stokTersedia',
                            title: 'Tersedia',
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // =================================================
                    // STATISTIK BARIS 2
                    // =================================================
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            count: '$_dipinjam',
                            title: 'Dipinjam',
                            icon: Icons.assignment_outlined,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            count: '$_menunggu',
                            title: 'Menunggu',
                            icon: Icons.access_time_rounded,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // =================================================
                    // PEMINJAMAN TERBARU
                    // =================================================
                    const Text(
                      'Peminjaman Terbaru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // =================================================
                    // DATA PEMINJAMAN
                    // =================================================
                    if (_peminjamanTerbaru.isEmpty)
                      _buildEmptyPeminjaman()
                    else
                      ...List.generate(_peminjamanTerbaru.length, (index) {
                        final data = _peminjamanTerbaru[index];

                        final nama = _ambilNilai(
                            data,
                            [
                              'nama_peminjam',
                              'nama_mahasiswa',
                              'nama',
                              'peminjam',
                            ],
                            'Peminjam');

                        final alat = _ambilNilai(
                            data,
                            [
                              'nama_alat',
                              'alat',
                            ],
                            'Alat');

                        final status = _ambilNilai(
                            data,
                            [
                              'status',
                            ],
                            'Menunggu');

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index == _peminjamanTerbaru.length - 1 ? 0 : 12,
                          ),
                          child: _buildPeminjamanCard(
                            nama: nama,
                            alat: alat,
                            status: status,
                            statusColor: _statusColor(status),
                            icon: Icons.person_outline,
                          ),
                        );
                      }),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

      // =====================================================
      // BOTTOM NAVIGATION
      // =====================================================
      //
      // SEKARANG ADA 6 MENU:
      //
      // Home | Alat | Peminjaman | Pengembalian | Laporan | Profil
      //
      // =====================================================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0F8A7D),
        unselectedItemColor: Colors.grey,
        elevation: 10,
        items: const [
          // ---------------------------------------------------
          // HOME
          // ---------------------------------------------------
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),

          // ---------------------------------------------------
          // ALAT
          // ---------------------------------------------------
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Alat',
          ),

          // ---------------------------------------------------
          // TRANSAKSI
          // ---------------------------------------------------
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Transaksi',
          ),

          // ---------------------------------------------------
          // LAPORAN
          // ---------------------------------------------------
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment_outlined),
            activeIcon: Icon(Icons.assessment),
            label: 'Laporan',
          ),

          // ---------------------------------------------------
          // PROFIL
          // ---------------------------------------------------
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CARD STATISTIK
  // =========================================================

  Widget _buildStatCard({
    required String count,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  // =========================================================
  // CARD PEMINJAMAN
  // =========================================================

  Widget _buildPeminjamanCard({
    required String nama,
    required String alat,
    required String status,
    required Color statusColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF0F8A7D).withValues(alpha: 0.1),
            child: Icon(icon, color: const Color(0xFF0F8A7D)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  alat,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DATA KOSONG
  // =========================================================

  Widget _buildEmptyPeminjaman() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.assignment_outlined, size: 50, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            'Belum ada peminjaman.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // AMBIL NILAI MAP
  // =========================================================

  String _ambilNilai(
    Map<String, dynamic> data,
    List<String> keys,
    String defaultValue,
  ) {
    for (final key in keys) {
      if (data.containsKey(key) &&
          data[key] != null &&
          data[key].toString().trim().isNotEmpty) {
        return data[key].toString();
      }
    }

    return defaultValue;
  }

  // =========================================================
  // WARNA STATUS
  // =========================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'dipinjam':
      case 'selesai':
        return Colors.green;

      case 'ditolak':
      case 'dibatalkan':
        return Colors.red;

      case 'dikembalikan':
        return Colors.blue;

      case 'menunggu':
      default:
        return Colors.orange;
    }
  }
}
