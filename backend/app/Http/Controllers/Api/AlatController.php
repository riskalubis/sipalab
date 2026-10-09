<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreAlatRequest;
use App\Http\Requests\UpdateAlatRequest;
use App\Models\Alat;
use App\Support\StokHelper;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class AlatController extends Controller
{
    // Catatan: `GROUP_CONCAT(DISTINCT ... ORDER BY ... SEPARATOR ...)` hanya
    // didukung MySQL/MariaDB. SQLite tidak mengenal klausa ORDER BY/SEPARATOR
    // di dalam aggregate, jadi DISTINCT dilakukan di subquery terpisah agar
    // query ini berjalan di kedua driver.
    private const BASE_SELECT = "
        SELECT a.id, a.kategori_id,
               k.nama_kategori,
               k.nama_kategori AS kategori,
               a.nama_alat, a.stok, a.kondisi, a.deskripsi, a.gambar,
               COALESCE(d.total, 0) AS stok_dipesan,
               COALESCE(kp.kelas_peminjam, '') AS kelas_peminjam
        FROM alat a
        LEFT JOIN kategori k ON k.id = a.kategori_id
        LEFT JOIN (
            SELECT dp.alat_id, SUM(dp.jumlah) AS total
            FROM detail_peminjaman dp
            JOIN peminjaman p ON p.id = dp.peminjaman_id
            WHERE p.status = 'menunggu'
            GROUP BY dp.alat_id
        ) d ON d.alat_id = a.id
        LEFT JOIN (
            SELECT kpd.alat_id, GROUP_CONCAT(kpd.kelas) AS kelas_peminjam
            FROM (
                SELECT DISTINCT dp.alat_id, u.kelas
                FROM detail_peminjaman dp
                JOIN peminjaman p
                    ON p.id = dp.peminjaman_id AND p.status = 'disetujui'
                LEFT JOIN pengembalian pg
                    ON pg.peminjaman_id = p.id AND pg.status = 'disetujui'
                JOIN users u ON u.id = p.user_id
                WHERE pg.id IS NULL
                  AND u.kelas IS NOT NULL AND TRIM(u.kelas) <> ''
            ) kpd
            GROUP BY kpd.alat_id
        ) kp ON kp.alat_id = a.id
    ";

    // ============================================================
    // DAFTAR ALAT
    // ============================================================
    public function index(): JsonResponse
    {
        $rows = DB::select(self::BASE_SELECT.' ORDER BY a.id');

        return response()->json(array_map([$this, 'keMap'], $rows));
    }

    // ============================================================
    // DETAIL ALAT
    // ============================================================
    public function show(string $id): JsonResponse
    {
        $rows = DB::select(
            self::BASE_SELECT.' WHERE a.id = ? LIMIT 1',
            [(int) $id],
        );

        if (empty($rows)) {
            return response()->json(['message' => 'Alat tidak ditemukan.'], 404);
        }

        return response()->json($this->keMap($rows[0]));
    }

    // ============================================================
    // STOK TERSEDIA UNTUK DIPINJAM
    // ============================================================
    public function stokTersedia(string $id): JsonResponse
    {
        $alat = Alat::find((int) $id);

        if (! $alat) {
            return response()->json(['message' => 'Alat tidak ditemukan.'], 404);
        }

        return response()->json([
            'alat_id' => $alat->id,
            'stok' => $alat->stok,
            'dipesan' => StokHelper::dipesan($alat->id),
        ]);
    }

    // ============================================================
    // TAMBAH ALAT
    // ============================================================
    public function store(StoreAlatRequest $request): JsonResponse
    {
        $alat = Alat::create([
            'kategori_id' => (int) $request->input('kategori_id'),
            'nama_alat' => trim((string) $request->input('nama_alat', '')),
            'stok' => (int) $request->input('stok'),
            'kondisi' => trim((string) $request->input('kondisi', 'Baik')),
            'deskripsi' => $request->input('deskripsi'),
            'gambar' => $request->input('gambar'),
        ]);

        return response()->json($alat->load('kategori')->toArray(), 201);
    }

    // ============================================================
    // UBAH ALAT
    // ============================================================
    public function update(UpdateAlatRequest $request, string $id): JsonResponse
    {
        $alat = Alat::find((int) $id);

        if (! $alat) {
            return response()->json(['message' => 'Alat tidak ditemukan.'], 404);
        }

        // Bila stok diturunkan, pastikan tidak melewati jumlah yang sedang
        // dipinjam/dipesan (konsisten dengan guard di database).
        $stokBaru = (int) $request->input('stok');
        $terpakai = StokHelper::sedangDipinjamAlat($alat->id) + StokHelper::dipesan($alat->id);

        if ($stokBaru < $terpakai) {
            return response()->json([
                'message' => "Stok tidak boleh lebih kecil dari jumlah yang sedang dipinjam/dipesan ({$terpakai}).",
            ], 422);
        }

        $alat->update([
            'kategori_id' => (int) $request->input('kategori_id'),
            'nama_alat' => trim((string) $request->input('nama_alat', '')),
            'stok' => $stokBaru,
            'kondisi' => trim((string) $request->input('kondisi', '')),
            'deskripsi' => $request->input('deskripsi'),
            'gambar' => $request->input('gambar'),
        ]);

        return response()->json($alat->fresh()->load('kategori')->toArray());
    }

    // ============================================================
    // HAPUS ALAT
    // ============================================================
    public function destroy(string $id): JsonResponse
    {
        $actor = request()->user();

        if (! $actor) {
            return response()->json(['message' => 'Tidak terautentikasi.'], 401);
        }

        if (! $actor->isAdmin()) {
            return response()->json(
                ['message' => 'Anda tidak berhak menghapus alat.'],
                403,
            );
        }

        $alat = Alat::find((int) $id);

        if (! $alat) {
            return response()->json(['message' => 'Alat tidak ditemukan.'], 404);
        }

        $dipakai = DB::table('detail_peminjaman')
            ->where('alat_id', $alat->id)
            ->exists();

        if ($dipakai) {
            return response()->json([
                'message' => 'Alat tidak dapat dihapus karena sudah tercatat dalam peminjaman.',
            ], 422);
        }

        $alat->delete();

        return response()->json(['success' => true]);
    }

    private function keMap(\stdClass $row): array
    {
        return [
            'id' => (int) $row->id,
            'kategori_id' => (int) $row->kategori_id,
            'nama_kategori' => (string) $row->nama_kategori,
            'kategori' => (string) $row->kategori,
            'nama_alat' => (string) $row->nama_alat,
            'stok' => (int) $row->stok,
            'kondisi' => (string) $row->kondisi,
            'deskripsi' => $row->deskripsi,
            'gambar' => $row->gambar,
            'stok_dipesan' => (int) $row->stok_dipesan,
            'kelas_peminjam' => (string) $row->kelas_peminjam,
        ];
    }
}
