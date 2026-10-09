<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class SetujuiPengembalianRequest extends FormRequest
{
    public function authorize(): bool
    {
        return (bool) $this->user()?->isAdmin();
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            // Flutter mengirim peminjaman_id agar frontend bisa memastikan
            // kartu yang ditekan memang milik pengajuan tersebut.
            'peminjaman_id' => ['required', 'integer', 'min:1'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'peminjaman_id.required' => 'Data pengembalian tidak cocok.',
        ];
    }
}
