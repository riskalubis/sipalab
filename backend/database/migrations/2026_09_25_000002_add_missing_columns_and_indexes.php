<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Menambahkan kolom & index yang dipakai aplikasi Flutter tetapi belum ada
 * di skema SIPALAB, plus index pendukung query.
 *
 * Semua operasi dibuat idempoten sehingga migrasi ini aman dijalankan pada
 * database lama yang sudah terisi (forward migration) maupun pada database
 * kosong hasil `migrate:fresh`.
 */
return new class extends Migration
{
    public function up(): void
    {
        // ---------------------------------------------------------------
        // users.no_hp — sudah dibaca model User dari Flutter (no_hp).
        // ---------------------------------------------------------------
        if (! Schema::hasColumn('users', 'no_hp')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('no_hp', 30)->nullable()->after('kelas');
            });
        }

        // ---------------------------------------------------------------
        // peminjaman.catatan — kolom catatan pada pengajuan peminjaman.
        // ---------------------------------------------------------------
        if (! Schema::hasColumn('peminjaman', 'catatan')) {
            Schema::table('peminjaman', function (Blueprint $table) {
                $table->text('catatan')->nullable();
            });
        }

        // ---------------------------------------------------------------
        // Index pendukung query.
        // ---------------------------------------------------------------
        $this->addIndex('users', 'role', 'users_role_index');
        $this->addIndex('users', 'nim', 'users_nim_index');
        $this->addIndex('alat', 'kategori_id', 'alat_kategori_id_index');
        $this->addIndex('detail_peminjaman', 'alat_id', 'detail_peminjaman_alat_id_index');
        $this->addIndex('pengembalian', 'status', 'pengembalian_status_index');
        $this->addIndex('pengembalian', ['peminjaman_id', 'status'], 'pengembalian_peminjaman_id_status_index');
    }

    public function down(): void
    {
        $this->dropIndexIfExists('users', 'users_role_index');
        $this->dropIndexIfExists('users', 'users_nim_index');
        $this->dropIndexIfExists('alat', 'alat_kategori_id_index');
        $this->dropIndexIfExists('detail_peminjaman', 'detail_peminjaman_alat_id_index');
        $this->dropIndexIfExists('pengembalian', 'pengembalian_status_index');
        $this->dropIndexIfExists('pengembalian', 'pengembalian_peminjaman_id_status_index');

        if (Schema::hasColumn('users', 'no_hp')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('no_hp');
            });
        }

        if (Schema::hasColumn('peminjaman', 'catatan')) {
            Schema::table('peminjaman', function (Blueprint $table) {
                $table->dropColumn('catatan');
            });
        }
    }

    /**
     * Hapus index bila ada (dipakai saat rollback).
     */
    private function dropIndexIfExists(string $table, string $name): void
    {
        if (! Schema::hasTable($table) || ! Schema::hasIndex($table, $name)) {
            return;
        }

        Schema::table($table, function (Blueprint $blueprint) use ($name) {
            $blueprint->dropIndex($name);
        });
    }

    /**
     * Tambahkan index bila belum ada.
     */
    private function addIndex(string $table, string|array $columns, string $name): void
    {
        if (! Schema::hasTable($table)) {
            return;
        }

        if (Schema::hasIndex($table, $name)) {
            return;
        }

        $column = is_array($columns) ? $columns[0] : $columns;

        if (! Schema::hasColumn($table, $column)) {
            return;
        }

        Schema::table($table, function (Blueprint $blueprint) use ($columns, $name) {
            $blueprint->index($columns, $name);
        });
    }
};
