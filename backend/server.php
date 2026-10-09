<?php

/**
 * Router untuk PHP built-in web server.
 *
 * `php artisan serve` biasanya sudah cukup, tetapi pada beberapa instalasi
 * PHP untuk Windows (Herd/PHP CLI) perintahnya gagal membuka socket. Berkas
 * ini adalah router standar Laravel dengan path absolut, sehingga bisa dipakai
 * melalui:
 *
 *     composer serve
 *
 * atau:
 *
 *     php -S 0.0.0.0:8000 -t public server.php
 */
$publicPath = __DIR__.'/public';

$uri = urldecode(
    parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?? '/'
);

// Beri kesempatan server built-in melayani file statis (CSS, gambar, dll.).
if ($uri !== '/' && file_exists($publicPath.$uri)) {
    return false;
}

// Semua request lain diteruskan ke front controller Laravel.
require_once $publicPath.'/index.php';
