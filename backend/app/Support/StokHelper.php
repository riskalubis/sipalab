<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;

class StokHelper
{
    /**
     * Total unit sebuah alat yang sedang "dipesan" (menunggu disetujui).
     * Peminjaman yang sudah disetujui TIDAK dihitung di sini karena
     * stoknya sudah dikurangkan dari kolom alat.stok saat disetujui.
     */
    public static function dipesan(int $alatId): int
    {
        $res = DB::selectOne(
            "SELECT COALESCE(SUM(dp.jumlah), 0) AS total
             FROM detail_peminjaman dp
             JOIN peminjaman p ON p.id = dp.peminjaman_id
             WHERE dp.alat_id = ?
               AND p.status = 'menunggu'",
            [$alatId],
        );

        return (int) ($res->total ?? 0);
    }

    /** Total unit yang sedang dipinjam untuk satu alat (disetujui & belum kembali). */
    public static function sedangDipinjamAlat(int $alatId): int
    {
        $res = DB::selectOne(
            "SELECT COALESCE(SUM(dp.jumlah), 0) AS total
             FROM detail_peminjaman dp
             JOIN peminjaman p ON p.id = dp.peminjaman_id
             WHERE dp.alat_id = ?
               AND p.status = 'disetujui'
               AND NOT EXISTS (
                   SELECT 1 FROM pengembalian pg
                    WHERE pg.peminjaman_id = p.id
                      AND LOWER(pg.status) = 'disetujui'
               )",
            [$alatId],
        );

        return (int) ($res->total ?? 0);
    }

    /** Total unit yang sedang dipinjam (status peminjaman disetujui). */
    public static function sedangDipinjam(): int
    {
        $res = DB::selectOne(
            "SELECT COALESCE(SUM(dp.jumlah), 0) AS total
             FROM detail_peminjaman dp
             JOIN peminjaman p ON p.id = dp.peminjaman_id
             WHERE p.status = 'disetujui'
               AND NOT EXISTS (
                   SELECT 1 FROM pengembalian pg
                    WHERE pg.peminjaman_id = p.id
                      AND LOWER(pg.status) = 'disetujui'
               )",
        );

        return (int) ($res->total ?? 0);
    }
}
