<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StorePengembalianRequest extends FormRequest
{
    public function authorize(): bool
    {
        return (bool) $this->user();
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'peminjaman_id' => ['required', 'integer', 'min:1', 'exists:peminjaman,id'],
            'tanggal_pengembalian' => ['required', 'date'],
            'kondisi' => ['required', 'string', 'max:100'],
            'catatan' => ['nullable', 'string', 'max:1000'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'peminjaman_id.required' => 'Data peminjaman tidak ditemukan.',
            'peminjaman_id.exists' => 'Data peminjaman tidak ditemukan.',
            'tanggal_pengembalian.required' => 'Tanggal pengembalian wajib diisi.',
            'tanggal_pengembalian.date' => 'Tanggal pengembalian tidak valid.',
            'kondisi.required' => 'Kondisi alat wajib diisi.',
        ];
    }
}
