<?php

namespace Tests\Feature;

use App\Models\Alat;
use App\Models\Kategori;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    private function mahasiswa(array $overrides = []): User
    {
        return User::factory()->create(array_merge([
            'email' => 'budi@labkamp.com',
            'password' => 'rahasia123',
        ], $overrides));
    }

    private function admin(array $overrides = []): User
    {
        return User::factory()->admin()->create(array_merge([
            'email' => 'admin@labkamp.com',
            'password' => 'admkamp',
        ], $overrides));
    }

    // ============================================================
    // LOGIN
    // ============================================================

    public function test_login_sukses_mengembalikan_token_bearer(): void
    {
        $this->mahasiswa();

        $response = $this->postJson('/api/login', [
            'email' => 'budi@labkamp.com',
            'password' => 'rahasia123',
        ]);

        $response->assertOk()
            ->assertJsonPath('status', 'ok')
            ->assertJsonPath('token_type', 'Bearer')
            ->assertJsonPath('user.email', 'budi@labkamp.com')
            ->assertJsonPath('user.role', 'mahasiswa')
            ->assertJsonStructure(['status', 'token', 'token_type', 'user']);

        $this->assertIsString($response->json('token'));
        $this->assertNotEmpty($response->json('token'));
    }

    public function test_login_tidak_bocorkan_password_hash(): void
    {
        $this->mahasiswa();

        $response = $this->postJson('/api/login', [
            'email' => 'budi@labkamp.com',
            'password' => 'rahasia123',
        ]);

        $response->assertOk()->assertJsonMissingPath('user.password');
    }

    public function test_login_dengan_email_tidak_terdaftar(): void
    {
        $response = $this->postJson('/api/login', [
            'email' => 'entah@labkamp.com',
            'password' => 'apa-saja',
        ]);

        $response->assertOk()->assertJsonPath('status', 'email_not_found');
    }

    public function test_login_dengan_password_salah(): void
    {
        $this->mahasiswa();

        $response = $this->postJson('/api/login', [
            'email' => 'budi@labkamp.com',
            'password' => 'salah-total',
        ]);

        $response->assertOk()->assertJsonPath('status', 'wrong_password');
    }

    public function test_login_kosong_mengembalikan_422(): void
    {
        $this->postJson('/api/login', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['email', 'password']);
    }

    public function test_login_dibatasi_throttle(): void
    {
        $this->mahasiswa();

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/login', [
                'email' => 'budi@labkamp.com',
                'password' => 'salah',
            ])->assertOk();
        }

        $response = $this->postJson('/api/login', [
            'email' => 'budi@labkamp.com',
            'password' => 'rahasia123',
        ]);

        $this->assertContains(
            $response->status(),
            [429],
            'Percobaan login keenam harus diblokir rate limiter.',
        );
    }

    // ============================================================
    // AKSES TANPA TOKEN
    // ============================================================

    public function test_endpoint_terlindungi_menolak_tanpa_token(): void
    {
        $this->getJson('/api/alat')->assertStatus(401);
        $this->getJson('/api/home/admin')->assertStatus(401);
        $this->postJson('/api/peminjaman', [])->assertStatus(401);
    }

    /**
     * Klien non-browser (Flutter/Postman) sering tidak mengirim
     * `Accept: application/json`. Balasannya tetap harus JSON 401, bukan
     * redirect (yang jadi 500) dan tentu bukan 403.
     */
    public function test_endpoint_terlindungi_tanpa_token_tanpa_accept_json(): void
    {
        $this->get('/api/alat')
            ->assertStatus(401)
            ->assertHeader('content-type', 'application/json')
            ->assertJsonPath('message', 'Tidak terautentikasi. Silakan login kembali.');
    }

    public function test_token_tidak_valid_menghasilkan_401(): void
    {
        $this->withToken('1|pasti-token-ngawur')
            ->getJson('/api/alat')
            ->assertStatus(401);
    }

    public function test_logout_mencabut_token_sedang_dipakai(): void
    {
        $mhs = $this->mahasiswa();
        $token = $mhs->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->postJson('/api/logout')
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertDatabaseCount('personal_access_tokens', 0);

        // Token yang sama tidak boleh bisa dipakai lagi.
        $this->withRawToken($token)
            ->getJson('/api/alat')
            ->assertStatus(401);
    }

    public function test_endpoint_publik_tetap_terbuka(): void
    {
        Kategori::create(['nama_kategori' => 'Elektronika']);

        // GET /api/kategori dipakai Flutter sebagai probe koneksi.
        $this->getJson('/api/kategori')
            ->assertOk()
            ->assertJsonPath('0.nama_kategori', 'Elektronika');

        $this->getJson('/api/health')->assertOk()->assertJsonPath('status', 'ok');
    }

    public function test_token_sah_diperlakukan_sebagai_admin(): void
    {
        $this->admin();
        $this->postJson('/api/login', ['email' => 'admin@labkamp.com', 'password' => 'admkamp'])
            ->assertOk();

        // Pesan berhasillogin berarti token valid & terbaca.
        $this->assertDatabaseCount('personal_access_tokens', 1);
    }

    public function test_mahasiswa_ditolak_dari_endpoint_admin(): void
    {
        $mhs = $this->mahasiswa();
        $token = $mhs->createToken('test')->plainTextToken;

        $this->withRawToken($token)->getJson('/api/home/admin')->assertStatus(403);
        $this->withRawToken($token)->getJson('/api/laporan')->assertStatus(403);
        $this->withRawToken($token)->getJson('/api/peminjaman/admin')->assertStatus(403);
        $this->withRawToken($token)->getJson('/api/pengembalian/admin')->assertStatus(403);
    }

    public function test_mahasiswa_tidak_bisa_menulis_kategori_dan_alat(): void
    {
        $kategori = Kategori::create(['nama_kategori' => 'Elektronika']);
        $token = $this->mahasiswa()->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->postJson('/api/kategori', ['nama_kategori' => 'Baru'])
            ->assertStatus(403);

        $this->withRawToken($token)
            ->postJson('/api/alat', [
                'kategori_id' => $kategori->id,
                'nama_alat' => 'Kabel',
                'stok' => 5,
                'kondisi' => 'Baik',
            ])
            ->assertStatus(403);
    }

    // ============================================================
    // KEPEMILIKAN DATA
    // ============================================================

    public function test_mahasiswa_hanya_bisa_membaca_riwayat_nya_sendiri(): void
    {
        $budi = $this->mahasiswa(['email' => 'budi@labkamp.com']);
        $siti = $this->mahasiswa(['email' => 'siti@labkamp.com']);

        $token = $budi->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->getJson("/api/peminjaman/riwayat/{$budi->id}")
            ->assertOk();

        $this->withRawToken($token)
            ->getJson("/api/peminjaman/riwayat/{$siti->id}")
            ->assertStatus(403);
    }

    public function test_mahasiswa_tidak_bisa_mengubah_profil_orang_lain(): void
    {
        $budi = $this->mahasiswa(['email' => 'budi@labkamp.com']);
        $siti = $this->mahasiswa(['email' => 'siti@labkamp.com', 'nama' => 'Siti Rahayu']);

        $this->withRawToken($budi->createToken('test')->plainTextToken)
            ->putJson('/api/users/update', [
                'id' => $siti->id,
                'nama' => 'Diretas',
                'email' => 'siti@labkamp.com',
            ])
            ->assertStatus(403);

        $this->assertDatabaseHas('users', ['id' => $siti->id, 'nama' => 'Siti Rahayu']);
    }

    public function test_mahasiswa_tidak_bisa_mengganti_password_orang_lain(): void
    {
        $budi = $this->mahasiswa(['email' => 'budi@labkamp.com']);
        $siti = $this->mahasiswa(['email' => 'siti@labkamp.com']);

        $token = $budi->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->putJson('/api/users/password', [
                'email' => 'siti@labkamp.com',
                'password_lama' => 'rahasia123',
                'password_baru' => 'baru12345',
            ])
            ->assertStatus(403);
    }

    // ============================================================
    // GANTI PASSWORD
    // ============================================================

    public function test_ganti_password_mahasiswa(): void
    {
        $mhs = $this->mahasiswa();
        $token = $mhs->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->putJson('/api/users/password', [
                'email' => 'budi@labkamp.com',
                'password_lama' => 'rahasia123',
                'password_baru' => 'baru12345',
            ])
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->postJson('/api/login', [
            'email' => 'budi@labkamp.com',
            'password' => 'baru12345',
        ])->assertOk()->assertJsonPath('status', 'ok');
    }

    public function test_ganti_password_menolak_password_lama_salah(): void
    {
        $mhs = $this->mahasiswa();
        $token = $mhs->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->putJson('/api/users/password', [
                'email' => 'budi@labkamp.com',
                'password_lama' => 'salah',
                'password_baru' => 'baru12345',
            ])
            ->assertStatus(422);
    }

    public function test_ganti_password_menghasilkan_422_saat_kosong(): void
    {
        $mhs = $this->mahasiswa();
        $token = $mhs->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->putJson('/api/users/password', [
                'email' => 'budi@labkamp.com',
                'password_lama' => '',
                'password_baru' => '',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['password_lama', 'password_baru']);
    }

    // ============================================================
    // GANTI PASSWORD ADMIN
    // ============================================================

    public function test_admin_bisa_mengganti_passwordnya_sendiri(): void
    {
        $admin = $this->admin();
        $token = $admin->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->putJson('/api/users/admin/password', [
                'password_lama' => 'admkamp',
                'password_baru' => 'adminbaru123',
            ])
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->postJson('/api/login', [
            'email' => 'admin@labkamp.com',
            'password' => 'adminbaru123',
        ])->assertOk()->assertJsonPath('status', 'ok');
    }

    public function test_update_admin_password_menolak_password_lama_salah(): void
    {
        $admin = $this->admin();
        $token = $admin->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->putJson('/api/users/admin/password', [
                'password_lama' => 'salah',
                'password_baru' => 'adminbaru123',
            ])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Kata sandi lama salah.');
    }

    public function test_mahasiswa_tidak_bisa_memanggil_update_admin_password(): void
    {
        $mhs = $this->mahasiswa();
        $token = $mhs->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->putJson('/api/users/admin/password', [
                'password_lama' => 'rahasia123',
                'password_baru' => 'hack12345',
            ])
            ->assertStatus(403);
    }

    // ============================================================
    // TAMBAH ALAT (validasi admin)
    // ============================================================

    public function test_admin_menambah_alat_dengan_validasi(): void
    {
        $token = $this->admin()->createToken('test')->plainTextToken;
        $kategori = Kategori::create(['nama_kategori' => 'Elektronika']);

        $this->withRawToken($token)
            ->postJson('/api/alat', [
                'kategori_id' => $kategori->id,
                'nama_alat' => 'Multimeter',
                'stok' => 4,
                'kondisi' => 'Baik',
            ])
            ->assertCreated()
            ->assertJsonPath('nama_alat', 'Multimeter');

        $this->assertDatabaseHas('alat', ['nama_alat' => 'Multimeter', 'stok' => 4]);
    }

    public function test_tambah_alat_tidak_boleh_stok_negatif(): void
    {
        $token = $this->admin()->createToken('test')->plainTextToken;
        $kategori = Kategori::create(['nama_kategori' => 'Elektronika']);

        $this->withRawToken($token)
            ->postJson('/api/alat', [
                'kategori_id' => $kategori->id,
                'nama_alat' => 'Multimeter',
                'stok' => -3,
                'kondisi' => 'Baik',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('stok');
    }

    public function test_tambah_alat_tanpa_kategori_tidak_ditemukan(): void
    {
        $token = $this->admin()->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->postJson('/api/alat', [
                'kategori_id' => 999,
                'nama_alat' => 'Multimeter',
                'stok' => 4,
                'kondisi' => 'Baik',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('kategori_id');
    }

    public function test_kategori_duplikat_ditolak(): void
    {
        $token = $this->admin()->createToken('test')->plainTextToken;

        Kategori::create(['nama_kategori' => 'Elektronika']);

        $this->withRawToken($token)
            ->postJson('/api/kategori', ['nama_kategori' => 'Elektronika'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('nama_kategori');
    }

    public function test_kategori_tanpa_nama_menghasilkan_422(): void
    {
        $token = $this->admin()->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->postJson('/api/kategori', ['nama_kategori' => ''])
            ->assertStatus(422)
            ->assertJsonValidationErrors('nama_kategori');
    }

    // ============================================================
    // STOK TERSEDIA
    // ============================================================

    public function test_stok_tersedia_menghitung_pemesanan_yg_menunggu(): void
    {
        $kategori = Kategori::create(['nama_kategori' => 'Elektronika']);
        $alat = Alat::create([
            'kategori_id' => $kategori->id,
            'nama_alat' => 'Multimeter',
            'stok' => 5,
            'kondisi' => 'Baik',
        ]);

        $mhs = $this->mahasiswa();

        $this->withApiToken($mhs)
            ->getJson("/api/alat/{$alat->id}/stok-tersedia")
            ->assertOk()
            ->assertJsonPath('stok', 5)
            ->assertJsonPath('dipesan', 0);
    }
}
