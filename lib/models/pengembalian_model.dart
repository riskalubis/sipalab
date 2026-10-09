class PengembalianModel {
  final int? id;
  final int peminjamanId;
  final String tglDikembalikan;
  final String kondisiAlat; // 'Baik', 'Rusak Ringan', 'Rusak Berat', 'Hilang'
  final String? catatan;

  PengembalianModel({
    this.id,
    required this.peminjamanId,
    required this.tglDikembalikan,
    required this.kondisiAlat,
    this.catatan,
  });

  factory PengembalianModel.fromMap(Map<String, dynamic> map) {
    return PengembalianModel(
      id: map['id'],
      peminjamanId: map['peminjaman_id'] ?? 0,
      // Nama field mengikuti API Laravel (`tanggal_pengembalian`, `kondisi`).
      // Nama lama tetap diterima agar cache lama tidak rusak.
      tglDikembalikan:
          map['tanggal_pengembalian'] ?? map['tgl_dikembalikan'] ?? '',
      kondisiAlat: map['kondisi'] ?? map['kondisi_alat'] ?? 'Baik',
      catatan: map['catatan'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peminjaman_id': peminjamanId,
      'tanggal_pengembalian': tglDikembalikan,
      'kondisi': kondisiAlat,
      'catatan': catatan,
    };
  }
}
