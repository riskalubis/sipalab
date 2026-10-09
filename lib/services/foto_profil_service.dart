import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// ============================================================
// LAYANAN FOTO PROFIL
// ============================================================
//
// Foto profil disimpan sebagai FILE di folder dokumen aplikasi
// (bukan base64 di database). Database hanya menyimpan PATH-nya,
// sehingga foto tidak membebani memori SQLite.

class FotoProfilService {
  // ============================================================
  // AMBIL GAMBAR (KAMERA / GALERI) LALU SALIN KE PENYIMPANAN
  // ============================================================
  //
  // Mengembalikan path absolut file foto baru, atau null bila
  // pengguna membatalkan pemilihan gambar.

  static Future<String?> pilihDanSimpanFoto({
    required String userId,
    required ImageSource source,
  }) async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();

    final folder = Directory('${dir.path}/foto_profil');

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final isPng = picked.path.toLowerCase().endsWith('.png');
    final ext = isPng ? '.png' : '.jpg';

    final fileName =
        'profil_${userId}_${DateTime.now().millisecondsSinceEpoch}$ext';

    final tujuan = File('${folder.path}/$fileName');

    await File(picked.path).copy(tujuan.path);

    return tujuan.path;
  }

  // ============================================================
  // HAPUS FILE FOTO
  // ============================================================

  static Future<void> hapusFotoTersimpan(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // File tidak ada atau gagal dihapus: abaikan.
    }
  }
}
