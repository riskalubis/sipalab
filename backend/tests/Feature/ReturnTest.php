<?php

namespace Tests\Feature;

use App\Models\Alat;
use App\Models\DetailPeminjaman;
use App\Models\Kategori;
use App\Models\Peminjaman;
use App\Models\Pengembalian;
use App\Models\User;
use App\Support\StokHelper;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ReturnTest extends TestCase
{
    use RefreshDatabase;

    private Kategori $kategori;

    protected function setUp(): void
    {
        parent::setUp();

        $this->kategori = Kategori::create(['nama_kategori' => 'Elektronika']);
    }

    private function alat(string $nama, int $stok): Alat
    {
        return Alat::create([
            'kategori_id' => $this->kategori->id,
            'nama_alat' => $nama,
            'stok' => $stok,
            'kondisi' => 'Baik',
        ]);
    }

    private function mahasiswa(string $email = 'budi@labkamp.com'): User
    {
        return User::factory()->create(['email' => $email]);
    }

    private function admin(): User
    {
        return User::factory()->admin()->create(['email' => 'admin@labkamp.com']);
    }

    /**
     * Buat peminjaman yang sudah disetujui (stok sudah dikurangi) lalu
     * kembalikan stok fisiknya agar konsisten.
     *
     * @param  array<string, int>  $detail
     */
    private function peminjamanDisetujui(User $mhs, array $detail): Peminjaman
    {
        $peminjaman = Peminjaman::create([
            'user_id' => $mhs->id,
            'tanggal_pinjam' => now()->subDays(3),
            'tanggal_kembali' => now()->subDay(),
            'keperluan' => 'Praktikum',
            'status' => Peminjaman::STATUS_DISETUJUI,
        ]);

        foreach ($detail as $alatId => $jumlah) {
            DetailPeminjaman::create([
                'peminjaman_id' => $peminjaman->id,
                'alat_id' => $alatId,
                'jumlah' => $jumlah,
            ]);
        }

        return $peminjaman;
    }

    // ============================================================
    // PENGAJUAN PENGEMBALIAN
    // ============================================================

    public function test_mahasiswa_mengajukan_pengembalian(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 2]);

        $response = $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
                'kondisi' => 'Baik',
                'catatan' => 'Alat kembali utuh.',
            ]);

        $response->assertCreated()->assertJsonStructure(['id']);

        $this->assertDatabaseHas('pengembalian', [
            'id' => $response->json('id'),
            'peminjaman_id' => $peminjaman->id,
            'status' => 'menunggu',
            'catatan' => 'Alat kembali utuh.',
        ]);

        // Stok belum dikembalikan sebelum admin menyetujui.
        $this->assertSame(7, $multimeter->fresh()->stok);
    }

    public function test_pengajuan_ganda_ditolak(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 2]);

        $token = $mhs->createToken('t')->plainTextToken;

        $this->withRawToken($token)->postJson('/api/pengembalian', [
            'peminjaman_id' => $peminjaman->id,
            'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
            'kondisi' => 'Baik',
        ])->assertCreated();

        $this->withRawToken($token)->postJson('/api/pengembalian', [
            'peminjaman_id' => $peminjaman->id,
            'tanggal_pengembalian' => '2026-09-25T11:00:00.000',
            'kondisi' => 'Baik',
        ])->assertStatus(422);

        $this->assertDatabaseCount('pengembalian', 1);
    }

    public function test_database_menolak_pengajuan_menunggu_ganda(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 2]);

        Pengembalian::create([
            'peminjaman_id' => $peminjaman->id,
            'tanggal_pengembalian' => now(),
            'kondisi' => 'Baik',
            'status' => 'menunggu',
        ]);

        // Melewati Insert diam-diam (raw query) harus ditolak unique index.
        $this->expectException(QueryException::class);

        DB::table('pengembalian')->insert([
            'peminjaman_id' => $peminjaman->id,
            'tanggal_pengembalian' => '2026-09-25 10:00:00',
            'kondisi' => 'Baik',
            'status' => 'menunggu',
            'pending_peminjaman_id' => $peminjaman->id,
        ]);
    }

    public function test_pengajuan_gagal_setelah_ditolak_admin_membolehkan_pengajuan_baru(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 2]);

        $pengembalianId = $this->withApiToken($mhs)->postJson('/api/pengembalian', [
            'peminjaman_id' => $peminjaman->id,
            'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
            'kondisi' => 'Rusak Ringan',
        ])->json('id');

        $this->withApiToken($admin)
            ->putJson("/api/pengembalian/{$pengembalianId}/tolak")
            ->assertOk()
            ->assertJsonPath('success', true);

        // Setelah ditolak, kolom penjaga harus kosong.
        $this->assertNull(
            DB::table('pengembalian')->where('id', $pengembalianId)->value('pending_peminjaman_id')
        );

        $this->withApiToken($mhs)->postJson('/api/pengembalian', [
            'peminjaman_id' => $peminjaman->id,
            'tanggal_pengembalian' => '2026-09-26T10:00:00.000',
            'kondisi' => 'Baik',
        ])->assertCreated();
    }

    public function test_peminjaman_belum_disetujui_tidak_bisa_dikembalikan(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $peminjaman = Peminjaman::create([
            'user_id' => $mhs->id,
            'tanggal_pinjam' => now(),
            'tanggal_kembali' => now()->addDays(2),
            'keperluan' => 'Praktikum',
            'status' => Peminjaman::STATUS_MENUNGGU,
        ]);
        DetailPeminjaman::create([
            'peminjaman_id' => $peminjaman->id,
            'alat_id' => $multimeter->id,
            'jumlah' => 1,
        ]);

        $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
                'kondisi' => 'Baik',
            ])
            ->assertStatus(422);
    }

    public function test_pengembalian_tanpa_kondisi_menghasilkan_422(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 1]);

        $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '',
                'kondisi' => '',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['tanggal_pengembalian', 'kondisi']);
    }

    /**
     * Body kosong harus 422 (validasi), bukan 422 "peminjaman tidak
     * ditemukan" dari level bisnis.
     */
    public function test_pengembalian_body_kosong_menghasilkan_422(): void
    {
        $mhs = $this->mahasiswa();

        $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['peminjaman_id', 'tanggal_pengembalian', 'kondisi']);
    }

    public function test_pengembalian_peminjaman_orang_lain_ditolak(): void
    {
        $budi = $this->mahasiswa();
        $siti = $this->mahasiswa('siti@labkamp.com');
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($budi, [$multimeter->id => 1]);

        $this->withApiToken($siti)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
                'kondisi' => 'Baik',
            ])
            ->assertStatus(403);
    }

    // ============================================================
    // PERSETUJUAN PENGEMBALIAN
    // ============================================================

    public function test_admin_menyetujui_pengembalian_mengembalikan_stok_dan_status_selesai(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $kabel = $this->alat('Kabel LAN', 15);

        $peminjaman = $this->peminjamanDisetujui($mhs, [
            $multimeter->id => 2,
            $kabel->id => 5,
        ]);

        $pengembalianId = $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
                'kondisi' => 'Baik',
            ])
            ->json('id');

        $this->withApiToken($admin)
            ->putJson("/api/pengembalian/{$pengembalianId}/setujui", [
                'peminjaman_id' => $peminjaman->id,
            ])
            ->assertOk()
            ->assertJsonPath('success', true);

        // Stok kembali tepat sejumlah yang dipinjam.
        $this->assertSame(9, $multimeter->fresh()->stok);
        $this->assertSame(20, $kabel->fresh()->stok);

        // Peminjaman menjadi selesai.
        $this->assertDatabaseHas('peminjaman', [
            'id' => $peminjaman->id,
            'status' => Peminjaman::STATUS_SELESAI,
        ]);

        $this->assertDatabaseHas('pengembalian', [
            'id' => $pengembalianId,
            'status' => Pengembalian::STATUS_DISETUJUI,
        ]);

        $this->assertSame(0, StokHelper::sedangDipinjamAlat($multimeter->id));
    }

    public function test_pengembalian_memulihkan_stok_walau_stok_saat_ini_nol(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();

        // Stok 0 adalah kondisi normal: seluruh unit sedang dipinjam.
        $multimeter = $this->alat('Multimeter Digital', 0);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 3]);

        $pengembalianId = $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
                'kondisi' => 'Baik',
            ])
            ->json('id');

        $this->withApiToken($admin)
            ->putJson("/api/pengembalian/{$pengembalianId}/setujui", [
                'peminjaman_id' => $peminjaman->id,
            ])
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertSame(3, $multimeter->fresh()->stok);
    }

    public function test_pengembalian_yang_sudah_selesai_tidak_bisa_disetujui_lagi(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 2]);

        $pengembalianId = $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
                'kondisi' => 'Baik',
            ])
            ->json('id');

        $this->withApiToken($admin)->putJson("/api/pengembalian/{$pengembalianId}/setujui", [
            'peminjaman_id' => $peminjaman->id,
        ])->assertOk();

        $this->withApiToken($admin)->putJson("/api/pengembalian/{$pengembalianId}/setujui", [
            'peminjaman_id' => $peminjaman->id,
        ])->assertStatus(422);

        // Stok tidak boleh bertambah dua kali.
        $this->assertSame(9, $multimeter->fresh()->stok);
    }

    public function test_setujui_pengembalian_menolak_peminjaman_id_yang_tidak_cocok(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 2]);

        $pengembalianId = $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
                'kondisi' => 'Baik',
            ])
            ->json('id');

        $this->withApiToken($admin)
            ->putJson("/api/pengembalian/{$pengembalianId}/setujui", ['peminjaman_id' => 999])
            ->assertStatus(422);

        $this->assertSame(7, $multimeter->fresh()->stok);
    }

    public function test_mahasiswa_tidak_bisa_menyetujui_pengembalian(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 2]);

        $pengembalianId = $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
                'kondisi' => 'Baik',
            ])
            ->json('id');

        $this->withApiToken($mhs)
            ->putJson("/api/pengembalian/{$pengembalianId}/setujui", [
                'peminjaman_id' => $peminjaman->id,
            ])
            ->assertStatus(403);

        $this->assertSame(7, $multimeter->fresh()->stok);
    }

    // ============================================================
    // PEMINJAMAN AKTIF
    // ============================================================

    public function test_peminjaman_aktif_masih_terlihat_setelah_pengembalian_ditolak(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 2]);

        $pengembalianId = $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
                'kondisi' => 'Rusak Ringan',
            ])
            ->json('id');

        $this->withApiToken($admin)
            ->putJson("/api/pengembalian/{$pengembalianId}/tolak")
            ->assertOk();

        $response = $this->withApiToken($mhs)
            ->getJson("/api/peminjaman/aktif/{$mhs->id}")
            ->assertOk()
            ->assertJsonCount(1);

        $this->assertSame($peminjaman->id, $response->json('0.id'));
        $this->assertSame('ditolak', $response->json('0.status_pengembalian'));
    }

    public function test_peminjaman_aktif_hilang_setelah_pengembalian_disetujui(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 7);
        $peminjaman = $this->peminjamanDisetujui($mhs, [$multimeter->id => 2]);

        $pengembalianId = $this->withApiToken($mhs)
            ->postJson('/api/pengembalian', [
                'peminjaman_id' => $peminjaman->id,
                'tanggal_pengembalian' => '2026-09-25T10:00:00.000',
                'kondisi' => 'Baik',
            ])
            ->json('id');

        $this->withApiToken($admin)
            ->putJson("/api/pengembalian/{$pengembalianId}/setujui", [
                'peminjaman_id' => $peminjaman->id,
            ])->assertOk();

        $this->withApiToken($mhs)
            ->getJson("/api/peminjaman/aktif/{$mhs->id}")
            ->assertOk()
            ->assertJsonCount(0);
    }

    public function test_daftar_pengembalian_mahasiswa_hanya_miliknya(): void
    {
        $budi = $this->mahasiswa();
        $siti = $this->mahasiswa('siti@labkamp.com');
        $multimeter = $this->alat('Multimeter Digital', 7);

        $peminjamanBudi = $this->peminjamanDisetujui($budi, [$multimeter->id => 1]);
        $peminjamanSiti = $this->peminjamanDisetujui($siti, [$multimeter->id => 1]);

        Pengembalian::create([
            'peminjaman_id' => $peminjamanBudi->id,
            'tanggal_pengembalian' => now(),
            'kondisi' => 'Baik',
            'status' => 'menunggu',
        ]);
        Pengembalian::create([
            'peminjaman_id' => $peminjamanSiti->id,
            'tanggal_pengembalian' => now(),
            'kondisi' => 'Baik',
            'status' => 'menunggu',
        ]);

        $response = $this->withApiToken($budi)->getJson('/api/pengembalian')->assertOk();

        $this->assertCount(1, $response->json());
        $this->assertSame($peminjamanBudi->id, $response->json('0.peminjaman_id'));

        // Admin melihat semuanya.
        $this->withApiToken($this->admin())
            ->getJson('/api/pengembalian')
            ->assertOk()
            ->assertJsonCount(2);
    }
}
