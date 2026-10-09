<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Membatasi akses ke route khusus admin.
 *
 * Karena seluruh route sudah dilindungi `auth:sanctum`, middleware ini
 * hanya perlu memeriksa role. Respond 403 (bukan 401) supaya klien tahu
 * token-nya valid tetapi tidak cukup berwenang.
 */
class EnsureUserIsAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user) {
            return response()->json(['message' => 'Tidak terautentikasi.'], 401);
        }

        if (! $user->isAdmin()) {
            return response()->json(
                ['message' => 'Akses ditolak: endpoint ini khusus admin.'],
                403,
            );
        }

        return $next($request);
    }
}
