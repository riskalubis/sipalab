class AlatModel {
  final int? id;
  final String namaAlat;
  final int kategoriId;
  final String? namaKategori;
  final int stok;
  final String kondisi; // 'Baik', 'Rusak Ringan', 'Rusak Berat'
  final String? deskripsi;
  final String? gambar;

  AlatModel({
    this.id,
    required this.namaAlat,
    required this.kategoriId,
    this.namaKategori,
    required this.stok,
    required this.kondisi,
    this.deskripsi,
    this.gambar,
  });

  factory AlatModel.fromMap(Map<String, dynamic> map) {
    return AlatModel(
      id: map['id'],
      namaAlat: map['nama_alat'] ?? '',
      kategoriId: map['kategori_id'] ?? 0,
      namaKategori: map['nama_kategori'],
      stok: map['stok'] ?? 0,
      kondisi: map['kondisi'] ?? 'Baik',
      deskripsi: map['deskripsi'],
      gambar: map['gambar'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_alat': namaAlat,
      'kategori_id': kategoriId,
      'stok': stok,
      'kondisi': kondisi,
      'deskripsi': deskripsi,
      'gambar': gambar,
    };
  }
}
