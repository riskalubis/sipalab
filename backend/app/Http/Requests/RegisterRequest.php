<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Normalkan email sebelum validasi agar pengecekan `unique` dan hasil
     * simpanannya konsisten (selalu lowercase tanpa spasi).
     */
    protected function prepareForValidation(): void
    {
        if ($this->has('email')) {
            $this->merge([
                'email' => Str::lower(trim((string) $this->input('email'))),
            ]);
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'nama' => ['required', 'string', 'max:255'],
            'nim' => ['nullable', 'string', 'max:50'],
            'kelas' => ['nullable', 'string', 'max:100'],
            'no_hp' => ['nullable', 'string', 'max:30'],
            'email' => [
                'required',
                'string',
                'email',
                'max:255',
                Rule::unique('users', 'email'),
            ],
            'password' => ['required', 'string', 'min:6', 'max:255'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'nama.required' => 'Nama wajib diisi.',
            'email.required' => 'Email wajib diisi.',
            'email.email' => 'Format email tidak valid.',
            'email.unique' => 'Email sudah digunakan akun lain.',
            'password.required' => 'Password wajib diisi.',
            'password.min' => 'Password minimal 6 karakter.',
        ];
    }

    /**
     * Data yang benar-benar disimpan. `role`, `id`, dan `foto` sengaja
     * diabaikan supaya klien tidak bisa mendaftarkan akun admin.
     *
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
            'password' => (string) $this->input('password', ''),
            'role' => 'mahasiswa',
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
