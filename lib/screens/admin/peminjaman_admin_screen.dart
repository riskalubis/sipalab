import 'package:flutter/material.dart';
import '../../services/peminjaman_service.dart';
import '../../utils/status_helper.dart';
import 'detail_peminjaman_admin_screen.dart';

class PeminjamanAdminScreen extends StatefulWidget {
  const PeminjamanAdminScreen({super.key});

  @override
  State<PeminjamanAdminScreen> createState() => _PeminjamanAdminScreenState();
}

class _PeminjamanAdminScreenState extends State<PeminjamanAdminScreen> {
  List<Map<String, dynamic>> listPengajuan = [];

  bool isLoading = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadPeminjaman();
  }

  // ============================================================
  // AMBIL DATA PEMINJAMAN DARI DATABASE
  // ============================================================

  Future<void> _loadPeminjaman() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Endpoint /peminjaman/admin mengembalikan seluruh data
      // pengajuan lengkap dengan data mahasiswa & alat.
      final data = await PeminjamanService().getAllPeminjamanAdmin();

      if (!mounted) return;

      setState(() {
        listPengajuan = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data peminjaman: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
  // UBAH STATUS PEMINJAMAN
  // ============================================================

  Future<void> _ubahStatus(Map<String, dynamic> item, String statusBaru) async {
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
            'Status berhasil diubah menjadi '
            '${_formatStatus(statusBaru)}',
          ),
          backgroundColor: _getStatusColor(statusBaru),
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

  // ============================================================
  // KONFIRMASI PERUBAHAN STATUS
  // ============================================================

  Future<void> _konfirmasiStatus(
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
                ? 'Apakah kamu yakin ingin menyetujui '
                    'peminjaman $alat oleh $nama?\n\n'
                    'Stok alat akan otomatis berkurang sesuai jumlah peminjaman.'
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

    await _ubahStatus(item, statusBaru);
  }

  // ============================================================
  // DETAIL
  // ============================================================

  Future<void> _lihatDetail(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailPeminjamanAdminScreen(peminjaman: item),
      ),
    );

    await _loadPeminjaman();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Peminjaman'), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : listPengajuan.isEmpty
              ? RefreshIndicator(
                  onRefresh: _loadPeminjaman,
                  child: ListView(
                    children: const [
                      SizedBox(height: 250),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 60,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Belum ada pengajuan peminjaman.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPeminjaman,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                    itemCount: listPengajuan.length,
                    itemBuilder: (context, index) {
                      final item = listPengajuan[index];

                      final status = item['status']?.toString() ?? 'menunggu';

                      final warnaStatus = _getStatusColor(status);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ======================================
                              // ID + STATUS
                              // ======================================
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'PMJ${item['id'].toString().padLeft(3, '0')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: warnaStatus.withValues(alpha: 0.1),
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

                              // ======================================
                              // NAMA ALAT
                              // ======================================
                              Text(
                                item['nama_alat']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // ======================================
                              // PEMINJAM
                              // ======================================
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    size: 19,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      '${item['nama_mahasiswa'] ?? '-'}'
                                      ' (${item['nim'] ?? '-'})',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 7),

                              // ======================================
                              // JUMLAH
                              // ======================================
                              Row(
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 19,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Jumlah: ${item['jumlah'] ?? 0}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 7),

                              // ======================================
                              // STOK TERSEDIA
                              // ======================================
                              Row(
                                children: [
                                  const Icon(
                                    Icons.storage_outlined,
                                    size: 19,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Stok saat ini: ${item['stok'] ?? 0}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 7),

                              // ======================================
                              // TANGGAL
                              // ======================================
                              Row(
                                children: [
                                  const Icon(
                                    Icons.date_range_outlined,
                                    size: 19,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      '${StatusHelper.formatTanggal(item['tgl_pinjam']?.toString())}'
                                      ' s/d '
                                      '${StatusHelper.formatTanggal(item['tgl_kembali']?.toString())}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),

                              // ======================================
                              // KEPERLUAN
                              // ======================================
                              if (item['keperluan'] != null &&
                                  item['keperluan'].toString().isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      size: 19,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        item['keperluan'].toString(),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 14),

                              const Divider(),

                              const SizedBox(height: 4),

                              // ======================================
                              // AKSI
                              // ======================================
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _lihatDetail(item),
                                      icon: const Icon(
                                        Icons.info_outline,
                                        size: 19,
                                      ),
                                      label: const Text('Detail'),
                                    ),
                                  ),
                                  if (status == 'menunggu') ...[
                                    const SizedBox(width: 6),
                                    OutlinedButton(
                                      onPressed: () =>
                                          _konfirmasiStatus(item, 'ditolak'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side:
                                            const BorderSide(color: Colors.red),
                                      ),
                                      child: const Text('Tolak'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _konfirmasiStatus(item, 'disetujui'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Setujui'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
