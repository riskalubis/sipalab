<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Pengembalian extends Model
{
    public $timestamps = false;

    protected $table = 'pengembalian';

    public const STATUS_MENUNGGU = 'menunggu';

    public const STATUS_DISETUJUI = 'disetujui';

    public const STATUS_DITOLAK = 'ditolak';

    protected $fillable = [
        'peminjaman_id',
        'tanggal_pengembalian',
        'kondisi',
        'catatan',
        'status',
        'pending_peminjaman_id',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'peminjaman_id' => 'integer',
            'pending_peminjaman_id' => 'integer',
            'tanggal_pengembalian' => 'datetime',
        ];
    }

    /**
     * Kolom `pending_peminjaman_id` memakai unique index untuk membatasi
     * maksimal satu pengajuan berstatus `menunggu` per peminjaman. Nilai
     * selalu disinkronkan dari `status` saat model disimpan.
     */
    protected static function booted(): void
    {
        static::saving(function (self $pengembalian): void {
            $pending = strtolower((string) $pengembalian->status) === self::STATUS_MENUNGGU;

            $pengembalian->pending_peminjaman_id = $pending
                ? $pengembalian->peminjaman_id
                : null;
        });
    }

    public function peminjaman(): BelongsTo
    {
        return $this->belongsTo(Peminjaman::class, 'peminjaman_id');
    }
}
