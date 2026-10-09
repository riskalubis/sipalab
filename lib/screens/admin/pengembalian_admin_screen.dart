import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/pengembalian_service.dart';

class PengembalianAdminScreen extends StatefulWidget {
  const PengembalianAdminScreen({super.key});

  @override
  State<PengembalianAdminScreen> createState() =>
      _PengembalianAdminScreenState();
}

class _PengembalianAdminScreenState extends State<PengembalianAdminScreen> {
  bool _isLoading = true;

  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ============================================================
  // LOAD PENGAJUAN PENGEMBALIAN
  // ============================================================

  Future<void> _loadData() async {
    try {
      // Endpoint /pengembalian/admin mengembalikan seluruh
      // pengajuan pengembalian (status 'menunggu') lengkap dengan
      // data mahasiswa & detail alat yang dikembalikan.
      final dataBaru = await ApiService.getList('/pengembalian/admin');

      if (!mounted) return;

      setState(() {
        _data = dataBaru;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat pengajuan pengembalian: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // SETUJUI PENGEMBALIAN
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
          content: Text(
            'Pengembalian disetujui. Stok alat telah dikembalikan.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _loadData();
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

  // ============================================================
  // TOLAK PENGEMBALIAN
  // ============================================================

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

      await _loadData();
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengembalian'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _data.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.assignment_return_outlined,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Tidak ada pengajuan pengembalian.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _data.length,
                      itemBuilder: (context, index) {
                        final item = _data[index];

                        final nama = item['nama_mahasiswa']?.toString() ?? '-';

                        final nim = item['nim']?.toString() ?? '-';

                        final kondisi = item['kondisi']?.toString() ?? '-';

                        final catatan = item['catatan']?.toString() ?? '';

                        final tanggal =
                            item['tanggal_pengembalian']?.toString() ?? '-';

                        final detail = (item['detail'] as List?) ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // =================================
                                // MAHASISWA
                                // =================================
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          Colors.indigo.withValues(alpha: 0.1),
                                      child: const Icon(
                                        Icons.person_outline,
                                        color: Colors.indigo,
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

                                const Divider(height: 24),

                                // =================================
                                // ALAT
                                // =================================
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
                                            d['nama_alat']?.toString() ?? '-',
                                          ),
                                        ),
                                        Text(
                                          '${d['jumlah'] ?? 0} Unit',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                const SizedBox(height: 10),

                                // =================================
                                // KONDISI
                                // =================================
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

                                // =================================
                                // TANGGAL
                                // =================================
                                Text(
                                  'Diajukan: $tanggal',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),

                                // =================================
                                // CATATAN
                                // =================================
                                if (catatan.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Catatan: $catatan',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // =================================
                                // BUTTON SETUJU / TOLAK
                                // =================================
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _setujuiPengembalian(item),
                                        icon: const Icon(Icons.check),
                                        label: const Text('SETUJUI'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 13,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _tolakPengembalian(item),
                                        icon: const Icon(Icons.close),
                                        label: const Text('TOLAK'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 13,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
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
