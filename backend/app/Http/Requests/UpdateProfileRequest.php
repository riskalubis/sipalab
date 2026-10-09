<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    /**
     * Samakan email dengan aturan penyimpanan (lowercase, tanpa spasi)
     * sebelum divalidasi, supaya `unique` tidak bisa ditembus beda kapitalisasi.
     */
    protected function prepareForValidation(): void
    {
        if ($this->has('email')) {
            $this->merge([
                'email' => Str::lower(trim((string) $this->input('email'))),
            ]);
        }
    }

    public function authorize(): bool
    {
        $user = $this->user();

        if (! $user) {
            return false;
        }

        $targetId = (int) $this->input('id', 0);

        // `id` kosong dilaporkan oleh validasi sebagai 422, bukan 403.
        if ($targetId <= 0) {
            return true;
        }

        // Admin boleh mengubah profil siapa saja; mahasiswa hanya dirinya.
        return $user->isAdmin() || $targetId === (int) $user->id;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $user = $this->user();
        $targetId = (int) $this->input('id', 0);

        return [
            'id' => ['required', 'integer', 'min:1', Rule::exists('users', 'id')],
            'nama' => ['required', 'string', 'max:255'],
            'nim' => ['nullable', 'string', 'max:50'],
            'kelas' => ['nullable', 'string', 'max:100'],
            'no_hp' => ['nullable', 'string', 'max:30'],
            'email' => [
                'required',
                'string',
                'email',
                'max:255',
                Rule::unique('users', 'email')->ignore($targetId, 'id'),
            ],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'id.required' => 'Data pengguna tidak ditemukan.',
            'nama.required' => 'Nama wajib diisi.',
            'email.required' => 'Email wajib diisi.',
            'email.email' => 'Format email tidak valid.',
            'email.unique' => 'Email sudah digunakan akun lain.',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function payload(): array
    {
        return [
            'nama' => trim((string) $this->input('nama', '')),
            'nim' => $this->nullableString('nim'),
            'kelas' => $this->nullableString('kelas'),
            'no_hp' => $this->nullableString('no_hp'),
            'email' => trim((string) $this->input('email', '')),
        ];
    }

    private function nullableString(string $key): ?string
    {
        $value = $this->input($key);

        if ($value === null) {
            return null;
        }

        $value = trim((string) $value);

        return $value === '' ? null : $value;
    }
}
