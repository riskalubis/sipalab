<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->registerRateLimiters();
    }

    /**
     * Pembatas laju untuk endpoint publik.
     *
     * `sipalab-login` dan `sipalab-register` adalah pengaman lapis pertama;
     * AuthController masih memakai RateLimiter manual per email supaya
     * percobaan login pada satu akun tidak terkunci dari IP lain.
     */
    private function registerRateLimiters(): void
    {
        RateLimiter::for('sipalab-login', function (Request $request) {
            return [
                Limit::perMinute(20)->by('login-ip:'.$request->ip()),
                Limit::perMinute(10)->by('login-email:'.mb_strtolower((string) $request->input('email'))),
            ];
        });

        RateLimiter::for('sipalab-register', function (Request $request) {
            return [
                Limit::perMinute(20)->by('register-ip:'.$request->ip()),
                Limit::perMinute(10)->by('register-email:'.mb_strtolower((string) $request->input('email'))),
            ];
        });

        RateLimiter::for('api', function (Request $request) {
            return Limit::perMinute(180)->by(
                $request->user()?->id !== null
                    ? 'user:'.$request->user()->id
                    : 'ip:'.$request->ip(),
            );
        });
    }
}
