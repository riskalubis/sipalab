import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/offline_service.dart';
import '../session/user_session.dart';
import 'package:sipalab/screens/register_screen.dart';
import 'server_settings_screen.dart';
import 'mahasiswa/mahasiswa_main_screen.dart';
import 'admin/admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ============================================================
  // WARNA
  // ============================================================

  static const Color primaryColor = Color(0xFF087F72);
  static const Color darkTeal = Color(0xFF075F58);
  static const Color backgroundColor = Color(0xFFF8F9FA);

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email dan password wajib diisi');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.postRaw('/login', {
        'email': email,
        'password': password,
      });

      if (!mounted) return;

      final status = result['status']?.toString();

      if (status == 'email_not_found') {
        _showMessage(
          'Anda belum mempunyai akun. Silakan daftar terlebih dahulu.',
        );
        return;
      }

      if (status == 'wrong_password') {
        _showMessage('Password yang Anda masukkan salah.');
        return;
      }

      final rawUser = result['user'];
      if (rawUser is! Map) {
        _showMessage('Data pengguna tidak valid');
        return;
      }

      final user = Map<String, dynamic>.from(rawUser);
      final token =
          result['token']?.toString() ?? result['access_token']?.toString();
      if (token == null || token.isEmpty) {
        _showMessage('Login gagal: server tidak mengembalikan token.');
        return;
      }

      UserSession.setUser(user, authToken: token);

      // Simpan sesi login di SQLite agar bisa login offline.
      await OfflineService.instance.saveLogin(user, password, token: token);

      if (!mounted) return;

      final role = user['role']?.toString();

      if (role == 'mahasiswa') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MahasiswaMainScreen()),
        );
      } else if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
        );
      } else {
        _showMessage('Role pengguna tidak dikenali');
      }
    } on OfflineException {
      // Server mati → coba login pakai sesi terakhir yang tersimpan di HP.
      if (!mounted) return;
      final cached =
          await OfflineService.instance.offlineLogin(email, password);
      if (!mounted) return;
      if (cached == null) {
        _showMessage(
          'Server sedang tidak terhubung. Login offline hanya bisa untuk '
          'akun yang pernah masuk di HP ini.',
        );
        return;
      }
      UserSession.setUser(cached);
      final role = cached['role']?.toString();
      if (role == 'mahasiswa') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MahasiswaMainScreen()),
        );
      } else if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
        );
      } else {
        _showMessage('Role pengguna tidak dikenali');
      }
    } catch (e) {
      _showMessage('Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // PESAN
  // ============================================================

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

  // ============================================================
  // INPUT FIELD
  // ============================================================

  InputDecoration _inputDecoration({
    required IconData icon,
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF667477),
        fontSize: 18,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: primaryColor, size: 29),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFFBFDFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: primaryColor, width: 1.8),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // ========================================================
      // PENTING:
      // LAYAR TIDAK IKUT RESIZE SAAT KEYBOARD MUNCUL
      // ========================================================
      resizeToAvoidBottomInset: false,

      body: SafeArea(
        child: Stack(
          children: [
            // ==================================================
            // BULATAN KIRI ATAS
            // ==================================================
            Positioned(
              top: -125,
              left: -125,
              child: Container(
                width: 395,
                height: 395,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EDEF).withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // ==================================================
            // BULATAN KANAN BAWAH
            // ==================================================
            Positioned(
              bottom: -185,
              right: -145,
              child: Container(
                width: 370,
                height: 370,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EDEF).withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // ==================================================
            // TOMBOL PENGATURAN ALAMAT SERVER
            // ==================================================
            Positioned(
              top: 4,
              right: 10,
              child: IconButton(
                tooltip: 'Alamat Server',
                icon: const Icon(
                  Icons.dns_outlined,
                  color: darkTeal,
                  size: 26,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ServerSettingsScreen(),
                    ),
                  );
                },
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==================================================
                  // LOGO + NAMA
                  // ==================================================
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // ==================================================
                        // LOGO SL ASLI
                        // ==================================================
                        SizedBox(
                          width: 175,
                          height: 175,
                          child: Image.asset(
                            'assets/logo_sipalab_SL_transparent.png',
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // ==================================================
                        // SIPALAB
                        // ==================================================
                        const Text(
                          'SIPALAB',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: darkTeal,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ==================================================
                        // SUBTITLE
                        // ==================================================
                        const Text(
                          'Sistem Peminjaman Alat Laboratorium',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF667477),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 42),

                  // ==================================================
                  // FORM CARD
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 25, 18, 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.055),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // ==================================================
                        // EMAIL
                        // ==================================================
                        SizedBox(
                          height: 72,
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              icon: Icons.email_outlined,
                              hint: 'Email',
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ==================================================
                        // PASSWORD
                        // ==================================================
                        SizedBox(
                          height: 72,
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_isLoading) {
                                _login();
                              }
                            },
                            decoration: _inputDecoration(
                              icon: Icons.lock_outline_rounded,
                              hint: 'Password',
                              suffixIcon: IconButton(
                                splashRadius: 24,
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF687276),
                                  size: 29,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),

                        // ==================================================
                        // LOGIN
                        // TANPA PANAH
                        // ==================================================
                        SizedBox(
                          width: double.infinity,
                          height: 62,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shadowColor: primaryColor.withValues(alpha: 0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
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
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 27),

                  // ==================================================
                  // ATAU
                  // ==================================================
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1.5,
                          color: Colors.grey.shade300,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'atau',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF7A8587),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1.5,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // CARD DAFTAR
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 17,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border:
                          Border.all(color: Colors.grey.shade200, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        // ==================================================
                        // ICON USER
                        // ==================================================
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEF1F4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: primaryColor,
                            size: 32,
                          ),
                        ),

                        const SizedBox(width: 15),

                        // ==================================================
                        // TEXT
                        // ==================================================
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Belum punya akun?',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Daftar untuk mulai\nmeminjam alat.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: Color(0xFF7A8587),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // ==================================================
                        // TOMBOL DAFTAR
                        // TANPA PANAH
                        // ==================================================
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: const BorderSide(
                              color: primaryColor,
                              width: 1.8,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Daftar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
