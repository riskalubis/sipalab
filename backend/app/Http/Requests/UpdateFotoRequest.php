<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateFotoRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();

        if (! $user) {
            return false;
        }

        $email = trim((string) $this->input('email', ''));

        // Email kosong dilaporkan oleh validasi sebagai 422, bukan 403.
        if ($email === '') {
            return true;
        }

        return $user->isAdmin() || strcasecmp($email, (string) $user->email) === 0;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'email', 'max:255', Rule::exists('users', 'email')],
            // Aplikasi menyimpan path file foto (bukan base64), jadi cukup
            // dibatasi panjangnya agar tidak monstrous.
            'foto' => ['present', 'nullable', 'string', 'max:2048'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'email.required' => 'Email wajib diisi.',
            'email.exists' => 'Data pengguna tidak ditemukan.',
            'foto.present' => 'Foto profil wajib diisi.',
        ];
    }
}
