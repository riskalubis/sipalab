<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Kategori extends Model
{
    public $timestamps = false;

    protected $table = 'kategori';

    protected $fillable = ['nama_kategori'];

    public function alat(): HasMany
    {
        return $this->hasMany(Alat::class, 'kategori_id');
    }
}
