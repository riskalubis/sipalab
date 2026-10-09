<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StorePeminjamanRequest;
use App\Http\Requests\UpdatePeminjamanStatusRequest;
use App\Models\Alat;
use App\Models\DetailPeminjaman;
use App\Models\Peminjaman;
use App\Support\StokHelper;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class PeminjamanController extends Controller
{
    // Kolom gabungan peminjaman + detail + alat + user.
    // Menyediakan alias ganda supaya semua layar (kelola_peminjaman,
    // peminjaman_admin, transaksi, detail) membaca field yang sama
    // persis seperti sebelumnya.
    private const JOIN_SELECT = '
        SELECT p.id, p.user_id,
               p.tanggal_pinjam, p.tanggal_kembali,
               p.tanggal_pinjam AS tgl_pinjam,
               p.tanggal_kembali AS tgl_kembali,
               p.keperluan, p.catatan, p.status,
               u.nama,
               u.nama AS nama_mahasiswa,
               u.nim, u.kelas, u.email,
               dp.id AS detail_id, dp.alat_id, dp.jumlah,
               a.nama_alat, a.stok, a.kondisi,
               pg.status AS status_pengembalian
        FROM peminjaman p
        JOIN users u ON u.id = p.user_id
        JOIN detail_peminjaman dp ON dp.peminjaman_id = p.id
        JOIN alat a ON a.id = dp.alat_id
        LEFT JOIN pengembalian pg ON pg.id = (
            SELECT MAX(pg2.id) FROM pengembalian pg2
            WHERE pg2.peminjaman_id = p.id
        )
    ';

    // ============================================================
    // BUAT PEMINJAMAN BARU + DETAIL (validasi stok di server)
    // ============================================================
    public function store(StorePeminjamanRequest $request): JsonResponse
    {
        $userId = (int) $request->input('user_id');

        // Gabungkan alat yang sama agar tidak ada dua baris detail untuk satu
        // alat (diverifikasi unique index di level database).
        $detail = $this->normalisasiDetail($request->input('detail', []));

        // Validasi semua alat & jumlah terlebih dahulu (atomic).
        $reserved = [];

        foreach ($detail as $item) {
            $alatId = (int) $item['alat_id'];
            $jumlah = (int) $item['jumlah'];

            $alat = Alat::find($alatId);

            if (! $alat) {
                return response()->json(['message' => 'Alat tidak ditemukan.'], 422);
            }

            if ($jumlah < 1) {
                return response()->json(
                    ['message' => 'Jumlah alat pada peminjaman tidak valid.'],
                    422,
                );
            }

            $dipesan = StokHelper::dipesan($alat->id) + ($reserved[$alatId] ?? 0);
            $tersedia = $alat->stok - $dipesan;

            if ($jumlah > $tersedia) {
                return response()->json([
                    'message' => "Stok {$alat->nama_alat} tidak mencukupi. Stok tersedia: {$tersedia}.",
                ], 422);
            }

            $reserved[$alatId] = ($reserved[$alatId] ?? 0) + $jumlah;
        }

        $peminjaman = DB::transaction(function () use ($request, $userId, $detail) {
            $peminjaman = Peminjaman::create([
                'user_id' => $userId,
                'tanggal_pinjam' => $this->tanggal($request->input('tanggal_pinjam')),
                'tanggal_kembali' => $this->tanggal($request->input('tanggal_kembali')),
                'keperluan' => trim((string) $request->input('keperluan', '')),
                'catatan' => $this->teksAtauNull($request->input('catatan')),
                'status' => Peminjaman::STATUS_MENUNGGU,
            ]);

            foreach ($detail as $item) {
                DetailPeminjaman::create([
                    'peminjaman_id' => $peminjaman->id,
                    'alat_id' => (int) $item['alat_id'],
                    'jumlah' => (int) $item['jumlah'],
                ]);
            }

            return $peminjaman;
        });

        return response()->json([
            'id' => $peminjaman->id,
            'status' => Peminjaman::STATUS_MENUNGGU,
        ], 201);
    }

    // ============================================================
    // RIWAYAT PEMINJAMAN MAHASISWA
    // ============================================================
    public function riwayat(Request $request, string $userId): JsonResponse
    {
        if ($response = $this->guardOwnership($request, (int) $userId)) {
            return $response;
        }

        $rows = DB::select(
            self::JOIN_SELECT.' WHERE p.user_id = ? ORDER BY p.id DESC',
            [(int) $userId],
        );

        return response()->json(array_map([$this, 'keMap'], $rows));
    }

    // ============================================================
    // PEMINJAMAN AKTIF (disetujui & belum pernah dikembalikan)
    // ============================================================
    public function aktif(Request $request, string $userId): JsonResponse
    {
        if ($response = $this->guardOwnership($request, (int) $userId)) {
            return $response;
        }

        // Pengembalian yang DITOLAK tidak boleh menyembunyikan peminjaman
        // yang masih aktif, jadi yang dicek hanya pengembalian disetujui.
        $rows = DB::select(
            self::JOIN_SELECT." WHERE p.user_id = ?
                 AND p.status = 'disetujui'
                 AND NOT EXISTS (
                     SELECT 1 FROM pengembalian pg2
                      WHERE pg2.peminjaman_id = p.id
                        AND LOWER(pg2.status) = 'disetujui'
                 )
                 ORDER BY p.id DESC",
            [(int) $userId],
        );

        return response()->json(array_map([$this, 'keMap'], $rows));
    }

    // ============================================================
    // DETAIL SATU PEMINJAMAN (dipakai layar detail admin & mahasiswa)
    // ============================================================
    public function show(Request $request, string $id): JsonResponse
    {
        $rows = DB::select(
            self::JOIN_SELECT.' WHERE p.id = ? LIMIT 1',
            [(int) $id],
        );

        if (empty($rows)) {
            return response()->json(
                ['message' => 'Data peminjaman tidak ditemukan.'],
                404,
            );
        }

        $row = $rows[0];

        if ($response = $this->guardOwnership($request, (int) $row->user_id)) {
            return $response;
        }

        return response()->json($this->keMap($row));
    }

    // ============================================================
    // SEMUA PEMINJAMAN (sisi admin, menunggu lebih dulu)
    // ============================================================
    public function adminIndex(Request $request): JsonResponse
    {
        if (! $request->user()?->isAdmin()) {
            return $this->tidakDiizinkan();
        }

        $rows = DB::select(
            self::JOIN_SELECT." ORDER BY
                CASE p.status WHEN 'menunggu' THEN 0 ELSE 1 END,
                p.id DESC",
        );

        return response()->json(array_map([$this, 'keMap'], $rows));
    }

    // ============================================================
    // NOTIFIKASI MAHASISWA
    // ============================================================
    public function notifikasiMahasiswa(Request $request, string $userId): JsonResponse
    {
        if ($response = $this->guardOwnership($request, (int) $userId)) {
            return $response;
        }

        $rows = DB::select(
            'SELECT p.id AS peminjaman_id,
                    p.status AS status_peminjaman,
                    p.tanggal_pinjam, p.tanggal_kembali,
                    dp.id AS detail_id, dp.jumlah, dp.alat_id,
                    a.nama_alat, a.stok, a.kondisi,
                    pg.id AS pengembalian_id, pg.status AS status_pengembalian
             FROM peminjaman p
             JOIN detail_peminjaman dp ON dp.peminjaman_id = p.id
             JOIN alat a ON a.id = dp.alat_id
             LEFT JOIN pengembalian pg ON pg.id = (
                 SELECT MAX(pg2.id) FROM pengembalian pg2
                 WHERE pg2.peminjaman_id = p.id
             )
             WHERE p.user_id = ?
             ORDER BY p.id DESC',
            [(int) $userId],
        );

        return response()->json(array_map(function ($row) {
            return [
                'peminjaman_id' => (int) $row->peminjaman_id,
                'status_peminjaman' => (string) $row->status_peminjaman,
                'tanggal_pinjam' => $this->formatTanggal($row->tanggal_pinjam),
                'tanggal_kembali' => $this->formatTanggal($row->tanggal_kembali),
                'detail_id' => (int) $row->detail_id,
                'jumlah' => (int) $row->jumlah,
                'alat_id' => (int) $row->alat_id,
                'nama_alat' => (string) $row->nama_alat,
                'stok' => (int) $row->stok,
                'kondisi' => (string) $row->kondisi,
                'pengembalian_id' => $row->pengembalian_id === null
                    ? null
                    : (int) $row->pengembalian_id,
                'status_pengembalian' => $row->status_pengembalian,
            ];
        }, $rows));
    }

    // ============================================================
    // UPDATE STATUS (disetujui / ditolak) â€” pengurangan stok di sini
    // ============================================================
    public function updateStatus(UpdatePeminjamanStatusRequest $request, string $id): JsonResponse
    {
        $statusBaru = strtolower((string) $request->input('status'));

        $outcome = DB::transaction(function () use ($id, $statusBaru) {
            $peminjaman = Peminjaman::query()->lockForUpdate()->find((int) $id);

            if (! $peminjaman) {
                return ['error' => ['message' => 'Data peminjaman tidak ditemukan.'], 'code' => 422];
            }

            if (! $peminjaman->isMenunggu()) {
                return ['error' => ['message' => 'Peminjaman ini sudah diproses.'], 'code' => 422];
            }

            if ($statusBaru === Peminjaman::STATUS_DITOLAK) {
                $peminjaman->update(['status' => Peminjaman::STATUS_DITOLAK]);

                return null;
            }

            return $this->kurangiStok($peminjaman, $statusBaru);
        });

        if ($outcome !== null) {
            return response()->json($outcome['error'], $outcome['code']);
        }

        return response()->json(['updated' => 1]);
    }

    // ============================================================
    // PENGURANGAN STOK SAAT DISETUJUI
    // ============================================================

    /**
     * @return array{error: array<string, string>, code: int}|null
     */
    private function kurangiStok(Peminjaman $peminjaman, string $statusBaru): ?array
    {
        $details = DetailPeminjaman::where('peminjaman_id', $peminjaman->id)
            ->orderBy('id')
            ->get();

        if ($details->isEmpty()) {
            return ['error' => ['message' => 'Detail alat pada peminjaman tidak ditemukan.'], 'code' => 422];
        }

        foreach ($details as $detail) {
            if ($detail->jumlah < 1) {
                return ['error' => ['message' => 'Jumlah alat pada peminjaman tidak valid.'], 'code' => 422];
            }
        }

        // Kunci baris alat lalu verifikasi stok satu per satu. Bila kurang,
        // transaksi dibatalkan (stok tidak pernah dikurangi sebagian).
        foreach ($details as $detail) {
            $alat = Alat::query()->lockForUpdate()->find($detail->alat_id);

            if (! $alat) {
                return ['error' => ['message' => 'Alat tidak ditemukan.'], 'code' => 422];
            }

            if ($detail->jumlah > $alat->stok) {
                return ['error' => [
                    'message' => "Stok {$alat->nama_alat} tidak mencukupi untuk disetujui. "
                        ."Stok tersedia: {$alat->stok}, dibutuhkan: {$detail->jumlah}.",
                ], 'code' => 422];
            }
        }

        foreach ($details as $detail) {
            // WHERE stok >= jumlah membuat pengurangan idempoten & aman
            // bila ada request bersamaan.
            $affected = DB::table('alat')
                ->where('id', $detail->alat_id)
                ->where('stok', '>=', $detail->jumlah)
                ->decrement('stok', $detail->jumlah);

            if ($affected !== 1) {
                return ['error' => [
                    'message' => 'Stok alat berubah saat persetujuan. Silakan ulangi.',
                ], 'code' => 422];
            }
        }

        $peminjaman->update(['status' => $statusBaru]);

        return null;
    }

    // ============================================================
    // PEMBANTU
    // ============================================================

    /**
     * Gabungkan detail yang menunjuk alat sama: jumlah dijumlahkan.
     *
     * @param  mixed  $detail
     * @return array<int, array{alat_id: int, jumlah: int}>
     */
    private function normalisasiDetail($detail): array
    {
        $gabung = [];

        foreach ((array) $detail as $item) {
            if (! is_array($item)) {
                continue;
            }

            $alatId = (int) ($item['alat_id'] ?? 0);
            $jumlah = (int) ($item['jumlah'] ?? 0);

            if ($alatId < 1) {
                continue;
            }

            $gabung[$alatId] = ($gabung[$alatId] ?? 0) + $jumlah;
        }

        $hasil = [];

        foreach ($gabung as $alatId => $jumlah) {
            $hasil[] = ['alat_id' => $alatId, 'jumlah' => $jumlah];
        }

        return $hasil;
    }

    /**
     * Mahasiswa hanya boleh membaca datanya sendiri; admin bebas.
     */
    private function guardOwnership(Request $request, int $userId): ?JsonResponse
    {
        $actor = $request->user();

        if (! $actor) {
            return response()->json(['message' => 'Tidak terautentikasi.'], 401);
        }

        if (! $actor->isAdmin() && (int) $actor->id !== $userId) {
            return $this->tidakDiizinkan();
        }

        return null;
    }

    private function tidakDiizinkan(): JsonResponse
    {
        return response()->json(
            ['message' => 'Anda tidak berhak mengakses data ini.'],
            403,
        );
    }

    private function tanggal(mixed $value): Carbon
    {
        return Carbon::parse((string) $value);
    }

    private function teksAtauNull(mixed $value): ?string
    {
        $value = $value === null ? '' : trim((string) $value);

        return $value === '' ? null : $value;
    }

    /**
     * Format tanggal ISO-8601. Nilai yang tidak bisa dibaca diteruskan
     * apa adanya agar tidak kehilangan informasi.
     */
    private function formatTanggal(mixed $value): string
    {
        if ($value === null || $value === '') {
            return '';
        }

        try {
            return Carbon::parse((string) $value)->toIso8601String();
        } catch (\Throwable) {
            return (string) $value;
        }
    }

    private function keMap(\stdClass $row): array
    {
        return [
            'id' => (int) $row->id,
            'user_id' => (int) $row->user_id,
            'tanggal_pinjam' => $this->formatTanggal($row->tanggal_pinjam),
            'tanggal_kembali' => $this->formatTanggal($row->tanggal_kembali),
            'tgl_pinjam' => $this->formatTanggal($row->tgl_pinjam),
            'tgl_kembali' => $this->formatTanggal($row->tgl_kembali),
            'keperluan' => (string) $row->keperluan,
            'catatan' => $row->catatan,
            'status' => (string) $row->status,
            'nama' => (string) $row->nama,
            'nama_mahasiswa' => (string) $row->nama_mahasiswa,
            'nim' => $row->nim,
            'kelas' => $row->kelas,
            'email' => (string) $row->email,
            'detail_id' => (int) $row->detail_id,
            'alat_id' => (int) $row->alat_id,
            'jumlah' => (int) $row->jumlah,
            'nama_alat' => (string) $row->nama_alat,
            'stok' => (int) $row->stok,
            'kondisi' => (string) $row->kondisi,
            'status_pengembalian' => $row->status_pengembalian,
        ];
    }
}
