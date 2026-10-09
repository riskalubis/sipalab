<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdatePasswordRequest extends FormRequest
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
            'email.required' => 'Email wajib diisi.',
            'email.exists' => 'Data pengguna tidak ditemukan.',
            'password_lama.required' => 'Password lama wajib diisi.',
            'password_baru.required' => 'Password baru wajib diisi.',
            'password_baru.min' => 'Password baru minimal 6 karakter.',
            'password_baru.different' => 'Password baru harus berbeda dari password lama.',
        ];
    }
}
