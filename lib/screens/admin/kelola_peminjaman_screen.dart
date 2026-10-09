import 'package:flutter/material.dart';
import '../../services/peminjaman_service.dart';

class KelolaPeminjamanScreen extends StatefulWidget {
  const KelolaPeminjamanScreen({super.key});

  @override
  State<KelolaPeminjamanScreen> createState() => _KelolaPeminjamanScreenState();
}

class _KelolaPeminjamanScreenState extends State<KelolaPeminjamanScreen> {
  String _selectedFilter = 'Semua';

  bool _isLoading = true;

  List<Map<String, dynamic>> _peminjamanList = [];

  @override
  void initState() {
    super.initState();
    _loadPeminjaman();
  }

  // ============================================================
  // LOAD DATA PEMINJAMAN
  // ============================================================

  Future<void> _loadPeminjaman() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Endpoint /peminjaman/admin mengembalikan seluruh data
      // peminjaman lengkap dengan data mahasiswa & alat.
      final result = await PeminjamanService().getAllPeminjamanAdmin();

      if (!mounted) return;

      setState(() {
        _peminjamanList = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Gagal memuat data peminjaman: $e', Colors.red);
    }
  }

  // ============================================================
  // FORMAT STATUS
  // ============================================================

  String _formatStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'menunggu':
        return 'Menunggu';

      case 'disetujui':
        return 'Disetujui';

      case 'ditolak':
        return 'Ditolak';

      case 'dikembalikan':
        return 'Dikembalikan';

      case 'selesai':
        return 'Selesai';

      default:
        return status ?? '-';
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'menunggu':
        return Colors.orange;

      case 'disetujui':
        return Colors.green;

      case 'ditolak':
        return Colors.red;

      case 'dikembalikan':
        return Colors.blue;

      case 'selesai':
        return Colors.blue;

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
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];

      return '${date.day.toString().padLeft(2, '0')} '
          '${bulan[date.month - 1]} '
          '${date.year}';
    } catch (e) {
      return tanggal;
    }
  }

  // ============================================================
  // SETUJUI PEMINJAMAN
  // ============================================================

  Future<void> _setujuiPeminjaman(Map<String, dynamic> item) async {
    final peminjamanId = item['id'];
    final alatId = item['alat_id'];
    final jumlah = int.tryParse(item['jumlah'].toString()) ?? 0;

    if (peminjamanId == null || alatId == null) {
      _showMessage('Data peminjaman tidak lengkap.', Colors.red);
      return;
    }

    if (jumlah <= 0) {
      _showMessage('Jumlah peminjaman tidak valid.', Colors.red);
      return;
    }

    try {
      // Setujui peminjaman lewat API. Seluruh validasi status
      // terbaru, pengecekan stok, dan pengurangan stok dilakukan
      // backend secara atomik (aman dari stok ganda).
      await PeminjamanService().updateStatusPeminjaman(
        peminjamanId,
        'disetujui',
      );

      if (!mounted) return;

      _showMessage('Peminjaman berhasil disetujui.', Colors.green);

      await _loadPeminjaman();
    } catch (e) {
      if (!mounted) return;

      _showMessage('Gagal menyetujui peminjaman: $e', Colors.red);
    }
  }

  // ============================================================
  // TOLAK PEMINJAMAN
  // ============================================================

  Future<void> _tolakPeminjaman(Map<String, dynamic> item) async {
    final peminjamanId = item['id'];

    if (peminjamanId == null) {
      _showMessage('ID peminjaman tidak ditemukan.', Colors.red);
      return;
    }

    try {
      // Tolak peminjaman lewat API. Bila peminjaman sudah tidak
      // berstatus 'menunggu', backend mengembalikan pesan bahwa
      // peminjaman sudah diproses sebelumnya.
      await PeminjamanService().updateStatusPeminjaman(
        peminjamanId,
        'ditolak',
      );

      if (!mounted) return;

      _showMessage('Peminjaman berhasil ditolak.', Colors.red);

      await _loadPeminjaman();
    } catch (e) {
      if (!mounted) return;

      _showMessage('Gagal menolak peminjaman: $e', Colors.red);
    }
  }

  // ============================================================
  // KONFIRMASI TOLAK
  // ============================================================

  Future<void> _konfirmasiTolak(Map<String, dynamic> item) async {
    final nama = item['nama']?.toString() ?? 'Mahasiswa';

    final alat = item['nama_alat']?.toString() ?? 'Alat';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tolak Peminjaman?'),
          content: Text('Peminjaman $alat oleh $nama akan ditolak.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Tolak'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _tolakPeminjaman(item);
    }
  }

  // ============================================================
  // KONFIRMASI SETUJUI
  // ============================================================

  Future<void> _konfirmasiSetujui(Map<String, dynamic> item) async {
    final nama = item['nama']?.toString() ?? 'Mahasiswa';

    final alat = item['nama_alat']?.toString() ?? 'Alat';

    final jumlah = item['jumlah']?.toString() ?? '0';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Setujui Peminjaman?'),
          content: Text(
            '$nama mengajukan $jumlah unit $alat.\n\n'
            'Jika disetujui, stok alat akan dikurangi.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Setujui'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _setujuiPeminjaman(item);
    }
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
    final filtered = _selectedFilter == 'Semua'
        ? _peminjamanList
        : _peminjamanList.where((item) {
            return _formatStatus(item['status']?.toString()) == _selectedFilter;
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peminjaman'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPeminjaman,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // FILTER
            // ==================================================
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Semua', 'Menunggu', 'Disetujui', 'Ditolak'].map((
                  filter,
                ) {
                  final isSelected = _selectedFilter == filter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (value) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // LOADING
            // ==================================================
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            // ==================================================
            // DATA KOSONG
            // ==================================================
            else if (filtered.isEmpty)
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadPeminjaman,
                  child: ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 60,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Belum ada data peminjaman.',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // ==================================================
            // DAFTAR PEMINJAMAN
            // ==================================================
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadPeminjaman,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];

                      final rawStatus = item['status']?.toString();

                      final status = _formatStatus(rawStatus);

                      final statusColor = _getStatusColor(rawStatus);

                      final isMenunggu = rawStatus == 'menunggu';

                      final nama = item['nama']?.toString() ?? '-';

                      final nim = item['nim']?.toString() ?? '-';

                      final alat = item['nama_alat']?.toString() ?? '-';

                      final jumlah = item['jumlah']?.toString() ?? '0';

                      final tanggalPinjam = _formatTanggal(
                        item['tanggal_pinjam']?.toString(),
                      );

                      final tanggalKembali = _formatTanggal(
                        item['tanggal_kembali']?.toString(),
                      );

                      final keperluan = item['keperluan']?.toString() ?? '-';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // =================================
                              // NAMA MAHASISWA
                              // =================================
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.teal.withValues(
                                      alpha: 0.1,
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      color: Colors.teal,
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
                                ],
                              ),

                              const SizedBox(height: 14),

                              const Divider(),

                              const SizedBox(height: 8),

                              // =================================
                              // ALAT
                              // =================================
                              _buildDetailRow(
                                Icons.science_outlined,
                                'Alat',
                                '$alat - $jumlah unit',
                              ),

                              const SizedBox(height: 8),

                              // =================================
                              // TANGGAL
                              // =================================
                              _buildDetailRow(
                                Icons.calendar_today_outlined,
                                'Tanggal',
                                '$tanggalPinjam - $tanggalKembali',
                              ),

                              const SizedBox(height: 8),

                              // =================================
                              // KEPERLUAN
                              // =================================
                              _buildDetailRow(
                                Icons.description_outlined,
                                'Keperluan',
                                keperluan,
                              ),

                              const SizedBox(height: 14),

                              // =================================
                              // STATUS
                              // =================================
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 9,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // =================================
                              // TOMBOL
                              // =================================
                              if (isMenunggu) ...[
                                const SizedBox(height: 14),
                                const Divider(),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                      onPressed: () {
                                        _konfirmasiTolak(item);
                                      },
                                      child: const Text('Tolak'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        _konfirmasiSetujui(item);
                                      },
                                      child: const Text('Setujui'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
