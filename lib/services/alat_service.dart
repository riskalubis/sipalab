import '../models/alat_model.dart';
import '../models/kategori_model.dart';
import 'api_service.dart';

class AlatService {
  // --- KATEGORI ---
  Future<List<KategoriModel>> getAllKategori() async {
    final list = await ApiService.getList('/kategori');
    return list.map(KategoriModel.fromMap).toList();
  }

  Future<int> insertKategori(String namaKategori) async {
    final map = await ApiService.postMap('/kategori', {
      'nama_kategori': namaKategori,
    });
    return map?['id'] ?? 0;
  }

  // --- ALAT ---
  Future<List<AlatModel>> getAllAlat() async {
    final list = await ApiService.getList('/alat');
    return list.map(AlatModel.fromMap).toList();
  }

  Future<int> insertAlat(AlatModel alat) async {
    final map = await ApiService.postMap('/alat', alat.toMap());
    return map?['id'] ?? 0;
  }

  Future<int> updateAlat(AlatModel alat) async {
    await ApiService.putMap('/alat/${alat.id}', alat.toMap());
    return 1;
  }

  Future<int> deleteAlat(int id) async {
    await ApiService.delete('/alat/$id');
    return 1;
  }
}
