class DetailPeminjamanModel {
  final int? id;
  final int peminjamanId;
  final int alatId;
  final String? namaAlat;
  final int jumlah;

  DetailPeminjamanModel({
    this.id,
    required this.peminjamanId,
    required this.alatId,
    this.namaAlat,
    required this.jumlah,
  });

  factory DetailPeminjamanModel.fromMap(Map<String, dynamic> map) {
    return DetailPeminjamanModel(
      id: map['id'],
      peminjamanId: map['peminjaman_id'] ?? 0,
      alatId: map['alat_id'] ?? 0,
      namaAlat: map['nama_alat'],
      jumlah: map['jumlah'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peminjaman_id': peminjamanId,
      'alat_id': alatId,
      'jumlah': jumlah,
    };
  }
}
