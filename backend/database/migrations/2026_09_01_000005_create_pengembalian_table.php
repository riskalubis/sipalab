<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pengembalian', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('peminjaman_id');
            $table->string('tanggal_pengembalian');
            $table->string('kondisi');
            $table->text('catatan')->nullable();
            $table->string('status')->default('menunggu');

            $table->foreign('peminjaman_id')
                ->references('id')
                ->on('peminjaman')
                ->onDelete('CASCADE')
                ->onUpdate('CASCADE');

            $table->index('peminjaman_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pengembalian');
    }
};
