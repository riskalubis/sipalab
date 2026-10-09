import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../session/user_session.dart';
import 'detail_peminjaman_screen.dart';

class PeminjamanSayaScreen extends StatefulWidget {
  const PeminjamanSayaScreen({super.key});

  @override
  PeminjamanSayaScreenState createState() => PeminjamanSayaScreenState();
}

class PeminjamanSayaScreenState extends State<PeminjamanSayaScreen> {
  List<Map<String, dynamic>> listPeminjaman = [];

  bool isLoading = true;

  static const Color primaryColor = Color(0xFF087F72);

  @override
  void initState() {
    super.initState();
    _loadPeminjaman();
  }

  // ============================================================
  // REFRESH DATA
  // ============================================================

  Future<void> refreshData() async {
    await _loadPeminjaman();
  }

  // ============================================================
  // LOAD PEMINJAMAN
  // ============================================================

  Future<void> _loadPeminjaman() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final userId = UserSession.userId;

      if (userId == null) {
        if (!mounted) return;

        setState(() {
          listPeminjaman = [];
          isLoading = false;
        });

        return;
      }

      final data = await ApiService.getList('/peminjaman/riwayat/$userId');

      if (!mounted) return;

      setState(() {
        listPeminjaman = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        listPeminjaman = [];
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat peminjaman: $e'),
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
        return 'Sedang Dipinjam';

      case 'ditolak':
        return 'Ditolak';

      case 'selesai':
        return 'Selesai';

      case 'dikembalikan':
        return 'Dikembalikan';

      case 'pengembalian_menunggu':
        return 'Menunggu Konfirmasi Pengembalian';

      case 'pengembalian_ditolak':
        return 'Pengembalian Ditolak';

      default:
        return status ?? 'Tidak diketahui';
    }
  }

  // ============================================================
  // WARNA STATUS
  // ============================================================

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Menunggu Konfirmasi':
        return Colors.orange;

      case 'Sedang Dipinjam':
        return Colors.green;

      case 'Ditolak':
        return Colors.red;

      case 'Selesai':
        return Colors.blue;

      case 'Dikembalikan':
        return Colors.teal;

      case 'Menunggu Konfirmasi Pengembalian':
        return Colors.orange;

      case 'Pengembalian Ditolak':
        return Colors.red;

      default:
        return Colors.grey;
    }
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peminjaman Saya'),
        actions: [
          IconButton(onPressed: refreshData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshData,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : listPeminjaman.isEmpty
                ? _emptyState()
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: listPeminjaman.length,
                    itemBuilder: (context, index) {
                      final item = listPeminjaman[index];

                      // ==================================================
                      // STATUS PEMINJAMAN + PENGEMBALIAN
                      // ==================================================

                      final statusPengembalian =
                          item['status_pengembalian']?.toString().toLowerCase();

                      String statusDatabase;

                      if (statusPengembalian == 'menunggu') {
                        statusDatabase = 'pengembalian_menunggu';
                      } else if (statusPengembalian == 'ditolak') {
                        statusDatabase = 'pengembalian_ditolak';
                      } else if (statusPengembalian == 'disetujui') {
                        statusDatabase = 'selesai';
                      } else {
                        statusDatabase =
                            item['status']?.toString().toLowerCase() ?? '';
                      }

                      final status = _formatStatus(statusDatabase);

                      final statusColor = _getStatusColor(status);

                      // ==================================================
                      // CARD PEMINJAMAN
                      // ==================================================

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DetailPeminjamanScreen(peminjaman: item),
                              ),
                            );

                            if (mounted) {
                              await refreshData();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ==========================
                                // HEADER
                                // ==========================
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.build_outlined,
                                        color: primaryColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item['nama_alat']?.toString() ?? 'Alat',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // ==========================
                                // ID
                                // ==========================
                                Text(
                                  'ID Peminjaman: PMJ${item['id']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ==========================
                                // JUMLAH
                                // ==========================
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Jumlah: ${item['jumlah'] ?? 1} Unit'),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // ==========================
                                // TANGGAL PINJAM
                                // ==========================
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Pinjam: ${_formatTanggal(item['tgl_pinjam']?.toString())}',
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // ==========================
                                // TANGGAL KEMBALI
                                // ==========================
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.event_outlined,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Kembali: ${_formatTanggal(item['tgl_kembali']?.toString())}',
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                // ==========================
                                // STATUS
                                // ==========================
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 180),
        Icon(Icons.assignment_outlined, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Belum ada riwayat peminjaman.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
        SizedBox(height: 10),
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Ajukan peminjaman alat untuk melihatnya di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}
