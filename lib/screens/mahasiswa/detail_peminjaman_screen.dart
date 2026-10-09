import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/status_helper.dart';
import 'pengembalian_screen.dart';

class DetailPeminjamanScreen extends StatefulWidget {
  final Map<String, dynamic> peminjaman;

  const DetailPeminjamanScreen({super.key, required this.peminjaman});

  @override
  State<DetailPeminjamanScreen> createState() => _DetailPeminjamanScreenState();
}

class _DetailPeminjamanScreenState extends State<DetailPeminjamanScreen> {
  String? statusPengembalian;
  String? kondisiPengembalian;
  String? catatanPengembalian;
  String? tanggalPengembalian;

  bool isLoadingPengembalian = true;

  static const Color primaryColor = Color(0xFF087F72);

  @override
  void initState() {
    super.initState();
    _loadPengembalian();
  }

  // ============================================================
  // LOAD DATA PENGEMBALIAN
  // ============================================================

  Future<void> _loadPengembalian() async {
    if (!mounted) return;

    setState(() {
      isLoadingPengembalian = true;
    });

    try {
      final peminjamanId = widget.peminjaman['id'];

      if (peminjamanId == null) {
        if (!mounted) return;

        setState(() {
          statusPengembalian = null;
          kondisiPengembalian = null;
          catatanPengembalian = null;
          tanggalPengembalian = null;
          isLoadingPengembalian = false;
        });

        return;
      }

      final data = await ApiService.getList(
        '/pengembalian?peminjaman_id=$peminjamanId&limit=1',
      );

      if (!mounted) return;

      if (data.isNotEmpty) {
        final pengembalian = data.first;

        setState(() {
          statusPengembalian = pengembalian['status']?.toString().toLowerCase();

          kondisiPengembalian = pengembalian['kondisi']?.toString();

          catatanPengembalian = pengembalian['catatan']?.toString();

          tanggalPengembalian =
              pengembalian['tanggal_pengembalian']?.toString();

          isLoadingPengembalian = false;
        });
      } else {
        setState(() {
          statusPengembalian = null;
          kondisiPengembalian = null;
          catatanPengembalian = null;
          tanggalPengembalian = null;
          isLoadingPengembalian = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingPengembalian = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data pengembalian: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // FORMAT TANGGAL
  // ============================================================
  // Selalu gunakan helper pusat supaya waktu ("T...", "00:00:00",
  // ".0000000") tidak pernah tampil.
  String _formatTanggal(String? tanggal) {
    return StatusHelper.formatTanggal(tanggal);
  }

  // ============================================================
  // BUKA FORM PENGEMBALIAN
  // ============================================================

  Future<void> _bukaFormPengembalian() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PengembalianScreen(peminjaman: widget.peminjaman),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _loadPengembalian();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final statusPeminjaman = StatusHelper.normalizePeminjaman(
      widget.peminjaman['status']?.toString(),
    );

    // ==========================================================
    // TENTUKAN STATUS YANG SEDANG DITAMPILKAN
    // ==========================================================
    // Mengikuti spesifikasi gabungan peminjaman + pengembalian:
    //  - Pengembalian diajukan       -> Konfirmasi Pengembalian
    //  - Pengembalian ditolak        -> Pengembalian Ditolak
    //  - Pengembalian disetujui      -> Selesai
    //  - Tanpa pengajuan pengembalian-> status peminjaman

    final bool sedangMengembalikan = statusPengembalian != null &&
        (statusPengembalian == 'menunggu' ||
            statusPengembalian == 'ditolak' ||
            statusPengembalian == 'disetujui');

    final statusDatabase = StatusHelper.combinedStatus(
      statusPeminjaman,
      statusPengembalian,
    );

    final judulStatus =
        sedangMengembalikan ? 'Status Pengembalian' : 'Status Peminjaman';

    final statusTampilan = StatusHelper.label(statusDatabase);

    final statusColor = StatusHelper.color(statusDatabase);

    final namaAlat = widget.peminjaman['nama_alat']?.toString() ??
        widget.peminjaman['alat']?.toString() ??
        'Alat';

    final jumlah = widget.peminjaman['jumlah']?.toString() ?? '1';

    final id = widget.peminjaman['id']?.toString() ?? '-';

    final keperluan = widget.peminjaman['keperluan']?.toString() ?? '-';

    final tanggalPinjam = widget.peminjaman['tgl_pinjam']?.toString() ??
        widget.peminjaman['tanggal_pinjam']?.toString();

    final tanggalKembali = widget.peminjaman['tgl_kembali']?.toString() ??
        widget.peminjaman['tanggal_kembali']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Peminjaman')),
      body: RefreshIndicator(
        onRefresh: _loadPengembalian,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =====================================================
              // STATUS
              // =====================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      statusDatabase == 'ditolak' ||
                              statusDatabase == StatusHelper.pgDitolak
                          ? Icons.cancel_outlined
                          : statusDatabase == 'disetujui' ||
                                  statusDatabase == 'selesai'
                              ? Icons.check_circle_outline
                              : Icons.assignment_outlined,
                      size: 42,
                      color: statusColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      judulStatus,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusTampilan,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // =====================================================
              // INFORMASI ALAT
              // =====================================================
              const Text(
                'Informasi Alat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildRowDetail('ID Peminjaman', 'PMJ$id'),
                      const Divider(),
                      _buildRowDetail('Nama Alat', namaAlat),
                      const Divider(),
                      _buildRowDetail('Jumlah', '$jumlah Unit'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // =====================================================
              // JADWAL
              // =====================================================
              const Text(
                'Jadwal Peminjaman',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildRowDetail(
                        'Tanggal Pinjam',
                        _formatTanggal(tanggalPinjam),
                      ),
                      const Divider(),
                      _buildRowDetail(
                        'Tanggal Kembali',
                        _formatTanggal(tanggalKembali),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // =====================================================
              // KEPERLUAN
              // =====================================================
              const Text(
                'Keperluan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(keperluan, style: const TextStyle(fontSize: 15)),
                ),
              ),

              const SizedBox(height: 30),

              // =====================================================
              // LOADING
              // =====================================================
              if (isLoadingPengembalian)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                ),

              // =====================================================
              // INFORMASI PENGEMBALIAN
              // =====================================================
              if (!isLoadingPengembalian && statusPengembalian != null)
                _buildPengembalianInfo(statusPeminjaman),

              // =====================================================
              // TOMBOL PENGEMBALIAN
              // =====================================================
              if (!isLoadingPengembalian &&
                  statusPeminjaman == 'disetujui' &&
                  (statusPengembalian == null ||
                      statusPengembalian == 'ditolak'))
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _bukaFormPengembalian,
                    icon: const Icon(Icons.assignment_return),
                    label: Text(
                      statusPengembalian == 'ditolak'
                          ? 'AJUKAN KEMBALI'
                          : 'AJUKAN PENGEMBALIAN',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

              // =====================================================
              // PENGEMBALIAN MENUNGGU
              // =====================================================
              if (statusPengembalian == 'menunggu')
                _buildInfoBox(
                  icon: Icons.info_outline,
                  color: Colors.orange,
                  title: 'Pengembalian Menunggu Konfirmasi',
                  text: 'Pengajuan pengembalian sedang menunggu '
                      'konfirmasi dari admin.',
                ),

              // =====================================================
              // PEMINJAMAN MENUNGGU
              // =====================================================
              if (statusPengembalian == null && statusPeminjaman == 'menunggu')
                _buildInfoBox(
                  icon: Icons.info_outline,
                  color: Colors.orange,
                  title: 'Peminjaman Menunggu Konfirmasi',
                  text: 'Pengajuan peminjaman sedang menunggu '
                      'konfirmasi dari admin.',
                ),

              // =====================================================
              // PENGEMBALIAN DITOLAK
              // =====================================================
              if (statusPengembalian == 'ditolak')
                _buildInfoBox(
                  icon: Icons.cancel_outlined,
                  color: Colors.red,
                  title: 'Pengembalian Ditolak',
                  text: 'Pengajuan pengembalian ditolak. '
                      'Silakan periksa catatan dan ajukan kembali.',
                ),

              // =====================================================
              // PEMINJAMAN DITOLAK
              // =====================================================
              if (statusPengembalian == null && statusPeminjaman == 'ditolak')
                _buildInfoBox(
                  icon: Icons.cancel_outlined,
                  color: Colors.red,
                  title: 'Peminjaman Ditolak',
                  text: 'Peminjaman ini ditolak oleh admin.',
                ),

              // =====================================================
              // PEMINJAMAN SELESAI
              // =====================================================
              if (statusPengembalian == 'disetujui')
                _buildInfoBox(
                  icon: Icons.check_circle_outline,
                  color: Colors.blue,
                  title: 'Peminjaman Selesai',
                  text: 'Alat telah dikembalikan dan pengembalian '
                      'telah disetujui.',
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFORMASI PENGEMBALIAN
  // ============================================================

  Widget _buildPengembalianInfo(String statusPeminjaman) {
    final statusDatabasePengembalian = StatusHelper.combinedStatus(
      statusPeminjaman,
      statusPengembalian,
    );
    final status = StatusHelper.label(statusDatabasePengembalian);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informasi Pengembalian',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRowDetail('Status', status),

                const Divider(),

                _buildRowDetail('Kondisi', kondisiPengembalian ?? '-'),

                const Divider(),

                _buildRowDetail(
                  'Tanggal Pengajuan',
                  _formatTanggal(tanggalPengembalian),
                ),

                // ==================================================
                // CATATAN
                // ==================================================
                if (catatanPengembalian != null &&
                    catatanPengembalian!.trim().isNotEmpty) ...[
                  const Divider(),
                  _buildCatatanDetail(catatanPengembalian!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ============================================================
  // CATATAN DETAIL
  // ============================================================

  Widget _buildCatatanDetail(String catatan) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catatan',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5FCFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              catatan,
              softWrap: true,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO BOX
  // ============================================================

  Widget _buildInfoBox({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: TextStyle(color: color, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROW DETAIL
  // ============================================================

  Widget _buildRowDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
