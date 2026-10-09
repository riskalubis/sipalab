$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:8123/api'

function Show($label, $resp) {
  Write-Output "--- $label [$($resp.StatusCode)]"
  $t = $resp.Content
  if ($t.Length -gt 320) { $t = $t.Substring(0,320) + '...' }
  Write-Output "    $t"
}

# 1. Probe koneksi publik (dipakai Flutter)
Show 'GET /kategori (publik)' (Invoke-WebRequest "$base/kategori" -UseBasicParsing)
Show 'GET /health (publik)'  (Invoke-WebRequest "$base/health"  -UseBasicParsing)

# 2. Endpoint terlindungi tanpa token
try { Invoke-WebRequest "$base/alat" -UseBasicParsing | Out-Null }
catch { Show 'GET /alat tanpa token' $_.Exception.Response }

# 3. Login admin
$admin = Invoke-RestMethod "$base/login" -Method Post -ContentType 'application/json' `
  -Body (@{email='admin@labkamp.com'; password='admkamp'} | ConvertTo-Json)
Write-Output "--- login admin status=$($admin.status) token_len=$($admin.token.Length) user_email=$($admin.user.email) role=$($admin.user.role)"
$adminToken = $admin.token

# 4. Login mahasiswa
$mhs = Invoke-RestMethod "$base/login" -Method Post -ContentType 'application/json' `
  -Body (@{email='budi@labkamp.com'; password='mhs12345'} | ConvertTo-Json)
Write-Output "--- login budi status=$($mhs.status) token_len=$($mhs.token.Length)"
$mhsToken = $mhs.token

# 5. Password salah
Show 'login password salah' (Invoke-WebRequest "$base/login" -Method Post -ContentType 'application/json' `
  -Body (@{email='budi@labkamp.com'; password='salah'} | ConvertTo-Json) -UseBasicParsing)

# 6. Mahasiswa mencoba endpoint admin -> 403
try { Invoke-WebRequest "$base/home/admin" -Headers @{Authorization="Bearer $mhsToken"} -UseBasicParsing | Out-Null }
catch { Show 'mahasiswa -> /home/admin' $_.Exception.Response }

# 7. Admin dashboard
$dash = Invoke-RestMethod "$base/home/admin" -Headers @{Authorization="Bearer $adminToken"}
Write-Output "--- dashboard: total_alat=$($dash.total_alat) stok=$($dash.stok_tersedia) dipinjam=$($dash.dipinjam) menunggu=$($dash.menunggu) notif_pg=$($dash.notifikasi_pengembalian.Count)"

# 8. Daftar alat + stok
$alat = Invoke-RestMethod "$base/alat" -Headers @{Authorization="Bearer $mhsToken"}
Write-Output "--- alat count=$($alat.Count); contoh:"
$alat | Select-Object -First 3 | ForEach-Object { "    $($_.nama_alat) stok=$($_.stok) dipesan=$($_.stok_dipesan) kelas_peminjam='$($_.kelas_peminjam)' kategori=$($_.nama_kategori)" }

# 9. Validasi: peminjaman kosong -> 422
try { Invoke-WebRequest "$base/peminjaman" -Method Post -Headers @{Authorization="Bearer $mhsToken"} -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null }
catch { Show 'POST /peminjaman {} -> 422?' $_.Exception.Response }

# 10. Buat peminjaman baru (duplikat alat_id dinormalkan)
$body = @{
  user_id = 2
  tanggal_pinjam = '2026-09-25T00:00:00.000'
  tanggal_kembali = '2026-09-28T00:00:00.000'
  keperluan = 'Uji otomatis dari PowerShell'
  catatan = 'catatan uji'
  detail = @(@{alat_id=3; jumlah=1}, @{alat_id=3; jumlah=2})
} | ConvertTo-Json -Depth 5
$p = Invoke-RestMethod "$base/peminjaman" -Method Post -Headers @{Authorization="Bearer $mhsToken"} -ContentType 'application/json' -Body $body
Write-Output "--- buat peminjaman id=$($p.id) status=$($p.status)"

$detail = Invoke-RestMethod "$base/peminjaman/$($p.id)/detail" -Headers @{Authorization="Bearer $mhsToken"}
Write-Output "--- detail (gabung duplikat): alat_id=$($detail.alat_id) jumlah=$($detail.jumlah) (harus 3) tanggal_pinjam=$($detail.tanggal_pinjam) tgl_pinjam=$($detail.tgl_pinjam)"

# 11. Stok setelah disetujui
$before = (Invoke-RestMethod "$base/alat/3/stok-tersedia" -Headers @{Authorization="Bearer $mhsToken"})
Invoke-RestMethod "$base/peminjaman/$($p.id)/status" -Method Put -Headers @{Authorization="Bearer $adminToken"} `
  -ContentType 'application/json' -Body (@{status='disetujui'} | ConvertTo-Json) | Out-Null
$after = (Invoke-RestMethod "$base/alat/3/stok-tersedia" -Headers @{Authorization="Bearer $mhsToken"})
Write-Output "--- stok alat 3: sebelum=$($before.stok) sesudah=$($after.stok) (turun 3)"

# 12. Pengembalian ganda ditolak
$pgBody = @{peminjaman_id=$p.id; tanggal_pengembalian='2026-09-28T09:00:00.000'; kondisi='Baik'; catatan='ok'} | ConvertTo-Json
$pg = Invoke-RestMethod "$base/pengembalian" -Method Post -Headers @{Authorization="Bearer $mhsToken"} -ContentType 'application/json' -Body $pgBody
Write-Output "--- pengembalian id=$($pg.id)"
try { Invoke-WebRequest "$base/pengembalian" -Method Post -Headers @{Authorization="Bearer $mhsToken"} -ContentType 'application/json' -Body $pgBody -UseBasicParsing | Out-Null }
catch { Show 'pengembalian ganda -> 422?' $_.Exception.Response }

# 13. Setujui pengembalian -> stok kembali + status selesai
Invoke-RestMethod "$base/pengembalian/$($pg.id)/setujui" -Method Put -Headers @{Authorization="Bearer $adminToken"} `
  -ContentType 'application/json' -Body (@{peminjaman_id=$p.id} | ConvertTo-Json) | Out-Null
$back = (Invoke-RestMethod "$base/alat/3/stok-tersedia" -Headers @{Authorization="Bearer $mhsToken"})
$row = Invoke-RestMethod "$base/peminjaman/$($p.id)/detail" -Headers @{Authorization="Bearer $mhsToken"}
Write-Output "--- stok alat 3 setelah kembali=$($back.stok) (kembali ke $($before.stok)); status peminjaman=$($row.status) (harus selesai)"

# 14. Aktif harus kosong
$aktif = Invoke-RestMethod "$base/peminjaman/aktif/2" -Headers @{Authorization="Bearer $mhsToken"}
Write-Output "--- peminjaman aktif budi setelah selesai: $($aktif.Count) (harus 0)"

# 15. CORS preflight (Flutter Web)
try {
  $cors = Invoke-WebRequest "$base/alat" -Method Options -Headers @{Origin='http://localhost:52400'; 'Access-Control-Request-Method'='GET'} -UseBasicParsing
  Show 'CORS preflight' $cors
} catch { Show 'CORS preflight' $_.Exception.Response }

# 16. Register duplikat -> 422
try { Invoke-WebRequest "$base/register" -Method Post -ContentType 'application/json' -Body (@{nama='X'; email='budi@labkamp.com'; password='mhs12345'} | ConvertTo-Json) -UseBasicParsing | Out-Null }
catch { Show 'register email duplikat' $_.Exception.Response }

# 17. Ganti password admin
Show 'admin ganti password (lama salah)' (Invoke-WebRequest "$base/users/admin/password" -Method Put -Headers @{Authorization="Bearer $adminToken"} `
  -ContentType 'application/json' -Body (@{password_lama='salah'; password_baru='admkampbaru'} | ConvertTo-Json) -UseBasicParsing)

Write-Output "=== E2E SELESAI ==="
