import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../session/user_session.dart';
import '../utils/api_config.dart';
import 'offline_service.dart';

/// Klien HTTP tunggal untuk seluruh pemanggilan REST API.
///
/// Seluruh respons dikembalikan sebagai `Map` / `List<Map>` dengan nama
/// field persis seperti hasil query SQLite sebelumnya, sehingga method
/// `.fromMap()` pada model SIPALAB tidak perlu diubah.
///
/// Host server dicoba berurutan (lihat [ApiConfig.candidates]); alamat
/// pertama yang berhasil diingat dan dipakai untuk request berikutnya,
/// supaya aplikasi jalan baik di emulator maupun HP asli tanpa rebuild.
class ApiService {
  ApiService._();

  static const Duration _timeout = Duration(seconds: 6);

  // ============================================================
  // KONFIGURASI SERVER (TERSIMPAN PER HP)
  // ============================================================
  // Alamat server pilihan pengguna dibaca dari penyimpanan perangkat
  // sekali saja, lalu di-cache selama aplikasi berjalan.

  static Future<void>? _configFuture;

  static Future<void> _ensureConfig() {
    return _configFuture ??= ApiConfig.loadCustomBase();
  }

  // ============================================================
  // CACHE GET (in-memory, TTL singkat)
  // ============================================================
  // Buka kembali layar dalam jangka waktu singkat memakai data yang
  // sudah pernah diambil, sehingga tidak menampilkan loading lagi.
  // Semua request yang mengubah data (POST/PUT/DELETE) menghapus cache.

  static const Object _notCached = Object();
  static const Duration _cacheTtl = Duration(seconds: 20);

  static final Map<String, _CacheEntry> _getCache = {};

  static dynamic _readCache(String endpoint) {
    final entry = _getCache[endpoint];
    if (entry != null && entry.expiresAt.isAfter(DateTime.now())) {
      return entry.data;
    }
    return _notCached;
  }

  static void _writeCache(String endpoint, dynamic data) {
    _getCache[endpoint] = _CacheEntry(
      data,
      DateTime.now().add(_cacheTtl),
    );
  }

  /// Menghapus cache respons agar data dari akun sebelumnya tidak bocor
  /// ke sesi berikutnya, terutama saat aplikasi dipakai pada perangkat bersama.
  static void clearRequestCache() {
    _getCache.clear();
  }

  /// Error yang menandakan kegagalan sambungan (bukan respons server).
  /// Khusus type ini, request dicoba ke alamat server berikutnya.
  static bool _isTransportError(Object e) {
    return e is TimeoutException ||
        e is SocketException ||
        e is HandshakeException ||
        e is http.ClientException;
  }

  // ============================================================
  // NORMALISASI NILAI
  // ============================================================
  // SQLite mengembalikan id/stok/jumlah sebagai angka (int), sedangkan
  // JSON dari Laravel bisa berupa string ("5"). Konversi balik agar
  // perilaku Model .fromMap() dan kode UI tetap sama persis.

  static dynamic _toNum(dynamic value) {
    if (value is String) {
      final v = value.trim();
      if (RegExp(r'^-?\d+$').hasMatch(v)) return int.parse(v);
      if (RegExp(r'^-?\d+\.\d+$').hasMatch(v)) return double.parse(v);
    }
    return value;
  }

  static Map<String, dynamic> _cleanMap(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      if (key == 'id' ||
          key.endsWith('_id') ||
          key == 'jumlah' ||
          key == 'stok' ||
          key == 'total' ||
          value is int ||
          value is double) {
        out[key] = _toNum(value);
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  // ============================================================
  // HEADER
  // ============================================================

  static Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = UserSession.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ============================================================
  // DEKODE RESPONS
  // ============================================================

  static dynamic _decode(http.Response res) {
    final body = res.body.trim();

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body.isEmpty) return null;
      return jsonDecode(body);
    }

    // Error: ambil "message" dari JSON Laravel bila tersedia,
    // supaya snackbar menampilkan pesan yang sama seperti sebelumnya.
    var pesan = 'Terjadi kesalahan (${res.statusCode}).';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        pesan = decoded['message'].toString();
      }
    } catch (_) {
      if (body.isNotEmpty) {
        pesan = body.length > 200 ? '${body.substring(0, 200)}...' : body;
      }
    }
    throw Exception(pesan);
  }

  // ============================================================
  // REQUEST TERPUSAT + FAILOVER HOST
  // ============================================================

  static Future<dynamic> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? data,
  }) async {
    await _ensureConfig();

    final bases = ApiConfig.candidates;

    for (var i = 0; i < bases.length; i++) {
      final uri = Uri.parse('${bases[i]}$endpoint');

      try {
        final headers = await _headers();

        http.Response res;

        switch (method) {
          case 'GET':
            res = await http.get(uri, headers: headers).timeout(_timeout);
          case 'POST':
            res = await http
                .post(
                  uri,
                  headers: headers,
                  body: data == null ? null : jsonEncode(data),
                )
                .timeout(_timeout);
          case 'PUT':
            res = await http
                .put(
                  uri,
                  headers: headers,
                  body: data == null ? null : jsonEncode(data),
                )
                .timeout(_timeout);
          case 'DELETE':
            res = await http.delete(uri, headers: headers).timeout(_timeout);
          default:
            throw StateError('Method tidak dikenal: $method');
        }

        // Server terhubung → ingat alamat ini untuk request berikutnya.
        ApiConfig.setActiveBase(bases[i]);

        // Semua operasi yang mengubah data (POST/PUT/DELETE) membuat
        // cache GET basi, supaya layar lain selalu tampil data terbaru.
        if (method != 'GET') _getCache.clear();

        return _decode(res);
      } catch (e) {
        // Respons server (4xx/5xx) atau isi tidak valid → jangan pindah host.
        if (!_isTransportError(e)) rethrow;

        // Kegagalan sambungan ke host ini → coba host berikutnya.
        if (i == bases.length - 1) {
          // Tandai offline supaya lapisan offline mengambil-alih.
          OfflineService.instance.isOffline.value = true;
          throw const OfflineException(
            'Tidak dapat terhubung ke server. Pastikan server Laravel '
            'berjalan di laptop dan HP terhubung ke Wi-Fi yang sama.',
          );
        }
      }
    }

    throw const OfflineException('Tidak dapat terhubung ke server.');
  }

  // ============================================================
  // PUBLIC METHODS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getList(String endpoint) async {
    final cached = _readCache(endpoint);
    if (cached != _notCached) return cached as List<Map<String, dynamic>>;

    try {
      final body = await _request('GET', endpoint) as List<dynamic>;
      final result =
          body.map((e) => _cleanMap(Map<String, dynamic>.from(e))).toList();

      _writeCache(endpoint, result);
      await OfflineService.instance.cachePut(endpoint, result);
      OfflineService.instance.isOffline.value = false;
      return result;
    } on OfflineException {
      // Server mati → pakai cache lokal bila tersedia.
      final lokal = await OfflineService.instance.cacheGet(endpoint);
      if (lokal is List) {
        _writeCache(endpoint, lokal);
        OfflineService.instance.isOffline.value = true;
        return lokal.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      rethrow;
    }
  }

  /// Versi [getList] yang selalu meminta data terbaru ke server
  /// (tidak memakai cache in-memory). Dipakai dashboard & layar yang
  /// wajib sinkron, misal saat aplikasi kembali aktif atau timer.
  static Future<List<Map<String, dynamic>>> getListFresh(
    String endpoint,
  ) async {
    try {
      final body = await _request('GET', endpoint) as List<dynamic>;
      final result =
          body.map((e) => _cleanMap(Map<String, dynamic>.from(e))).toList();

      _writeCache(endpoint, result);
      await OfflineService.instance.cachePut(endpoint, result);
      OfflineService.instance.isOffline.value = false;
      return result;
    } on OfflineException {
      final lokal = await OfflineService.instance.cacheGet(endpoint);
      if (lokal is List) {
        _writeCache(endpoint, lokal);
        OfflineService.instance.isOffline.value = true;
        return lokal.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getMap(String endpoint) async {
    final cached = _readCache(endpoint);
    if (cached != _notCached) {
      return cached == null ? null : cached as Map<String, dynamic>;
    }

    try {
      final body = await _request('GET', endpoint);
      Map<String, dynamic>? result;
      if (body != null) {
        result = _cleanMap(Map<String, dynamic>.from(body));
      }

      _writeCache(endpoint, result);
      await OfflineService.instance.cachePut(endpoint, result ?? {});
      OfflineService.instance.isOffline.value = false;
      return result;
    } on OfflineException {
      final lokal = await OfflineService.instance.cacheGet(endpoint);
      if (lokal is Map) {
        _writeCache(endpoint, lokal);
        OfflineService.instance.isOffline.value = true;
        return _cleanMap(Map<String, dynamic>.from(lokal));
      }
      rethrow;
    }
  }

  /// Versi [getMap] yang selalu meminta data terbaru ke server
  /// (tidak memakai cache in-memory). Dipakai dashboard admin supaya
  /// statistik & notifikasi selalu sinkron secara otomatis.
  static Future<Map<String, dynamic>?> getMapFresh(String endpoint) async {
    try {
      final body = await _request('GET', endpoint);
      Map<String, dynamic>? result;
      if (body != null) {
        result = _cleanMap(Map<String, dynamic>.from(body));
      }

      _writeCache(endpoint, result);
      await OfflineService.instance.cachePut(endpoint, result ?? {});
      OfflineService.instance.isOffline.value = false;
      return result;
    } on OfflineException {
      final lokal = await OfflineService.instance.cacheGet(endpoint);
      if (lokal is Map) {
        _writeCache(endpoint, lokal);
        OfflineService.instance.isOffline.value = true;
        return _cleanMap(Map<String, dynamic>.from(lokal));
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> postMap(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final body = await _request('POST', endpoint, data: data);
      OfflineService.instance.isOffline.value = false;
      if (body == null) return null;
      return _cleanMap(Map<String, dynamic>.from(body));
    } on OfflineException {
      return _queueSync('POST', endpoint, data);
    }
  }

  /// POST yang mengembalikan map berstatus tanpa dianggap error
  /// selama status HTTP 200 (misal hasil login).
  static Future<Map<String, dynamic>> postRaw(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final body = await _request('POST', endpoint, data: data);
      OfflineService.instance.isOffline.value = false;
      return _cleanMap(Map<String, dynamic>.from(body));
    } on OfflineException {
      OfflineService.instance.isOffline.value = true;
      await _queueSync('POST', endpoint, data);
      return {};
    }
  }

  static Future<Map<String, dynamic>?> putMap(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final body = await _request('PUT', endpoint, data: data);
      OfflineService.instance.isOffline.value = false;
      if (body == null) return null;
      return _cleanMap(Map<String, dynamic>.from(body));
    } on OfflineException {
      return _queueSync('PUT', endpoint, data);
    }
  }

  /// Mencabut bearer token di server. Sengaja tidak diantri saat offline:
  /// token lokal sudah dihapus pada logout, sehingga tidak perlu sinkronisasi.
  static Future<void> logout() async {
    try {
      await postMap('/logout', const <String, dynamic>{});
    } catch (_) {
      // Server mati/ sudah tidak bisa dijangkau — logout lokal tetap jalan.
    }
  }

  static Future<void> delete(String endpoint) async {
    try {
      await _request('DELETE', endpoint);
      OfflineService.instance.isOffline.value = false;
    } on OfflineException {
      OfflineService.instance.isOffline.value = true;
      if (_isQueueable('DELETE', endpoint)) {
        await OfflineService.instance.enqueue('DELETE', endpoint, {});
        await OfflineService.instance.applyLocalOp('DELETE', endpoint, {});
      } else {
        rethrow;
      }
    }
  }

  /// Endpoint yang BOLEH diantri saat server mati (transaksi & inventori).
  /// Operasi akun (login/register/ganti password/foto) harus langsung,
  /// jangan menunggu sinkronisasi.
  static bool _isQueueable(
    String method,
    String endpoint,
  ) {
    if (endpoint.contains('/login') ||
        endpoint.contains('/logout') ||
        endpoint.contains('/register') ||
        endpoint.contains('/password') ||
        endpoint.contains('/check-email') ||
        endpoint.contains('/users/foto') ||
        endpoint.contains('/users/update')) {
      return false;
    }

    if (method == 'GET') return false;

    return true;
  }

  /// Operasi tulis saat offline: masukkan ke antrian & terapkan
  /// dampaknya ke cache lokal supaya tampilan langsung berubah.
  static Future<Map<String, dynamic>?> _queueSync(
    String method,
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    OfflineService.instance.isOffline.value = true;

    if (!_isQueueable(method, endpoint)) {
      throw const OfflineException(
        'Server tidak terhubung. Operasi ini memerlukan koneksi aktif.',
      );
    }

    await OfflineService.instance.enqueue(method, endpoint, data);
    await OfflineService.instance.applyLocalOp(method, endpoint, data);

    // Kembalikan nilai "sukses lokal" supaya alur UI tidak error.
    final sukses = <String, dynamic>{'status': 'menunggu', 'success': true};
    return sukses;
  }

  // ============================================================
  // UJI KONEKSI (untuk Pengaturan Alamat Server)
  // ============================================================
  // Mencoba menghubungi endpoint kategori pada setiap kandidat host.
  // Mengembalikan base URL pertama yang berhasil, atau null bila semua gagal.

  static Future<String?> testConnection() async {
    await _ensureConfig();

    final bases = ApiConfig.candidates;

    for (final base in bases) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/kategori'),
              headers: await _headers(),
            )
            .timeout(_timeout);

        if (res.statusCode < 500) {
          ApiConfig.setActiveBase(base);
          return base;
        }
      } catch (_) {
        // Host ini tidak terjangkau → lanjut ke kandidat berikutnya.
      }
    }

    return null;
  }

  /// Menguji satu alamat server tertentu (dipakai halaman Pengaturan).
  static Future<bool> testBase(String base) async {
    try {
      final res = await http
          .get(
            Uri.parse('$base/kategori'),
            headers: await _headers(),
          )
          .timeout(_timeout);

      return res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // HOOK LAPISAN OFFLINE
  // ============================================================
  // Memasang callback ke OfflineService agar sinkronisasi berkala,
  // ping koneksi, dan penyegaran cache berjalan lewat ApiService.

  static void setupOfflineHooks() {
    final svc = OfflineService.instance;

    // Ping / cek koneksi: cukup endpoint kategori.
    svc.rawGetHandler = (endpoint) async {
      final body = await _request('GET', endpoint);
      return body;
    };

    // Replay satu operasi antrian ke server.
    svc.sendHandler =
        (String method, String endpoint, Map<String, dynamic> data) async {
      switch (method) {
        case 'POST':
          await _request('POST', endpoint, data: data);
          return true;
        case 'PUT':
          await _request('PUT', endpoint, data: data);
          return true;
        case 'DELETE':
          await _request('DELETE', endpoint);
          return true;
        default:
          return false;
      }
    };

    // Segarkan cache endpoint penting setelah sinkronisasi.
    svc.refreshHandler = () async {
      await CacheWarmer.warm();
    };
  }
}

/// Pemanas cache: mengisi ulang cache lokal dari endpoint penting
/// saat koneksi kembali, supaya layar lain tidak menampilkan data basi.
/// Memakai path langsung (melewati cache in-memory) agar selalu segar.
class CacheWarmer {
  static Future<void> warm() async {
    try {
      await _rawIntoOffline('GET', '/kategori');
      await _rawIntoOffline('GET', '/alat');

      if (UserSession.role == 'admin') {
        await _rawIntoOffline('GET', '/home/admin');
        await _rawIntoOffline('GET', '/peminjaman/admin');
        await _rawIntoOffline('GET', '/pengembalian/admin');
        await _rawIntoOffline('GET', '/laporan');
      } else if (UserSession.role == 'mahasiswa') {
        final uid = UserSession.userId;
        if (uid != null) {
          await _rawIntoOffline('GET', '/peminjaman/riwayat/$uid');
          await _rawIntoOffline('GET', '/peminjaman/aktif/$uid');
          await _rawIntoOffline('GET', '/peminjaman/notifikasi-mahasiswa/$uid');
        }
      }
    } catch (_) {
      // Kalau server belum pulih, biarkan cache lama dipakai.
    }
  }

  /// Fetch langsung dari server + menyalin ke cache offline.
  static Future<void> _rawIntoOffline(
    String method,
    String endpoint,
  ) async {
    final body = await ApiService._request(method, endpoint);
    if (body != null) {
      await OfflineService.instance.cachePut(endpoint, body);
    }
  }
}

class _CacheEntry {
  const _CacheEntry(this.data, this.expiresAt);

  final dynamic data;
  final DateTime expiresAt;
}
