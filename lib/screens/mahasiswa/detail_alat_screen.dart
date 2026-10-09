import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'form_peminjaman_screen.dart';

class DetailAlatScreen extends StatefulWidget {
  final Map<String, dynamic> alat;

  const DetailAlatScreen({super.key, required this.alat});

  @override
  State<DetailAlatScreen> createState() => _DetailAlatScreenState();
}

class _DetailAlatScreenState extends State<DetailAlatScreen> {
  Map<String, dynamic>? _alatTerbaru;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlat();
  }

  // ============================================================
  // AMBIL DATA ALAT TERBARU DARI DATABASE
  // ============================================================

  Future<void> _loadAlat() async {
    try {
      final alatId = widget.alat['id'];

      if (alatId == null) {
        setState(() {
          _alatTerbaru = widget.alat;
          _isLoading = false;
        });

        return;
      }

      final result = await ApiService.getMap('/alat/$alatId');

      if (!mounted) return;

      setState(() {
        _alatTerbaru = result ?? widget.alat;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _alatTerbaru = widget.alat;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data alat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // BUKA FORM PEMINJAMAN
  // ============================================================

  Future<void> _bukaFormPeminjaman() async {
    if (_alatTerbaru == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormPeminjamanScreen(alat: _alatTerbaru!),
      ),
    );

    if (!mounted) return;

    // Setelah peminjaman berhasil,
    // ambil stok terbaru dari database.
    if (result == true) {
      await _loadAlat();

      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Alat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final alat = _alatTerbaru ?? widget.alat;

    final namaAlat = alat['nama_alat']?.toString() ?? 'Alat';

    final stok = int.tryParse(alat['stok']?.toString() ?? '0') ?? 0;

    // Jumlah yang masih menunggu persetujuan admin ikut
    // dihitung sebagai cadangan, sehingga stok tersedia
    // otomatis berkurang saat ada pengajuan lain.

    final dipesan = int.tryParse(alat['stok_dipesan']?.toString() ?? '0') ?? 0;

    final stokTersedia = (stok - dipesan) < 0 ? 0 : stok - dipesan;

    final kondisi = alat['kondisi']?.toString() ?? '-';

    final deskripsi = alat['deskripsi']?.toString() ?? '';

    final kelasPeminjam = alat['kelas_peminjam']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Alat')),
      body: RefreshIndicator(
        onRefresh: _loadAlat,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // GAMBAR ALAT
              // ==================================================
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.build, size: 90, color: Colors.grey),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // NAMA ALAT
              // ==================================================
              Text(
                namaAlat,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              // ==================================================
              // STOK
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: stokTersedia > 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: stokTersedia > 0
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: stokTersedia > 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      stokTersedia > 0
                          ? 'Stok tersedia: $stokTersedia unit'
                          : 'Stok sudah tidak ada',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: stokTersedia > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              if (kelasPeminjam.isNotEmpty) ...[
                const SizedBox(height: 10),

                // ==================================================
                // DIPINJAM OLEH KELAS
                // ==================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_outlined,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stokTersedia > 0
                              ? 'Sebagian dipinjam oleh: $kelasPeminjam'
                              : 'Dipinjam oleh: $kelasPeminjam',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ==================================================
              // KONDISI
              // ==================================================
              Row(
                children: [
                  const Icon(Icons.check_circle_outline),
                  const SizedBox(width: 10),
                  Text(
                    'Kondisi: $kondisi',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // ==================================================
              // DESKRIPSI
              // ==================================================
              const Text(
                'Deskripsi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                deskripsi.isNotEmpty ? deskripsi : 'Tidak ada deskripsi alat.',
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),

              const SizedBox(height: 35),

              // ==================================================
              // TOMBOL PINJAM
              // ==================================================
              //
              // Saat stok habis tombol berubah MERAH dan
              // tidak bisa ditekan.

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: stokTersedia > 0 ? _bukaFormPeminjaman : null,
                  icon: Icon(
                    stokTersedia > 0 ? Icons.assignment_outlined : Icons.block,
                  ),
                  label: Text(
                    stokTersedia > 0 ? 'PINJAM ALAT' : 'STOK HABIS',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF087F72),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // INFO JUMLAH
              // ==================================================
              Center(
                child: Text(
                  stokTersedia > 0
                      ? 'Kamu dapat meminjam maksimal $stokTersedia unit.'
                      : 'Stok alat sedang habis, tunggu pengembalian alat.',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
