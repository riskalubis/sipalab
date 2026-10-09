import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/api_config.dart';

/// Pengaturan alamat server SIPALAB.
///
/// Pengguna cukup mengetik IP laptop (misal `192.168.1.16:8000`) sekali per
/// HP. Alamat tersimpan di HP dan dipakai app untuk semua permintaan.
/// Kosongkan kolom untuk kembali ke mode otomatis.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  static const Color _primary = Color(0xFF087F72);
  static const Color _darkTeal = Color(0xFF075F58);

  late final TextEditingController _serverController;

  bool _isLoading = true;
  bool _isTesting = false;
  bool _isSaving = false;

  String _serverAktif = '';
  String _pesan = '';

  @override
  void initState() {
    super.initState();

    _serverController = TextEditingController();

    _init();
  }

  Future<void> _init() async {
    await ApiConfig.loadCustomBase();

    if (!mounted) return;

    setState(() {
      _serverController.text = ApiConfig.customBaseDisplay();
      _serverAktif = _serverAktifLabel();
      _isLoading = false;
    });
  }

  String _serverAktifLabel() {
    if (ApiConfig.customBase.isNotEmpty) {
      return ApiConfig.customBaseDisplay();
    }
    return 'Otomatis (mencoba beberapa alamat)';
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  // ============================================================
  // UJI KONEKSI
  // ============================================================

  Future<void> _ujiKoneksi() async {
    final normalized = _normalizeInput();

    if (normalized.isEmpty) {
      _tampilkanPesan(
        'Ketik alamat server dulu, misal 192.168.1.16:8000',
        isError: true,
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _pesan = '';
    });

    final ok = await ApiService.testBase(
        normalized.contains('://') ? normalized : 'http://$normalized');

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      if (ok) {
        _pesan = 'Terhubung ke $normalized. Klik Simpan untuk memakainya.';
      } else {
        _pesan = 'Tidak dapat terhubung ke $normalized. '
            'Pastikan server Laravel jalan & HP di Wi-Fi yang sama.';
      }
    });
  }

  String _normalizeInput() {
    var v = _serverController.text.trim();
    if (v.isEmpty) return '';
    if (!v.contains('://')) v = 'http://$v';
    return v
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/api$'), '');
  }

  // ============================================================
  // SIMPAN
  // ============================================================

  Future<void> _simpan() async {
    final raw = _serverController.text.trim();

    setState(() {
      _isSaving = true;
    });

    await ApiConfig.saveCustomBase(raw);

    if (!mounted) return;

    final tersimpan =
        ApiConfig.customBase.isNotEmpty ? ApiConfig.customBaseDisplay() : null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tersimpan == null
            ? 'Mode otomatis diaktifkan.'
            : 'Alamat server disimpan: $tersimpan'),
        backgroundColor: _primary,
      ),
    );

    Navigator.pop(context, true);
  }

  void _tampilkanPesan(String pesan, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(pesan),
          backgroundColor: isError ? Colors.red : _primary,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Alamat Server'),
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: _darkTeal,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.dns_outlined,
                                color: _primary,
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Server aktif',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _darkTeal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _serverAktif,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF075F58),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ==============================================
                  // FORM
                  // ==============================================
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'IP Server (di HP ini)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Isi IP laptop tempat server Laravel jalan, '
                          'diikuti port 8000. Contoh: 192.168.1.16:8000',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Color(0xFF667477),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _serverController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _simpan(),
                          decoration: InputDecoration(
                            hintText: '192.168.1.16:8000',
                            prefixIcon: const Icon(
                              Icons.lan_outlined,
                              color: _primary,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFFBFDFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: _primary,
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_pesan.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _pesan.startsWith('Terhubung')
                                  ? Colors.white
                                  : const Color(0xFFFFECEC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _pesan.startsWith('Terhubung')
                                    ? const Color(0xFFCDEFEA)
                                    : const Color(0xFFFFCDCD),
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              _pesan,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: _pesan.startsWith('Terhubung')
                                    ? _darkTeal
                                    : const Color(0xFFB3261E),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isTesting ? null : _ujiKoneksi,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _primary,
                                  side: const BorderSide(
                                    color: _primary,
                                    width: 1.6,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isTesting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: _primary,
                                        ),
                                      )
                                    : const Text('Uji Koneksi'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _simpan,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Simpan'),
                              ),
                            ),
                          ],
                        ),
                        if (ApiConfig.customBase.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _serverController.clear();
                                _pesan = '';
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFB3261E),
                            ),
                            child: const Text(
                              'Kosongkan untuk kembali ke mode otomatis',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
