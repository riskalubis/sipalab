class KategoriModel {
  final int? id;
  final String namaKategori;

  KategoriModel({this.id, required this.namaKategori});

  factory KategoriModel.fromMap(Map<String, dynamic> map) {
    return KategoriModel(
      id: map['id'],
      namaKategori: map['nama_kategori'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'nama_kategori': namaKategori};
  }
}
