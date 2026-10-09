<?php

namespace Database\Seeders;

use App\Models\Alat;
use App\Models\DetailPeminjaman;
use App\Models\Kategori;
use App\Models\Peminjaman;
use App\Models\Pengembalian;
use App\Models\User;
use App\Support\StokHelper;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

/**
 * Seeder demo SIPALAB.
 *
 * Sifat penting: **aman dijalankan berulang kali** (idempoten). Semua data
 * dicocokkan lewat `firstOrCreate` / `updateOrCreate` memakai kunci alami,
 * dan stok alat dihitung ulang dari transaksi yang benar-benar ada,
 * sehingga hasil `db:seed` selalu sama.
 *
 * Akun demo (semua password minimal 6 karakter, sesuai aturan validasi):
 *
 *   Admin      admin@labkamp.com  / admkamp
 *   Mahasiswa  budi@labkamp.com   / mhs12345
 *   Mahasiswa  siti@labkamp.com   / mhs12345
 *   Mahasiswa  andi@labkamp.com   / mhs12345
 */
class DatabaseSeeder extends Seeder
{
    /**
     * Data alat: nama => [kategori, stok awal, kondisi, deskripsi].
     *
     * @var array<string, array{0: string, 1: int, 2: string, 3: string}>
     */
    private const DAFTAR_ALAT = [
        'Multimeter Digital' => ['Elektronika', 10, 'Baik', 'Alat yang digunakan untuk mengukur tegangan, arus, dan resistansi.'],
        'Oscilloscope' => ['Elektronika', 5, 'Baik', 'Alat untuk mengamati dan mengukur bentuk gelombang sinyal listrik.'],
        'Power Supply DC' => ['Elektronika', 6, 'Baik', 'Perangkat untuk menyediakan sumber tegangan DC pada kegiatan praktikum.'],
        'Solder' => ['Elektronika', 8, 'Baik', 'Alat untuk menyolder komponen elektronik.'],
        'Soldering Station' => ['Elektronika', 4, 'Baik', 'Perangkat solder dengan pengaturan suhu untuk kegiatan praktikum.'],

        'Router' => ['Jaringan', 5, 'Baik', 'Perangkat jaringan untuk menghubungkan dan mengatur lalu lintas jaringan.'],
        'Switch' => ['Jaringan', 6, 'Baik', 'Perangkat untuk menghubungkan beberapa perangkat dalam jaringan.'],
        'Access Point' => ['Jaringan', 4, 'Baik', 'Perangkat untuk menyediakan akses jaringan nirkabel.'],
        'Kabel LAN' => ['Jaringan', 20, 'Baik', 'Kabel jaringan untuk menghubungkan perangkat komputer dan jaringan.'],
        'LAN Tester' => ['Jaringan', 8, 'Baik', 'Alat untuk menguji koneksi dan susunan kabel LAN.'],
        'Tang Crimping' => ['Jaringan', 7, 'Baik', 'Alat untuk memasang konektor RJ45 pada kabel jaringan.'],

        'Proyektor' => ['Pendukung', 3, 'Baik', 'Perangkat untuk menampilkan materi praktikum ke layar.'],
        'Webcam' => ['Pendukung', 6, 'Baik', 'Perangkat kamera untuk mendukung kegiatan praktikum.'],
        'Kabel HDMI' => ['Pendukung', 10, 'Baik', 'Kabel untuk menghubungkan perangkat ke layar atau proyektor.'],
        'Hard Disk Eksternal' => ['Pendukung', 5, 'Baik', 'Media penyimpanan eksternal untuk mendukung kegiatan praktikum.'],
    ];

    public function run(): void
    {
        $users = $this->seedUsers();
        $kategori = $this->seedKategori();
        $alat = $this->seedAlat($kategori);

        $this->seedTransaksi($users, $alat);

        $this->selaraskanStok($alat);
    }

    // ============================================================
    // PENGGUNA
    // ============================================================

    /**
     * @return array<string, User>
     */
    private function seedUsers(): array
    {
        $daftar = [
            'admin' => [
                'nama' => 'Admin Laboratorium',
                'nim' => 'ADM001',
                'kelas' => null,
                'no_hp' => '081200000001',
                'email' => 'admin@labkamp.com',
                'password' => 'admkamp',
                'role' => 'admin',
            ],
            'budi' => [
                'nama' => 'Budi Santoso',
                'nim' => '221011234',
                'kelas' => '23TI-01',
                'no_hp' => '081234567890',
                'email' => 'budi@labkamp.com',
                'password' => 'mhs12345',
                'role' => 'mahasiswa',
            ],
            'siti' => [
                'nama' => 'Siti Rahayu',
                'nim' => '221011235',
                'kelas' => '23TI-02',
                'no_hp' => '081234567891',
                'email' => 'siti@labkamp.com',
                'password' => 'mhs12345',
                'role' => 'mahasiswa',
            ],
            'andi' => [
                'nama' => 'Andi Pratama',
                'nim' => '221011236',
                'kelas' => '22DKV-01',
                'no_hp' => '081234567892',
                'email' => 'andi@labkamp.com',
                'password' => 'mhs12345',
                'role' => 'mahasiswa',
            ],
        ];

        $users = [];

        foreach ($daftar as $key => $attributes) {
            $users[$key] = User::updateOrCreate(
                ['email' => $attributes['email']],
                [
                    'nama' => $attributes['nama'],
                    'nim' => $attributes['nim'],
                    'kelas' => $attributes['kelas'],
                    'no_hp' => $attributes['no_hp'],
                    // Cast `hashed` pada model User akan mem-bcrypt nilai ini.
                    'password' => $attributes['password'],
                    'role' => $attributes['role'],
                ],
            );
        }

        return $users;
    }

    // ============================================================
    // KATEGORI & ALAT
    // ============================================================

    /**
     * @return array<string, Kategori>
     */
    private function seedKategori(): array
    {
        $daftar = ['Elektronika', 'Jaringan', 'Pendukung'];

        $kategori = [];

        foreach ($daftar as $nama) {
            $kategori[$nama] = Kategori::firstOrCreate(['nama_kategori' => $nama]);
        }

        return $kategori;
    }

    /**
     * @param  array<string, Kategori>  $kategori
     * @return array<string, Alat> key = nama alat
     */
    private function seedAlat(array $kategori): array
    {
        $alat = [];

        foreach (self::DAFTAR_ALAT as $nama => [$kategoriNama, $stok, $kondisi, $deskripsi]) {
            $alat[$nama] = Alat::updateOrCreate(
                ['kategori_id' => $kategori[$kategoriNama]->id, 'nama_alat' => $nama],
                [
                    'stok' => $stok,
                    'kondisi' => $kondisi,
                    'deskripsi' => $deskripsi,
                    'gambar' => '',
                ],
            );
        }

        return $alat;
    }

    // ============================================================
    // TRANSAKSI CONTOH
    // ============================================================

    /**
     * @param  array<string, User>  $users
     * @param  array<string, Alat>  $alat
     */
    private function seedTransaksi(array $users, array $alat): void
    {
        $today = now()->startOfDay();

        // --- Menunggu persetujuan admin ----------------------------
        $this->peminjaman([
            'user_id' => $users['budi']->id,
            'tanggal_pinjam' => $today->copy(),
            'tanggal_kembali' => $today->copy()->addDays(3),
            'keperluan' => 'Praktikum Elektronika Dasar - Modul Pengukuran',
            'catatan' => 'Pengajuan yang menunggu persetujuan admin.',
            'status' => Peminjaman::STATUS_MENUNGGU,
        ], [
            'Multimeter Digital' => 2,
            'Kabel LAN' => 3,
        ], $alat);

        $this->peminjaman([
            'user_id' => $users['andi']->id,
            'tanggal_pinjam' => $today->copy()->addDay(),
            'tanggal_kembali' => $today->copy()->addDays(2),
            'keperluan' => 'Konfigurasi Jaringan Laboratorium',
            'catatan' => 'Pengajuan kedua yang menunggu persetujuan admin.',
            'status' => Peminjaman::STATUS_MENUNGGU,
        ], ['Router' => 1], $alat);

        // --- Disetujui & masih dipinjam ----------------------------
        $this->peminjaman([
            'user_id' => $users['budi']->id,
            'tanggal_pinjam' => $today->copy()->subDays(2),
            'tanggal_kembali' => $today->copy()->addDay(),
            'keperluan' => 'Praktikum Elektronika - Minggu 1',
            'catatan' => 'Peminjaman aktif, belum ada pengembalian.',
            'status' => Peminjaman::STATUS_DISETUJUI,
        ], ['Multimeter Digital' => 3], $alat);

        $this->peminjaman([
            'user_id' => $users['budi']->id,
            'tanggal_pinjam' => $today->copy()->subDays(2),
            'tanggal_kembali' => $today->copy()->addDay(),
            'keperluan' => 'Praktikum Jaringan - Minggu 1',
            'catatan' => 'Peminjaman aktif kedua, belum ada pengembalian.',
            'status' => Peminjaman::STATUS_DISETUJUI,
        ], ['Kabel LAN' => 5], $alat);

        // --- Disetujui & pengembalian menunggu ---------------------
        $sitiMenungguKembali = $this->peminjaman([
            'user_id' => $users['siti']->id,
            'tanggal_pinjam' => $today->copy()->subDays(4),
            'tanggal_kembali' => $today->copy(),
            'keperluan' => 'Praktikum Multimedia - Dokumentasi Kegiatan',
            'catatan' => 'Pengembalian sudah diajukan, menunggu admin.',
            'status' => Peminjaman::STATUS_DISETUJUI,
        ], [
            'Proyektor' => 1,
            'Webcam' => 2,
        ], $alat);

        $this->pengembalian($sitiMenungguKembali, [
            'tanggal_pengembalian' => $today->copy(),
            'kondisi' => 'Baik',
            'catatan' => 'Semua alat kembali utuh.',
            'status' => Pengembalian::STATUS_MENUNGGU,
        ]);

        // --- Ditolak -----------------------------------------------
        $this->peminjaman([
            'user_id' => $users['andi']->id,
            'tanggal_pinjam' => $today->copy()->subDays(3),
            'tanggal_kembali' => $today->copy()->addDays(4),
            'keperluan' => 'Praktikum Osiloskop',
            'catatan' => 'Pengajuan ditolak karena bentrok jadwal.',
            'status' => Peminjaman::STATUS_DITOLAK,
        ], ['Oscilloscope' => 1], $alat);

        // --- Selesai (sudah dikembalikan & disetujui) --------------
        $sitiSelesai = $this->peminjaman([
            'user_id' => $users['siti']->id,
            'tanggal_pinjam' => $today->copy()->subDays(10),
            'tanggal_kembali' => $today->copy()->subDays(7),
            'keperluan' => 'Praktikum Jaringan - Pengkabelan',
            'catatan' => 'Peminjaman selesai, alat sudah dikembalikan.',
            'status' => Peminjaman::STATUS_SELESAI,
        ], [
            'LAN Tester' => 2,
            'Tang Crimping' => 1,
        ], $alat);

        $this->pengembalian($sitiSelesai, [
            'tanggal_pengembalian' => $today->copy()->subDays(7),
            'kondisi' => 'Baik',
            'catatan' => 'Alat dikembalikan sebelum jadwal.',
            'status' => Pengembalian::STATUS_DISETUJUI,
        ]);

        // --- Pengembalian ditolak (peminjaman tetap aktif) ----------
        $andiAktif = $this->peminjaman([
            'user_id' => $users['andi']->id,
            'tanggal_pinjam' => $today->copy()->subDays(1),
            'tanggal_kembali' => $today->copy()->addDay(),
            'keperluan' => 'Praktikum Jaringan - Troubleshooting',
            'catatan' => 'Pengembalian ditolak, peminjaman tetap aktif.',
            'status' => Peminjaman::STATUS_DISETUJUI,
        ], ['Switch' => 2], $alat);

        $this->pengembalian($andiAktif, [
            'tanggal_pengembalian' => $today->copy(),
            'kondisi' => 'Rusak Ringan',
            'catatan' => 'Salah satu switch belum diperiksa admin.',
            'status' => Pengembalian::STATUS_DITOLAK,
        ]);
    }

    /**
     * @param  array<string, mixed>  $header
     * @param  array<string, int>  $detail  [nama alat => jumlah]
     * @param  array<string, Alat>  $alat
     */
    private function peminjaman(array $header, array $detail, array $alat): Peminjaman
    {
        $peminjaman = Peminjaman::updateOrCreate(
            [
                'user_id' => $header['user_id'],
                'keperluan' => $header['keperluan'],
            ],
            [
                'tanggal_pinjam' => Carbon::parse($header['tanggal_pinjam'])->startOfDay(),
                'tanggal_kembali' => Carbon::parse($header['tanggal_kembali'])->startOfDay(),
                'catatan' => $header['catatan'] ?? null,
                'status' => $header['status'],
            ],
        );

        foreach ($detail as $namaAlat => $jumlah) {
            DetailPeminjaman::updateOrCreate(
                [
                    'peminjaman_id' => $peminjaman->id,
                    'alat_id' => $alat[$namaAlat]->id,
                ],
                ['jumlah' => $jumlah],
            );
        }

        return $peminjaman;
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function pengembalian(Peminjaman $peminjaman, array $data): Pengembalian
    {
        $ada = Pengembalian::where('peminjaman_id', $peminjaman->id)
            ->orderBy('id')
            ->first();

        $atribut = [
            'tanggal_pengembalian' => Carbon::parse($data['tanggal_pengembalian'])->startOfDay(),
            'kondisi' => $data['kondisi'],
            'catatan' => $data['catatan'],
            'status' => $data['status'],
        ];

        if ($ada) {
            $ada->update($atribut);

            return $ada->fresh();
        }

        return Pengembalian::create([
            'peminjaman_id' => $peminjaman->id,
            ...$atribut,
        ]);
    }

    // ============================================================
    // STOK
    // ============================================================

    /**
     * Hitung ulang stok tiap alat supaya selalu konsisten dengan transaksi.
     *
     * Stok yang disimpan adalah jumlah unit yang masih ada di laboratorium,
     * yaitu `stok awal - (unit yang sedang dipinjam)`. Peminjaman yang
     * ditolak, yang masih menunggu, dan yang sudah dikembalikan tidak
     * berpengaruh: stok baru dikurangi saat disetujui dan dikembalikan lagi
     * saat pengembalian disetujui.
     *
     * @param  array<string, Alat>  $alat
     */
    private function selaraskanStok(array $alat): void
    {
        foreach ($alat as $nama => $model) {
            $stokAwal = self::DAFTAR_ALAT[$nama][1];
            $stok = max(0, $stokAwal - StokHelper::sedangDipinjamAlat($model->id));

            if ($model->stok !== $stok) {
                $model->update(['stok' => $stok]);
            }
        }
    }
}
