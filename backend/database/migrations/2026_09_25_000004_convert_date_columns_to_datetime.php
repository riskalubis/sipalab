<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

/**
 * Mengubah kolom tanggal yang sebelumnya disimpan sebagai VARCHAR menjadi
 * kolom DATE_TIME yang sesungguhnya.
 *
 * Data lama sudah berisi string ISO-8601 (mis. "2026-09-18T00:00:00.000"
 * dari `DateTime.toIso8601String()` di Flutter), jadi langkah pertama adalah
 * menormalkan setiap nilai menjadi format kanonik `Y-m-d H:i:s` milik
 * database. Nilai kosong/tidak terbaca diisi tanggal migrasi berjalan dan
 * dilaporkan lewat log, supaya tidak ada data yang hilang diam-diam.
 */
return new class extends Migration
{
    /** Format kanonik yang dipakai kolom date_time. */
    private const STORAGE_FORMAT = 'Y-m-d H:i:s';

    public function up(): void
    {
        $this->normaliseDates('peminjaman', ['tanggal_pinjam', 'tanggal_kembali']);
        $this->normaliseDates('pengembalian', ['tanggal_pengembalian']);

        $this->changeToDateTime('peminjaman', 'tanggal_pinjam');
        $this->changeToDateTime('peminjaman', 'tanggal_kembali');
        $this->changeToDateTime('pengembalian', 'tanggal_pengembalian');
    }

    public function down(): void
    {
        // Kembalikan ke VARCHAR tanpa mengubah isi data.
        $this->changeToString('peminjaman', 'tanggal_pinjam');
        $this->changeToString('peminjaman', 'tanggal_kembali');
        $this->changeToString('pengembalian', 'tanggal_pengembalian');
    }

    // ============================================================
    // NORMALISASI DATA
    // ============================================================

    /**
     * @param  array<int, string>  $columns
     */
    private function normaliseDates(string $table, array $columns): void
    {
        if (! Schema::hasTable($table)) {
            return;
        }

        $present = array_values(array_filter(
            $columns,
            fn (string $column) => Schema::hasColumn($table, $column),
        ));

        if ($present === []) {
            return;
        }

        $rows = DB::table($table)->select(array_merge(['id'], $present))->get();
        $fallback = now()->startOfSecond();
        $repaired = 0;

        foreach ($rows as $row) {
            $updates = [];

            foreach ($present as $column) {
                $value = $row->{$column};

                if ($value === null) {
                    $updates[$column] = $fallback->format(self::STORAGE_FORMAT);
                    $repaired++;

                    continue;
                }

                $value = trim((string) $value);

                if ($value === '') {
                    $updates[$column] = $fallback->format(self::STORAGE_FORMAT);
                    $repaired++;

                    continue;
                }

                try {
                    $parsed = Carbon::parse($value);
                } catch (Throwable) {
                    $updates[$column] = $fallback->format(self::STORAGE_FORMAT);
                    $repaired++;

                    continue;
                }

                $canonical = $parsed->format(self::STORAGE_FORMAT);

                if ($canonical !== $value) {
                    $updates[$column] = $canonical;
                }
            }

            if ($updates !== []) {
                DB::table($table)->where('id', $row->id)->update($updates);
            }
        }

        if ($repaired > 0) {
            Log::warning(
                "SIPALAB migration: {$repaired} nilai tanggal tidak terbaca pada tabel "
                ."{$table} diisi dengan tanggal migrasi ({$fallback->format(self::STORAGE_FORMAT)})."
            );
        }
    }

    // ============================================================
    // PERUBAHAN TIPE KOLOM
    // ============================================================

    private function changeToDateTime(string $table, string $column): void
    {
        if (! Schema::hasTable($table) || ! Schema::hasColumn($table, $column)) {
            return;
        }

        Schema::table($table, function (Blueprint $blueprint) use ($column) {
            $blueprint->dateTime($column)->change();
        });
    }

    private function changeToString(string $table, string $column): void
    {
        if (! Schema::hasTable($table) || ! Schema::hasColumn($table, $column)) {
            return;
        }

        Schema::table($table, function (Blueprint $blueprint) use ($column) {
            $blueprint->string($column)->change();
        });
    }
};
