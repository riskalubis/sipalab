<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Menambahkan jaminan bahwa `alat.stok` tidak pernah negatif.
 *
 * Lapisan aplikasi (validasi request + `UPDATE ... WHERE stok >= n`) sudah
 * menolak pengurangan yang tidak cukup, tapi batasan di database adalah
 * jaring pengaman terakhir bila ada script/seed yang tidak melalui API.
 *
 * SQLite tidak punya `ALTER TABLE ... ADD CONSTRAINT`, jadi tabel dibangun
 * ulang di sana. Karena `PRAGMA foreign_key` diabaikan di dalam transaksi,
 * migrasi ini sengaja berjalan DI LUAR transaksi (`$withinTransaction = false`).
 */
return new class extends Migration
{
    /** Bypass transaksi supaya PRAGMA SQLite benar-benar diterapkan. */
    public $withinTransaction = false;

    private const CHECK_NAME = 'alat_stok_non_negative';

    public function up(): void
    {
        if (! Schema::hasTable('alat')) {
            return;
        }

        if (DB::getDriverName() === 'sqlite') {
            $this->addSqliteCheckConstraint();
            $this->restoreAlatKategoriIndex();

            return;
        }

        if (DB::getDriverName() === 'mysql') {
            $this->addMysqlCheckConstraint();

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            $this->addPostgresCheckConstraint();
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('alat')) {
            return;
        }

        if (DB::getDriverName() === 'sqlite') {
            $this->addSqliteCheckConstraint(false);
            $this->restoreAlatKategoriIndex();

            return;
        }

        if (DB::getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE alat DROP CONSTRAINT IF EXISTS '.self::CHECK_NAME);

            return;
        }

        if (DB::getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE alat DROP CONSTRAINT IF EXISTS '.self::CHECK_NAME);
        }
    }

    /**
     * Rebuild tabel SQLite menghapus index turunan. Index kategori dibuat
     * ulang supaya query daftar alat tetap terindeks.
     */
    private function restoreAlatKategoriIndex(): void
    {
        if (Schema::hasIndex('alat', 'alat_kategori_id_index')) {
            return;
        }

        Schema::table('alat', function (Blueprint $blueprint) {
            $blueprint->index('kategori_id', 'alat_kategori_id_index');
        });
    }

    // ============================================================
    // POSTGRESQL
    // ============================================================

    private function addPostgresCheckConstraint(): void
    {
        $exists = DB::selectOne(
            "SELECT COUNT(*) AS total
               FROM pg_constraint
              WHERE conname = ?
                AND conrelid = 'alat'::regclass",
            [self::CHECK_NAME],
        );

        if ((int) ($exists->total ?? 0) > 0) {
            return;
        }

        DB::statement(
            'ALTER TABLE alat ADD CONSTRAINT '.self::CHECK_NAME.' CHECK (stok >= 0)'
        );
    }

    // ============================================================
    // SQLITE
    // ============================================================

    private function addSqliteCheckConstraint(bool $enable = true): void
    {
        if ($this->sqliteHasCheckConstraint() === $enable) {
            return;
        }

        $connection = DB::connection();
        $connection->statement('PRAGMA foreign_keys = OFF');
        $connection->statement('PRAGMA legacy_alter_table = ON');

        try {
            $connection->statement('DROP TABLE IF EXISTS alat__check_rebuild');
            $connection->statement($this->sqliteCreateStatement($enable));

            $connection->statement(
                'INSERT INTO alat__check_rebuild
                    (id, kategori_id, nama_alat, stok, kondisi, deskripsi, gambar)
                 SELECT id, kategori_id, nama_alat,
                        MAX(stok, 0), kondisi, deskripsi, gambar
                   FROM alat'
            );

            $connection->statement('DROP TABLE alat');
            $connection->statement('ALTER TABLE alat__check_rebuild RENAME TO alat');
        } finally {
            $connection->statement('DROP TABLE IF EXISTS alat__check_rebuild');
            $connection->statement('PRAGMA legacy_alter_table = OFF');
            $connection->statement('PRAGMA foreign_keys = ON');
        }
    }

    private function sqliteHasCheckConstraint(): bool
    {
        $sql = (string) DB::selectOne(
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'alat'"
        )->sql;

        return str_contains($sql, 'stok >= 0');
    }

    private function sqliteCreateStatement(bool $enable): string
    {
        $check = $enable
            ? 'CHECK ("stok" >= 0)'
            : '';

        return <<<SQL
            CREATE TABLE "alat__check_rebuild" (
                "id" integer NOT NULL PRIMARY KEY AUTOINCREMENT,
                "kategori_id" integer NOT NULL,
                "nama_alat" varchar NOT NULL,
                "stok" integer NOT NULL DEFAULT 0 {$check},
                "kondisi" varchar NOT NULL,
                "deskripsi" text NULL,
                "gambar" text NULL,
                CONSTRAINT "alat_kategori_id_foreign" FOREIGN KEY ("kategori_id")
                    REFERENCES "kategori" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
            )
            SQL;
    }

    // ============================================================
    // MYSQL / MARIA DB
    // ============================================================

    private function addMysqlCheckConstraint(): void
    {
        $exists = DB::selectOne(
            'SELECT COUNT(*) AS total
               FROM information_schema.table_constraints
              WHERE constraint_schema = DATABASE()
                AND table_name = \'alat\'
                AND constraint_name = ?',
            [self::CHECK_NAME],
        );

        if ((int) ($exists->total ?? 0) > 0) {
            return;
        }

        DB::statement(
            'ALTER TABLE alat ADD CONSTRAINT '.self::CHECK_NAME.' CHECK (stok >= 0)'
        );
    }
};
