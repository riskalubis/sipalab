<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

/**
 * Versi lama SIPALAB menyimpan password sebagai teks biasa. Migrasi ini
 * mengubahnya menjadi hash bcrypt.
 *
 * Aman terhadap data yang sudah berupa hash: `password_get_info()` melaporkan
 * algo `null`/`0` untuk teks biasa, sehingga password yang sudah di-hash
 * tidak akan di-hash dua kali.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('users')) {
            return;
        }

        $hashed = 0;

        DB::table('users')
            ->select('id', 'password')
            ->orderBy('id')
            ->chunkById(200, function ($users) use (&$hashed) {
                foreach ($users as $user) {
                    $plain = (string) $user->password;

                    if ($plain === '' || ! $this->looksLikePlaintext($plain)) {
                        continue;
                    }

                    DB::table('users')
                        ->where('id', $user->id)
                        ->update(['password' => Hash::make($plain)]);

                    $hashed++;
                }
            });

        if ($hashed > 0) {
            Log::info(
                "SIPALAB migration: {$hashed} password users diubah dari teks biasa menjadi hash."
            );
        }
    }

    public function down(): void
    {
        // Password yang sudah di-hash tidak dapat dikembalikan menjadi teks
        // biasa, jadi tidak ada yang perlu dibatalkan.
    }

    /**
     * True bila nilai belum pernah di-hash (algo `null` pada PHP 8, atau
     * algo `0` pada PHP < 8 / driver yang mengembalikan nilai legacy).
     */
    private function looksLikePlaintext(string $value): bool
    {
        $info = password_get_info($value);

        if (! is_array($info)) {
            return true;
        }

        $algo = $info['algo'] ?? null;

        return $algo === null || $algo === 0 || $algo === '0' || $algo === '';
    }
};
