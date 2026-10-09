<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\SetujuiPengembalianRequest;
use App\Http\Requests\StorePengembalianRequest;
use App\Models\DetailPeminjaman;
use App\Models\Peminjaman;
use App\Models\Pengembalian;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PengembalianController extends Controller
{
    private const ADMIN_SELECT = '
        SELECT pg.id AS pengembalian_id,
               pg.peminjaman_id,
               pg.tanggal_pengembalian,
               pg.kondisi,
               pg.catatan,
               pg.status AS status_pengembalian,
               p.tanggal_pinjam,
               p.tanggal_kembali,
               p.status AS status_peminjaman,
               u.nama AS nama_mahasiswa,
               u.nim
        FROM pengembalian pg
        JOIN peminjaman p ON p.id = pg.peminjaman_id
        JOIN users u ON u.id = p.user_id
    ';

    // ============================================================
    // DAFTAR PENGEMBALIAN (opsional filter peminjaman_id & limit)
    // ============================================================
    public function index(Request $request): JsonResponse
    {
        $actor = $request->user();

        if (! $actor) {
            return response()->json(['message' => 'Tidak terautentikasi.'], 401);
        }

        $query = DB::table('pengembalian')
            ->join('peminjaman', 'peminjaman.id', '=', 'pengembalian.peminjaman_id')
            ->select('pengembalian.*');

        $peminjamanId = (int) $request->query('peminjaman_id', 0);

        if ($peminjamanId > 0) {
            $query->where('pengembalian.peminjaman_id', $peminjamanId);
        }

        // Mahasiswa hanya melihat pengembalian atas miliknya sendiri.
        if (! $actor->isAdmin()) {
            $query->where('peminjaman.user_id', $actor->id);
        }

        $limit = (int) $request->query('limit', 0);

        if ($limit > 0) {
            $query->limit($limit);
        }

        $rows = $query->orderByDesc('pengembalian.id')->get();

        $result = $rows->map(fn ($row) => [
            'id' => (int) $row->id,
            'peminjaman_id' => (int) $row->peminjaman_id,
            'tanggal_pengembalian' => $this->formatTanggal($row->tanggal_pengembalian ?? null),
            'kondisi' => (string) ($row->kondisi ?? ''),
            'catatan' => $row->catatan ?? null,
            'status' => (string) ($row->status ?? ''),
        ])->all();

        return response()->json($result);
    }

    // ============================================================
    // AJUKAN PENGEMBALIAN (mahasiswa) — validasi sama seperti dahulu
    // ============================================================
    public function store(StorePengembalianRequest $request): JsonResponse
    {
        $peminjamanId = (int) $request->input('peminjaman_id');

        try {
            $pengembalian = DB::transaction(function () use ($request, $peminjamanId) {
                $peminjaman = Peminjaman::query()->lockForUpdate()->find($peminjamanId);

                if (! $peminjaman) {
                    return ['error' => ['message' => 'Data peminjaman tidak ditemukan.'], 'code' => 422];
                }

                // Mahasiswa hanya boleh mengembalikan miliknya sendiri.
                $actor = $request->user();

                if (! $actor->isAdmin() && (int) $peminjaman->user_id !== (int) $actor->id) {
                    return ['error' => [
                        'message' => 'Anda tidak berhak mengembalikan peminjaman ini.',
                    ], 'code' => 403];
                }

                if (strtolower((string) $peminjaman->status) !== Peminjaman::STATUS_DISETUJUI) {
                    return ['error' => [
                        'message' => 'Peminjaman belum dapat dikembalikan.',
                    ], 'code' => 422];
                }

                $details = DetailPeminjaman::where('peminjaman_id', $peminjaman->id)->get();

                if ($details->isEmpty()) {
                    return ['error' => [
                        'message' => 'Detail alat pada peminjaman tidak ditemukan.',
                    ], 'code' => 422];
                }

                foreach ($details as $detail) {
                    if ($detail->jumlah < 1) {
                        return ['error' => [
                            'message' => 'Jumlah alat pada peminjaman tidak valid.',
                        ], 'code' => 422];
                    }
                }

                $selesai = Pengembalian::where('peminjaman_id', $peminjaman->id)
                    ->where('status', Pengembalian::STATUS_DISETUJUI)
                    ->exists();

                if ($selesai) {
                    return ['error' => [
                        'message' => 'Alat untuk peminjaman ini sudah dikembalikan.',
                    ], 'code' => 422];
                }

                $menunggu = Pengembalian::where('peminjaman_id', $peminjaman->id)
                    ->where('status', Pengembalian::STATUS_MENUNGGU)
                    ->exists();

                if ($menunggu) {
                    return ['error' => [
                        'message' => 'Pengajuan pengembalian masih menunggu konfirmasi admin.',
                    ], 'code' => 422];
                }

                $row = Pengembalian::create([
                    'peminjaman_id' => $peminjaman->id,
                    'tanggal_pengembalian' => Carbon::parse((string) $request->input('tanggal_pengembalian')),
                    'kondisi' => trim((string) $request->input('kondisi', '')),
                    'catatan' => $this->teksAtauNull($request->input('catatan')),
                    'status' => Pengembalian::STATUS_MENUNGGU,
                ]);

                return ['id' => $row->id];
            });
        } catch (QueryException $exception) {
            // Unique index `pengembalian_pending_unique` yang menolak
            // pengajuan ganda yang lolos cek di atas (kasus konkuren).
            if (! $this->isUniqueViolation($exception)) {
                throw $exception;
            }

            return response()->json([
                'message' => 'Pengajuan pengembalian masih menunggu konfirmasi admin.',
            ], 422);
        }

        if (isset($pengembalian['error'])) {
            return response()->json($pengembalian['error'], $pengembalian['code']);
        }

        return response()->json(['id' => $pengembalian['id']], 201);
    }

    // ============================================================
    // DAFTAR PENGAJUAN PENGEMBALIAN (sisi admin)
    //
    // Parameter query opsional `status`:
    //   - menunggu (default) → pengajuan blm diproses
    //   - riwayat            → sudah disetujui / ditolak
    //   - all                → seluruh pengembalian
    // ============================================================
    public function adminIndex(Request $request): JsonResponse
    {
        if (! $request->user()?->isAdmin()) {
            return $this->tidakDiizinkan();
        }

        $status = (string) $request->query('status', 'menunggu');

        $where = "pg.status = 'menunggu'";

        if ($status === 'riwayat') {
            $where = "pg.status IN ('disetujui', 'ditolak')";
        } elseif ($status === 'all') {
            $where = '1 = 1';
        }

        $rows = DB::select(
            self::ADMIN_SELECT." WHERE $where ORDER BY pg.id DESC",
        );

        $result = [];

        foreach ($rows as $row) {
            $details = DB::select(
                'SELECT dp.id, dp.jumlah, dp.alat_id, a.nama_alat
                 FROM detail_peminjaman dp
                 JOIN alat a ON a.id = dp.alat_id
                 WHERE dp.peminjaman_id = ?',
                [(int) $row->peminjaman_id],
            );

            $result[] = [
                'pengembalian_id' => (int) $row->pengembalian_id,
                'peminjaman_id' => (int) $row->peminjaman_id,
                'tanggal_pengembalian' => $this->formatTanggal($row->tanggal_pengembalian),
                'kondisi' => (string) $row->kondisi,
                'catatan' => $row->catatan,
                'status' => (string) $row->status_pengembalian,
                'status_pengembalian' => (string) $row->status_pengembalian,
                'tanggal_pinjam' => $this->formatTanggal($row->tanggal_pinjam),
                'tanggal_kembali' => $this->formatTanggal($row->tanggal_kembali),
                'status_peminjaman' => (string) $row->status_peminjaman,
                'nama_mahasiswa' => (string) $row->nama_mahasiswa,
                'nim' => $row->nim,
                'detail' => array_map(fn ($d) => [
                    'id' => (int) $d->id,
                    'jumlah' => (int) $d->jumlah,
                    'alat_id' => (int) $d->alat_id,
                    'nama_alat' => (string) $d->nama_alat,
                ], $details),
            ];
        }

        return response()->json($result);
    }

    // ============================================================
    // SETUJUI PENGEMBALIAN → stok dikembalikan (transaksi)
    // ============================================================
    public function setujui(SetujuiPengembalianRequest $request, string $id): JsonResponse
    {
        $outcome = DB::transaction(function () use ($request, $id) {
            $pengembalian = Pengembalian::query()->lockForUpdate()->find((int) $id);

            if (! $pengembalian) {
                return ['error' => ['message' => 'Data pengembalian tidak ditemukan.'], 'code' => 422];
            }

            if ((int) $pengembalian->peminjaman_id !== (int) $request->input('peminjaman_id')) {
                return ['error' => ['message' => 'Data pengembalian tidak cocok.'], 'code' => 422];
            }

            if ($pengembalian->status !== Pengembalian::STATUS_MENUNGGU) {
                return ['error' => ['message' => 'Pengembalian ini sudah diproses.'], 'code' => 422];
            }

            $details = DetailPeminjaman::where('peminjaman_id', $pengembalian->peminjaman_id)
                ->orderBy('id')
                ->get();

            if ($details->isEmpty()) {
                return ['error' => [
                    'message' => 'Detail alat pada peminjaman tidak ditemukan.',
                ], 'code' => 422];
            }

            // Kembalikan stok tepat sejumlah yang dipinjam. `increment`
            // bersifat atomik dan tidak menimpa perubahan stok lain yang
            // terjadi bersamaan. Tidak ada syarat `stok >= jumlah` di sini:
            // stok saat pengembalian boleh saja lebih kecil dari jumlah yang
            // kembali (mis. seluruh stok sedang dipinjam), dan itulah kondisi
            // normal yang harus memulihkan stok.
            foreach ($details as $detail) {
                $affected = DB::table('alat')
                    ->where('id', $detail->alat_id)
                    ->increment('stok', $detail->jumlah);

                if ($affected !== 1) {
                    return ['error' => [
                        'message' => 'Data stok alat tidak konsisten, pengembalian dibatalkan.',
                    ], 'code' => 422];
                }
            }

            $pengembalian->update(['status' => Pengembalian::STATUS_DISETUJUI]);

            // Pengembalian disetujui → peminjaman selesai.
            $peminjaman = Peminjaman::query()
                ->lockForUpdate()
                ->find($pengembalian->peminjaman_id);

            if ($peminjaman) {
                $peminjaman->update(['status' => Peminjaman::STATUS_SELESAI]);
            }

            return null;
        });

        if ($outcome !== null) {
            return response()->json($outcome['error'], $outcome['code']);
        }

        return response()->json(['success' => true]);
    }

    // ============================================================
    // TOLAK PENGEMBALIAN
    // ============================================================
    public function tolak(Request $request, string $id): JsonResponse
    {
        if (! $request->user()?->isAdmin()) {
            return $this->tidakDiizinkan();
        }

        $outcome = DB::transaction(function () use ($id) {
            $pengembalian = Pengembalian::query()->lockForUpdate()->find((int) $id);

            if (! $pengembalian) {
                return ['error' => ['message' => 'Data pengembalian tidak ditemukan.'], 'code' => 422];
            }

            if ($pengembalian->status !== Pengembalian::STATUS_MENUNGGU) {
                return ['error' => ['message' => 'Pengembalian ini sudah diproses.'], 'code' => 422];
            }

            // Status ditolak → kolom penjaga dikosongkan (lihat model).
            $pengembalian->update(['status' => Pengembalian::STATUS_DITOLAK]);

            return null;
        });

        if ($outcome !== null) {
            return response()->json($outcome['error'], $outcome['code']);
        }

        return response()->json(['success' => true]);
    }

    // ============================================================
    // PEMBANTU
    // ============================================================

    private function tidakDiizinkan(): JsonResponse
    {
        return response()->json(
            ['message' => 'Anda tidak berhak mengakses data ini.'],
            403,
        );
    }

    private function teksAtauNull(mixed $value): ?string
    {
        $value = $value === null ? '' : trim((string) $value);

        return $value === '' ? null : $value;
    }

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

    /**
     * Deteksi pelanggaran unique index pada driver apa pun.
     */
    private function isUniqueViolation(QueryException $exception): bool
    {
        $message = Str::lower($exception->getMessage());

        return Str::contains($message, 'unique constraint failed')
            || Str::contains($message, 'duplicate entry')
            || Str::contains($message, 'duplicate key');
    }
}
