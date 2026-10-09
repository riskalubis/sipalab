<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Alat;
use App\Models\Peminjaman;
use App\Support\StokHelper;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    // ============================================================
    // DASHBOARD ADMIN
    // ============================================================
    public function home(Request $request): JsonResponse
    {
        if (! $this->admin($request)) {
            return $this->tidakDiizinkan();
        }

        $peminjamanTerbaru = DB::select(
            "SELECT p.id, u.nama, a.nama_alat, p.status, p.tanggal_pinjam
             FROM peminjaman p
             JOIN users u ON u.id = p.user_id
             JOIN detail_peminjaman dp ON dp.peminjaman_id = p.id
             JOIN alat a ON a.id = dp.alat_id
             WHERE p.status = 'menunggu'
             ORDER BY p.id DESC
             LIMIT 5",
        );

        $notifPeminjaman = DB::select(
            "SELECT p.id, u.nama
             FROM peminjaman p
             JOIN users u ON u.id = p.user_id
             WHERE p.status = 'menunggu'
             ORDER BY p.id DESC",
        );

        $notifPengembalian = DB::select(
            "SELECT pg.id, u.nama
             FROM pengembalian pg
             JOIN peminjaman p ON p.id = pg.peminjaman_id
             JOIN users u ON u.id = p.user_id
             WHERE pg.status = 'menunggu'
             ORDER BY pg.id DESC",
        );

        $peminjamanTerbaru = array_map(function ($row) {
            return [
                'id' => (int) $row->id,
                'nama' => (string) $row->nama,
                'nama_alat' => (string) $row->nama_alat,
                'status' => (string) $row->status,
                'tanggal_pinjam' => $this->formatTanggal($row->tanggal_pinjam),
            ];
        }, $peminjamanTerbaru);

        $notifPeminjaman = array_map(fn ($row) => [
            'id' => (int) $row->id,
            'nama' => (string) $row->nama,
        ], $notifPeminjaman);

        $notifPengembalian = array_map(fn ($row) => [
            'id' => (int) $row->id,
            'nama' => (string) $row->nama,
        ], $notifPengembalian);

        return response()->json([
            'total_alat' => Alat::count(),
            'stok_tersedia' => (int) Alat::sum('stok'),
            'dipinjam' => StokHelper::sedangDipinjam(),
            'menunggu' => Peminjaman::where('status', 'menunggu')->count(),
            'peminjaman_terbaru' => $peminjamanTerbaru,
            'notifikasi_peminjaman' => $notifPeminjaman,
            'notifikasi_pengembalian' => $notifPengembalian,
        ]);
    }

    // ============================================================
    // LAPORAN ADMIN
    // ============================================================
    public function laporan(Request $request): JsonResponse
    {
        if (! $this->admin($request)) {
            return $this->tidakDiizinkan();
        }

        $dikembalikan = DB::selectOne(
            "SELECT COUNT(*) AS total FROM pengembalian WHERE status = 'disetujui'",
        );

        $ditolak = DB::selectOne(
            "SELECT COUNT(*) AS total FROM peminjaman WHERE status = 'ditolak'",
        );

        return response()->json([
            'total_alat' => Alat::count(),
            'stok_alat' => (int) Alat::sum('stok'),
            'dipinjam' => StokHelper::sedangDipinjam(),
            'menunggu' => Peminjaman::where('status', 'menunggu')->count(),
            'dikembalikan' => (int) ($dikembalikan->total ?? 0),
            'ditolak' => (int) ($ditolak->total ?? 0),
        ]);
    }

    // ============================================================
    // PEMBANTU
    // ============================================================

    private function admin(Request $request): bool
    {
        return (bool) $request->user()?->isAdmin();
    }

    private function tidakDiizinkan(): JsonResponse
    {
        return response()->json(
            ['message' => 'Anda tidak berhak mengakses data ini.'],
            403,
        );
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
}
