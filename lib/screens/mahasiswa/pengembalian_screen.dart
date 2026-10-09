import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class PengembalianScreen extends StatefulWidget {
  final Map<String, dynamic> peminjaman;

  const PengembalianScreen({super.key, required this.peminjaman});

  @override
  State<PengembalianScreen> createState() => _PengembalianScreenState();
}

class _PengembalianScreenState extends State<PengembalianScreen> {
  final _formKey = GlobalKey<FormState>();

  String _kondisiAlat = 'Baik';

  final TextEditingController _catatanController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  // ============================================================
  // SUBMIT PENGEMBALIAN
  // ============================================================

  Future<void> _submitPengembalian() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final peminjamanId = int.tryParse(widget.peminjaman['id'].toString());

    if (peminjamanId == null) {
      _showMessage('ID peminjaman tidak ditemukan.', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ========================================================
      // KIRIM PENGAJUAN PENGEMBALIAN KE API
      // ========================================================
      //
      // Seluruh validasi (status peminjaman disetujui, tidak ada
      // pengembalian yang masih menunggu, dst.) ditangani backend
      // Laravel sehingga hasilnya sama persis seperti sebelumnya.
      //
      // PENTING: stok BELUM ditambah di sini. Stok akan dikembalikan
      // ketika pengembalian disetujui admin.
      // ========================================================

      await ApiService.postMap('/pengembalian', {
        'peminjaman_id': peminjamanId,
        'tanggal_pengembalian': DateTime.now().toIso8601String(),
        'kondisi': _kondisiAlat,
        'catatan': _catatanController.text.trim(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan pengembalian berhasil dikirim.'),
          backgroundColor: Colors.green,
        ),
      );

      // Kembali ke Detail Peminjaman
      // dengan membawa hasil true supaya
      // data langsung direfresh.

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengajukan pengembalian: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
  // WARNA KONDISI
  // ============================================================

  Color _getConditionColor(String kondisi) {
    switch (kondisi) {
      case 'Baik':
        return Colors.green;

      case 'Rusak Ringan':
        return Colors.orange;

      case 'Rusak Berat':
        return Colors.red;

      case 'Hilang':
        return Colors.red.shade900;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final namaAlat = widget.peminjaman['nama_alat']?.toString() ?? 'Alat';

    final id = widget.peminjaman['id']?.toString() ?? '-';

    final jumlah = widget.peminjaman['jumlah']?.toString() ?? '1';

    final kondisiColor = _getConditionColor(_kondisiAlat);

    return Scaffold(
      appBar: AppBar(title: const Text('Form Pengembalian Alat')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =================================================
              // INFORMASI PEMINJAMAN
              // =================================================
              Card(
                elevation: 1,
                color: Colors.teal.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Peminjaman',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        namaAlat,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('ID Peminjaman: PMJ$id'),
                      const SizedBox(height: 4),
                      Text('Jumlah: $jumlah Unit'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // =================================================
              // KONDISI ALAT
              // =================================================
              const Text(
                'Kondisi Alat Saat Dikembalikan',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                initialValue: _kondisiAlat,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.build_outlined, color: kondisiColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Baik', child: Text('Baik')),
                  DropdownMenuItem(
                    value: 'Rusak Ringan',
                    child: Text('Rusak Ringan'),
                  ),
                  DropdownMenuItem(
                    value: 'Rusak Berat',
                    child: Text('Rusak Berat'),
                  ),
                  DropdownMenuItem(value: 'Hilang', child: Text('Hilang')),
                ],
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _kondisiAlat = value;
                        });
                      },
              ),

              const SizedBox(height: 24),

              // =================================================
              // CATATAN
              // =================================================
              const Text(
                'Catatan Tambahan (Opsional)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _catatanController,
                maxLines: 4,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Masukkan catatan kondisi atau kendala jika ada...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.notes_outlined),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // =================================================
              // INFO
              // =================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pengembalian akan diperiksa terlebih dahulu. Stok alat akan kembali setelah pengembalian disetujui.',
                        style: TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // BUTTON
              // =================================================
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitPengembalian,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.assignment_return),
                  label: Text(
                    _isLoading ? 'MEMPROSES...' : 'KIRIM PENGEMBALIAN',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.green.shade300,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
