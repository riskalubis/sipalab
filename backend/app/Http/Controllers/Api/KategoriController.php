<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreKategoriRequest;
use App\Models\Kategori;
use Illuminate\Http\JsonResponse;

class KategoriController extends Controller
{
    /**
     * PUBLIK: endpoint ini dipakai aplikasi Flutter sebagai probe koneksi
     * (lihat `ApiService.testConnection`) sebelum pengguna login, jadi
     * harus bisa diakses tanpa bearer token.
     */
    public function index(): JsonResponse
    {
        return response()->json(
            Kategori::orderBy('id')->get(['id', 'nama_kategori'])->toArray(),
        );
    }

    public function store(StoreKategoriRequest $request): JsonResponse
    {
        $kategori = Kategori::create([
            'nama_kategori' => trim((string) $request->input('nama_kategori', '')),
        ]);

        return response()->json(['id' => $kategori->id], 201);
    }
}
