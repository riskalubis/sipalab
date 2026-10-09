<?php

use App\Http\Controllers\Api\AlatController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\KategoriController;
use App\Http\Controllers\Api\PeminjamanController;
use App\Http\Controllers\Api\PengembalianController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — SIPALAB
|--------------------------------------------------------------------------
|
| Autentikasi memakai Laravel Sanctum. Klien (Flutter) mengirim header
| `Authorization: Bearer <token>`; token diperoleh dari POST /api/login.
|
| Endpoint publik sengaja dipertahankan agar aplikasi Flutter bisa
| menjalankan probe koneksi & pendaftaran sebelum login:
|   GET  /api/health   → health check
|   GET  /api/kategori → dipakai `ApiService.testConnection()`
|   POST /api/login, POST /api/register
|   GET  /api/users/check-email
|
*/

// ============================================================
// HEALTH CHECK (publik)
// ============================================================
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'app' => config('app.name'),
    ]);
})->name('api.health');

// ============================================================
// AUTH & USER (publik)
// ============================================================
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:sipalab-login');
Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:sipalab-register');
Route::get('/users/check-email', [AuthController::class, 'checkEmail'])->middleware('throttle:30,1');

// ============================================================
// KATEGORI
// ============================================================
// GET /kategori tetap publik: dipakai Flutter sebagai probe koneksi.
Route::get('/kategori', [KategoriController::class, 'index']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/users/{id}', [AuthController::class, 'show']);
    Route::put('/users/update', [AuthController::class, 'update']);
    Route::put('/users/foto', [AuthController::class, 'updateFoto']);
    Route::put('/users/password', [AuthController::class, 'updatePassword']);
    Route::put('/users/admin/password', [AuthController::class, 'updateAdminPassword']);

    // ========================================================
    // KATEGORI (tulis)
    // ========================================================
    Route::post('/kategori', [KategoriController::class, 'store'])->middleware('role:admin');

    // ========================================================
    // ALAT
    // ========================================================
    Route::get('/alat', [AlatController::class, 'index']);
    Route::get('/alat/{id}/stok-tersedia', [AlatController::class, 'stokTersedia']);
    Route::get('/alat/{id}', [AlatController::class, 'show']);
    Route::post('/alat', [AlatController::class, 'store'])->middleware('role:admin');
    Route::put('/alat/{id}', [AlatController::class, 'update'])->middleware('role:admin');
    Route::delete('/alat/{id}', [AlatController::class, 'destroy'])->middleware('role:admin');

    // ========================================================
    // PEMINJAMAN
    // ========================================================
    Route::post('/peminjaman', [PeminjamanController::class, 'store']);
    Route::get('/peminjaman/riwayat/{userId}', [PeminjamanController::class, 'riwayat']);
    Route::get('/peminjaman/aktif/{userId}', [PeminjamanController::class, 'aktif']);
    Route::get('/peminjaman/notifikasi-mahasiswa/{userId}', [PeminjamanController::class, 'notifikasiMahasiswa']);
    Route::get('/peminjaman/admin', [PeminjamanController::class, 'adminIndex'])->middleware('role:admin');
    Route::get('/peminjaman/{id}/detail', [PeminjamanController::class, 'show']);
    Route::put('/peminjaman/{id}/status', [PeminjamanController::class, 'updateStatus'])->middleware('role:admin');

    // ========================================================
    // PENGEMBALIAN
    // ========================================================
    Route::get('/pengembalian', [PengembalianController::class, 'index']);
    Route::get('/pengembalian/admin', [PengembalianController::class, 'adminIndex'])->middleware('role:admin');
    Route::post('/pengembalian', [PengembalianController::class, 'store']);
    Route::put('/pengembalian/{id}/setujui', [PengembalianController::class, 'setujui'])->middleware('role:admin');
    Route::put('/pengembalian/{id}/tolak', [PengembalianController::class, 'tolak'])->middleware('role:admin');

    // ========================================================
    // DASHBOARD & LAPORAN
    // ========================================================
    Route::get('/home/admin', [DashboardController::class, 'home'])->middleware('role:admin');
    Route::get('/laporan', [DashboardController::class, 'laporan'])->middleware('role:admin');
});
