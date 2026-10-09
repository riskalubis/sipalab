<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Menambahkan batasan uniqueness yang menopang integritas data SIPALAB:
 *
 *  1. `kategori.nama_kategori` unik (sebelumnya bisa dobel).
 *  2. `detail_peminjaman (peminjaman_id, alat_id)` unik — satu alat hanya
 *     boleh muncul satu kali per peminjaman (duplikat digabung lebih dulu).
 *  3. `pengembalian.pending_peminjaman_id` unik — kolom ini berisi
 *     `peminjaman_id` SELAGU ada pengajuan pengembalian berstatus
 *     `menunggu`, dan NULL setelah pengajuan diproses. Dengan begitu
 *     maksimal satu pengembalian menunggu per peminjaman, bahkan saat dua
 *     request datang bersamaan, karena database yang menolaknya.
 *
 * Baris data lama yang melanggar batasan dibersihkan lebih dulu supaya
 * migrasi tidak gagal pada database yang sudah terisi.
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->deduplicateKategori();
        $this->makeKategoriNameUnique();

        $this->deduplicateLoanDetails();
        $this->makeLoanDetailsUnique();

        $this->addPendingReturnGuard();
    }

    public function down(): void
    {
        if (Schema::hasTable('pengembalian') && Schema::hasColumn('pengembalian', 'pending_peminjaman_id')) {
            Schema::table('pengembalian', function (Blueprint $table) {
                $table->dropUnique('pengembalian_pending_unique');
                $table->dropColumn('pending_peminjaman_id');
            });
        }

        if (Schema::hasTable('detail_peminjaman') && Schema::hasIndex('detail_peminjaman', 'detail_peminjaman_peminjaman_id_alat_id_unique')) {
            Schema::table('detail_peminjaman', function (Blueprint $table) {
                $table->dropUnique('detail_peminjaman_peminjaman_id_alat_id_unique');
            });
        }

        if (Schema::hasTable('kategori') && Schema::hasIndex('kategori', 'kategori_nama_kategori_unique')) {
            Schema::table('kategori', function (Blueprint $table) {
                $table->dropUnique('kategori_nama_kategori_unique');
            });
        }
    }

    // ============================================================
    // KATEGORI
    // ============================================================

    /**
     * Gabungkan kategori duplikat (nama sama, abaikan huruf besar/kecil dan
     * spasi). Alat yang menunjuk ke kategori duplikat diarahkan ke kategori
     * yang dipertahankan, lalu kategori duplikat dihapus.
     */
    private function deduplicateKategori(): void
    {
        if (! Schema::hasTable('kategori') || ! Schema::hasTable('alat')) {
            return;
        }

        $duplicates = DB::table('kategori')
            ->selectRaw('LOWER(TRIM(nama_kategori)) AS key_nama, MIN(id) AS keep_id, COUNT(*) AS total')
            ->groupBy(DB::raw('LOWER(TRIM(nama_kategori))'))
            ->havingRaw('COUNT(*) > 1')
            ->get();

        foreach ($duplicates as $group) {
            $remove = DB::table('kategori')
                ->where('id', '<>', $group->keep_id)
                ->whereRaw('LOWER(TRIM(nama_kategori)) = ?', [$group->key_nama])
                ->pluck('id');

            foreach ($remove as $kategoriId) {
                DB::table('alat')->where('kategori_id', $kategoriId)->update([
                    'kategori_id' => $group->keep_id,
                ]);

                DB::table('kategori')->where('id', $kategoriId)->delete();
            }
        }
    }

    private function makeKategoriNameUnique(): void
    {
        if (Schema::hasIndex('kategori', 'kategori_nama_kategori_unique')) {
            return;
        }

        Schema::table('kategori', function (Blueprint $table) {
            $table->unique('nama_kategori', 'kategori_nama_kategori_unique');
        });
    }

    // ============================================================
    // DETAIL PEMINJAMAN
    // ============================================================

    /**
     * Gabungkan baris detail yang menunjuk alat sama pada peminjaman sama
     * dengan menjumlahkan `jumlah` ke baris paling awal.
     */
    private function deduplicateLoanDetails(): void
    {
        if (! Schema::hasTable('detail_peminjaman')) {
            return;
        }

        $duplicates = DB::table('detail_peminjaman')
            ->selectRaw('peminjaman_id, alat_id, MIN(id) AS keep_id, COUNT(*) AS total')
            ->groupBy('peminjaman_id', 'alat_id')
            ->havingRaw('COUNT(*) > 1')
            ->get();

        foreach ($duplicates as $group) {
            $remove = DB::table('detail_peminjaman')
                ->where('peminjaman_id', $group->peminjaman_id)
                ->where('alat_id', $group->alat_id)
                ->where('id', '<>', $group->keep_id)
                ->pluck('id');

            $total = (int) DB::table('detail_peminjaman')
                ->where('peminjaman_id', $group->peminjaman_id)
                ->where('alat_id', $group->alat_id)
                ->sum('jumlah');

            DB::table('detail_peminjaman')
                ->where('id', $group->keep_id)
                ->update(['jumlah' => max($total, 1)]);

            DB::table('detail_peminjaman')->whereIn('id', $remove)->delete();
        }
    }

    private function makeLoanDetailsUnique(): void
    {
        if (Schema::hasIndex('detail_peminjaman', 'detail_peminjaman_peminjaman_id_alat_id_unique')) {
            return;
        }

        Schema::table('detail_peminjaman', function (Blueprint $table) {
            $table->unique(['peminjaman_id', 'alat_id'], 'detail_peminjaman_peminjaman_id_alat_id_unique');
        });
    }

    // ============================================================
    // PENGEMBALIAN
    // ============================================================

    /**
     * Kolom penjaga pengembalian menunggu. Nilai NULL membuat unique index
     * tetap mengizinkan banyak baris yang sudah diproses.
     */
    private function addPendingReturnGuard(): void
    {
        if (! Schema::hasTable('pengembalian')) {
            return;
        }

        if (! Schema::hasColumn('pengembalian', 'pending_peminjaman_id')) {
            Schema::table('pengembalian', function (Blueprint $table) {
                $table->unsignedBigInteger('pending_peminjaman_id')->nullable();
            });
        }

        DB::statement(
            'UPDATE pengembalian
                SET pending_peminjaman_id = peminjaman_id
              WHERE LOWER(status) = \'menunggu\''
        );

        // Bersihkan pengajuan menunggu ganda yang mungkin sudah terlanjur ada.
        $duplicates = DB::table('pengembalian')
            ->selectRaw('pending_peminjaman_id, MIN(id) AS keep_id')
            ->whereNotNull('pending_peminjaman_id')
            ->groupBy('pending_peminjaman_id')
            ->havingRaw('COUNT(*) > 1')
            ->get();

        foreach ($duplicates as $group) {
            DB::table('pengembalian')
                ->where('pending_peminjaman_id', $group->pending_peminjaman_id)
                ->where('id', '<>', $group->keep_id)
                ->delete();
        }

        if (Schema::hasIndex('pengembalian', 'pengembalian_pending_unique')) {
            return;
        }

        Schema::table('pengembalian', function (Blueprint $table) {
            $table->unique('pending_peminjaman_id', 'pengembalian_pending_unique');
        });
    }
};
