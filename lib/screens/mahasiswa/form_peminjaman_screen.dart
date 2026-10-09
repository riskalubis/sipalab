import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../session/user_session.dart';

class FormPeminjamanScreen extends StatefulWidget {
  final Map<String, dynamic> alat;

  const FormPeminjamanScreen({super.key, required this.alat});

  @override
  State<FormPeminjamanScreen> createState() => _FormPeminjamanScreenState();
}

class _FormPeminjamanScreenState extends State<FormPeminjamanScreen> {
  final _formKey = GlobalKey<FormState>();

  int _jumlah = 1;

  late DateTime _tglPinjam;
  late DateTime _tglKembali;

  final TextEditingController _keperluanController = TextEditingController(
    text: 'Praktikum',
  );

  bool _isLoading = false;

  // Stok tersedia dihitung dari stok alat dikurangi jumlah
  // pengajuan yang masih menunggu persetujuan admin.
  // -1 artinya masih sedang dimuat.
  int _stokTersedia = -1;

  static const Color primaryColor = Color(0xFF087F72);

  @override
  void initState() {
    super.initState();

    final sekarang = DateTime.now();

    _tglPinjam = DateTime(sekarang.year, sekarang.month, sekarang.day);

    _tglKembali = _tglPinjam.add(const Duration(days: 2));

    _hitungStokTersedia();
  }

  @override
  void dispose() {
    _keperluanController.dispose();
    super.dispose();
  }

  // ============================================================
  // AMBIL ID ALAT YANG BENAR DARI DATABASE
  // ============================================================

  Future<Map<String, dynamic>?> _ambilDataAlat() async {
    final semuaAlat = await ApiService.getList('/alat');

    // ----------------------------------------------------------
    // 1. Coba cari berdasarkan ID yang dikirim dari halaman alat
    // ----------------------------------------------------------

    final kemungkinanId = [
      widget.alat['id'],
      widget.alat['alat_id'],
      widget.alat['id_alat'],
    ];

    for (final value in kemungkinanId) {
      if (value == null) continue;

      final id = int.tryParse(value.toString());

      if (id == null) continue;

      for (final alat in semuaAlat) {
        if ((alat['id'] ?? -1) == id) {
          return alat;
        }
      }
    }

    // ----------------------------------------------------------
    // 2. Kalau ID tidak ada / tidak cocok,
    //    cari berdasarkan nama alat
    // ----------------------------------------------------------

    final namaAlat = widget.alat['nama_alat']?.toString().trim();

    if (namaAlat == null || namaAlat.isEmpty) {
      return null;
    }

    for (final alat in semuaAlat) {
      final namaDb = alat['nama_alat']?.toString().trim().toLowerCase() ?? '';

      if (namaDb == namaAlat.toLowerCase()) {
        return alat;
      }
    }

    // ----------------------------------------------------------
    // 3. Fallback terakhir menggunakan LIKE / contains
    // ----------------------------------------------------------

    for (final alat in semuaAlat) {
      final namaDb = alat['nama_alat']?.toString() ?? '';

      if (namaDb.contains(namaAlat)) {
        return alat;
      }
    }

    return null;
  }

  // ============================================================
  // PILIH TANGGAL
  // ============================================================

  Future<void> _selectDate(BuildContext context, bool isPinjam) async {
    final initialDate = isPinjam ? _tglPinjam : _tglKembali;

    final firstDate = isPinjam ? DateTime.now() : _tglPinjam;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2030),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      final tanggal = DateTime(picked.year, picked.month, picked.day);

      if (isPinjam) {
        _tglPinjam = tanggal;

        if (_tglKembali.isBefore(_tglPinjam)) {
          _tglKembali = _tglPinjam.add(const Duration(days: 1));
        }
      } else {
        _tglKembali = tanggal;
      }
    });
  }

  // ============================================================
  // FORMAT TANGGAL
  // ============================================================

  String _formatTanggal(DateTime tanggal) {
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

    return '${tanggal.day.toString().padLeft(2, '0')} '
        '${bulan[tanggal.month - 1]} '
        '${tanggal.year}';
  }

  // ============================================================
  // HITUNG STOK TERSEDIA
  //
  // stok alat - jumlah pengajuan yang masih menunggu admin.
  // ============================================================

  Future<void> _hitungStokTersedia() async {
    try {
      final alatData = await _ambilDataAlat();

      if (alatData == null) return;

      final alatId = int.tryParse(alatData['id'].toString());

      if (alatId == null) return;

      final info = await ApiService.getMap('/alat/$alatId/stok-tersedia');

      if (info == null) return;

      final stok = int.tryParse(info['stok']?.toString() ?? '0') ?? 0;

      final dipesan = int.tryParse(info['dipesan']?.toString() ?? '0') ?? 0;

      if (!mounted) return;

      setState(() {
        _stokTersedia = (stok - dipesan) < 0 ? 0 : stok - dipesan;
      });
    } catch (_) {
      // Biarkan stok dihitung ulang saat pengajuan dikirim.
    }
  }

  // ============================================================
  // AJUKAN PEMINJAMAN
  // ============================================================

  Future<void> _ajukanPeminjaman() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ----------------------------------------------------------
    // CEK USER LOGIN
    // ----------------------------------------------------------

    final userId = UserSession.userId;

    if (userId == null) {
      _showMessage(
        'Sesi login tidak ditemukan. Silakan login kembali.',
        Colors.red,
      );
      return;
    }

    // ----------------------------------------------------------
    // CEK TANGGAL
    // ----------------------------------------------------------

    if (_tglKembali.isBefore(_tglPinjam)) {
      _showMessage(
        'Tanggal kembali tidak boleh sebelum tanggal pinjam.',
        Colors.red,
      );
      return;
    }

    if (_tglKembali.isAtSameMomentAs(_tglPinjam)) {
      _showMessage('Tanggal kembali harus setelah tanggal pinjam.', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ========================================================
      // AMBIL DATA ALAT DARI DATABASE
      // ========================================================

      final alatData = await _ambilDataAlat();

      if (alatData == null) {
        throw Exception('Data alat tidak ditemukan di database.');
      }

      final alatId = int.tryParse(alatData['id'].toString());

      if (alatId == null) {
        throw Exception('ID alat tidak valid.');
      }

      // ========================================================
      // API - KIRIM PENGAJUAN PEMINJAMAN
      // ========================================================
      //
      // Validasi stok & transaksi (peminjaman + detail) ditangani
      // backend Laravel sehingga hasil akhirnya sama persis dengan
      // transaksi SQLite sebelumnya.
      // ========================================================

      await ApiService.postMap('/peminjaman', {
        'user_id': userId,
        'tanggal_pinjam': _tglPinjam.toIso8601String(),
        'tanggal_kembali': _tglKembali.toIso8601String(),
        'keperluan': _keperluanController.text.trim(),
        'detail': [
          {'alat_id': alatId, 'jumlah': _jumlah},
        ],
      });

      // ========================================================
      // BERHASIL
      // ========================================================

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pengajuan peminjaman berhasil dikirim'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengajukan peminjaman: $e'),
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final namaAlat = widget.alat['nama_alat']?.toString() ?? 'Alat';

    // Saat stok masih dimuat, jangan tampilkan stok -1.
    final bool stokBelumDiketahui = _stokTersedia < 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Peminjaman')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // ALAT
              // ==================================================
              const Text(
                'Alat',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),

              const SizedBox(height: 4),

              Text(
                namaAlat,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                stokBelumDiketahui
                    ? 'Menghitung stok tersedia...'
                    : _stokTersedia > 0
                        ? 'Stok tersedia: $_stokTersedia'
                        : 'Stok sudah tidak ada',
                style: TextStyle(
                  color: stokBelumDiketahui
                      ? Colors.grey
                      : _stokTersedia > 0
                          ? Colors.green
                          : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // JUMLAH
              // ==================================================
              const Text(
                'Jumlah',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  IconButton.outlined(
                    onPressed: _jumlah > 1
                        ? () {
                            setState(() {
                              _jumlah--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$_jumlah',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: _stokTersedia > 0 && _jumlah < _stokTersedia
                        ? () {
                            setState(() {
                              _jumlah++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ==================================================
              // TANGGAL PINJAM
              // ==================================================
              const Text(
                'Tanggal Pinjam',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),

              InkWell(
                onTap: () => _selectDate(context, true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatTanggal(_tglPinjam),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // TANGGAL KEMBALI
              // ==================================================
              const Text(
                'Tanggal Kembali',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),

              InkWell(
                onTap: () => _selectDate(context, false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatTanggal(_tglKembali),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // KEPERLUAN
              // ==================================================
              const Text(
                'Keperluan',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),

              const SizedBox(height: 6),

              TextFormField(
                controller: _keperluanController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Masukkan keperluan peminjaman...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Keperluan wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 30),

              // ==================================================
              // TOMBOL
              // ==================================================
              //
              // Saat stok habis tombol berubah MERAH dan
              // tidak bisa ditekan.

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading || _stokTersedia <= 0
                      ? null
                      : _ajukanPeminjaman,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _stokTersedia < 0
                              ? 'MENGAMBIL STOK...'
                              : _stokTersedia <= 0
                                  ? 'STOK HABIS'
                                  : 'AJUKAN PEMINJAMAN',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
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
