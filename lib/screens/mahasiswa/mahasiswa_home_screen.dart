import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../session/user_session.dart';
import 'detail_peminjaman_screen.dart';

class MahasiswaHomeScreen extends StatefulWidget {
  const MahasiswaHomeScreen({super.key});

  @override
  State<MahasiswaHomeScreen> createState() => _MahasiswaHomeScreenState();
}

class _MahasiswaHomeScreenState extends State<MahasiswaHomeScreen>
    with WidgetsBindingObserver {
  // ============================================================
  // WARNA
  // ============================================================

  static const Color primaryColor = Color(0xFF087F72);
  static const Color softNeutral = Color(0xFFEEF1F4);
  static const Color backgroundColor = Color(0xFFF7F8FA);

  // ============================================================
  // DATA PEMINJAMAN AKTIF
  // ============================================================

  List<Map<String, dynamic>> _peminjamanAktif = [];

  bool _isLoadingPeminjaman = true;

  // ============================================================
  // DATA NOTIFIKASI
  // ============================================================

  List<Map<String, dynamic>> _notifikasi = [];

  final Set<String> _notifikasiTerbaca = {};

  /// Kunci penyimpanan status notifikasi terbaca (per HP, per role).
  static const String _storageKey = 'notifikasi_terbaca_mahasiswa';

  bool _isLoadingNotifikasi = false;

  Timer? _notifikasiTimer;

  // ============================================================
  // DATA PENGUMUMAN
  // ============================================================

  final List<Map<String, dynamic>> pengumuman = [
    {
      'judul': 'Laboratorium Sistem Informasi',
      'isi':
          'Laboratorium Sistem Informasi akan tutup pada pukul 17.00 hari ini.\n\n'
              'Silakan menyelesaikan proses pengambilan atau pengembalian alat '
              'sebelum laboratorium tutup.',
      'icon': Icons.campaign_outlined,
    },
    {
      'judul': 'Pemeliharaan & Inventarisasi Alat',
      'isi': 'Seluruh peminjaman alat ditangguhkan sementara pada tanggal '
          '20–21 September untuk pemeliharaan berkala dan stock opname.',
      'icon': Icons.build_circle_outlined,
    },
    {
      'judul': 'Ketentuan Keterlambatan Pengembalian',
      'isi': 'Pengembalian alat yang melewati batas waktu pengembalian akan '
          'dikenakan sanksi pembekuan hak pinjam selama 3 hari. '
          'Harap kembalikan tepat waktu.',
      'icon': Icons.warning_amber_outlined,
    },
    {
      'judul': 'Alat Praktikum Baru Tersedia',
      'isi': 'Unit Multimeter Digital dan Oscilloscope baru telah ditambahkan '
          'ke katalog. Mahasiswa sudah bisa mengajukan peminjaman mulai hari ini.',
      'icon': Icons.inventory_2_outlined,
    },
    {
      'judul': 'Operasional Lab Selama Libur Nasional',
      'isi': 'Laboratorium libur operasional pada tanggal merah. '
          'Pengembalian alat yang jatuh pada hari libur dapat dilakukan '
          'pada hari kerja berikutnya.',
      'icon': Icons.calendar_month_outlined,
    },
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _init();
  }

  Future<void> _init() async {
    // Muat notifikasi yang sudah dibaca (persisten) sebelum polling,
    // supaya notifikasi yang selesai tidak muncul lagi setelah
    // aplikasi ditutup & dibuka kembali.
    await _muatNotifikasiTerbaca();

    if (!mounted) return;

    _loadPeminjamanAktif();
    _loadNotifikasi();

    _notifikasiTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadNotifikasi();
      _loadPeminjamanAktif();
    });
  }

  // ============================================================
  // TANDAI NOTIFIKASI SUDAH DIBACA
  //
  // Status terbaca (notifikasi_terbaca) disimpan lewat
  // SharedPreferences sehingga tetap teringat walau aplikasi
  // ditutup & dibuka lagi. Tidak perlu disimpan di server.
  // ============================================================

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
      // Bila gagal membaca, mulai dari set kosong.
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

  // ============================================================
  // SAAT APLIKASI KEMBALI AKTIF
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotifikasi();
      _loadPeminjamanAktif();
    }
  }

  // ============================================================
  // LOAD PEMINJAMAN AKTIF
  // ============================================================

  Future<void> _loadPeminjamanAktif() async {
    if (!mounted) return;

    if (_peminjamanAktif.isEmpty) {
      setState(() {
        _isLoadingPeminjaman = true;
      });
    }

    try {
      final userId = UserSession.userId;

      if (userId == null) {
        if (!mounted) return;

        setState(() {
          _peminjamanAktif = [];
          _isLoadingPeminjaman = false;
        });

        return;
      }

      final data = await ApiService.getList('/peminjaman/aktif/$userId');

      if (!mounted) return;

      setState(() {
        _peminjamanAktif =
            data.map((item) => Map<String, dynamic>.from(item)).toList();

        _isLoadingPeminjaman = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _peminjamanAktif = [];
        _isLoadingPeminjaman = false;
      });
    }
  }

  // ============================================================
  // LOAD NOTIFIKASI
  // ============================================================

  Future<void> _loadNotifikasi() async {
    if (!mounted) return;

    if (_isLoadingNotifikasi) return;

    _isLoadingNotifikasi = true;

    try {
      final userId = UserSession.userId;

      if (userId == null) {
        if (!mounted) return;

        setState(() {
          _notifikasi = [];
        });

        _isLoadingNotifikasi = false;
        return;
      }

      // Ambil daftar peminjaman & status terbaru dari API.
      // Backend mengembalikan baris yang sama seperti query
      // notifikasi sebelumnya (peminjaman_id, status_peminjaman,
      // tanggal_pinjam, tanggal_kembali, jumlah, nama_alat,
      // pengembalian_id, status_pengembalian).

      final data = await ApiService.getList(
        '/peminjaman/notifikasi-mahasiswa/$userId',
      );

      final List<Map<String, dynamic>> hasilNotifikasi = [];

      for (final row in data) {
        final peminjamanId = row['peminjaman_id'];

        final namaAlat = row['nama_alat']?.toString() ?? 'Alat';

        final jumlah = int.tryParse(row['jumlah']?.toString() ?? '1') ?? 1;

        final statusPeminjaman =
            row['status_peminjaman']?.toString().toLowerCase();

        final pengembalianId = row['pengembalian_id'];

        final statusPengembalian =
            row['status_pengembalian']?.toString().toLowerCase();

        // ======================================================
        // PEMINJAMAN DISETUJUI
        // ======================================================

        if (statusPeminjaman == 'disetujui') {
          final key = 'peminjaman_${peminjamanId}_disetujui';

          // HANYA masukkan kalau BELUM dibaca
          if (!_notifikasiTerbaca.contains(key)) {
            hasilNotifikasi.add({
              'key': key,
              'peminjaman_id': peminjamanId,
              'jenis': 'peminjaman',
              'status': 'disetujui',
              'judul': 'Peminjaman Disetujui',
              'pesan': 'Pengajuan peminjaman $namaAlat sebanyak '
                  '$jumlah unit telah disetujui oleh admin.',
              'icon': Icons.check_circle_outline,
              'color': Colors.green,
            });
          }
        }
        // ======================================================
        // PEMINJAMAN DITOLAK
        // ======================================================
        else if (statusPeminjaman == 'ditolak') {
          final key = 'peminjaman_${peminjamanId}_ditolak';

          // HANYA masukkan kalau BELUM dibaca
          if (!_notifikasiTerbaca.contains(key)) {
            hasilNotifikasi.add({
              'key': key,
              'peminjaman_id': peminjamanId,
              'jenis': 'peminjaman',
              'status': 'ditolak',
              'judul': 'Peminjaman Ditolak',
              'pesan': 'Pengajuan peminjaman $namaAlat sebanyak '
                  '$jumlah unit telah ditolak oleh admin.',
              'icon': Icons.cancel_outlined,
              'color': Colors.red,
            });
          }
        }

        // ======================================================
        // PENGEMBALIAN DISETUJUI
        // ======================================================

        if (pengembalianId != null && statusPengembalian == 'disetujui') {
          final key = 'pengembalian_${pengembalianId}_disetujui';

          // HANYA masukkan kalau BELUM dibaca
          if (!_notifikasiTerbaca.contains(key)) {
            hasilNotifikasi.add({
              'key': key,
              'peminjaman_id': peminjamanId,
              'jenis': 'pengembalian',
              'status': 'disetujui',
              'judul': 'Pengembalian Disetujui',
              'pesan': 'Pengembalian $namaAlat sebanyak '
                  '$jumlah unit telah disetujui oleh admin.',
              'icon': Icons.assignment_turned_in_outlined,
              'color': Colors.green,
            });
          }
        }
        // ======================================================
        // PENGEMBALIAN DITOLAK
        // ======================================================
        else if (pengembalianId != null && statusPengembalian == 'ditolak') {
          final key = 'pengembalian_${pengembalianId}_ditolak';

          // HANYA masukkan kalau BELUM dibaca
          if (!_notifikasiTerbaca.contains(key)) {
            hasilNotifikasi.add({
              'key': key,
              'peminjaman_id': peminjamanId,
              'jenis': 'pengembalian',
              'status': 'ditolak',
              'judul': 'Pengembalian Ditolak',
              'pesan': 'Pengembalian $namaAlat sebanyak '
                  '$jumlah unit telah ditolak oleh admin. '
                  'Silakan periksa kembali alat sebelum '
                  'mengajukan pengembalian lagi.',
              'icon': Icons.cancel_outlined,
              'color': Colors.red,
            });
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _notifikasi = hasilNotifikasi;
      });
    } catch (_) {
      // Jangan tampilkan error setiap polling.
    } finally {
      _isLoadingNotifikasi = false;
    }
  }

  // ============================================================
  // JUMLAH NOTIFIKASI BARU
  // ============================================================

  int get _jumlahNotifikasiBaru {
    return _notifikasi.where((item) {
      final key = item['key']?.toString();

      if (key == null) {
        return false;
      }

      return !_notifikasiTerbaca.contains(key);
    }).length;
  }

  // ============================================================
  // BUKA NOTIFIKASI
  // ============================================================

  Future<void> _bukaNotifikasi() async {
    // ==========================================================
    // SIMPAN DULU NOTIFIKASI YANG MAU DITAMPILKAN
    // ==========================================================

    final notifikasiDitampilkan = List<Map<String, dynamic>>.from(_notifikasi);

    // ==========================================================
    // TANDAI SEMUA SEBAGAI SUDAH DIBACA
    // ==========================================================

    for (final item in notifikasiDitampilkan) {
      final key = item['key']?.toString();

      if (key != null && key.isNotEmpty) {
        _tandaiNotifikasiTerbaca(key);
      }
    }

    // ==========================================================
    // KOSONGKAN NOTIFIKASI DI LONCENG
    // ==========================================================

    if (mounted) {
      setState(() {
        _notifikasi = [];
      });
    }

    // ==========================================================
    // BOTTOM SHEET NOTIFIKASI
    // ==========================================================

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          builder: (context, scrollController) {
            return Column(
              children: [
                // ==============================================
                // HEADER GRADIENT
                // ==============================================
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: softNeutral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: primaryColor,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 15),
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
                              'Ketuk untuk melihat detail peminjamanmu.',
                              style: TextStyle(
                                fontSize: 13.5,
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
                if (notifikasiDitampilkan.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 58,
                              color: Color(0xFFD9DDE2),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Belum ada notifikasi baru',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Notifikasi tentang peminjaman dan '
                              'pengembalian alatmu akan muncul di sini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      itemCount: notifikasiDitampilkan.length,
                      itemBuilder: (context, index) {
                        final item = notifikasiDitampilkan[index];

                        final color = item['color'] as Color? ?? primaryColor;

                        final icon = item['icon'] as IconData? ??
                            Icons.notifications_outlined;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _aksiNotifikasi(item),
                            child: Ink(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.22),
                                ),
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
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(icon, color: color, size: 25),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['judul']?.toString() ??
                                              'Notifikasi',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          item['pesan']?.toString() ?? '',
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.grey.shade400,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) {
                        return const SizedBox(height: 12);
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // AKSI KETIKA NOTIFIKASI DIKETUK
  // ============================================================

  Future<void> _aksiNotifikasi(Map<String, dynamic> item) async {
    final peminjamanId = item['peminjaman_id'];

    if (peminjamanId == null) return;

    // ==========================================================
    // TAMBAHKAN KE DAFTAR SUDAH DIBACA (JIKA BELUM)
    // ==========================================================

    final key = item['key']?.toString();

    if (key != null && key.isNotEmpty && !_notifikasiTerbaca.contains(key)) {
      _tandaiNotifikasiTerbaca(key);
    }

    // ==========================================================
    // TUTUP BOTTOM SHEET
    // ==========================================================

    if (!mounted) return;

    Navigator.pop(context);

    // ==========================================================
    // AMBIL DATA PEMINJAMAN LENGKAP
    // ==========================================================

    final peminjaman = await _ambilPeminjaman(
      int.tryParse(peminjamanId.toString()) ?? 0,
    );

    if (!mounted) return;

    if (peminjaman == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peminjaman tidak ditemukan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ==========================================================
    // BUKA HALAMAN DETAIL PEMINJAMAN
    // ==========================================================

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailPeminjamanScreen(peminjaman: peminjaman),
      ),
    );

    // ==========================================================
    // MUAT ULANG DATA SETELAH KEMBALI
    // ==========================================================

    await _loadNotifikasi();
    await _loadPeminjamanAktif();
  }

  // ============================================================
  // AMBIL DATA PEMINJAMAN LENGKAP BERDASARKAN ID
  // ============================================================

  Future<Map<String, dynamic>?> _ambilPeminjaman(int peminjamanId) async {
    try {
      // Endpoint mengembalikan detail peminjaman dengan bentuk
      // yang sama seperti query lengkap sebelumnya.
      final data = await ApiService.getMap('/peminjaman/$peminjamanId/detail');

      if (data == null || data.isEmpty) return null;

      return data;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // PENGUMUMAN
  // ============================================================

  void _bukaPengumuman() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Column(
              children: [
                // ==============================================
                // HEADER GRADIENT
                // ==============================================
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: softNeutral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.campaign_outlined,
                          color: primaryColor,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengumuman Laboratorium',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Informasi & ketentuan terbaru untuk mahasiswa.',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // ==============================================
                // DAFTAR PENGUMUMAN
                // ==============================================
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    itemCount: pengumuman.length,
                    itemBuilder: (context, index) {
                      return _pengumumanItem(pengumuman[index]);
                    },
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 12);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // PANDUAN
  // ============================================================

  void _bukaPanduan() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Column(
              children: [
                // ==============================================
                // HEADER GRADIENT
                // ==============================================
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: softNeutral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu_book_outlined,
                          color: primaryColor,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panduan Peminjaman & Pengembalian Alat',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Ikuti langkah mudah berikut.',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // ==============================================
                // LANGKAH-LANGKAH (TIMELINE)
                // ==============================================
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                    children: [
                      _panduanItem(
                        number: '1',
                        icon: Icons.search,
                        title: 'Pilih Alat',
                        description:
                            'Pilih alat praktikum yang ingin Anda pinjam melalui halaman Alat.',
                      ),
                      _panduanItem(
                        number: '2',
                        icon: Icons.description_outlined,
                        title: 'Ajukan Peminjaman',
                        description:
                            'Isi form peminjaman, kemudian kirim pengajuan.',
                      ),
                      _panduanItem(
                        number: '3',
                        icon: Icons.hourglass_top,
                        title: 'Tunggu Persetujuan',
                        description:
                            'Tunggu admin memeriksa dan menyetujui pengajuan peminjaman.',
                      ),
                      _panduanItem(
                        number: '4',
                        icon: Icons.inventory_2_outlined,
                        title: 'Ambil Alat',
                        description:
                            'Setelah disetujui, ambil alat sesuai jadwal yang telah ditentukan.',
                      ),
                      _panduanItem(
                        number: '5',
                        icon: Icons.assignment_return_outlined,
                        title: 'Kembalikan Alat',
                        description:
                            'Ajukan pengembalian untuk dikonfirmasi oleh admin dan serahkan kembali alat ke laboratorium.',
                        isLast: true,
                      ),
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

  // ============================================================
  // ITEM PANDUAN
  // ============================================================

  Widget _panduanItem({
    required String number,
    required IconData icon,
    required String title,
    required String description,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==========================================
          // NOMOR LANGKAH + GARIS PENGHUBUNG
          // ==========================================
          Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: softNeutral,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 15),

          // ==========================================
          // KARTU DETAIL LANGKAH
          // ==========================================
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: softNeutral,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Icon(icon, color: primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT TANGGAL
  // ============================================================

  String _formatTanggal(String? tanggal) {
    if (tanggal == null || tanggal.isEmpty) {
      return '-';
    }

    try {
      final date = DateTime.parse(tanggal);

      const bulan = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];

      return '${date.day.toString().padLeft(2, '0')} '
          '${bulan[date.month - 1]} '
          '${date.year}';
    } catch (_) {
      return tanggal;
    }
  }

  // ============================================================
  // CARD PEMINJAMAN AKTIF
  // ============================================================

  Widget _statusPeminjamanCard() {
    if (_isLoadingPeminjaman) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: primaryColor,
            ),
          ),
        ),
      );
    }

    if (_peminjamanAktif.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: softNeutral,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: primaryColor,
                size: 31,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Belum Ada Peminjaman Aktif',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _peminjamanAktif.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _peminjamanAktifItem(item),
        );
      }).toList(),
    );
  }

  // ============================================================
  // SATU CARD PEMINJAMAN AKTIF
  // ============================================================

  Widget _peminjamanAktifItem(Map<String, dynamic> item) {
    final namaAlat = item['nama_alat']?.toString() ?? 'Alat';

    final jumlah = int.tryParse(item['jumlah']?.toString() ?? '1') ?? 1;

    final tanggalKembali = item['tanggal_kembali']?.toString();

    final teksJumlah = '$jumlah Alat Sedang Dipinjam';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFE9ECF8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF4B57B5),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        teksJumlah,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Aktif',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  namaAlat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 5),
                Text(
                  'Batas kembali: '
                  '${_formatTanggal(tanggalKembali)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD PANDUAN
  //
  // KARTU PREVIEW PANDUAN, BISA DIKLIK UNTUK MEMBUKA PANDUAN.
  // ============================================================

  Widget _panduanCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _bukaPanduan,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const _CardIconCircle(
                icon: Icons.menu_book_outlined,
                iconColor: primaryColor,
                backgroundColor: softNeutral,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panduan Peminjaman & Pengembalian Alat',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Cara mudah meminjam & mengembalikan alat lab.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                color: primaryColor,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final jumlahNotifikasi = _jumlahNotifikasiBaru;

    return Scaffold(
      backgroundColor: backgroundColor,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'SIPALAB',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: _bukaNotifikasi,
                icon: Icon(
                  jumlahNotifikasi > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  size: 30,
                  color: jumlahNotifikasi > 0 ? primaryColor : Colors.black87,
                ),
              ),
              if (jumlahNotifikasi > 0)
                Positioned(
                  right: 4,
                  top: 5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      jumlahNotifikasi > 9 ? '9+' : jumlahNotifikasi.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadPeminjamanAktif();
            await _loadNotifikasi();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================================================
                // GREETING
                // ==================================================
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, ${UserSession.nama ?? 'Mahasiswa'} 👋',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Mau Meminjam Apa Hari Ini?',
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // ==================================================
                // PENGUMUMAN
                // ==================================================
                const Text(
                  'Pengumuman',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),

                // KARTU PREVIEW, BISA DIKLIK.
                _pengumumanCard(),

                const SizedBox(height: 30),

                // ==================================================
                // PEMINJAMAN AKTIF
                // ==================================================
                const Text(
                  'Peminjaman Aktif',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),

                _statusPeminjamanCard(),

                const SizedBox(height: 30),

                // ==================================================
                // PANDUAN
                // ==================================================
                const Text(
                  'Panduan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),

                // KARTU PREVIEW, BISA DIKLIK.
                _panduanCard(),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CARD PENGUMUMAN
  //
  // PREVIEW PENGUMUMAN PALING BARU DI HOME.
  // ============================================================

  Widget _pengumumanCard() {
    if (pengumuman.isEmpty) {
      return const SizedBox.shrink();
    }

    final item = pengumuman.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _bukaPengumuman,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: softNeutral,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['judul'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['isi'] as String,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ITEM PENGUMUMAN (DIALOG)
  // ============================================================

  Widget _pengumumanItem(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            decoration: const BoxDecoration(
              color: softNeutral,
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['judul'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['isi'] as String,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _notifikasiTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }
}

// ============================================================
// LINGKARAN IKON PADA KARTU PREVIEW (PENGUMUMAN / PANDUAN)
// ============================================================

class _CardIconCircle extends StatelessWidget {
  const _CardIconCircle({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: 30),
    );
  }
}
