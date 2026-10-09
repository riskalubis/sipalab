import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class TambahAlatScreen extends StatefulWidget {
  final Map<String, dynamic>? alat;

  const TambahAlatScreen({super.key, this.alat});

  @override
  State<TambahAlatScreen> createState() => _TambahAlatScreenState();
}

class _TambahAlatScreenState extends State<TambahAlatScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _namaController;
  late TextEditingController _stokController;
  late TextEditingController _deskripsiController;

  List<Map<String, dynamic>> listKategori = [];

  String? _kategoriId;
  String _kondisi = 'Baik';

  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> listKondisi = ['Baik', 'Rusak Ringan', 'Rusak Berat'];

  bool get isEdit => widget.alat != null;

  @override
  void initState() {
    super.initState();

    _namaController = TextEditingController(
      text: widget.alat?['nama_alat']?.toString() ?? '',
    );

    _stokController = TextEditingController(
      text: widget.alat?['stok']?.toString() ?? '0',
    );

    _deskripsiController = TextEditingController(
      text: widget.alat?['deskripsi']?.toString() ?? '',
    );

    // Isi kondisi ketika mode edit
    final kondisiLama = widget.alat?['kondisi']?.toString();

    if (kondisiLama != null && listKondisi.contains(kondisiLama)) {
      _kondisi = kondisiLama;
    }

    _loadKategori();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _stokController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD KATEGORI DARI DATABASE
  // ============================================================

  Future<void> _loadKategori() async {
    try {
      final data = await ApiService.getList('/kategori');

      if (!mounted) return;

      setState(() {
        listKategori = data;

        // MODE EDIT
        if (isEdit) {
          final kategoriLama = widget.alat?['kategori_id'];

          if (kategoriLama != null) {
            final kategoriId = kategoriLama.toString();

            // Pastikan kategori tersebut memang masih ada
            final adaKategori = listKategori.any(
              (kategori) => kategori['id'].toString() == kategoriId,
            );

            if (adaKategori) {
              _kategoriId = kategoriId;
            }
          }
        }

        // MODE TAMBAH
        if (_kategoriId == null && listKategori.isNotEmpty) {
          _kategoriId = listKategori.first['id'].toString();
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat kategori: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // SIMPAN / UPDATE DATA ALAT
  // ============================================================

  Future<void> _simpanData() async {
    // Validasi form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Pastikan kategori sudah dipilih
    if (_kategoriId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih kategori alat.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final namaAlat = _namaController.text.trim();

    final stok = int.tryParse(_stokController.text.trim());

    if (stok == null || stok < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stok harus berupa angka dan tidak boleh negatif.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dataAlat = {
        'kategori_id': int.parse(_kategoriId!),
        'nama_alat': namaAlat,
        'stok': stok,
        'kondisi': _kondisi,
        'deskripsi': _deskripsiController.text.trim(),
        'gambar': widget.alat?['gambar']?.toString() ?? '',
      };

      // ========================================================
      // MODE EDIT / TAMBAH LEWAT API
      // ========================================================

      if (isEdit) {
        final id = widget.alat!['id'];

        await ApiService.putMap('/alat/$id', dataAlat);
      } else {
        await ApiService.postMap('/alat', dataAlat);
      }

      if (!mounted) return;

      // ========================================================
      // BERHASIL
      // ========================================================

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Data alat berhasil diperbarui!'
                : 'Alat berhasil ditambahkan!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Kembali ke Kelola Alat
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan data alat: $e'),
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
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Data Alat' : 'Tambah Alat Baru'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : listKategori.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada kategori alat di database.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ==================================================
                        // NAMA ALAT
                        // ==================================================
                        const Text(
                          'Nama Alat',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _namaController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'Contoh: Multimeter Digital',
                            prefixIcon: const Icon(Icons.build_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama alat wajib diisi';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        // ==================================================
                        // KATEGORI
                        // ==================================================
                        const Text(
                          'Kategori',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 8),

                        DropdownButtonFormField<String>(
                          initialValue: _kategoriId,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.category_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: listKategori.map((kategori) {
                            return DropdownMenuItem<String>(
                              value: kategori['id'].toString(),
                              child: Text(kategori['nama_kategori'].toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _kategoriId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Kategori wajib dipilih';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        // ==================================================
                        // STOK
                        // ==================================================
                        const Text(
                          'Jumlah Stok',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _stokController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Contoh: 10',
                            prefixIcon: const Icon(Icons.inventory_2_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Stok wajib diisi';
                            }

                            final stok = int.tryParse(value.trim());

                            if (stok == null) {
                              return 'Stok harus berupa angka';
                            }

                            if (stok < 0) {
                              return 'Stok tidak boleh negatif';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        // ==================================================
                        // KONDISI
                        // ==================================================
                        const Text(
                          'Kondisi Alat',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 8),

                        DropdownButtonFormField<String>(
                          initialValue: _kondisi,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.health_and_safety_outlined,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: listKondisi.map((kondisi) {
                            return DropdownMenuItem<String>(
                              value: kondisi,
                              child: Text(kondisi),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _kondisi = value;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 18),

                        // ==================================================
                        // DESKRIPSI
                        // ==================================================
                        const Text(
                          'Deskripsi Alat',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _deskripsiController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText:
                                'Tuliskan spesifikasi atau keterangan alat...',
                            alignLabelWithHint: true,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 65),
                              child: Icon(Icons.description_outlined),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // ==================================================
                        // TOMBOL SIMPAN
                        // ==================================================
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _simpanData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isEdit ? 'PERBARUI DATA' : 'SIMPAN ALAT',
                                    style: const TextStyle(
                                      fontSize: 16,
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
