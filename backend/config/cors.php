<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS) Configuration
    |--------------------------------------------------------------------------
    |
    | Aplikasi SIPALAB juga bisa dijalankan sebagai Flutter Web, di mana
    | permintaan dikirim dari origin browser (mis. http://localhost:xxxxx).
    | Tanpa CORS, browser akan memblokir respons API.
    |
    | Daftar origin dipisah tanda koma. Nilai '*' mengizinkan semua origin
    | (cocok untuk pengembangan; batasi di produksi).
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie', 'up'],

    'allowed_methods' => ['*'],

    'allowed_origins' => explode(',', (string) env(
        'CORS_ALLOWED_ORIGINS',
        '*',
    )),

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
