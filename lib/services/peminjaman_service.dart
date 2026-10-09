import 'api_service.dart';

class PeminjamanService {
  // Ajukan Peminjaman Baru (Header + Detail).
  // Seluruh validasi stok & transaksi dipindah ke endpoint Laravel.
  Future<int> buatPeminjaman({
    required int userId,
    required String tglPinjam,
    required String tglKembali,
    required String keperluan,
    required List<Map<String, dynamic>> detail, // [{alat_id, jumlah}]
  }) async {
    final map = await ApiService.postMap('/peminjaman', {
      'user_id': userId,
      'tanggal_pinjam': tglPinjam,
      'tanggal_kembali': tglKembali,
      'keperluan': keperluan,
      'detail': detail,
    });
    return map?['id'] ?? 0;
  }

  // Ambil Riwayat Peminjaman Mahasiswa
  Future<List<Map<String, dynamic>>> getRiwayatMahasiswa(int userId) async =>
      ApiService.getList('/peminjaman/riwayat/$userId');

  // Ambil Semua Peminjaman (Sisi Admin)
  Future<List<Map<String, dynamic>>> getAllPeminjamanAdmin() async =>
      ApiService.getList('/peminjaman/admin');

  // Update Status Peminjaman. Logika pengurangan stok ada di backend.
  Future<int> updateStatusPeminjaman(
    int peminjamanId,
    String statusBaru,
  ) async {
    final map = await ApiService.putMap(
      '/peminjaman/$peminjamanId/status',
      {'status': statusBaru},
    );
    return map?['updated'] ?? 0;
  }
}
