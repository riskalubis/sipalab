import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/peminjaman_service.dart';
import '../../services/pengembalian_service.dart';
import 'detail_peminjaman_admin_screen.dart';

class TransaksiAdminScreen extends StatefulWidget {
  const TransaksiAdminScreen({super.key});

  @override
  State<TransaksiAdminScreen> createState() => _TransaksiAdminScreenState();
}

class _TransaksiAdminScreenState extends State<TransaksiAdminScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF0F8A7D);
  static const Color _bg = Color(0xFFF7F8FA);

  late final TabController _tabController;

  // ----------------------------------------------------------
  // DATA PEMINJAMAN
  // ----------------------------------------------------------

  List<Map<String, dynamic>> _listPeminjaman = [];
  bool _isLoadingPeminjaman = true;
  String _filterPeminjaman = 'Semua';

  // ----------------------------------------------------------
  // DATA PENGEMBALIAN
  // ----------------------------------------------------------

  List<Map<String, dynamic>> _listPengembalian = [];
  bool _isLoadingPengembalian = true;
  String _filterPengembalian = 'Semua';

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _loadPeminjaman();
    _loadPengembalian();

    // Pindah tab → segarkan data tab tersebut dari server.
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _loadPeminjaman();
      _loadPengembalian();
    });

    // Sinkronkan transaksi secara otomatis: data baru dari mahasiswa
    // (peminjaman/pengembalian baru) muncul tanpa harus keluar layar.
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadPeminjaman();
      _loadPengembalian();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PEMINJAMAN
  // ============================================================

  Future<void> _loadPeminjaman({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoadingPeminjaman = true);
    }

    try {
      // Endpoint /peminjaman/admin mengembalikan seluruh transaksi
      // peminjaman (disusun menunggu duluan) lengkap dengan data
      // mahasiswa & alat. getListFresh melewati cache 20 detik supaya
      // daftar transaksi selalu sinkron dengan server.
      final data = await ApiService.getListFresh('/peminjaman/admin');

      if (!mounted) return;

      setState(() {
        _listPeminjaman = data;
        _isLoadingPeminjaman = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingPeminjaman = false;
      });

      // Sinkronasi berkala (timer) gagal → abaikan diam-diam supaya
      // tidak memunculkan snackbar berulang saat server offline.
      if (!showLoading && _listPeminjaman.isNotEmpty) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data peminjaman: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // LOAD PENGEMBALIAN
  // ============================================================

  Future<void> _loadPengembalian({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoadingPengembalian = true);
    }

    try {
      // Endpoint /pengembalian/admin?status=all mengembalikan seluruh
      // pengembalian (menunggu + riwayat disetujui/ditolak) lengkap
      // dengan detail alat yang dikembalikan.
      final dataBaru =
          await ApiService.getListFresh('/pengembalian/admin?status=all');

      if (!mounted) return;

      setState(() {
        _listPengembalian = dataBaru;
        _isLoadingPengembalian = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingPengembalian = false;
      });

      // Sinkronasi berkala (timer) gagal → abaikan diam-diam supaya
      // tidak memunculkan snackbar berulang saat server offline.
      if (!showLoading && _listPengembalian.isNotEmpty) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat pengajuan pengembalian: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // PEMINJAMAN: UBAH STATUS
  // ============================================================

  Future<void> _ubahStatusPeminjaman(
    Map<String, dynamic> item,
    String statusBaru,
  ) async {
    final peminjamanId = item['id'];

    try {
      // Ubah status lewat API. Validasi status terbaru, cek stok,
      // dan pengurangan stok dilakukan backend secara atomik.
      await PeminjamanService().updateStatusPeminjaman(
        peminjamanId,
        statusBaru,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Peminjaman berhasil di'
            '${statusBaru == 'disetujui' ? 'setujui' : 'tolak'}.',
          ),
          backgroundColor:
              statusBaru == 'disetujui' ? Colors.green : Colors.red,
        ),
      );

      await _loadPeminjaman();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _konfirmasiPeminjaman(
    Map<String, dynamic> item,
    String statusBaru,
  ) async {
    final nama = item['nama_mahasiswa']?.toString() ?? '-';
    final alat = item['nama_alat']?.toString() ?? '-';

    final isSetujui = statusBaru == 'disetujui';

    final hasil = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isSetujui ? 'Setujui Peminjaman' : 'Tolak Peminjaman'),
          content: Text(
            isSetujui
                ? 'Apakah Anda yakin ingin menyetujui '
                    'peminjaman $alat oleh $nama?\n\n'
                    'Stok alat akan otomatis berkurang sesuai jumlah peminjaman.'
                : 'Apakah Anda yakin ingin menolak '
                    'peminjaman $alat oleh $nama?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSetujui ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(isSetujui ? 'Setujui' : 'Tolak'),
            ),
          ],
        );
      },
    );

    if (hasil != true) return;

    await _ubahStatusPeminjaman(item, statusBaru);
  }

  // ============================================================
  // PENGEMBALIAN: SETUJU / TOLAK
  // ============================================================

  Future<void> _setujuiPengembalian(Map<String, dynamic> data) async {
    final pengembalianId = data['pengembalian_id'];
    final peminjamanId = data['peminjaman_id'];

    final nama = data['nama_mahasiswa']?.toString() ?? '-';

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Setujui Pengembalian'),
          content: Text(
            'Apakah alat yang dikembalikan oleh $nama sudah diperiksa dan dapat disetujui?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('SETUJUI'),
            ),
          ],
        );
      },
    );

    if (konfirmasi != true) return;

    try {
      // Service menjamin stok hanya dikembalikan SATU KALI
      // (hanya pengembalian berstatus 'menunggu' yang diproses).
      await PengembalianService().setujuiPengembalian(
        pengembalianId: pengembalianId,
        peminjamanId: peminjamanId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Pengembalian disetujui. Stok alat telah dikembalikan.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadPengembalian();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyetujui pengembalian: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _tolakPengembalian(Map<String, dynamic> data) async {
    final pengembalianId = data['pengembalian_id'];
    final nama = data['nama_mahasiswa']?.toString() ?? '-';

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tolak Pengembalian'),
          content: Text(
            'Apakah pengembalian dari $nama akan ditolak?\n\n'
            'Mahasiswa harus memperbaiki alat terlebih dahulu '
            'dan mengajukan pengembalian kembali.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('TOLAK'),
            ),
          ],
        );
      },
    );

    if (konfirmasi != true) return;

    try {
      final berhasil = await PengembalianService().tolakPengembalian(
        pengembalianId: pengembalianId,
      );

      if (!berhasil) {
        throw Exception('Pengembalian ini sudah diproses.');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pengembalian ditolak. Mahasiswa harus memperbaiki alat.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      await _loadPengembalian();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menolak pengembalian: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // LIHAT DETAIL PEMINJAMAN TERKAIT (dipakai riwayat pengembalian)
  // ============================================================

  Future<void> _lihatDetailPengembalian(Map<String, dynamic> item) async {
    final peminjamanId = item['peminjaman_id'];

    if (peminjamanId == null) return;

    try {
      final data = await ApiService.getMap('/peminjaman/$peminjamanId/detail');

      if (!mounted) return;

      if (data == null || data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data peminjaman tidak ditemukan.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailPeminjamanAdminScreen(peminjaman: data),
        ),
      );

      await _loadPengembalian();
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

  // ============================================================
  // FORMAT HELPERS
  // ============================================================

  String _formatStatus(String? status) {
    switch (status) {
      case 'menunggu':
        return 'Menunggu';
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      case 'dipinjam':
        return 'Dipinjam';
      case 'dikembalikan':
        return 'Dikembalikan';
      case 'selesai':
        return 'Selesai';
      default:
        return status ?? '-';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'disetujui':
      case 'dipinjam':
        return Colors.green;
      case 'menunggu':
        return Colors.orange;
      case 'ditolak':
        return Colors.red;
      case 'dikembalikan':
        return Colors.teal;
      case 'selesai':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTanggal(String? tanggal) {
    if (tanggal == null || tanggal.isEmpty) return '-';

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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Transaksi'),
        centerTitle: true,
        backgroundColor: _bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primary,
          indicatorWeight: 3,
          labelColor: _primary,
          unselectedLabelColor: Colors.grey,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(
              icon: Icon(Icons.outbox_outlined),
              text: 'Peminjaman',
            ),
            Tab(
              icon: Icon(Icons.inbox_outlined),
              text: 'Pengembalian',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ======================================================
          // TAB PEMINJAMAN
          // ======================================================
          _buildPeminjamanTab(),

          // ======================================================
          // TAB PENGEMBALIAN
          // ======================================================
          _buildPengembalianTab(),
        ],
      ),
    );
  }

  // ============================================================
  // TAB PEMINJAMAN
  // ============================================================

  Widget _buildPeminjamanTab() {
    final filtered = _filterPeminjamanList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ================================================
        // FILTER (selalu tampil, meski hasil filter kosong)
        // ================================================
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildFilterChips(
            nilai: _filterPeminjaman,
            pilihan: const ['Semua', 'Menunggu', 'Riwayat'],
            onDipilih: (v) {
              setState(() => _filterPeminjaman = v);
              // Setiap ganti filter → ambil data terbaru dari server
              // supaya daftar "menunggu" tidak kosong karena cache basi.
              _loadPeminjaman(showLoading: true);
            },
          ),
        ),
        Expanded(
          child: _isLoadingPeminjaman
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : filtered.isEmpty
                  ? _emptyState(
                      icon: Icons.outbox_outlined,
                      title: 'Belum ada transaksi peminjaman',
                      subtitle:
                          'Pengajuan peminjaman mahasiswa akan muncul di sini.',
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadPeminjaman(),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];

                          final status =
                              item['status']?.toString() ?? 'menunggu';

                          final warnaStatus = _statusColor(status);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ==========================================
                                // ID + STATUS
                                // ==========================================
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'PMJ${item['id'].toString().padLeft(3, '0')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            warnaStatus.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _formatStatus(status),
                                        style: TextStyle(
                                          color: warnaStatus,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                // ==========================================
                                // NAMA ALAT + PEMINJAM
                                // ==========================================
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: _primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: _primary,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['nama_alat']?.toString() ??
                                                'Alat',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item['nama_mahasiswa'] ?? '-'} '
                                            '(${item['nim'] ?? '-'})',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // ==========================================
                                // INFO JUMLAH & TANGGAL
                                // ==========================================
                                _infoRow(
                                  Icons.storage_outlined,
                                  'Jumlah: ${item['jumlah'] ?? 0} Unit  •  Stok: ${item['stok'] ?? 0}',
                                ),

                                const SizedBox(height: 6),

                                _infoRow(
                                  Icons.date_range_outlined,
                                  '${_formatTanggal(item['tgl_pinjam']?.toString())} '
                                  's/d ${_formatTanggal(item['tgl_kembali']?.toString())}',
                                ),

                                if (item['keperluan'] != null &&
                                    item['keperluan']
                                        .toString()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  _infoRow(
                                    Icons.description_outlined,
                                    item['keperluan'].toString(),
                                  ),
                                ],

                                // ==========================================
                                // AKSI
                                // ==========================================
                                if (status == 'menunggu') ...[
                                  const SizedBox(height: 14),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _konfirmasiPeminjaman(
                                                  item, 'ditolak'),
                                          icon:
                                              const Icon(Icons.close, size: 18),
                                          label: const Text('Tolak'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(
                                                color: Colors.red),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _konfirmasiPeminjaman(
                                                  item, 'disetujui'),
                                          icon:
                                              const Icon(Icons.check, size: 18),
                                          label: const Text('Setujui'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                DetailPeminjamanAdminScreen(
                                              peminjaman: item,
                                            ),
                                          ),
                                        );
                                        await _loadPeminjaman();
                                      },
                                      icon: const Icon(Icons.info_outline,
                                          size: 18),
                                      label: const Text('Lihat Detail'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ============================================================
  // FILTER LIST PEMINJAMAN
  // ============================================================

  List<Map<String, dynamic>> _filterPeminjamanList() {
    if (_filterPeminjaman == 'Menunggu') {
      return _listPeminjaman
          .where((item) => item['status']?.toString() == 'menunggu')
          .toList();
    }

    if (_filterPeminjaman == 'Riwayat') {
      return _listPeminjaman
          .where((item) => item['status']?.toString() != 'menunggu')
          .toList();
    }

    return _listPeminjaman;
  }

  // ============================================================
  // FILTER LIST PENGEMBALIAN
  // ============================================================

  String? _statusPengembalian(Map<String, dynamic> item) =>
      item['status']?.toString() ?? item['status_pengembalian']?.toString();

  List<Map<String, dynamic>> _filterPengembalianList() {
    if (_filterPengembalian == 'Menunggu') {
      return _listPengembalian
          .where((item) => _statusPengembalian(item) == 'menunggu')
          .toList();
    }

    if (_filterPengembalian == 'Riwayat') {
      return _listPengembalian.where((item) {
        final s = _statusPengembalian(item);
        return s != null && s != 'menunggu' && s.isNotEmpty;
      }).toList();
    }

    return _listPengembalian;
  }

  // ============================================================
  // FILTER CHIPS
  // ============================================================

  Widget _buildFilterChips({
    required String nilai,
    required List<String> pilihan,
    required ValueChanged<String> onDipilih,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: pilihan.map((p) {
            final aktif = nilai == p;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p),
                selected: aktif,
                selectedColor: _primary.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  color: aktif ? _primary : Colors.grey.shade700,
                  fontWeight: aktif ? FontWeight.bold : FontWeight.w500,
                ),
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: aktif ? _primary : Colors.grey.shade300,
                  ),
                ),
                onSelected: (_) => onDipilih(p),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ============================================================
  // TAB PENGEMBALIAN
  // ============================================================

  Widget _buildPengembalianTab() {
    final filtered = _filterPengembalianList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ================================================
        // FILTER (selalu tampil, meski hasil filter kosong)
        // ================================================
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildFilterChips(
            nilai: _filterPengembalian,
            pilihan: const ['Semua', 'Menunggu', 'Riwayat'],
            onDipilih: (v) {
              setState(() => _filterPengembalian = v);
              // Setiap ganti filter → ambil data terbaru dari server
              // supaya daftar "menunggu" tidak kosong karena cache basi.
              _loadPengembalian(showLoading: true);
            },
          ),
        ),
        Expanded(
          child: _isLoadingPengembalian
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : filtered.isEmpty
                  ? _emptyState(
                      icon: Icons.inbox_outlined,
                      title: 'Belum ada data pengembalian',
                      subtitle:
                          'Pengajuan & riwayat pengembalian mahasiswa akan muncul di sini.',
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadPengembalian(),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];

                          final nama =
                              item['nama_mahasiswa']?.toString() ?? '-';
                          final nim = item['nim']?.toString() ?? '-';
                          final kondisi = item['kondisi']?.toString() ?? '-';
                          final catatan = item['catatan']?.toString() ?? '';
                          final tanggal =
                              item['tanggal_pengembalian']?.toString() ?? '-';

                          final status = item['status']?.toString() ??
                              item['status_pengembalian']?.toString() ??
                              'menunggu';

                          final warnaStatus = _statusColor(status);

                          final detail = (item['detail'] as List?) ?? [];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ======================================
                                // MAHASISWA
                                // ======================================
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          _primary.withValues(alpha: 0.08),
                                      child: const Icon(
                                        Icons.person_outline,
                                        color: _primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nama,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'NIM: $nim',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            warnaStatus.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _formatStatus(status),
                                        style: TextStyle(
                                          color: warnaStatus,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const Divider(height: 24),

                                // ======================================
                                // ALAT YANG DIKEMBALIKAN
                                // ======================================
                                const Text(
                                  'Alat yang Dikembalikan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                ...detail.map((d) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                              d['nama_alat']?.toString() ??
                                                  '-'),
                                        ),
                                        Text(
                                          '${d['jumlah'] ?? 0} Unit',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                const SizedBox(height: 10),

                                // ======================================
                                // KONDISI
                                // ======================================
                                Row(
                                  children: [
                                    const Text(
                                      'Kondisi: ',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Text(
                                      kondisi,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kondisi == 'Baik'
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  'Diajukan: ${_formatTanggal(tanggal)}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),

                                if (catatan.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Catatan: $catatan',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // ======================================
                                // BUTTON SETUJU/TOLAK (menunggu) ATAU
                                // LIHAT DETAIL (riwayat)
                                // ======================================
                                if (status == 'menunggu')
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _setujuiPengembalian(item),
                                          icon:
                                              const Icon(Icons.check, size: 18),
                                          label: const Text('SETUJUI'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 13),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _tolakPengembalian(item),
                                          icon:
                                              const Icon(Icons.close, size: 18),
                                          label: const Text('TOLAK'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 13),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _lihatDetailPengembalian(item),
                                      icon: const Icon(Icons.info_outline,
                                          size: 18),
                                      label: const Text('Lihat Detail'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ============================================================
  // HELPERS UI
  // ============================================================

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadPeminjaman();
        await _loadPengembalian();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Icon(icon, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
