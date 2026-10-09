import 'api_service.dart';

class PengembalianService {
  // Ajukan Pengembalian oleh Mahasiswa (stok belum dikembalikan).
  Future<int> ajukanPengembalian({
    required int peminjamanId,
    required String tanggalPengembalian,
    required String kondisi,
    String? catatan,
  }) async {
    final map = await ApiService.postMap('/pengembalian', {
      'peminjaman_id': peminjamanId,
      'tanggal_pengembalian': tanggalPengembalian,
      'kondisi': kondisi,
      'catatan': catatan ?? '',
    });
    return map?['id'] ?? 0;
  }

  // Setujui Pengembalian (Admin): stok bertambah di sisi backend.
  Future<bool> setujuiPengembalian({
    required int pengembalianId,
    required int peminjamanId,
  }) async {
    final map = await ApiService.putMap(
      '/pengembalian/$pengembalianId/setujui',
      {'peminjaman_id': peminjamanId},
    );
    return map?['success'] ?? false;
  }

  Future<bool> tolakPengembalian({required int pengembalianId}) async {
    final map = await ApiService.putMap(
      '/pengembalian/$pengembalianId/tolak',
      {},
    );
    return map?['success'] ?? false;
  }

  // Get Semua Data Pengembalian
  Future<List<Map<String, dynamic>>> getAllPengembalian() async =>
      ApiService.getList('/pengembalian');
}
