import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Dilempar saat SEMUA alamat server tidak terhubung (transport error)
/// bukan karena respons error dari server. Dipakai ApiService agar
/// lapisan offline bisa membedakan "server mati" vs "server menolak".
class OfflineException implements Exception {
  final String message;

  const OfflineException([this.message = 'Tidak dapat terhubung ke server.']);

  @override
  String toString() => message;
}

class PendingOp {
  final int id;
  final String method;
  final String endpoint;
  final Map<String, dynamic> payload;

  PendingOp(this.id, this.method, this.endpoint, this.payload);
}

/// Database lokal + logika offline (cache endpoint + antrian operasi).
///
/// Pola kerja:
///   - Setiap GET yang berhasil dari server disalin ke tabel cache
///     (kunci = endpoint), sehingga bisa dibaca lagi saat server mati.
///   - Setiap operasi tulis (POST/PUT/DELETE) yang gagal karena server
///     tidak terhubung masuk ke tabel pending_ops.
///   - Saat koneksi pulih, [tryFlush] mengirim ulang antrian secara
///     berurutan, lalu menyegarkan cache.
class OfflineService {
  OfflineService._();

  static final OfflineService instance = OfflineService._();

  Database? _db;
  bool _disabled = false;

  /// Notifier status offline untuk banner UI.
  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  /// Jumlah operasi yang masih menunggu sinkronisasi.
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  Timer? _syncTimer;

  Future<Database> _database() async {
    if (_disabled) throw StateError('offline-disabled');

    if (_db != null) return _db!;

    try {
      final dir = await getDatabasesPath();
      final path = p.join(dir, 'sipalab_offline.db');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE api_cache (
              endpoint TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE pending_ops (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              method TEXT NOT NULL,
              endpoint TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE session (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE meta (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        },
      );

      return _db!;
    } catch (e) {
      // Platform tanpa dukungan sqflite (mis. desktop) → dinonaktifkan.
      _disabled = true;
      rethrow;
    }
  }

  Future<void> _safe(Future<void> Function(Database db) fn) async {
    try {
      final db = await _database();
      await fn(db);
    } catch (_) {
      // Offline dinonaktifkan / db rusak → abaikan.
    }
  }

  // ============================================================
  // CACHE ENDPOINT
  // ============================================================

  Future<void> cachePut(String endpoint, dynamic data) {
    return _safe((db) async {
      await db.insert(
          'api_cache',
          {
            'endpoint': endpoint,
            'payload': jsonEncode(data),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<dynamic> cacheGet(String endpoint) async {
    try {
      final db = await _database();
      final rows = await db.query(
        'api_cache',
        where: 'endpoint = ?',
        whereArgs: [endpoint],
        limit: 1,
      );

      if (rows.isEmpty) return null;

      return jsonDecode(rows.first['payload'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheRemove(String endpoint) {
    return _safe((db) async {
      await db.delete('api_cache', where: 'endpoint = ?', whereArgs: [
        endpoint,
      ]);
    });
  }

  Future<void> clearAll() {
    return _safe((db) async {
      await db.delete('api_cache');
    });
  }

  // ============================================================
  // ANTRIAN (PENDING OPS)
  // ============================================================

  Future<int?> enqueue(
      String method, String endpoint, Map<String, dynamic> payload) {
    int? inserted;

    return _safe((db) async {
      inserted = await db.insert('pending_ops', {
        'method': method,
        'endpoint': endpoint,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await _countPending(db);
    }).then((_) => inserted);
  }

  Future<void> removeOp(int id) {
    return _safe((db) async {
      await db.delete('pending_ops', where: 'id = ?', whereArgs: [id]);
      await _countPending(db);
    });
  }

  Future<List<PendingOp>> allPendingOps() async {
    try {
      final db = await _database();
      final rows = await db.query('pending_ops', orderBy: 'id ASC');

      return rows.map((row) {
        return PendingOp(
          row['id'] as int,
          row['method'] as String,
          row['endpoint'] as String,
          Map<String, dynamic>.from(
            jsonDecode(row['payload'] as String) as Map,
          ),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _countPending(Database db) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM pending_ops',
    );

    if (rows.isNotEmpty) {
      pendingCount.value = rows.first['c'] as int? ?? 0;
    }
  }

  Future<void> refreshPendingCount() async {
    await _safe((db) => _countPending(db));
  }

  // ============================================================
  // TERAPKAN OPERASI SECARA LOKAL (optimistic) KE CACHE
  //
  // Dipakai saat server mati: operasi masuk antrian, dan dampaknya
  // langsung dituangkan ke cache sehingga layar tetap "hidup" dan
  // konsisten sampai sinkronisasi benar-benar terjadi.
  // ============================================================

  Future<void> applyLocalOp(
    String method,
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = await _database();

      // ----------------------------------------------------------
      // PUT /peminjaman/{id}/status  → setujui / tolak
      // ----------------------------------------------------------
      final statusMatch =
          RegExp(r'^/peminjaman/(\d+)/status$').firstMatch(endpoint);
      if (method == 'PUT' && statusMatch != null) {
        final peminjamanId = int.parse(statusMatch.group(1)!);
        final status = payload['status']?.toString();

        await _updatePeminjamanCache(db, peminjamanId, status);

        if (status == 'disetujui') {
          await _adjustAlatStock(db, peminjamanId, -1);
        }
        return;
      }

      // ----------------------------------------------------------
      // PUT /pengembalian/{id}/setujui → stok naik
      // ----------------------------------------------------------
      final setujuiMatch =
          RegExp(r'^/pengembalian/(\d+)/setujui$').firstMatch(endpoint);
      if (method == 'PUT' && setujuiMatch != null) {
        final pengembalianId = int.parse(setujuiMatch.group(1)!);
        final peminjamanId =
            int.tryParse(payload['peminjaman_id']?.toString() ?? '') ?? 0;

        await _setPengembalianStatus(db,
            id: pengembalianId, status: 'disetujui');

        if (peminjamanId > 0) {
          await _adjustAlatStock(db, peminjamanId, 1);
        }
        return;
      }

      // ----------------------------------------------------------
      // PUT /pengembalian/{id}/tolak
      // ----------------------------------------------------------
      final tolakMatch =
          RegExp(r'^/pengembalian/(\d+)/tolak$').firstMatch(endpoint);
      if (method == 'PUT' && tolakMatch != null) {
        final pengembalianId = int.parse(tolakMatch.group(1)!);
        await _setPengembalianStatus(db, id: pengembalianId, status: 'ditolak');
        return;
      }

      // ----------------------------------------------------------
      // DELETE /alat/{id}
      // ----------------------------------------------------------
      final delAlat = RegExp(r'^/alat/(\d+)$').firstMatch(endpoint);
      if (method == 'DELETE' && delAlat != null) {
        final alatId = int.parse(delAlat.group(1)!);
        await _removeAlatCache(db, alatId);
        return;
      }
    } catch (_) {
      // Best-effort; kalau gagal, sinkronisasi tetap akan membetulkan.
    }
  }

  /// Update status peminjaman di seluruh cache yang memuat data itu.
  Future<void> _updatePeminjamanCache(
    Database db,
    int peminjamanId,
    String? status,
  ) async {
    final rows = await db.query('api_cache');
    for (final row in rows) {
      final endpoint = row['endpoint'] as String;
      if (!endpoint.contains('/peminjaman/')) continue;

      final data = jsonDecode(row['payload'] as String);
      if (data is List) {
        final mapped = <dynamic>[];
        for (final item in data) {
          if (item is Map &&
              (item['id'] ?? item['peminjaman_id']) == peminjamanId) {
            final copy = Map<String, dynamic>.from(item);
            if (copy.containsKey('status') == false &&
                copy['status_peminjaman'] != null) {
              copy['status_peminjaman'] = status;
            } else {
              copy['status'] = status;
            }
            mapped.add(copy);
          } else {
            mapped.add(item);
          }
        }
        await scheduleUpdate(db, endpoint, mapped);
      }
    }
  }

  /// Menambah / mengurangi stok alat pada cache `/alat` dan `/alat/{id}/stok-tersedia`.
  Future<void> _adjustAlatStock(
      Database db, int peminjamanId, int multiplier) async {
    // Cari detail jumlah dari cache peminjaman yang masih tersedia.
    var jumlah = 0;
    var alatId = 0;

    final rows = await db.query('api_cache');
    for (final row in rows) {
      if (!(row['endpoint'] as String).contains('peminjaman/')) continue;
      final data = jsonDecode(row['payload'] as String);
      if (data is! List) continue;

      for (final item in data) {
        if (item is Map &&
            int.tryParse(item['id']?.toString() ?? '') == peminjamanId) {
          alatId = int.tryParse(item['alat_id']?.toString() ?? '0') ?? 0;
          jumlah = int.tryParse(item['jumlah']?.toString() ?? '0') ?? 0;
          if (alatId > 0 && jumlah > 0) break;
        }
      }
      if (alatId > 0) break;
    }

    if (alatId == 0 || jumlah == 0) return;

    // Cache daftar /alat
    final alatCache = await db.query('api_cache',
        where: 'endpoint = ?',
        whereArgs: [
          '/alat',
        ],
        limit: 1);
    if (alatCache.isNotEmpty) {
      final list = jsonDecode(alatCache.first['payload'] as String) as List;
      final updated = list.map((e) {
        final item = Map<String, dynamic>.from(e as Map);
        if (int.tryParse(item['id']?.toString() ?? '') == alatId) {
          item['stok'] = (int.tryParse(item['stok']?.toString() ?? '0') ?? 0) +
              (multiplier * jumlah);
        }
        return item;
      }).toList();
      await db.insert(
          'api_cache',
          {
            'endpoint': '/alat',
            'payload': jsonEncode(updated),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Cache /alat/{id}/stok-tersedia
    final tersediaCache = await db.query(
      'api_cache',
      where: 'endpoint = ?',
      whereArgs: ['/alat/$alatId/stok-tersedia'],
      limit: 1,
    );
    if (tersediaCache.isNotEmpty) {
      final map = Map<String, dynamic>.from(
        jsonDecode(tersediaCache.first['payload'] as String) as Map,
      );
      map['stok'] = (int.tryParse(map['stok']?.toString() ?? '0') ?? 0) +
          (multiplier * jumlah);
      await db.insert(
          'api_cache',
          {
            'endpoint': '/alat/$alatId/stok-tersedia',
            'payload': jsonEncode(map),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Update status pengembalian di cache (termasuk menghapus dari daftar
  /// menunggu bila status menuntut hilang dari antrian admin).
  Future<void> _setPengembalianStatus(Database db,
      {required int id, required String status}) async {
    final rows = await db.query('api_cache');
    for (final row in rows) {
      final endpoint = row['endpoint'] as String;
      if (!endpoint.contains('/pengembalian/')) continue;

      final data = jsonDecode(row['payload'] as String);
      if (data is! List) continue;

      final mapped = <dynamic>[];
      for (final item in data) {
        if (item is Map &&
            int.tryParse(item['id']?.toString() ??
                    item['pengembalian_id']?.toString() ??
                    '') ==
                id) {
          // Untuk daftar admin (hanya menunggu), setujui/tolak → hilang.
          if (endpoint.contains('/admin')) continue;

          final copy = Map<String, dynamic>.from(item);
          copy['status'] = status;
          mapped.add(copy);
        } else {
          mapped.add(item);
        }
      }
      await scheduleUpdate(db, endpoint, mapped);
    }
  }

  /// Hapus alat dari cache `/alat`.
  Future<void> _removeAlatCache(Database db, int alatId) async {
    final alatCache = await db.query('api_cache',
        where: 'endpoint = ?',
        whereArgs: [
          '/alat',
        ],
        limit: 1);
    if (alatCache.isEmpty) return;

    final list =
        (jsonDecode(alatCache.first['payload'] as String) as List).where((e) {
      return int.tryParse((e as Map)['id']?.toString() ?? '') != alatId;
    }).toList();

    await db.insert(
        'api_cache',
        {
          'endpoint': '/alat',
          'payload': jsonEncode(list),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> scheduleUpdate(Database db, String endpoint, dynamic data) {
    return db.insert(
        'api_cache',
        {
          'endpoint': endpoint,
          'payload': jsonEncode(data),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ============================================================
  // SESI (login offline)
  // ============================================================

  String _passwordHash(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<void> saveLogin(
    Map<String, dynamic> user,
    String password, {
    String? token,
  }) {
    return _safe((db) async {
      await db.insert(
          'session',
          {
            'key': 'user',
            'value': jsonEncode(user),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert(
          'session',
          {
            'key': 'password_hash',
            'value': _passwordHash(password),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      // Hapus skema lama yang menyimpan password sebagai teks biasa.
      await db.delete('session', where: 'key = ?', whereArgs: ['password']);

      if (token != null && token.isNotEmpty) {
        await db.insert(
            'session',
            {
              'key': 'token',
              'value': token,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await db.delete('session', where: 'key = ?', whereArgs: ['token']);
      }
    });
  }

  Future<void> clearLogin() {
    return _safe((db) async {
      await db.delete('session');
    });
  }

  Future<Map<String, dynamic>?> offlineLogin(
    String email,
    String password,
  ) async {
    try {
      final db = await _database();
      final rows = await db.query('session');
      final values = <String, String>{
        for (final row in rows) row['key'] as String: row['value'] as String,
      };

      final rawUser = values['user'];
      final savedHash = values['password_hash'];
      if (rawUser == null || savedHash == null) return null;

      final user = Map<String, dynamic>.from(
        jsonDecode(rawUser) as Map,
      );
      final savedEmail = user['email']?.toString().toLowerCase() ?? '';
      final token = values['token'];

      if (savedEmail != email.trim().toLowerCase() ||
          savedHash != _passwordHash(password)) {
        return null;
      }

      if (token != null && token.isNotEmpty) {
        user['_token'] = token;
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // SINKRONISASI OTOMATIS (TIMER BERKALA)
  // ============================================================

  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(tryFlush());
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Mencoba mengirim semua operasi antrian ke server.
  /// Dijalankan berkala; bila server belum pulih, antrian aman menunggu.
  Future<void> tryFlush() async {
    if (_disabled) return;

    try {
      final ops = await allPendingOps();
      if (ops.isEmpty) {
        isOffline.value = false;
        return;
      }

      // Cek dulu koneksi: kalau server belum pulih, jangan lanjut.
      if (!await _serverAlive()) {
        isOffline.value = true;
        return;
      }

      for (final op in ops) {
        final code = await _replay(op);
        if (code == 1) {
          await removeOp(op.id);
        } else if (code == -1) {
          // Transport error → server belum pulih, hentikan & tunggu timer.
          break;
        } else {
          // Server menolak op (mis. stok habis setelah dicek server).
          // Hapus agar tidak memblok antrian, namun catat di konsol.
          debugPrint('OfflineService: op ${op.id} ${op.method} ${op.endpoint} '
              'ditolak server, dihapus dari antrian.');
          await removeOp(op.id);
        }
      }

      isOffline.value = false;

      // Segarkan data agar semua HP melihat hasil sinkronisasi.
      await refreshCaches();
    } catch (_) {
      isOffline.value = true;
    }
  }

  Future<bool> _serverAlive() async {
    try {
      final alive = await _pingServer();
      return alive;
    } catch (_) {
      return false;
    }
  }

  /// Implementasi ping diisi ApiService (hindari circular import).
  Future<bool> _pingServer() async {
    // Gunakan sinkronisasi langsung lewat get jenis endpoint ringan.
    try {
      final data = await _rawGet('/kategori');
      return data != null;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _rawGet(String endpoint) async {
    // Akan diganti oleh ApiService melalui callbacks di bawah.
    final handler = _rawGetHandler;
    if (handler == null) throw StateError('no-handler');
    return handler(endpoint);
  }

  /// Replay satu operasi antrian ke server.
  /// Kembalian: 1 = sukses, 0 = ditolak server, -1 = transport error.
  Future<int> _replay(PendingOp op) async {
    final callback = _sendHandler;
    if (callback == null) {
      return -1;
    }

    try {
      final ok = await callback(op.method, op.endpoint, op.payload);
      return ok ? 1 : 0;
    } on OfflineException {
      return -1;
    } catch (_) {
      return 0;
    }
  }

  // Hook ke ApiService (dipasang saat aplikasi start) untuk menghindari
  // circular import antara api_service.dart dan offline_service.dart.
  Future<dynamic> Function(String endpoint)? _rawGetHandler;

  set rawGetHandler(Future<dynamic> Function(String endpoint)? h) =>
      _rawGetHandler = h;

  Future<bool> Function(String, String, Map<String, dynamic>)? _sendHandler;

  set sendHandler(
          Future<bool> Function(String, String, Map<String, dynamic>)? h) =>
      _sendHandler = h;

  // ============================================================
  // SEGARKAN CACHE SETELAH SINKRON
  // ============================================================

  /// Pull endpoint penting dari server untuk menyegarkan cache lokal.
  Future<void> refreshCaches() async {
    final handler = _refreshHandler;
    if (handler == null) return;

    try {
      await handler();
    } catch (_) {
      // Abaikan; cache lama masih boleh dipakai.
    }
  }

  Future<void> Function()? _refreshHandler;

  set refreshHandler(Future<void> Function()? h) => _refreshHandler = h;
}
