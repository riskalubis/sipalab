<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Tabel `users` SIPALAB tidak punya kolom name/email_verified_at/
     * remember_token dan tidak menggunakan timestamp.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'nama' => fake()->name(),
            'nim' => (string) fake()->unique()->numerify('2#########'),
            'kelas' => fake()->randomElement(['23TI-01', '23TI-02', '22DKV-01', '22DKV-02']),
            'no_hp' => fake()->numerify('08##########'),
            'email' => fake()->unique()->safeEmail(),
            'password' => static::$password ??= Hash::make('password'),
            'role' => 'mahasiswa',
            'foto' => null,
        ];
    }

    /**
     * Akun admin untuk pengujian endpoint khusus admin.
     */
    public function admin(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'admin',
        ]);
    }

    /**
     * Akun mahasiswa (sama seperti default, dipakai agar tes terbaca jelas).
     */
    public function mahasiswa(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'mahasiswa',
        ]);
    }
}
