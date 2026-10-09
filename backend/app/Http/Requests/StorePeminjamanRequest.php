<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StorePeminjamanRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();

        if (! $user) {
            return false;
        }

        $targetId = (int) $this->input('user_id', 0);

        // `user_id` kosong tidak perlu ditolak di sini — biarkan aturan
        // validasi yang melaporkannya sebagai 422, bukan 403.
        if ($targetId <= 0) {
            return true;
        }

        // Mahasiswa hanya boleh mengajukan atas namanya sendiri; admin boleh
        // mengajukan untuk mahasiswa mana pun (dipakai untuk input manual).
        return $user->isAdmin() || $targetId === (int) $user->id;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'user_id' => ['required', 'integer', 'min:1', 'exists:users,id'],
            'tanggal_pinjam' => ['required', 'date'],
            'tanggal_kembali' => ['required', 'date', 'after_or_equal:tanggal_pinjam'],
            'keperluan' => ['required', 'string', 'max:1000'],
            'catatan' => ['nullable', 'string', 'max:1000'],
            'detail' => ['required', 'array', 'min:1', 'max:50'],
            'detail.*.alat_id' => ['required', 'integer', 'min:1', 'exists:alat,id'],
            'detail.*.jumlah' => ['required', 'integer', 'min:1', 'max:1000000'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'user_id.required' => 'Data pengguna tidak ditemukan.',
            'user_id.exists' => 'Data pengguna tidak ditemukan.',
            'tanggal_pinjam.required' => 'Tanggal pinjam wajib diisi.',
            'tanggal_pinjam.date' => 'Tanggal pinjam tidak valid.',
            'tanggal_kembali.required' => 'Tanggal kembali wajib diisi.',
            'tanggal_kembali.date' => 'Tanggal kembali tidak valid.',
            'tanggal_kembali.after_or_equal' => 'Tanggal kembali tidak boleh lebih awal dari tanggal pinjam.',
            'keperluan.required' => 'Keperluan peminjaman wajib diisi.',
            'detail.required' => 'Detail peminjaman tidak boleh kosong.',
            'detail.min' => 'Detail peminjaman tidak boleh kosong.',
            'detail.*.alat_id.required' => 'Alat tidak ditemukan.',
            'detail.*.alat_id.exists' => 'Alat tidak ditemukan.',
            'detail.*.jumlah.required' => 'Jumlah alat pada peminjaman tidak valid.',
            'detail.*.jumlah.min' => 'Jumlah alat pada peminjaman tidak valid.',
        ];
    }
}
