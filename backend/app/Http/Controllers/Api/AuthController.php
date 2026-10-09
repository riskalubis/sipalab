<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Requests\UpdateAdminPasswordRequest;
use App\Http\Requests\UpdateFotoRequest;
use App\Http\Requests\UpdatePasswordRequest;
use App\Http\Requests\UpdateProfileRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    /** Batas percobaan login per menit (kunci: email + IP). */
    private const LOGIN_MAX_ATTEMPTS = 5;

    /** Lama kunci login dikunci (detik). */
    private const LOGIN_DECAY_SECONDS = 60;

    /** Batas pendaftaran akun baru per menit (kunci: IP). */
    private const REGISTER_MAX_ATTEMPTS = 10;

    /** Nama token yang disimpan aplikasi Flutter. */
    private const TOKEN_NAME = 'sipalab-mobile';

    // ============================================================
    // LOGIN
    // ============================================================
    // Mengikuti kontrak lama: status 'ok', 'email_not_found', atau
    // 'wrong_password', dengan data user + token bearer dikembalikan
    // (password tetap disembunyikan oleh cast `hidden`).
    public function login(LoginRequest $request): JsonResponse
    {
        $email = Str::lower(trim((string) $request->input('email')));
        $password = (string) $request->input('password');

        $throttleKey = $this->throttleKey('login', $email, $request);

        if (RateLimiter::tooManyAttempts($throttleKey, self::LOGIN_MAX_ATTEMPTS)) {
            $seconds = RateLimiter::availableIn($throttleKey);

            return response()->json([
                'status' => 'throttled',
                'message' => "Terlalu banyak percobaan login. Coba lagi dalam {$seconds} detik.",
            ], 429, ['Retry-After' => (string) $seconds]);
        }

        $user = User::where('email', $email)->first();

        if (! $user) {
            RateLimiter::hit($throttleKey, self::LOGIN_DECAY_SECONDS);

            return response()->json(['status' => 'email_not_found']);
        }

        if (! Hash::check($password, (string) $user->password)) {
            RateLimiter::hit($throttleKey, self::LOGIN_DECAY_SECONDS);

            return response()->json(['status' => 'wrong_password']);
        }

        RateLimiter::clear($throttleKey);

        // Satu token aktif per perangkat login; token lama dicabut supaya
        // tidak menumpuk setiap kali pengguna login.
        $user->tokens()->where('name', self::TOKEN_NAME)->delete();

        $token = $user->createToken(self::TOKEN_NAME)->plainTextToken;

        $userPayload = $user->toArray();
        $userPayload['token'] = $token;

        return response()->json([
            'status' => 'ok',
            'token_type' => 'Bearer',
            'token' => $token,
            'user' => $userPayload,
        ]);
    }

    // ============================================================
    // REGISTER MAHASISWA BARU
    // ============================================================
    public function register(RegisterRequest $request): JsonResponse
    {
        $throttleKey = $this->throttleKey('register', (string) $request->input('email'), $request);

        if (RateLimiter::tooManyAttempts($throttleKey, self::REGISTER_MAX_ATTEMPTS)) {
            $seconds = RateLimiter::availableIn($throttleKey);

            return response()->json([
                'message' => "Terlalu banyak percobaan pendaftaran. Coba lagi dalam {$seconds} detik.",
            ], 429, ['Retry-After' => (string) $seconds]);
        }

        RateLimiter::hit($throttleKey, self::LOGIN_DECAY_SECONDS);

        // Role dipaksa 'mahasiswa' oleh RegisterRequest::payload().
        $user = User::create($request->payload());

        return response()->json($user->toArray(), 201);
    }

    // ============================================================
    // CEK EMAIL TERDAFTAR?
    // ============================================================
    public function checkEmail(Request $request): JsonResponse
    {
        $email = Str::lower(trim((string) $request->query('email', '')));

        $registered = $email !== '' && User::where('email', $email)->exists();

        return response()->json(['registered' => $registered]);
    }

    // ============================================================
    // DETAIL USER BY ID
    // ============================================================
    public function show(string $id): JsonResponse
    {
        $actor = request()->user();

        if (! $actor) {
            return response()->json(['message' => 'Tidak terautentikasi.'], 401);
        }

        if (! $actor->isAdmin() && (int) $id !== (int) $actor->id) {
            return response()->json(
                ['message' => 'Anda tidak berhak mengakses data pengguna lain.'],
                403,
            );
        }

        $user = User::find((int) $id);

        if (! $user) {
            return response()->json(
                ['message' => 'Data pengguna tidak ditemukan.'],
                404,
            );
        }

        return response()->json($user->toArray());
    }

    // ============================================================
    // UPDATE PROFIL (nama, nim, kelas, no_hp, email)
    // ============================================================
    public function update(UpdateProfileRequest $request): JsonResponse
    {
        $user = User::find((int) $request->input('id'));

        if (! $user) {
            return response()->json(
                ['message' => 'Data pengguna tidak ditemukan.'],
                404,
            );
        }

        $user->update($request->payload());

        return response()->json($user->fresh()->toArray());
    }

    // ============================================================
    // UPDATE FOTO PROFIL (email, foto)
    // ============================================================
    public function updateFoto(UpdateFotoRequest $request): JsonResponse
    {
        $user = User::where('email', Str::lower(trim((string) $request->input('email'))))->first();

        if (! $user) {
            return response()->json(
                ['message' => 'Data pengguna tidak ditemukan.'],
                404,
            );
        }

        $user->update(['foto' => $request->input('foto')]);

        return response()->json(['success' => true]);
    }

    // ============================================================
    // GANTI PASSWORD (email, password_lama, password_baru)
    // ============================================================
    public function updatePassword(UpdatePasswordRequest $request): JsonResponse
    {
        $user = User::where('email', Str::lower(trim((string) $request->input('email'))))->first();

        if (! $user) {
            return response()->json(
                ['message' => 'Data pengguna tidak ditemukan.'],
                404,
            );
        }

        if (! Hash::check((string) $request->input('password_lama'), (string) $user->password)) {
            return response()->json(
                ['message' => 'Password lama salah.'],
                422,
            );
        }

        $user->update(['password' => (string) $request->input('password_baru')]);

        // Password berubah → cabut token lama, tapi biarkan token yang sedang
        // dipakai (agar aplikasi tidak langsung terlempar keluar).
        $this->revokeOtherTokens($user, $request);

        return response()->json(['success' => true]);
    }

    // ============================================================
    // GANTI PASSWORD ADMIN (password_lama, password_baru)
    // ============================================================
    public function updateAdminPassword(UpdateAdminPasswordRequest $request): JsonResponse
    {
        $admin = $request->user();

        if (! $admin || ! $admin->isAdmin()) {
            return response()->json(
                ['message' => 'Hanya admin yang dapat mengganti password admin.'],
                403,
            );
        }

        if (! Hash::check((string) $request->input('password_lama'), (string) $admin->password)) {
            return response()->json(
                ['message' => 'Kata sandi lama salah.'],
                422,
            );
        }

        $admin->update(['password' => (string) $request->input('password_baru')]);

        $this->revokeOtherTokens($admin, $request);

        return response()->json(['success' => true]);
    }

    // ============================================================
    // LOGOUT — cabut token yang sedang dipakai
    // ============================================================
    public function logout(Request $request): JsonResponse
    {
        $token = $request->user()?->currentAccessToken();

        if ($token !== null && method_exists($token, 'delete')) {
            $token->delete();
        }

        return response()->json(['success' => true]);
    }

    // ============================================================
    // BANTUAN
    // ============================================================

    /**
     * Cabut semua personal access token milik user kecuali token yang sedang
     * dipakai request ini. Dipanggil setelah password berubah supaya sesi
     * di perangkat lain tidak bisa tetap aktif.
     */
    private function revokeOtherTokens(User $user, Request $request): void
    {
        $current = $user->currentAccessToken();

        $query = $user->tokens();

        if ($current !== null && isset($current->id)) {
            $query->where('id', '!=', $current->id);
        }

        $query->delete();
    }

    private function throttleKey(string $action, string $email, Request $request): string
    {
        return 'sipalab:'.$action.':'.Str::lower($email).'|'.$request->ip();
    }
}
