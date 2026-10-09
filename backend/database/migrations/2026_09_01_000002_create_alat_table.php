<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('alat', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('kategori_id');
            $table->string('nama_alat');
            $table->integer('stok')->default(0);
            $table->string('kondisi');
            $table->text('deskripsi')->nullable();
            $table->text('gambar')->nullable();

            $table->foreign('kategori_id')
                ->references('id')
                ->on('kategori')
                ->onDelete('RESTRICT')
                ->onUpdate('CASCADE');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('alat');
    }
};
