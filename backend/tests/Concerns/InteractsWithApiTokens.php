<?php

namespace Tests\Concerns;

use App\Models\User;

/**
 * Helper untuk menguji endpoint yang dilindungi bearer token Sanctum.
 */
trait InteractsWithApiTokens
{
    /**
     * Kirim request berikutnya sebagai $user dengan token Sanctum asli.
     *
     * Catatan: `RequestGuard` menyimpan user yang sudah ter-resolve, dan pada
     * feature test satu proses PHP dipakai untuk banyak request. Karena itu
     * guard perlu di-reset agar request berikutnya memakai token yang baru.
     * Ini murni kebutuhan pengujian — di produksi tiap request berjalan di
     * proses/instance aplikasi sendiri.
     */
    protected function withApiToken(User $user, string $name = 'test'): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($user->createToken($name)->plainTextToken);
    }

    /**
     * Sama seperti [withApiToken], tapi untuk token yang sudah dibuat.
     */
    protected function withRawToken(string $token): static
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($token);
    }
}
