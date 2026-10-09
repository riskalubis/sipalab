<?php

use App\Http\Middleware\EnsureUserIsAdmin;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Tanpa callback ini, Authenticate mencoba `route('login')` yang tidak
        // ada di proyek API → RouteNotFoundException (500). Kembalikan null
        // agar autentikasi gagal sebagai AuthenticationException → JSON 401.
        $middleware->redirectGuestsTo(
            fn (Request $request): ?string => $request->is('api/*') ? null : '/',
        );

        // Route API memakai alias `role:admin` untuk membatasi akses.
        $middleware->alias([
            'role' => EnsureUserIsAdmin::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // API tidak punya halaman login, jadi permintaan tanpa token harus
        // dibalas JSON 401 — bukan redirect (yang akan menjadi 500 pada
        // klien non-browser seperti Flutter/Postman).
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*') || $request->expectsJson()) {
                return response()->json(
                    ['message' => 'Tidak terautentikasi. Silakan login kembali.'],
                    401,
                );
            }

            return null;
        });
    })->create();
