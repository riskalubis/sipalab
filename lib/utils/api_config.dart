import 'package:shared_preferences/shared_preferences.dart';

/// Konfigurasi alamat server API Laravel.
///
/// Aplikasi mencoba beberapa alamat secara berurutan:
///   1. Alamat yang di-set pengguna lewat Pengaturan (tersimpan per HP),
///      bila diisi.
///   2. Nilai --dart-define=API_URL (bila di-set saat build).
///   3. IP LAN laptop (untuk HP asli di Wi-Fi yang sama).
///   4. IP Mobile Hotspot laptop (untuk HP yang terhubung ke hotspot laptop,
///      jalur ini tetap jalan walau router mengaktifkan AP/Client Isolation).
///   5. 10.0.2.2 (untuk emulator Android).
/// Alamat yang berhasil pertama kali akan diingat untuk request berikutnya.
class ApiConfig {
  static const String _fromDefine = String.fromEnvironment('API_URL');

  /// IP LAN laptop saat pengembangan. Bisa dioverride saat build dengan
  /// `--dart-define=LAN_IP=192.168.x.x` agar tidak perlu edit kode.
  static const String _lanIp = String.fromEnvironment(
    'LAN_IP',
    defaultValue: '192.168.1.11',
  );

  /// IP laptop pada mode Mobile Hotspot Windows: `192.168.137.1`.
  static const String _hotspotIp = '192.168.137.1';

  static const String _storageKey = 'api_server_base';

  /// Alamat server yang dipilih pengguna lewat Pengaturan.
  static String _customBase = '';

  /// Alamat server khusus yang pernah disimpan pengguna (kosong = otomatis).
  static String get customBase => _customBase;

  /// Membaca alamat server tersimpan dari penyimpanan perangkat.
  static Future<void> loadCustomBase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customBase = prefs.getString(_storageKey) ?? '';
    } catch (_) {
      _customBase = '';
    }
  }

  /// Menyimpan alamat server pilihan pengguna. Pengguna boleh mengetik
  /// hanya IP ("192.168.1.16"), IP+port ("192.168.1.16:8000"), atau URL
  /// lengkap. Nilai kosong mengembalikan aplikasi ke mode otomatis.
  static Future<void> saveCustomBase(String value) async {
    _customBase = _normalize(value);
    _activeBase = '';

    final prefs = await SharedPreferences.getInstance();
    if (_customBase.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey, _customBase);
    }
  }

  /// Bentuk alamat input pengguna menjadi base URL siap pakai,
  /// contoh: `192.168.1.16` -> `http://192.168.1.16:8000/api`.
  static String _normalize(String raw) {
    var v = raw.trim();
    if (v.isEmpty) return '';

    if (!v.contains('://')) {
      v = 'http://$v';
    }

    final uri = Uri.tryParse(v);
    if (uri == null || uri.host.isEmpty) return raw;

    final port = uri.hasPort ? uri.port : 80;

    var path = uri.path;
    if (path.isEmpty || path == '/') {
      path = '/api';
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    return 'http://${uri.host}:$port$path';
  }

  /// Bentuk untuk ditampilkan di form Pengaturan (tanpa skema & /api).
  static String customBaseDisplay() {
    if (_customBase.isEmpty) return '';
    return _customBase
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/api$'), '');
  }

  /// Daftar alamat server yang dicoba berurutan.
  static List<String> get candidates {
    final bases = <String>[
      if (_customBase.isNotEmpty) _customBase,
      // 127.0.0.1 dipakai bila piranti dev berjalan via 'adb reverse'
      // tcp:8000 tcp:8000 (USB) -- mem-bypass semua masalah Wi-Fi/router.
      'http://127.0.0.1:8000/api',
      'http://$_lanIp/api',
      'http://$_hotspotIp/api',
      'http://10.0.2.2:8000/api',
    ];
    if (_fromDefine.isNotEmpty) {
      bases.insert(0, _fromDefine);
    }
    return bases;
  }

  static String _activeBase = '';

  /// Alamat yang sedang dipakai (kandidat pertama yang berhasil terhubung).
  static String get baseUrl {
    if (_activeBase.isEmpty) _activeBase = candidates.first;
    return _activeBase;
  }

  static void setActiveBase(String url) => _activeBase = url;
}
