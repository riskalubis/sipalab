import 'package:flutter/material.dart';
import '../../services/peminjaman_service.dart';
import '../../utils/status_helper.dart';

class DetailPeminjamanAdminScreen extends StatefulWidget {
  final Map<String, dynamic> peminjaman;

  const DetailPeminjamanAdminScreen({super.key, required this.peminjaman});

  @override
  State<DetailPeminjamanAdminScreen> createState() =>
      _DetailPeminjamanAdminScreenState();
}

class _DetailPeminjamanAdminScreenState
    extends State<DetailPeminjamanAdminScreen> {
  late String status;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    status = widget.peminjaman['status']?.toString() ?? 'menunggu';
  }

  // ============================================================
  // FORMAT STATUS
  // ============================================================

  String _formatStatus(String? status) {
    switch (status) {
      case 'menunggu':
        return 'Menunggu Konfirmasi';

      case 'disetujui':
        return 'Disetujui';

      case 'ditolak':
        return 'Ditolak';

      case 'selesai':
        return 'Selesai';

      case 'dikembalikan':
        return 'Dikembalikan';

      default:
        return status ?? '-';
    }
  }

  // ============================================================
  // WARNA STATUS
  // ============================================================

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'disetujui':
        return Colors.green;

      case 'menunggu':
        return Colors.orange;

      case 'ditolak':
        return Colors.red;

      case 'selesai':
        return Colors.blue;

      case 'dikembalikan':
        return Colors.teal;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================

  Future<void> _updateStatus(String statusBaru) async {
    if (isSaving) return;

    final id = widget.peminjaman['id'];

    if (id == null) {
      _showMessage('ID peminjaman tidak ditemukan.', Colors.red);
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // Gunakan service agar stok otomatis berkurang
      // hanya saat peminjaman benar-benar disetujui.
      // (Aman dari pengurangan stok ganda.)
      await PeminjamanService().updateStatusPeminjaman(id, statusBaru);

      if (!mounted) return;

      setState(() {
        status = statusBaru;
        isSaving = false;
      });

      _showMessage(
        'Status berhasil diubah menjadi ${_formatStatus(statusBaru)}',
        _getStatusColor(statusBaru),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage('Gagal mengubah status: $e', Colors.red);
    }
  }

  // ============================================================
  // KONFIRMASI STATUS
  // ============================================================

  Future<void> _konfirmasiStatus(String statusBaru) async {
    final isSetujui = statusBaru == 'disetujui';

    final nama = widget.peminjaman['nama_mahasiswa']?.toString() ?? '-';

    final alat = widget.peminjaman['nama_alat']?.toString() ?? '-';

    final hasil = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isSetujui ? 'Setujui Peminjaman' : 'Tolak Peminjaman'),
          content: Text(
            isSetujui
                ? 'Apakah kamu yakin ingin menyetujui '
                    'peminjaman $alat oleh $nama?'
                : 'Apakah kamu yakin ingin menolak '
                    'peminjaman $alat oleh $nama?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
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

    await _updateStatus(statusBaru);
  }

  // ============================================================
  // PESAN
  // ============================================================

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final warnaStatus = _getStatusColor(status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Peminjaman Admin'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // STATUS
            // ==================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: warnaStatus.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: warnaStatus),
              ),
              child: Column(
                children: [
                  const Text(
                    'Status Peminjaman',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatStatus(status),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: warnaStatus,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // INFORMASI PEMOHON
            // ==================================================
            const Text(
              'Informasi Pemohon',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

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
                      'Nama Mahasiswa',
                      widget.peminjaman['nama_mahasiswa']?.toString() ?? '-',
                    ),
                    const Divider(),
                    _buildRowDetail(
                      'NIM',
                      widget.peminjaman['nim']?.toString() ?? '-',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // RINCIAN PEMINJAMAN
            // ==================================================
            const Text(
              'Rincian Peminjaman',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

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
                      'ID Transaksi',
                      'PMJ${widget.peminjaman['id'].toString().padLeft(3, '0')}',
                    ),
                    const Divider(),
                    _buildRowDetail(
                      'Nama Alat',
                      widget.peminjaman['nama_alat']?.toString() ?? '-',
                    ),
                    const Divider(),
                    _buildRowDetail(
                      'Jumlah',
                      '${widget.peminjaman['jumlah'] ?? 0} Unit',
                    ),
                    const Divider(),
                    _buildRowDetail(
                      'Tanggal Pinjam',
                      StatusHelper.formatTanggal(
                        widget.peminjaman['tgl_pinjam']?.toString(),
                      ),
                    ),
                    const Divider(),
                    _buildRowDetail(
                      'Tanggal Kembali',
                      StatusHelper.formatTanggal(
                        widget.peminjaman['tgl_kembali']?.toString(),
                      ),
                    ),
                    if (widget.peminjaman['keperluan'] != null &&
                        widget.peminjaman['keperluan']
                            .toString()
                            .isNotEmpty) ...[
                      const Divider(),
                      _buildRowDetail(
                        'Keperluan',
                        widget.peminjaman['keperluan'].toString(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ==================================================
            // TOMBOL APPROVAL
            // ==================================================
            if (status == 'menunggu') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          isSaving ? null : () => _konfirmasiStatus('ditolak'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'TOLAK',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () => _konfirmasiStatus('disetujui'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'SETUJUI',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],

            // ==================================================
            // INFO SUDAH DIKEMBALIKAN
            // ==================================================
            if (status == 'dikembalikan' || status == 'selesai') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.teal, size: 35),
                    SizedBox(height: 8),
                    Text(
                      'Alat Sudah Dikembalikan',
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Stok alat telah ditambahkan kembali.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            // ==================================================
            // INFO DITOLAK
            // ==================================================
            if (status == 'ditolak') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Peminjaman ini ditolak oleh admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ROW DETAIL
  // ============================================================

  Widget _buildRowDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
