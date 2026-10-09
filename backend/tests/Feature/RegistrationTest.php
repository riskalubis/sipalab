<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class RegistrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_pendaftaran_mahasiswa_berhasil(): void
    {
        $response = $this->postJson('/api/register', [
            'nama' => 'Budi Santoso',
            'nim' => '221011234',
            'kelas' => '23TI-01',
            'no_hp' => '081234567890',
            'email' => 'budi@labkamp.com',
            'password' => 'mhs12345',
            // Klien mengirim role, tapi server harus memaksa 'mahasiswa'.
            'role' => 'admin',
        ]);

        $response->assertCreated()
            ->assertJsonPath('email', 'budi@labkamp.com')
            ->assertJsonPath('nama', 'Budi Santoso')
            ->assertJsonPath('no_hp', '081234567890')
            ->assertJsonPath('role', 'mahasiswa');

        $this->assertDatabaseHas('users', [
            'email' => 'budi@labkamp.com',
            'role' => 'mahasiswa',
        ]);

        $user = User::where('email', 'budi@labkamp.com')->first();

        $this->assertNotSame('mhs12345', $user->password, 'Password tidak boleh disimpan sebagai teks biasa.');
        $this->assertTrue(Hash::check('mhs12345', $user->password));
    }

    public function test_email_pendaftaran_dinormalkan_lowercase_dan_bisa_login(): void
    {
        $this->postJson('/api/register', [
            'nama' => 'Budi Santoso',
            'email' => '  BUDI@LabKamp.COM ',
            'password' => 'mhs12345',
        ])->assertCreated()->assertJsonPath('email', 'budi@labkamp.com');

        $this->assertDatabaseHas('users', ['email' => 'budi@labkamp.com']);

        // Login dengan huruf kecil harus menemukan akun yang sama.
        $this->postJson('/api/login', [
            'email' => 'BUDI@labkamp.com',
            'password' => 'mhs12345',
        ])->assertOk()
            ->assertJsonPath('status', 'ok')
            ->assertJsonPath('user.email', 'budi@labkamp.com');
    }

    public function test_pendaftaran_tidak_membocorkan_password(): void
    {
        $this->postJson('/api/register', [
            'nama' => 'Budi',
            'email' => 'budi@labkamp.com',
            'password' => 'mhs12345',
        ])->assertCreated()->assertJsonMissingPath('password');
    }

    public function test_pendaftaran_tanpa_nama_menghasilkan_422(): void
    {
        $this->postJson('/api/register', [
            'nama' => '',
            'email' => 'budi@labkamp.com',
            'password' => 'mhs12345',
        ])->assertStatus(422)->assertJsonValidationErrors('nama');
    }

    public function test_pendaftaran_tanpa_email_valid_menghasilkan_422(): void
    {
        $this->postJson('/api/register', [
            'nama' => 'Budi',
            'email' => 'bukan-email',
            'password' => 'mhs12345',
        ])->assertStatus(422)->assertJsonValidationErrors('email');
    }

    public function test_pendaftaran_tanpa_password_menghasilkan_422(): void
    {
        $this->postJson('/api/register', [
            'nama' => 'Budi',
            'email' => 'budi@labkamp.com',
            'password' => '',
        ])->assertStatus(422)->assertJsonValidationErrors('password');
    }

    public function test_pendaftaran_password_terlalu_pendek_menghasilkan_422(): void
    {
        $this->postJson('/api/register', [
            'nama' => 'Budi',
            'email' => 'budi@labkamp.com',
            'password' => '123',
        ])->assertStatus(422)->assertJsonValidationErrors('password');
    }

    public function test_pendaftaran_email_duplikat_menghasilkan_422(): void
    {
        User::factory()->create(['email' => 'budi@labkamp.com']);

        $this->postJson('/api/register', [
            'nama' => 'Budi Santoso',
            'email' => 'budi@labkamp.com',
            'password' => 'mhs12345',
        ])->assertStatus(422)->assertJsonValidationErrors('email');

        $this->assertSame(1, User::where('email', 'budi@labkamp.com')->count());
    }

    public function test_pendaftaran_kosong_total_menghasilkan_422_bukan_500(): void
    {
        $this->postJson('/api/register', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['nama', 'email', 'password']);
    }

    public function test_cek_email_terdaftar(): void
    {
        User::factory()->create(['email' => 'budi@labkamp.com']);

        $this->getJson('/api/users/check-email?email=budi@labkamp.com')
            ->assertOk()
            ->assertJsonPath('registered', true);

        $this->getJson('/api/users/check-email?email=bukan@labkamp.com')
            ->assertOk()
            ->assertJsonPath('registered', false);
    }

    public function test_cek_email_kosong_tidak_meledak(): void
    {
        $this->getJson('/api/users/check-email')
            ->assertOk()
            ->assertJsonPath('registered', false);
    }

    public function test_profil_dapat_diambil_sendiri(): void
    {
        $mhs = User::factory()->create(['email' => 'budi@labkamp.com']);
        $token = $mhs->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->getJson("/api/users/{$mhs->id}")
            ->assertOk()
            ->assertJsonPath('email', 'budi@labkamp.com')
            ->assertJsonMissingPath('password');
    }

    public function test_update_profil_validasi_422(): void
    {
        $mhs = User::factory()->create(['email' => 'budi@labkamp.com']);

        $this->withApiToken($mhs)
            ->putJson('/api/users/update', [
                'id' => $mhs->id,
                'nama' => '',
                'email' => 'bukan-email',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['nama', 'email']);
    }

    /**
     * Field identitas yang kosong harus dilaporkan sebagai 422 oleh
     * validasi, bukan 403 oleh pemeriksaan otorisasi.
     */
    public function test_update_profil_tanpa_id_menghasilkan_422(): void
    {
        $mhs = User::factory()->create(['email' => 'budi@labkamp.com']);

        $this->withApiToken($mhs)
            ->putJson('/api/users/update', ['nama' => 'Budi'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('id');
    }

    public function test_update_password_tanpa_email_menghasilkan_422(): void
    {
        $mhs = User::factory()->create(['email' => 'budi@labkamp.com']);

        $this->withApiToken($mhs)
            ->putJson('/api/users/password', [
                'password_lama' => 'apa-saja',
                'password_baru' => 'baru12345',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('email');
    }

    public function test_update_foto_tanpa_email_menghasilkan_422(): void
    {
        $mhs = User::factory()->create(['email' => 'budi@labkamp.com']);

        $this->withApiToken($mhs)
            ->putJson('/api/users/foto', ['foto' => 'C:/foto/profil.jpg'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('email');
    }

    public function test_update_profil_menyimpan_no_hp(): void
    {
        $mhs = User::factory()->create(['email' => 'budi@labkamp.com']);
        $token = $mhs->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->putJson('/api/users/update', [
                'id' => $mhs->id,
                'nama' => 'Budi Santoso',
                'nim' => '221011234',
                'kelas' => '23TI-01',
                'no_hp' => '081200000000',
                'email' => 'budi@labkamp.com',
            ])
            ->assertOk()
            ->assertJsonPath('no_hp', '081200000000');

        $this->assertDatabaseHas('users', ['id' => $mhs->id, 'no_hp' => '081200000000']);
    }

    public function test_update_foto_profil(): void
    {
        $mhs = User::factory()->create(['email' => 'budi@labkamp.com']);
        $token = $mhs->createToken('test')->plainTextToken;

        $this->withRawToken($token)
            ->putJson('/api/users/foto', [
                'email' => 'budi@labkamp.com',
                'foto' => 'C:/foto/profil.jpg',
            ])
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertDatabaseHas('users', ['id' => $mhs->id, 'foto' => 'C:/foto/profil.jpg']);
    }
}
