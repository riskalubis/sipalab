class PeminjamanModel {
  final int? id;
  final int userId;
  final String? namaMahasiswa;
  final String? nim;
  final String tglPinjam;
  final String tglKembali;
  final String
      status; // 'Menunggu Konfirmasi', 'Disetujui', 'Ditolak', 'Selesai'
  final String? catatan;

  PeminjamanModel({
    this.id,
    required this.userId,
    this.namaMahasiswa,
    this.nim,
    required this.tglPinjam,
    required this.tglKembali,
    required this.status,
    this.catatan,
  });

  factory PeminjamanModel.fromMap(Map<String, dynamic> map) {
    return PeminjamanModel(
      id: map['id'],
      userId: map['user_id'] ?? 0,
      namaMahasiswa: map['nama_mahasiswa'],
      nim: map['nim'],
      tglPinjam: map['tgl_pinjam'] ?? '',
      tglKembali: map['tgl_kembali'] ?? '',
      status: map['status'] ?? 'Menunggu Konfirmasi',
      catatan: map['catatan'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'tgl_pinjam': tglPinjam,
      'tgl_kembali': tglKembali,
      'status': status,
      'catatan': catatan,
    };
  }
}
