import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Kode status tunggal untuk transaksi peminjaman + pengembalian.
///
/// Normalisasi: semua status database (huruf kecil, kapital, nilai lama
/// seperti 'dipinjam' / 'dikembalikan') dipetakan ke satu set konstanta.
class StatusHelper {
  // Status Peminjaman
  static const String menunggu = 'menunggu';
  static const String disetujui = 'disetujui';
  static const String ditolak = 'ditolak';
  static const String selesai = 'selesai';
  static const String dipinjam = 'dipinjam';
  static const String dikembalikan = 'dikembalikan';

  // Status Pengembalian
  static const String pgMenunggu = 'pengembalian_menunggu';
  static const String pgDitolak = 'pengembalian_ditolak';
  static const String pgDisetujui = 'pengembalian_disetujui';

  // ============================================================
  // NORMALISASI
  // ============================================================

  static String normalizePeminjaman(String? status) {
    final value = (status ?? '').trim().toLowerCase();

    switch (value) {
      case 'menunggu':
      case 'menunggu konfirmasi':
      case 'diproses':
        return menunggu;

      case 'disetujui':
      case 'approved':
        return disetujui;

      case 'ditolak':
      case 'rejected':
      case 'dibatalkan':
        return ditolak;

      case 'selesai':
        return selesai;

      case 'dipinjam':
      case 'dikembalikan':
        return value;

      default:
        return value.isEmpty ? menunggu : value;
    }
  }

  static String normalizePengembalian(String? status) {
    final value = (status ?? '').trim().toLowerCase();

    switch (value) {
      case 'menunggu':
      case 'menunggu konfirmasi':
        return menunggu;

      case 'disetujui':
        return disetujui;

      case 'ditolak':
        return ditolak;

      case 'selesai':
      case 'dikembalikan':
        // Nilai lama dari flow admin tanpa konfirmasi.
        return disetujui;

      default:
        return value.isEmpty ? '' : value;
    }
  }

  // ============================================================
  // STATUS GABUNGAN (PEMINJAMAN + PENGEMBALIAN TERAKHIR)
  // ============================================================
  // KL:
  //  - Mahasiswa mengajukan pengembalian  -> pengembalian_menunggu (kuning)
  //  - Admin menolak pengembalian         -> pengembalian_ditolak (merah)
  //  - Admin menyetujui pengembalian      -> selesai (biru)
  //  - Tanpa pengembalian                 -> status peminjaman

  static String combinedStatus(
      String? peminjamanStatus, String? pengembalianStatus) {
    final pg = normalizePengembalian(pengembalianStatus);
    final p = normalizePeminjaman(peminjamanStatus);

    if (pg == menunggu) return pgMenunggu;
    if (pg == ditolak) return pgDitolak;
    if (pg == disetujui || p == selesai || p == dikembalikan) return selesai;

    return p;
  }

  // ============================================================
  // LABEL
  // ============================================================

  static String label(String status) {
    switch (status) {
      case menunggu:
        return 'Menunggu Konfirmasi';
      case disetujui:
        return 'Disetujui';
      case ditolak:
        return 'Ditolak';
      case selesai:
        return 'Selesai';
      case pgMenunggu:
        return 'Konfirmasi Pengembalian';
      case pgDitolak:
        return 'Pengembalian Ditolak';
      case pgDisetujui:
        return 'Pengembalian Disetujui';
      case dipinjam:
        return 'Sedang Dipinjam';
      case dikembalikan:
        return 'Selesai';
      default:
        return status.isEmpty ? 'Menunggu Konfirmasi' : status;
    }
  }

  // ============================================================
  // WARNA
  // ============================================================

  static Color color(String status) {
    switch (status) {
      case disetujui:
      case pgDisetujui:
        return AppColors.statusApproved;
      case menunggu:
      case pgMenunggu:
      case dipinjam:
        return AppColors.statusPending;
      case ditolak:
      case pgDitolak:
        return AppColors.statusRejected;
      case selesai:
      case dikembalikan:
        return AppColors.statusCompleted;
      default:
        return AppColors.textSecondary;
    }
  }

  // ============================================================
  // FORMAT TANGGAL INDONESIA
  // ============================================================

  /// Format tanggal Indonesia (hanya tanggal, waktu dibuang).
  ///
  /// Nilai database bisa berupa ISO string ("2026-09-18T00:00:00.000"),
  /// hasil `toIso8601String()`, atau format lama lain yang menyertakan
  /// waktu. Bagian waktu ("T...", "00:00:00", ".0000000") selalu dibuang
  /// supaya tidak tampil di aplikasi.
  static String formatTanggal(String? tanggal) {
    if (tanggal == null || tanggal.isEmpty) return '-';

    // Ambil hanya bagian tanggal (buang "T", spasi, dan sisa waktu).
    final bersih = tanggal.trim().split(RegExp(r'[T\s]')).first;

    final date = DateTime.tryParse(bersih);

    if (date == null) return tanggal;

    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${bulan[date.month - 1]} '
        '${date.year}';
  }
}
