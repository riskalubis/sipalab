import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class UbahPasswordAdminScreen extends StatefulWidget {
  const UbahPasswordAdminScreen({super.key});

  @override
  State<UbahPasswordAdminScreen> createState() =>
      _UbahPasswordAdminScreenState();
}

class _UbahPasswordAdminScreenState extends State<UbahPasswordAdminScreen> {
  final _formKey = GlobalKey<FormState>();

  final _passwordLamaController = TextEditingController();
  final _passwordBaruController = TextEditingController();
  final _konfirmasiController = TextEditingController();

  bool _isLoading = false;

  bool _obscureLama = true;
  bool _obscureBaru = true;
  bool _obscureKonfirmasi = true;

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

  Future<void> _ubahPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Ubah kata sandi admin lewat API.
      //
      // Backend mengambil akun admin (role 'admin'), memeriksa
      // kata sandi lama, lalu memperbarui kata sandinya.
      // Bila kata sandi lama salah, backend mengembalikan pesan
      // "Kata sandi lama salah.".
      await ApiService.putMap('/users/admin/password', {
        'password_lama': _passwordLamaController.text,
        'password_baru': _passwordBaruController.text,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata sandi berhasil diubah.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4FAF8),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Ubah Kata Sandi',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              const Text(
                'Ubah Kata Sandi Admin',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D3D3D),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Masukkan kata sandi lama dan kata sandi baru Anda.',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),

              const SizedBox(height: 28),

              // ==================================================
              // PASSWORD LAMA
              // ==================================================
              TextFormField(
                controller: _passwordLamaController,
                obscureText: _obscureLama,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Lama',
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Kata sandi lama wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ==================================================
              // PASSWORD BARU
              // ==================================================
              TextFormField(
                controller: _passwordBaruController,
                obscureText: _obscureBaru,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Baru',
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Kata sandi baru wajib diisi';
                  }

                  if (value.length < 6) {
                    return 'Minimal 6 karakter';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ==================================================
              // KONFIRMASI PASSWORD
              // ==================================================
              TextFormField(
                controller: _konfirmasiController,
                obscureText: _obscureKonfirmasi,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Kata Sandi Baru',
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Konfirmasi kata sandi wajib diisi';
                  }

                  if (value != _passwordBaruController.text) {
                    return 'Konfirmasi kata sandi tidak cocok';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 30),

              // ==================================================
              // TOMBOL SIMPAN
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _ubahPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF159B8C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'SIMPAN KATA SANDI',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
