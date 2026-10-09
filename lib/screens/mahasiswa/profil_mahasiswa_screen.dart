import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/foto_profil_service.dart';
import '../../services/offline_service.dart';
import '../../session/user_session.dart';
import '../../widgets/bantuan_sheet.dart';
import '../../widgets/profile_avatar.dart';
import '../login_screen.dart';
import '../server_settings_screen.dart';

class ProfilMahasiswaScreen extends StatefulWidget {
  const ProfilMahasiswaScreen({super.key});

  @override
  State<ProfilMahasiswaScreen> createState() => _ProfilMahasiswaScreenState();
}

class _ProfilMahasiswaScreenState extends State<ProfilMahasiswaScreen> {
  @override
  Widget build(BuildContext context) {
    final nama = UserSession.nama ?? 'Mahasiswa';
    final nim = UserSession.nim ?? '-';
    final kelas = UserSession.kelas ?? '-';
    final email = UserSession.email ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ==================================================
            // AVATAR & NAMA
            // ==================================================
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _ubahFotoProfil(context),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ProfileAvatar(
                          nama: nama,
                          fotoPath: UserSession.foto,
                          backgroundColor: Colors.teal,
                        ),

                        // Ikon kamera kecil sebagai penanda bisa di-ubah
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.photo_camera,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ketuk untuk mengubah foto',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nama,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'NIM: $nim',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  if (kelas != '-')
                    Text(
                      'Kelas: $kelas',
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ==================================================
            // INFORMASI AKUN
            // ==================================================
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Informasi Akun',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),

                  // Tombol edit informasi akun
                  IconButton(
                    onPressed: () => _editInfoAkun(context),
                    tooltip: 'Edit Informasi Akun',
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.teal,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileItem(Icons.person_outline, 'Nama', nama),
                    const Divider(),
                    _buildProfileItem(Icons.badge_outlined, 'NIM', nim),
                    const Divider(),
                    _buildProfileItem(Icons.school_outlined, 'Kelas', kelas),
                    const Divider(),
                    _buildProfileItem(Icons.email_outlined, 'Email', email),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // PENGATURAN
            // ==================================================
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pengaturan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // ==================================================
                  // ALAMAT SERVER
                  // ==================================================
                  ListTile(
                    leading: const Icon(Icons.dns_outlined, color: Colors.teal),
                    title: const Text('Alamat Server'),
                    subtitle: const Text(
                      'Sesuaikan IP server agar terhubung dari HP ini',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ServerSettingsScreen(),
                        ),
                      );
                    },
                  ),

                  const Divider(height: 1),

                  // ==================================================
                  // UBAH KATA SANDI
                  // ==================================================
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.teal),
                    title: const Text('Ubah Kata Sandi'),
                    subtitle: const Text('Ubah password akun kamu'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _ubahKataSandi(context);
                    },
                  ),

                  const Divider(height: 1),

                  // ==================================================
                  // BANTUAN
                  // ==================================================
                  ListTile(
                    leading: const Icon(Icons.help_outline, color: Colors.teal),
                    title: const Text('Bantuan & Dukungan'),
                    subtitle: const Text(
                      'Informasi bantuan penggunaan aplikasi',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showBantuan(context);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ==================================================
            // TOMBOL LOGOUT
            // ==================================================
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  _logout(context);
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'LOGOUT',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ITEM PROFIL
  // ============================================================

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.teal, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDIT INFORMASI AKUN
  // ============================================================

  Future<void> _editInfoAkun(BuildContext context) async {
    final berhasil = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _EditProfilDialog(),
    );

    if (berhasil == true && context.mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informasi akun berhasil diperbarui.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ============================================================
  // UBAH FOTO PROFIL
  // ============================================================

  Future<void> _ubahFotoProfil(BuildContext context) async {
    final userId = UserSession.userId;
    final email = UserSession.email;

    if (userId == null || email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data akun tidak ditemukan.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final pilihan = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.teal,
                ),
                title: const Text(
                  'Ambil Foto',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Menggunakan kamera'),
                onTap: () => Navigator.pop(sheetContext, 'kamera'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.teal,
                ),
                title: const Text(
                  'Pilih dari Galeri',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Mengambil dari penyimpanan perangkat'),
                onTap: () => Navigator.pop(sheetContext, 'galeri'),
              ),
              if (UserSession.foto != null && UserSession.foto!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Hapus Foto',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text('Kembalikan ke avatar huruf awal'),
                  onTap: () => Navigator.pop(sheetContext, 'hapus'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (pilihan == null || !mounted) return;

    try {
      if (pilihan == 'hapus') {
        await FotoProfilService.hapusFotoTersimpan(UserSession.foto);
        await _simpanFotoPath(email, null);
      } else {
        final source =
            pilihan == 'kamera' ? ImageSource.camera : ImageSource.gallery;

        final pathBaru = await FotoProfilService.pilihDanSimpanFoto(
          userId: '$userId',
          source: source,
        );

        if (pathBaru == null) return;

        final fotoLama = UserSession.foto;

        await _simpanFotoPath(email, pathBaru);
        await FotoProfilService.hapusFotoTersimpan(fotoLama);
      }

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui foto profil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // SIMPAN PATH FOTO KE DATABASE + SESSION
  // ============================================================

  Future<void> _simpanFotoPath(String email, String? path) async {
    await ApiService.putMap('/users/foto', {
      'email': email,
      'foto': path,
    });

    UserSession.foto = path;
  }

  // ============================================================
  // UBAH KATA SANDI
  // ============================================================

  Future<void> _ubahKataSandi(BuildContext context) async {
    final berhasil = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _UbahKataSandiDialog(),
    );

    // ============================================================
    // PESAN BERHASIL
    // ============================================================
    // SnackBar ditampilkan setelah dialog benar-benar tertutup,
    // lewat context halaman (bukan context dialog).

    if (berhasil == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata sandi berhasil diubah.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Apakah kamu yakin ingin keluar dari akun?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ApiService.logout();
                if (!context.mounted) return;

                // Bersihkan session
                UserSession.clear();
                ApiService.clearRequestCache();
                OfflineService.instance.clearLogin();
                OfflineService.instance.clearAll();

                // Tutup dialog
                Navigator.pop(dialogContext);

                // Kembali ke Login
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BANTUAN
  // ============================================================

  void _showBantuan(BuildContext context) {
    showBantuanSheet(
      context,
      primaryColor: Colors.teal,
      subtitle: 'Punya kendala saat meminjam atau mengembalikan alat? '
          'Hubungi Customer Service kami lewat WhatsApp.',
    );
  }
}

// ============================================================
// DIALOG UBAH KATA SANDI
// ============================================================
//
// Controller dibuat & dibuang di dalam State dialog sendiri
// (bukan di-dispose manual setelah showDialog) supaya tidak pernah
// dibuang selagi elemen dialog masih hidup / belum selesai unmount.
// Cara lama memicu assertion framework '_dependents.isEmpty'.

class _UbahKataSandiDialog extends StatefulWidget {
  const _UbahKataSandiDialog();

  @override
  State<_UbahKataSandiDialog> createState() => _UbahKataSandiDialogState();
}

class _UbahKataSandiDialogState extends State<_UbahKataSandiDialog> {
  final _formKey = GlobalKey<FormState>();

  final _passwordLamaController = TextEditingController();
  final _passwordBaruController = TextEditingController();
  final _konfirmasiController = TextEditingController();

  bool _obscureLama = true;
  bool _obscureBaru = true;
  bool _obscureKonfirmasi = true;

  bool _isSaving = false;

  @override
  void dispose() {
    _passwordLamaController.dispose();
    _passwordBaruController.dispose();
    _konfirmasiController.dispose();
    super.dispose();
  }

  // ============================================================
  // SIMPAN PASSWORD BARU
  // ============================================================

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final email = UserSession.email;

      if (email == null || email.isEmpty) {
        throw Exception('Email akun tidak ditemukan.');
      }

      // ========================================================
      // UBAH PASSWORD LEWAT API
      // ========================================================
      // Backend memeriksa password lama & mengupdate password.
      // Bila password lama salah, backend mengembalikan pesan
      // "Password lama salah."
      // ========================================================

      await ApiService.putMap('/users/password', {
        'email': email,
        'password_lama': _passwordLamaController.text,
        'password_baru': _passwordBaruController.text,
      });

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah kata sandi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah Kata Sandi'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PASSWORD LAMA
              TextFormField(
                controller: _passwordLamaController,
                obscureText: _obscureLama,
                decoration: InputDecoration(
                  labelText: 'Password Lama',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureLama
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureLama = !_obscureLama;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password lama wajib diisi';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // PASSWORD BARU
              TextFormField(
                controller: _passwordBaruController,
                obscureText: _obscureBaru,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureBaru
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureBaru = !_obscureBaru;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password baru wajib diisi';
                  }

                  if (value.length < 6) {
                    return 'Minimal 6 karakter';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // KONFIRMASI PASSWORD
              TextFormField(
                controller: _konfirmasiController,
                obscureText: _obscureKonfirmasi,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKonfirmasi
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureKonfirmasi = !_obscureKonfirmasi;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Konfirmasi password wajib diisi';
                  }

                  if (value != _passwordBaruController.text) {
                    return 'Password tidak sama';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _simpan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

// ============================================================
// DIALOG EDIT INFORMASI AKUN
// ============================================================
//
// Mengubah nama, NIM, kelas, dan email.
// Email ikut diperbarui di session agar login foto & ubah
// password tetap memakai email terbaru. Wajib unik.

class _EditProfilDialog extends StatefulWidget {
  const _EditProfilDialog();

  @override
  State<_EditProfilDialog> createState() => _EditProfilDialogState();
}

class _EditProfilDialogState extends State<_EditProfilDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _namaController;
  late final TextEditingController _nimController;
  late final TextEditingController _kelasController;
  late final TextEditingController _emailController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: UserSession.nama ?? '');
    _nimController = TextEditingController(text: UserSession.nim ?? '');
    _kelasController = TextEditingController(text: UserSession.kelas ?? '');
    _emailController = TextEditingController(text: UserSession.email ?? '');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nimController.dispose();
    _kelasController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ============================================================
  // SIMPAN PERUBAHAN
  // ============================================================

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = UserSession.userId;

      if (userId == null) {
        throw Exception('Data akun tidak ditemukan.');
      }

      final nama = _namaController.text.trim();
      final nim = _nimController.text.trim();
      final kelas = _kelasController.text.trim();
      final email = _emailController.text.trim();

      // ========================================================
      // UPDATE PROFIL LEWAT API
      // ========================================================
      // Backend memeriksa duplikasi email lalu mengupdate profil.
      // Bila email sudah dipakai akun lain, backend mengembalikan
      // pesan "Email sudah digunakan akun lain."
      // ========================================================

      await ApiService.putMap('/users/update', {
        'id': userId,
        'nama': nama,
        'nim': nim,
        'kelas': kelas,
        'email': email,
      });

      UserSession.nama = nama;
      UserSession.nim = nim;
      UserSession.kelas = kelas;
      UserSession.email = email;

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui informasi akun: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _dekorasi({
    required IconData icon,
    required String label,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Informasi Akun'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // NAMA
              TextFormField(
                controller: _namaController,
                textCapitalization: TextCapitalization.words,
                decoration: _dekorasi(
                  icon: Icons.person_outline,
                  label: 'Nama Lengkap',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama wajib diisi';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // NIM
              TextFormField(
                controller: _nimController,
                decoration: _dekorasi(
                  icon: Icons.badge_outlined,
                  label: 'NIM',
                ),
              ),

              const SizedBox(height: 14),

              // KELAS
              TextFormField(
                controller: _kelasController,
                decoration: _dekorasi(
                  icon: Icons.school_outlined,
                  label: 'Kelas',
                ),
              ),

              const SizedBox(height: 14),

              // EMAIL
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _dekorasi(
                  icon: Icons.email_outlined,
                  label: 'Email',
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';

                  if (email.isEmpty) {
                    return 'Email wajib diisi';
                  }

                  final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');

                  if (!regex.hasMatch(email)) {
                    return 'Format email tidak valid';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _simpan,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
