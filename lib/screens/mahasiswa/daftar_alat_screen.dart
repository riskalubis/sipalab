import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'detail_alat_screen.dart';

class DaftarAlatScreen extends StatefulWidget {
  const DaftarAlatScreen({super.key});

  @override
  State<DaftarAlatScreen> createState() => _DaftarAlatScreenState();
}

class _DaftarAlatScreenState extends State<DaftarAlatScreen>
    with WidgetsBindingObserver {
  // ============================================================
  // DATA ALAT DARI DATABASE
  // ============================================================

  List<Map<String, dynamic>> _allAlat = [];
  List<Map<String, dynamic>> _filteredAlat = [];

  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadAlat();
  }

  // ============================================================
  // SAAT APLIKASI KEMBALI AKTIF
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _tutupKeyboard();
    }
  }

  // ============================================================
  // TUTUP KEYBOARD
  // ============================================================

  void _tutupKeyboard() {
    _searchFocusNode.unfocus();

    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ============================================================
  // LOAD DATA ALAT + KATEGORI
  // ============================================================

  Future<void> _loadAlat() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ========================================================
      // AMBIL DATA ALAT SEKALIGUS NAMA KATEGORI + INFO PINJAMAN
      // ========================================================
      // Endpoint /alat mengembalikan field:
      //   id, kategori_id, nama_alat, stok, kondisi, deskripsi,
      //   gambar, kategori, kelas_peminjam, stok_dipesan
      // ========================================================

      final data = await ApiService.getList('/alat');

      if (!mounted) return;

      setState(() {
        _allAlat = data;
        _filteredAlat = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });

      // Terapkan pencarian yang sedang aktif
      if (_searchController.text.trim().isNotEmpty) {
        _filterAlat(_searchController.text);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
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
  // PENCARIAN ALAT
  // ============================================================

  void _filterAlat(String query) {
    final searchQuery = query.trim().toLowerCase();

    setState(() {
      if (searchQuery.isEmpty) {
        _filteredAlat = List<Map<String, dynamic>>.from(_allAlat);
      } else {
        _filteredAlat = _allAlat.where((alat) {
          final nama = alat['nama_alat']?.toString().toLowerCase() ?? '';

          final kategori = alat['kategori']?.toString().toLowerCase() ?? '';

          return nama.contains(searchQuery) || kategori.contains(searchQuery);
        }).toList();
      }
    });
  }

  // ============================================================
  // ICON SESUAI KATEGORI
  // ============================================================

  IconData _getIcon(String? kategori) {
    switch (kategori) {
      case 'Elektronika':
        return Icons.electrical_services;

      case 'Jaringan':
        return Icons.router;

      case 'Pendukung':
        return Icons.business_center;

      default:
        return Icons.build;
    }
  }

  // ============================================================
  // DETAIL ALAT
  // ============================================================

  Future<void> _lihatDetail(Map<String, dynamic> alat) async {
    // ========================================================
    // PENTING:
    // TUTUP KEYBOARD SEBELUM PINDAH HALAMAN
    // ========================================================

    _tutupKeyboard();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetailAlatScreen(alat: alat)),
    );

    // Pastikan keyboard tetap tertutup setelah kembali
    _tutupKeyboard();

    // Setelah kembali dari detail,
    // ambil ulang stok dan kategori terbaru dari database.
    await _loadAlat();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Klik area kosong mana pun → tutup keyboard
      onTap: () {
        _tutupKeyboard();
      },

      child: Scaffold(
        appBar: AppBar(title: const Text('Daftar Alat')),
        body: RefreshIndicator(
          onRefresh: _loadAlat,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // ==================================================
                // SEARCH BAR
                // ==================================================
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _filterAlat,
                  decoration: InputDecoration(
                    hintText: 'Cari alat...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),

                const SizedBox(height: 16),

                // ==================================================
                // LOADING
                // ==================================================
                if (_isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                // ==================================================
                // DATA KOSONG
                // ==================================================
                else if (_filteredAlat.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Alat tidak ditemukan.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                // ==================================================
                // LIST ALAT
                // ==================================================
                else
                  Expanded(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filteredAlat.length,
                      itemBuilder: (context, index) {
                        final alat = _filteredAlat[index];

                        // ==================================================
                        // STOK
                        // ==================================================

                        final int stok =
                            int.tryParse(alat['stok']?.toString() ?? '0') ?? 0;

                        // Jumlah yang sudah dipesan (status menunggu)
                        // ikut dipakai sebagai cadangan, sehingga stok
                        // tersedia yang terlihat mengurangi pesanan
                        // yang masih menunggu persetujuan admin.

                        final int dipesan = int.tryParse(
                                alat['stok_dipesan']?.toString() ?? '0') ??
                            0;

                        final int stokTersedia =
                            (stok - dipesan) < 0 ? 0 : stok - dipesan;

                        final bool tersedia = stokTersedia > 0;

                        // ==================================================
                        // KELAS YANG SEDANG MEMINJAM
                        // ==================================================

                        final String kelasPeminjam =
                            alat['kelas_peminjam']?.toString() ?? '';

                        // ==================================================
                        // NAMA ALAT
                        // ==================================================

                        final String namaAlat =
                            alat['nama_alat']?.toString() ?? 'Alat';

                        // ==================================================
                        // KATEGORI
                        // ==================================================

                        final String kategori =
                            alat['kategori']?.toString() ?? '-';

                        // ==================================================
                        // CARD ALAT
                        // ==================================================

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),

                            // ==================================================
                            // ICON
                            // ==================================================
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: tersedia
                                    ? Colors.grey.shade200
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getIcon(kategori),
                                color: tersedia
                                    ? Colors.grey
                                    : Colors.red.shade300,
                              ),
                            ),

                            // ==================================================
                            // NAMA ALAT
                            // ==================================================
                            title: Text(
                              namaAlat,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // ==================================================
                            // INFORMASI ALAT
                            // ==================================================
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text('Kategori: $kategori'),
                                const SizedBox(height: 3),
                                Text(
                                  tersedia
                                      ? 'Stok tersedia: $stokTersedia unit'
                                      : 'Stok sudah tidak ada',
                                  style: TextStyle(
                                    color: tersedia ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (kelasPeminjam.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    tersedia
                                        ? 'Sebagian dipinjam oleh: $kelasPeminjam'
                                        : 'Dipinjam oleh: $kelasPeminjam',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // ==================================================
                            // PANAH
                            // ==================================================
                            trailing: const Icon(Icons.chevron_right),

                            // ==================================================
                            // BUKA DETAIL
                            // ==================================================
                            onTap: () {
                              _lihatDetail(alat);
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }
}
