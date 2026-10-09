import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _namaController = TextEditingController();
  final _nimController = TextEditingController();
  final _kelasController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _konfirmasiController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureKonfirmasi = true;
  bool _isLoading = false;

  static const Color _primary = Color(0xFF087F72);
  static const Color _primaryDark = Color(0xFF075F58);
  static const Color _bg = Color(0xFFF8F9FA);
  static const Color _softMint = Color(0xFFE9EDEF);
  static const Color _fill = Color(0xFFFBFDFC);

  Future<void> _register() async {
    final nama = _namaController.text.trim();
    final nim = _nimController.text.trim();
    final kelas = _kelasController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final konfirmasi = _konfirmasiController.text.trim();

    if (nama.isEmpty ||
        nim.isEmpty ||
        kelas.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        konfirmasi.isEmpty) {
      _showMessage('Semua data wajib diisi');
      return;
    }

    if (password != konfirmasi) {
      _showMessage('Konfirmasi password tidak sesuai');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Cek apakah email sudah digunakan
      final hasilCek = await ApiService.getMap(
        '/users/check-email?email=${Uri.encodeQueryComponent(email)}',
      );

      if (hasilCek?['registered'] == true) {
        _showMessage('Email sudah terdaftar');
        return;
      }

      await ApiService.postMap('/register', {
        'nama': nama,
        'nim': nim,
        'kelas': kelas,
        'email': email,
        'password': password,
        'role': 'mahasiswa',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pendaftaran berhasil! Silakan login.')),
      );

      Navigator.pop(context);
    } catch (e) {
      _showMessage('Pendaftaran gagal: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  InputDecoration _dec({
    required IconData icon,
    required String label,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 16, color: Color(0xFF667477)),
      prefixIcon: Icon(icon, color: _primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primary, width: 1.8),
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nimController.dispose();
    _kelasController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _konfirmasiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            // ==================================================
            // DEKORASI
            // ==================================================
            Positioned(
              top: -125,
              left: -125,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  color: _softMint.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              right: -140,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  color: _softMint.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.black87),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Daftar Akun',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: _primaryDark,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Buat akun mahasiswa untuk mulai meminjam alat laboratorium.',
                    style: TextStyle(fontSize: 15, color: Color(0xFF667477)),
                  ),

                  const SizedBox(height: 26),

                  // ==================================================
                  // CARD FORM
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _namaController,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            icon: Icons.person_outline,
                            label: 'Nama Lengkap',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _nimController,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            icon: Icons.badge_outlined,
                            label: 'NIM',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _kelasController,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            icon: Icons.class_outlined,
                            label: 'Kelas',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            icon: Icons.email_outlined,
                            label: 'Email',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: _dec(
                            icon: Icons.lock_outline,
                            label: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF687276),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _konfirmasiController,
                          obscureText: _obscureKonfirmasi,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_isLoading) {
                              _register();
                            }
                          },
                          decoration: _dec(
                            icon: Icons.lock_outline,
                            label: 'Konfirmasi Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureKonfirmasi
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF687276),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureKonfirmasi = !_obscureKonfirmasi;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shadowColor: _primary.withValues(alpha: 0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'DAFTAR',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
