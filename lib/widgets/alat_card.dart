import 'package:flutter/material.dart';
import '../models/alat_model.dart';
import '../utils/app_colors.dart';

class AlatCard extends StatelessWidget {
  final AlatModel alat;
  final VoidCallback? onTap;

  const AlatCard({super.key, required this.alat, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool tersedia = alat.stok > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.build_rounded, color: AppColors.primary),
        ),
        title: Text(
          alat.namaAlat,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Kondisi: ${alat.kondisi}'),
            Text(
              tersedia ? 'Stok: ${alat.stok}' : 'Stok Habis',
              style: TextStyle(
                color: tersedia ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
