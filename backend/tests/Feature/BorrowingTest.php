<?php

namespace Tests\Feature;

use App\Models\Alat;
use App\Models\DetailPeminjaman;
use App\Models\Kategori;
use App\Models\Peminjaman;
use App\Models\Pengembalian;
use App\Models\User;
use App\Support\StokHelper;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BorrowingTest extends TestCase
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
            'deskripsi' => null,
            'gambar' => null,
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
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function payload(array $overrides = []): array
    {
        return array_merge([
            'tanggal_pinjam' => '2026-09-18T00:00:00.000',
            'tanggal_kembali' => '2026-09-21T00:00:00.000',
            'keperluan' => 'Praktikum Elektronika',
        ], $overrides);
    }

    // ============================================================
    // PENGAJUAN
    // ============================================================

    public function test_mahasiswa_mengajukan_peminjaman(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $response = $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'catatan' => 'Kebutuhannya untuk modul 1.',
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 2]],
            ]));

        $response->assertCreated()
            ->assertJsonPath('status', 'menunggu')
            ->assertJsonStructure(['id', 'status']);

        $this->assertDatabaseHas('peminjaman', [
            'id' => $response->json('id'),
            'user_id' => $mhs->id,
            'status' => 'menunggu',
            'catatan' => 'Kebutuhannya untuk modul 1.',
        ]);

        $this->assertDatabaseHas('detail_peminjaman', [
            'peminjaman_id' => $response->json('id'),
            'alat_id' => $multimeter->id,
            'jumlah' => 2,
        ]);

        // Saat masih menunggu, stok TIDAK boleh berkurang.
        $this->assertSame(5, $multimeter->fresh()->stok);
    }

    public function test_detail_alat_duplikat_dinormalkan_menjadi_satu_baris(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $response = $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [
                    ['alat_id' => $multimeter->id, 'jumlah' => 1],
                    ['alat_id' => $multimeter->id, 'jumlah' => 2],
                    ['alat_id' => $multimeter->id, 'jumlah' => 1],
                ],
            ]));

        $response->assertCreated();

        $details = DetailPeminjaman::where('peminjaman_id', $response->json('id'))->get();

        $this->assertCount(1, $details, 'Alat yang sama harus digabung menjadi satu baris detail.');
        $this->assertSame(4, $details->first()->jumlah);
    }

    public function test_peminjaman_melebihi_stok_ditolak(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 2);

        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 3]],
            ]))
            ->assertStatus(422);

        $this->assertDatabaseCount('peminjaman', 0);
    }

    public function test_total_gabungan_lewat_stok_ditolak(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 3);

        // 2 + 2 = 4 > 3 walau tiap baris sendiri valid.
        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [
                    ['alat_id' => $multimeter->id, 'jumlah' => 2],
                    ['alat_id' => $multimeter->id, 'jumlah' => 2],
                ],
            ]))
            ->assertStatus(422);
    }

    public function test_stok_yg_sudah_dipesan_ikut_dihitung(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 3);

        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 3]],
            ]))
            ->assertCreated();

        $this->assertSame(3, StokHelper::dipesan($multimeter->id));

        // Tidak ada stok tersisa untuk pengajuan kedua.
        $siti = $this->mahasiswa('siti@labkamp.com');

        $this->withApiToken($siti)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $siti->id,
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 1]],
            ]))
            ->assertStatus(422);
    }

    public function test_peminjaman_tanpa_detail_menghasilkan_422(): void
    {
        $mhs = $this->mahasiswa();

        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [],
            ]))
            ->assertStatus(422)
            ->assertJsonValidationErrors('detail');
    }

    /**
     * Body kosong harus 422 (dari validasi), bukan 403 (dari otorisasi).
     */
    public function test_peminjaman_body_kosong_menghasilkan_422(): void
    {
        $mhs = $this->mahasiswa();

        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['user_id', 'tanggal_pinjam', 'tanggal_kembali', 'keperluan', 'detail']);
    }

    public function test_peminjaman_tanpa_keperluan_menghasilkan_422(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', [
                'user_id' => $mhs->id,
                'tanggal_pinjam' => '2026-09-18T00:00:00.000',
                'tanggal_kembali' => '2026-09-21T00:00:00.000',
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 1]],
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('keperluan');
    }

    public function test_tanggal_tidak_valid_menghasilkan_422(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'tanggal_pinjam' => 'bukan-tanggal',
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 1]],
            ]))
            ->assertStatus(422)
            ->assertJsonValidationErrors('tanggal_pinjam');
    }

    public function test_tanggal_kembali_lebih_awal_menghasilkan_422(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'tanggal_pinjam' => '2026-09-21T00:00:00.000',
                'tanggal_kembali' => '2026-09-18T00:00:00.000',
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 1]],
            ]))
            ->assertStatus(422)
            ->assertJsonValidationErrors('tanggal_kembali');
    }

    public function test_jumlah_nol_atau_negatif_menghasilkan_422(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 0]],
            ]))
            ->assertStatus(422)
            ->assertJsonValidationErrors('detail.0.jumlah');
    }

    public function test_alat_tidak_ada_menghasilkan_422(): void
    {
        $mhs = $this->mahasiswa();

        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [['alat_id' => 9999, 'jumlah' => 1]],
            ]))
            ->assertStatus(422)
            ->assertJsonValidationErrors('detail.0.alat_id');
    }

    public function test_mahasiswa_tidak_bisa_mengaju_atas_nama_orang_lain(): void
    {
        $budi = $this->mahasiswa();
        $siti = $this->mahasiswa('siti@labkamp.com');
        $multimeter = $this->alat('Multimeter Digital', 5);

        $this->withApiToken($budi)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $siti->id,
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 1]],
            ]))
            ->assertStatus(403);

        $this->assertDatabaseCount('peminjaman', 0);
    }

    // ============================================================
    // PERSETUJUAN
    // ============================================================

    public function test_admin_menyetujui_peminjaman_dan_mengurangi_stok(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $id = $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 2]],
            ]))
            ->assertCreated()
            ->json('id');

        $this->withApiToken($admin)
            ->putJson("/api/peminjaman/{$id}/status", ['status' => 'disetujui'])
            ->assertOk()
            ->assertJsonPath('updated', 1);

        $this->assertDatabaseHas('peminjaman', ['id' => $id, 'status' => 'disetujui']);
        $this->assertSame(3, $multimeter->fresh()->stok, 'Stok harus berkurang tepat jumlah yang dipinjam.');
    }

    public function test_persetujuan_ditolak_bila_stok_kurang(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $id = $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 4]],
            ]))
            ->json('id');

        // Ssomeone mengurangi stok di luar aplikasi setelah pengajuan.
        $multimeter->update(['stok' => 2]);

        $this->withApiToken($admin)
            ->putJson("/api/peminjaman/{$id}/status", ['status' => 'disetujui'])
            ->assertStatus(422);

        $this->assertDatabaseHas('peminjaman', ['id' => $id, 'status' => 'menunggu']);
        $this->assertSame(2, $multimeter->fresh()->stok, 'Stok tidak boleh dikurangi (di-clamp) diam-diam.');
    }

    public function test_menolak_peminjaman_tidak_mengubah_stok(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $id = $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 2]],
            ]))
            ->json('id');

        $this->withApiToken($admin)
            ->putJson("/api/peminjaman/{$id}/status", ['status' => 'ditolak'])
            ->assertOk();

        $this->assertDatabaseHas('peminjaman', ['id' => $id, 'status' => 'ditolak']);
        $this->assertSame(5, $multimeter->fresh()->stok);
    }

    public function test_status_tidak_valid_menghasilkan_422(): void
    {
        $admin = $this->admin();

        $this->withApiToken($admin)
            ->putJson('/api/peminjaman/1/status', ['status' => 'ngawur'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('status');
    }

    public function test_peminjaman_yang_sudah_diproses_tidak_bisa_diubah(): void
    {
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 5);
        $mhs = $this->mahasiswa();

        $peminjaman = Peminjaman::create([
            'user_id' => $mhs->id,
            'tanggal_pinjam' => now(),
            'tanggal_kembali' => now()->addDay(),
            'keperluan' => 'Praktikum',
            'status' => 'disetujui',
        ]);
        DetailPeminjaman::create([
            'peminjaman_id' => $peminjaman->id,
            'alat_id' => $multimeter->id,
            'jumlah' => 1,
        ]);

        $this->withApiToken($admin)
            ->putJson("/api/peminjaman/{$peminjaman->id}/status", ['status' => 'ditolak'])
            ->assertStatus(422);

        $this->assertDatabaseHas('peminjaman', ['id' => $peminjaman->id, 'status' => 'disetujui']);
    }

    public function test_mahasiswa_tidak_bisa_menyetujui_peminjaman(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $id = $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 1]],
            ]))
            ->json('id');

        $this->withApiToken($mhs)
            ->putJson("/api/peminjaman/{$id}/status", ['status' => 'disetujui'])
            ->assertStatus(403);

        $this->assertSame(5, $multimeter->fresh()->stok);
    }

    // ============================================================
    // DAFTAR & DETAIL
    // ============================================================

    public function test_riwayat_mengembalikan_field_yang_dipakai_flutter(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $this->withApiToken($mhs)
            ->postJson('/api/peminjaman', $this->payload([
                'user_id' => $mhs->id,
                'detail' => [['alat_id' => $multimeter->id, 'jumlah' => 2]],
            ]))
            ->assertCreated();

        $response = $this->withApiToken($mhs)
            ->getJson("/api/peminjaman/riwayat/{$mhs->id}")
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonStructure([[
                'id', 'user_id', 'tanggal_pinjam', 'tanggal_kembali',
                'tgl_pinjam', 'tgl_kembali', 'keperluan', 'status',
                'nama', 'nama_mahasiswa', 'nim', 'kelas', 'email',
                'detail_id', 'alat_id', 'jumlah', 'nama_alat', 'stok',
                'kondisi', 'status_pengembalian',
            ]]);

        // Format tanggal tetap bisa di-parse StatusHelper di Flutter.
        $this->assertStringStartsWith('2026-09-18', $response->json('0.tanggal_pinjam'));
        $this->assertSame('menunggu', $response->json('0.status'));
    }

    public function test_daftar_alat_mengembalikan_field_yang_dipakai_flutter(): void
    {
        $multimeter = $this->alat('Multimeter Digital', 5);
        $mhs = $this->mahasiswa();

        $this->withApiToken($mhs)
            ->getJson('/api/alat')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonStructure([[
                'id', 'kategori_id', 'nama_kategori', 'kategori', 'nama_alat',
                'stok', 'kondisi', 'deskripsi', 'gambar', 'stok_dipesan',
                'kelas_peminjam',
            ]]);

        $this->withApiToken($mhs)
            ->getJson("/api/alat/{$multimeter->id}")
            ->assertOk()
            ->assertJsonPath('nama_alat', 'Multimeter Digital');
    }

    public function test_dashboard_admin_menghitung_statistik(): void
    {
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 5);
        $mhs = $this->mahasiswa();

        $peminjaman = Peminjaman::create([
            'user_id' => $mhs->id,
            'tanggal_pinjam' => now(),
            'tanggal_kembali' => now()->addDays(2),
            'keperluan' => 'Praktikum',
            'status' => 'disetujui',
        ]);
        DetailPeminjaman::create([
            'peminjaman_id' => $peminjaman->id,
            'alat_id' => $multimeter->id,
            'jumlah' => 2,
        ]);

        $this->withApiToken($admin)
            ->getJson('/api/home/admin')
            ->assertOk()
            ->assertJsonPath('total_alat', 1)
            ->assertJsonPath('stok_tersedia', 5)
            ->assertJsonPath('dipinjam', 2)
            ->assertJsonPath('menunggu', 0);
    }

    public function test_pengembalian_menunggu_ikut_terhitung_di_dipesan(): void
    {
        $mhs = $this->mahasiswa();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $peminjaman = Peminjaman::create([
            'user_id' => $mhs->id,
            'tanggal_pinjam' => now(),
            'tanggal_kembali' => now()->addDays(2),
            'keperluan' => 'Praktikum',
            'status' => 'menunggu',
        ]);
        DetailPeminjaman::create([
            'peminjaman_id' => $peminjaman->id,
            'alat_id' => $multimeter->id,
            'jumlah' => 2,
        ]);

        $this->assertSame(2, StokHelper::dipesan($multimeter->id));
        $this->assertSame(0, StokHelper::sedangDipinjam());
    }

    public function test_pengembalian_admin_menampilkan_detail(): void
    {
        $mhs = $this->mahasiswa();
        $admin = $this->admin();
        $multimeter = $this->alat('Multimeter Digital', 5);

        $peminjaman = Peminjaman::create([
            'user_id' => $mhs->id,
            'tanggal_pinjam' => now(),
            'tanggal_kembali' => now()->addDays(2),
            'keperluan' => 'Praktikum',
            'status' => 'disetujui',
        ]);
        DetailPeminjaman::create([
            'peminjaman_id' => $peminjaman->id,
            'alat_id' => $multimeter->id,
            'jumlah' => 1,
        ]);
        Pengembalian::create([
            'peminjaman_id' => $peminjaman->id,
            'tanggal_pengembalian' => now(),
            'kondisi' => 'Baik',
            'catatan' => 'Utuh',
            'status' => 'menunggu',
        ]);

        $this->withApiToken($admin)
            ->getJson('/api/pengembalian/admin')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonStructure([[
                'pengembalian_id', 'peminjaman_id', 'tanggal_pengembalian',
                'kondisi', 'catatan', 'status', 'status_pengembalian',
                'tanggal_pinjam', 'tanggal_kembali', 'status_peminjaman',
                'nama_mahasiswa', 'nim', 'detail',
            ]]);
    }
}
