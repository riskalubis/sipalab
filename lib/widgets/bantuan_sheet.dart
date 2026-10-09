import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ============================================================
// PINDAH KE WHATSAPP
// ============================================================

class _CSWa {
  final String label;
  final String nomorTampil;
  final String nomorWhatsApp;

  const _CSWa({
    required this.label,
    required this.nomorTampil,
    required this.nomorWhatsApp,
  });
}

const List<_CSWa> _daftarCS = [
  _CSWa(
    label: 'CS SIPALAB 1',
    nomorTampil: '+62 857-6306-1527',
    nomorWhatsApp: '6285763061527',
  ),
  _CSWa(
    label: 'CS SIPALAB 2',
    nomorTampil: '+62 859-1859-95844',
    nomorWhatsApp: '62859185995844',
  ),
];

// ============================================================
// TAMPILKAN BANTUAN & DUKUNGAN
// ============================================================

void showBantuanSheet(
  BuildContext context, {
  required Color primaryColor,
  String subtitle =
      'Punya kendala? Hubungi Customer Service kami lewat WhatsApp.',
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF8F9FA),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Column(
            children: [
              // ================================================
              // HEADER GRADIENT
              // ================================================
              Container(
                padding: const EdgeInsets.fromLTRB(22, 18, 12, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF1F4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Color(0xFF087F72),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bantuan & Dukungan',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kami siap membantu setiap kendala aplikasi.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // ================================================
              // ISI
              // ================================================
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  children: [
                    // ============================================
                    // INFO AWAL
                    // ============================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hubungi CS via WhatsApp',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ============================================
                    // KARTU NOMOR WA
                    // ============================================
                    for (final cs in _daftarCS) ...[
                      _WaCard(cs, primaryColor),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 6),

                    // ============================================
                    // ALUR PEMINJAMAN
                    // ============================================
                    Text(
                      'Alur Peminjaman Alat',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _Langkah(
                            '1',
                            Icons.search,
                            'Pilih alat yang ingin dipinjam.',
                            primaryColor,
                          ),
                          _Langkah(
                            '2',
                            Icons.description_outlined,
                            'Isi form peminjaman lalu kirim pengajuan.',
                            primaryColor,
                          ),
                          _Langkah(
                            '3',
                            Icons.hourglass_top,
                            'Tunggu konfirmasi dari admin.',
                            primaryColor,
                          ),
                          _Langkah(
                            '4',
                            Icons.inventory_2_outlined,
                            'Alat dapat digunakan setelah disetujui.',
                            primaryColor,
                          ),
                          _Langkah(
                            '5',
                            Icons.assignment_return_outlined,
                            'Ajukan pengembalian setelah selesai.',
                            primaryColor,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

// ============================================================
// KARTU KONTAK WHATSAPP
// ============================================================

class _WaCard extends StatelessWidget {
  final _CSWa cs;
  final Color primaryColor;

  const _WaCard(this.cs, this.primaryColor);

  Future<void> _buka(BuildContext context) async {
    final url = Uri.parse('https://wa.me/${cs.nomorWhatsApp}');

    final berhasil = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!berhasil && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka WhatsApp.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _buka(context),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ================================================
              // IKON WHATSAPP
              // ================================================
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Color(0xFF25D366),
                  size: 26,
                ),
              ),

              const SizedBox(width: 13),

              // ================================================
              // TEKS
              // ================================================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cs.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cs.nomorTampil,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ketuk untuk chat via WhatsApp',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BARIS LANGKAH
// ============================================================

class _Langkah extends StatelessWidget {
  final String number;
  final IconData icon;
  final String teks;
  final Color primaryColor;
  final bool isLast;

  const _Langkah(
    this.number,
    this.icon,
    this.teks,
    this.primaryColor, {
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF1F4),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: Colors.grey.shade500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      teks,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
