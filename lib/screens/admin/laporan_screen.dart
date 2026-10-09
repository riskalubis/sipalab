import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/api_service.dart';

class LaporanAdminScreen extends StatefulWidget {
  const LaporanAdminScreen({super.key});

  @override
  State<LaporanAdminScreen> createState() => _LaporanAdminScreenState();
}

class _LaporanAdminScreenState extends State<LaporanAdminScreen> {
  bool _isLoading = true;

  int _totalAlat = 0;
  int _stokAlat = 0;
  int _sedangDipinjam = 0;
  int _menunggu = 0;
  int _dikembalikan = 0;
  int _ditolak = 0;

  @override
  void initState() {
    super.initState();
    _loadLaporan();
  }

  // ============================================================
  // LOAD LAPORAN
  // ============================================================

  Future<void> _loadLaporan() async {
    try {
      // Endpoint /laporan mengembalikan seluruh ringkasan laporan
      // dalam satu payload: total_alat, stok_alat, dipinjam,
      // menunggu, dikembalikan, ditolak.
      final payload = (await ApiService.getMap('/laporan')) ?? {};

      if (!mounted) return;

      setState(() {
        _totalAlat =
            int.tryParse(payload['total_alat']?.toString() ?? '0') ?? 0;

        _stokAlat = int.tryParse(payload['stok_alat']?.toString() ?? '0') ?? 0;

        _sedangDipinjam =
            int.tryParse(payload['dipinjam']?.toString() ?? '0') ?? 0;

        _menunggu = int.tryParse(payload['menunggu']?.toString() ?? '0') ?? 0;

        _dikembalikan =
            int.tryParse(payload['dikembalikan']?.toString() ?? '0') ?? 0;

        _ditolak = int.tryParse(payload['ditolak']?.toString() ?? '0') ?? 0;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat laporan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // EXPORT PDF
  // ============================================================

  Future<void> _exportPdf() async {
    try {
      final pdf = pw.Document();

      final tanggal = DateTime.now();

      final tanggalText = '${tanggal.day.toString().padLeft(2, '0')}-'
          '${tanggal.month.toString().padLeft(2, '0')}-'
          '${tanggal.year}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LAPORAN PEMINJAMAN ALAT LABORATORIUM',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Tanggal laporan: $tanggalText',
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 25),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    _pdfRow('Keterangan', 'Jumlah', header: true),
                    _pdfRow('Total Alat', '$_totalAlat'),
                    _pdfRow('Stok Alat', '$_stokAlat'),
                    _pdfRow('Sedang Dipinjam', '$_sedangDipinjam'),
                    _pdfRow('Menunggu Konfirmasi', '$_menunggu'),
                    _pdfRow('Sudah Dikembalikan', '$_dikembalikan'),
                    _pdfRow('Ditolak', '$_ditolak'),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Laporan ini dibuat secara otomatis dari sistem.',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'laporan_peminjaman_$tanggalText.pdf',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF berhasil dibuat.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal export PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // BARIS PDF
  // ============================================================

  pw.TableRow _pdfRow(String kiri, String kanan, {bool header = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            kiri,
            style: pw.TextStyle(
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            kanan,
            style: pw.TextStyle(
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EXPORT EXCEL
  // ============================================================

  Future<void> _exportExcel() async {
    try {
      final excel = Excel.createExcel();

      final sheet = excel['Laporan'];

      final tanggal = DateTime.now();

      final tanggalText = '${tanggal.day.toString().padLeft(2, '0')}-'
          '${tanggal.month.toString().padLeft(2, '0')}-'
          '${tanggal.year}';

      // Judul
      sheet.appendRow([TextCellValue('LAPORAN PEMINJAMAN ALAT LABORATORIUM')]);

      // Tanggal
      sheet.appendRow([
        TextCellValue('Tanggal Laporan'),
        TextCellValue(tanggalText),
      ]);

      // Baris kosong
      sheet.appendRow([]);

      // Header
      sheet.appendRow([TextCellValue('Keterangan'), TextCellValue('Jumlah')]);

      // Data
      sheet.appendRow([
        TextCellValue('Total Alat'),
        IntCellValue(_totalAlat),
      ]);

      sheet.appendRow([
        TextCellValue('Stok Alat'),
        IntCellValue(_stokAlat),
      ]);

      sheet.appendRow([
        TextCellValue('Sedang Dipinjam'),
        IntCellValue(_sedangDipinjam),
      ]);

      sheet.appendRow([
        TextCellValue('Menunggu Konfirmasi'),
        IntCellValue(_menunggu),
      ]);

      sheet.appendRow([
        TextCellValue('Sudah Dikembalikan'),
        IntCellValue(_dikembalikan),
      ]);

      sheet.appendRow([TextCellValue('Ditolak'), IntCellValue(_ditolak)]);

      final bytes = excel.encode();

      if (bytes == null) {
        throw Exception('Gagal membuat file Excel.');
      }

      final directory = await getTemporaryDirectory();

      final file = File(
        '${directory.path}/laporan_peminjaman_$tanggalText.xlsx',
      );

      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Laporan Peminjaman Alat Laboratorium',
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel berhasil dibuat.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal export Excel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // JUDUL SECTION
  // ============================================================

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARD STATISTIK GRID (2 KOLOM)
  // ============================================================

  Widget _buildStatCard({
    required String jumlah,
    required String judul,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jumlah,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    judul,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BARIS STATISTIK
  // ============================================================

  Widget _buildStatRow(List<Widget> cards) {
    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          cards[i],
        ],
      ],
    );
  }

  // ============================================================
  // TOMBOL EXPORT
  // ============================================================

  Widget _buildExportButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Laporan'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLaporan,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Laporan Peminjaman',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Ringkasan aktivitas peminjaman alat laboratorium.',
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 24),

                  // =============================================
                  // AKTIVITAS PEMINJAMAN
                  // =============================================
                  _buildSectionHeader(
                    Icons.swap_horiz_outlined,
                    'Aktivitas Peminjaman',
                    const Color(0xFF0F8A7D),
                  ),

                  const SizedBox(height: 12),

                  _buildStatRow([
                    _buildStatCard(
                      jumlah: '$_sedangDipinjam',
                      judul: 'Sedang Dipinjam',
                      icon: Icons.inventory_2_outlined,
                      color: Colors.orange,
                    ),
                    _buildStatCard(
                      jumlah: '$_menunggu',
                      judul: 'Menunggu Konfirmasi',
                      icon: Icons.access_time_rounded,
                      color: Colors.blue,
                    ),
                  ]),

                  const SizedBox(height: 12),

                  _buildStatRow([
                    _buildStatCard(
                      jumlah: '$_dikembalikan',
                      judul: 'Dikembalikan',
                      icon: Icons.assignment_return_outlined,
                      color: Colors.green,
                    ),
                    _buildStatCard(
                      jumlah: '$_ditolak',
                      judul: 'Ditolak',
                      icon: Icons.cancel_outlined,
                      color: Colors.red,
                    ),
                  ]),

                  const SizedBox(height: 26),

                  // =============================================
                  // INVENTORI ALAT
                  // =============================================
                  _buildSectionHeader(
                    Icons.warehouse_outlined,
                    'Inventori Alat',
                    Colors.teal,
                  ),

                  const SizedBox(height: 12),

                  _buildStatRow([
                    _buildStatCard(
                      jumlah: '$_totalAlat',
                      judul: 'Total Alat',
                      icon: Icons.inventory_outlined,
                      color: const Color(0xFF0F8A7D),
                    ),
                    _buildStatCard(
                      jumlah: '$_stokAlat',
                      judul: 'Stok Alat',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // EXPORT
                  const Text(
                    'Export Laporan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _buildExportButton(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Export PDF',
                        color: Colors.red,
                        onTap: _exportPdf,
                      ),
                      const SizedBox(width: 12),
                      _buildExportButton(
                        icon: Icons.table_chart_outlined,
                        title: 'Export Excel',
                        color: Colors.green,
                        onTap: _exportExcel,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
