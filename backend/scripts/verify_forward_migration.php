<?php

/*
|--------------------------------------------------------------------------
| Uji migrasi maju (forward migration)
|--------------------------------------------------------------------------
|
| Script ini mensimulasikan database SIPALAB versi LAMA yang sudah terisi,
| lalu menjalankan migrasi baru di atasnya dan memastikan:
|   - password teks biasa menjadi hash (tanpa double-hash)
|   - tanggal ISO string menjadi kolom DATETIME
|   - kategori & detail duplikat digabung, unique index terpasang
|   - stok negatif tidak mungkin lagi
|
| Pakai: php scripts/verify_forward_migration.php
|
*/

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;

$root = dirname(__DIR__);
$dbPath = $root.'/database/forward_migration_check.sqlite';

if (file_exists($dbPath)) {
    unlink($dbPath);
}
touch($dbPath);

require $root.'/vendor/autoload.php';

$app = require $root.'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

config([
    'database.default' => 'sqlite_check',
    'database.connections.sqlite_check' => [
        'driver' => 'sqlite',
        'database' => $dbPath,
        'prefix' => '',
        'foreign_key_constraints' => true,
    ],
]);

DB::purge('sqlite_check');
DB::setDefaultConnection('sqlite_check');

$schema = Schema::connection('sqlite_check');

echo "== 1. Bangun skema LAMA ==\n";

$schema->create('users', function (Blueprint $table) {
    $table->id();
    $table->string('nama');
    $table->string('nim')->nullable();
    $table->string('kelas')->nullable();
    $table->string('email')->unique();
    $table->string('password');
    $table->string('role')->default('mahasiswa');
    $table->text('foto')->nullable();
});

$schema->create('kategori', function (Blueprint $table) {
    $table->id();
    $table->string('nama_kategori');
});

$schema->create('alat', function (Blueprint $table) {
    $table->id();
    $table->unsignedBigInteger('kategori_id');
    $table->string('nama_alat');
    $table->integer('stok')->default(0);
    $table->string('kondisi');
    $table->text('deskripsi')->nullable();
    $table->text('gambar')->nullable();
});

$schema->create('peminjaman', function (Blueprint $table) {
    $table->id();
    $table->unsignedBigInteger('user_id');
    $table->string('tanggal_pinjam');
    $table->string('tanggal_kembali');
    $table->text('keperluan');
    $table->string('status')->default('menunggu');
});

$schema->create('detail_peminjaman', function (Blueprint $table) {
    $table->id();
    $table->unsignedBigInteger('peminjaman_id');
    $table->unsignedBigInteger('alat_id');
    $table->integer('jumlah');
});

$schema->create('pengembalian', function (Blueprint $table) {
    $table->id();
    $table->unsignedBigInteger('peminjaman_id');
    $table->string('tanggal_pengembalian');
    $table->string('kondisi');
    $table->text('catatan')->nullable();
    $table->string('status')->default('menunggu');
});

echo "   skema lama dibuat\n";

echo "\n== 2. Isi dengan data 'kusam' (duplikat, plaintext, ISO string) ==\n";

$db = DB::connection('sqlite_check');

$db->table('users')->insert([
    ['nama' => 'Admin Lama', 'nim' => 'ADM001', 'kelas' => null, 'email' => 'admin@labkamp.com', 'password' => 'admkamp', 'role' => 'admin', 'foto' => null],
    // Password SUDAH di-hash (harus tidak di-hash ulang).
    ['nama' => 'Budi', 'nim' => '221011234', 'kelas' => '23TI-01', 'email' => 'budi@labkamp.com', 'password' => '$2y$12$'.str_repeat('a', 53), 'role' => 'mahasiswa', 'foto' => null],
]);

// Kategori duplikat (beda kapitalisasi).
$db->table('kategori')->insert([
    ['nama_kategori' => 'Elektronika'],
    ['nama_kategori' => 'elektronika'],
]);

$db->table('alat')->insert([
    ['kategori_id' => 2, 'nama_alat' => 'Multimeter', 'stok' => -5, 'kondisi' => 'Baik', 'deskripsi' => null, 'gambar' => null],
]);

// Tanggal dalam format ISO-8601 (persis seperti dikirim Flutter).
$db->table('peminjaman')->insert([
    ['user_id' => 2, 'tanggal_pinjam' => '2026-09-18T00:00:00.000', 'tanggal_kembali' => '2026-09-21T00:00:00.000', 'keperluan' => 'Praktikum', 'status' => 'disetujui'],
    ['user_id' => 2, 'tanggal_pinjam' => 'bukan tanggal', 'tanggal_kembali' => '', 'keperluan' => 'Rusak', 'status' => 'menunggu'],
]);

// Detail duplikat untuk alat yang sama pada peminjaman yang sama.
$db->table('detail_peminjaman')->insert([
    ['peminjaman_id' => 1, 'alat_id' => 1, 'jumlah' => 2],
    ['peminjaman_id' => 1, 'alat_id' => 1, 'jumlah' => 3],
]);

// Dua pengembalian menunggu untuk peminjaman yang sama (harus digabung).
$db->table('pengembalian')->insert([
    ['peminjaman_id' => 1, 'tanggal_pengembalian' => '2026-09-21T09:30:00.000', 'kondisi' => 'Baik', 'catatan' => null, 'status' => 'menunggu'],
    ['peminjaman_id' => 1, 'tanggal_pengembalian' => '2026-09-21T10:00:00.000', 'kondisi' => 'Baik', 'catatan' => null, 'status' => 'menunggu'],
]);

echo "   data kusam dibuat (stok -5, kategori duplikat, detail duplikat, 2 pengembalian menunggu)\n";

echo "\n== 3. Jalankan migrasi baru (hanya 2026_09_25_*) ==\n";

$runner = new class($root)
{
    public function __construct(private string $root) {}

    public function run(): int
    {
        $migrator = app('migrator');

        $files = glob($this->root.'/database/migrations/2026_09_25_*.php');
        sort($files);

        foreach ($files as $file) {
            $migration = require $file;
            $name = basename($file, '.php');

            echo "   -> {$name}\n";
            $migration->up();
        }

        return 0;
    }
};

$runner->run();

echo "\n== 4. Verifikasi hasil ==\n";

$fail = 0;

function check(string $label, bool $ok, string $detail = ''): void
{
    global $fail;

    echo ($ok ? '   [OK]   ' : '   [FAIL] ').$label.($detail !== '' ? ' — '.$detail : '')."\n";

    if (! $ok) {
        $fail++;
    }
}

// Password
$admin = $db->table('users')->where('email', 'admin@labkamp.com')->first();
$budi = $db->table('users')->where('email', 'budi@labkamp.com')->first();

check('password lama (plaintext) di-hash', password_get_info($admin->password)['algoName'] === 'bcrypt');
check('password lama benar-benar bisa diverifikasi', Hash::check('admkamp', $admin->password));
check('password yang sudah di-hash tidak di-hash ulang', $budi->password === '$2y$12$'.str_repeat('a', 53));

// Tanggal
$row = $db->table('peminjaman')->find(1);
check('tanggal ISO dinormalkan', $row->tanggal_pinjam === '2026-09-18 00:00:00', $row->tanggal_pinjam);
check('tanggal kembali dinormalkan', $row->tanggal_kembali === '2026-09-21 00:00:00', $row->tanggal_kembali);
check('tanggal rusak diperbaiki', (bool) $db->table('peminjaman')->find(2)->tanggal_pinjam);

$cols = $db->select("PRAGMA table_info('peminjaman')");
$types = [];
foreach ($cols as $c) {
    $types[$c->name] = $c->type;
}
check('tanggal_pinjam jadi DATETIME', strtolower($types['tanggal_pinjam']) === 'datetime', $types['tanggal_pinjam']);
check('tanggal_kembali jadi DATETIME', strtolower($types['tanggal_kembali']) === 'datetime', $types['tanggal_kembali']);
check('kolom catatan ditambahkan', array_key_exists('catatan', $types));

// Kategori
check('kategori duplikat digabung', $db->table('kategori')->count() === 1, 'sisa='.$db->table('kategori')->count());
$alatKategori = $db->table('alat')->first()->kategori_id;
check('alat diarahkan ke kategori sisa', $alatKategori === 1, 'kategori_id='.$alatKategori);

// Detail
$details = $db->table('detail_peminjaman')->where('peminjaman_id', 1)->get();
check('detail duplikat digabung', $details->count() === 1, 'sisa='.$details->count());
check('jumlah detail digabung (2+3)', (int) $details->first()->jumlah === 5, 'jumlah='.$details->first()->jumlah);

// Pengembalian
check('hanya satu pengembalian menunggu', $db->table('pengembalian')->where('status', 'menunggu')->count() === 1);
check('kolom penjaga terisi', $db->table('pengembalian')->where('status', 'menunggu')->first()->pending_peminjaman_id === 1);

// Stok
$stok = $db->table('alat')->first()->stok;
check('stok negatif dikoreksi menjadi 0', (int) $stok === 0, 'stok='.$stok);

$inserted = false;
try {
    $db->table('alat')->insert([
        'kategori_id' => 1, 'nama_alat' => 'Uji', 'stok' => -1, 'kondisi' => 'Baik',
    ]);
} catch (Throwable $e) {
    $inserted = true;
}
check('CHECK constraint menolak stok negatif', $inserted);

$insertedNeg = false;
try {
    $db->table('pengembalian')->insert([
        'peminjaman_id' => 1, 'tanggal_pengembalian' => '2026-09-25 00:00:00',
        'kondisi' => 'Baik', 'status' => 'menunggu', 'pending_peminjaman_id' => 1,
    ]);
} catch (Throwable $e) {
    $insertedNeg = true;
}
check('unique constraint menolak pengembalian menunggu ganda', $insertedNeg);

// Rollback
echo "\n== 5. Uji rollback (down) ==\n";
$files = glob($root.'/database/migrations/2026_09_25_*.php');
rsort($files);
foreach ($files as $file) {
    $migration = require $file;
    $migration->down();
}
echo "   down() selesai tanpa error\n";

// Tutup koneksi dulu (SQLite mengunci file di Windows).
DB::purge('sqlite_check');

@unlink($dbPath);

echo "\n== HASIL: ".($fail === 0 ? 'SEMUA LULUS' : "$fail KEGAGALAN")." ==\n";

exit($fail === 0 ? 0 : 1);
