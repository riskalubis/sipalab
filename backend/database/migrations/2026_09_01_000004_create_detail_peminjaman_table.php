<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('detail_peminjaman', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('peminjaman_id');
            $table->unsignedBigInteger('alat_id');
            $table->integer('jumlah');

            $table->foreign('peminjaman_id')
                ->references('id')
                ->on('peminjaman')
                ->onDelete('CASCADE')
                ->onUpdate('CASCADE');

            $table->foreign('alat_id')
                ->references('id')
                ->on('alat')
                ->onDelete('RESTRICT')
                ->onUpdate('CASCADE');

            $table->index(['peminjaman_id', 'alat_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('detail_peminjaman');
    }
};
