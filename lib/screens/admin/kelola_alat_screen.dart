import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'tambah_alat_screen.dart';

class KelolaAlatScreen extends StatefulWidget {
  const KelolaAlatScreen({super.key});

  @override
  State<KelolaAlatScreen> createState() => _KelolaAlatScreenState();
}

class _KelolaAlatScreenState extends State<KelolaAlatScreen> {
  List<Map<String, dynamic>> listAlat = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlat();
  }

  // ============================================================
  // AMBIL DATA LANGSUNG DARI DATABASE
  // ============================================================

  Future<void> _loadAlat() async {
    try {
      // Endpoint /alat mengembalikan daftar alat lengkap dengan
      // nama_kategori, sudah urut sesuai kategori & id.
      final data = await ApiService.getList('/alat');

      if (!mounted) return;

      setState(() {
        listAlat = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
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
  // HAPUS DATA ALAT
  // ============================================================

  Future<void> _hapusAlat(Map<String, dynamic> alat) async {
    final namaAlat = alat['nama_alat']?.toString() ?? '-';
    final id = alat['id'];

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Alat'),
          content: Text('Apakah kamu yakin ingin menghapus "$namaAlat"?'),
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
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (konfirmasi != true) return;

    try {
      await ApiService.delete('/alat/$id');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alat berhasil dihapus.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadAlat();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus alat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // EDIT ALAT
  // ============================================================

  Future<void> _editAlat(Map<String, dynamic> alat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TambahAlatScreen(alat: alat)),
    );

    if (!mounted) return;

    await _loadAlat();
  }

  // ============================================================
  // TAMBAH ALAT
  // ============================================================

  Future<void> _tambahAlat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TambahAlatScreen()),
    );

    if (!mounted) return;

    await _loadAlat();
  }

  // ============================================================
  // EMOJI KATEGORI
  // ============================================================

  String _emojiKategori(String kategori) {
    final nama = kategori.toLowerCase().trim();

    if (nama == 'elektronika' || nama == 'elektronik') {
      return '🔌';
    }

    if (nama == 'jaringan') {
      return '🌐';
    }

    if (nama == 'pendukung') {
      return '🧰';
    }

    return '📦';
  }

  // ============================================================
  // NAMA KATEGORI UNTUK TAMPILAN
  // ============================================================

  String _namaKategori(String kategori) {
    final nama = kategori.trim();

    if (nama.toLowerCase() == 'elektronik') {
      return 'Elektronika';
    }

    if (nama.isEmpty) {
      return 'Lainnya';
    }

    return nama;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Kelompokkan data berdasarkan kategori.
    final Map<String, List<Map<String, dynamic>>> kelompokAlat = {};

    for (final alat in listAlat) {
      final kategori = alat['nama_kategori']?.toString().trim() ?? 'Lainnya';

      kelompokAlat.putIfAbsent(kategori, () => []);
      kelompokAlat[kategori]!.add(alat);
    }

    // Nomor dibuat GLOBAL supaya tidak kembali ke 1
    // pada setiap kategori.
    int nomorGlobal = 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kelola Data Alat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : listAlat.isEmpty
              ? RefreshIndicator(
                  onRefresh: _loadAlat,
                  child: ListView(
                    children: const [
                      SizedBox(height: 250),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 60,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Belum ada data alat.',
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
                  onRefresh: _loadAlat,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
                    children: [
                      // ==================================================
                      // SETIAP KATEGORI
                      // ==================================================
                      ...kelompokAlat.entries.map((entry) {
                        final kategori = entry.key;
                        final daftar = entry.value;

                        final nomorAwal = nomorGlobal;

                        nomorGlobal += daftar.length;

                        return _buildKategoriSection(
                            kategori, daftar, nomorAwal);
                      }),
                    ],
                  ),
                ),

      // ============================================================
      // TOMBOL TAMBAH
      // ============================================================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahAlat,
        backgroundColor: const Color(0xFF0F8A7D),
        foregroundColor: Colors.white,
        label: const Text('Tambah Alat'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ============================================================
  // SECTION KATEGORI
  // ============================================================

  Widget _buildKategoriSection(
    String kategori,
    List<Map<String, dynamic>> daftar,
    int nomorAwal,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======================================================
          // JUDUL KATEGORI
          // ======================================================
          Row(
            children: [
              Text(
                _emojiKategori(kategori),
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 10),
              Text(
                _namaKategori(kategori),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F8A7D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${daftar.length} Alat',
                  style: const TextStyle(
                    color: Color(0xFF0F8A7D),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ======================================================
          // HEADER
          // ======================================================
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FAF8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    'No',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 54),
                Expanded(
                  child: Text(
                    'Nama Alat',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ======================================================
          // DATA ALAT
          // ======================================================
          ...List.generate(daftar.length, (index) {
            final alat = daftar[index];

            return _buildAlatRow(alat, nomorAwal + index);
          }),
        ],
      ),
    );
  }

  // ============================================================
  // BARIS DATA ALAT
  // ============================================================

  // ============================================================
  // BARIS DATA ALAT
  // ============================================================
  //
  // Desain disesuaikan untuk layar handphone: nama alat dibatasi
  // maksimal 2 baris dengan elipsis, info stok & kondisi tampil
  // sebagai badge kecil di bawah nama (bukan kolom tabel kaku).

  Widget _buildAlatRow(Map<String, dynamic> alat, int nomor) {
    final nama = alat['nama_alat']?.toString() ?? '-';
    final stok = alat['stok'] ?? 0;
    final kondisi = alat['kondisi']?.toString() ?? '-';

    Color warnaKondisi;

    switch (kondisi.toLowerCase()) {
      case 'baik':
        warnaKondisi = Colors.green;
        break;

      case 'rusak ringan':
        warnaKondisi = Colors.orange;
        break;

      case 'rusak berat':
        warnaKondisi = Colors.red;
        break;

      default:
        warnaKondisi = Colors.blueGrey;
    }

    Color warnaStok = const Color(0xFF0F8A7D);

    if (stok == 0) {
      warnaStok = Colors.red;
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEFEFEF), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ======================================================
          // NOMOR
          // ======================================================
          SizedBox(
            width: 32,
            child: Text(
              '$nomor',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),

          // ======================================================
          // AVATAR
          // ======================================================
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0F8A7D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Color(0xFF0F8A7D),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ======================================================
          // NAMA ALAT + BADGE
          // ======================================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _buildBadge('Stok: $stok', warnaStok),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _buildBadge(kondisi, warnaKondisi),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ======================================================
          // AKSI
          // ======================================================
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // EDIT
              InkWell(
                onTap: () => _editAlat(alat),
                borderRadius: BorderRadius.circular(18),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: Colors.blue,
                  ),
                ),
              ),

              // HAPUS
              InkWell(
                onTap: () => _hapusAlat(alat),
                borderRadius: BorderRadius.circular(18),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BADGE INFO (STOK / KONDISI)
  // ============================================================

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
