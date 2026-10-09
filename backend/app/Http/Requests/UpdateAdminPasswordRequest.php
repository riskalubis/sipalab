<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateAdminPasswordRequest extends FormRequest
{
    /**
     * Hanya admin yang boleh mengganti password lewat endpoint ini, dan
     * targetnya adalah akun admin yang sedang login (bukan "admin pertama
     * yang ditemukan di database").
     */
    public function authorize(): bool
    {
        $user = $this->user();

        return $user !== null && $user->isAdmin();
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'password_lama' => ['required', 'string', 'max:255'],
            'password_baru' => ['required', 'string', 'min:6', 'max:255', 'different:password_lama'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'password_lama.required' => 'Kata sandi lama wajib diisi.',
            'password_baru.required' => 'Kata sandi baru wajib diisi.',
            'password_baru.min' => 'Kata sandi baru minimal 6 karakter.',
            'password_baru.different' => 'Kata sandi baru harus berbeda dari kata sandi lama.',
        ];
    }
}
