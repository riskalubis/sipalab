<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * Tabel `users` memang tidak memakai created_at/updated_at.
     */
    public $timestamps = false;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'nama',
        'nim',
        'kelas',
        'no_hp',
        'email',
        'password',
        'role',
        'foto',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Cast kolom. `hashed` membuat Laravel mem-bcrypt password secara
     * otomatis, sehingga tidak ada jalur kode yang bisa menyimpan teks biasa.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'password' => 'hashed',
        ];
    }

    // ============================================================
    // NORMALISASI EMAIL
    // ============================================================

    /**
     * Email selalu disimpan lowercase + tanpa spasi agar pencocokan login
     * (`Str::lower`) selalu konsisten dan tidak ada duplikat beda kapitalisasi.
     *
     * @return Attribute<string, string|null>
     */
    protected function email(): Attribute
    {
        return Attribute::make(
            set: fn (?string $value): ?string => $value === null
                ? null
                : Str::lower(trim($value)),
        );
    }

    // ============================================================
    // RELASI
    // ============================================================

    public function peminjaman()
    {
        return $this->hasMany(Peminjaman::class, 'user_id');
    }

    // ============================================================
    // PEMBANTU ROLE
    // ============================================================

    public function isAdmin(): bool
    {
        return strtolower((string) $this->role) === 'admin';
    }

    public function isMahasiswa(): bool
    {
        return ! $this->isAdmin();
    }
}
