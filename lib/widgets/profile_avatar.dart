import 'dart:io';

import 'package:flutter/material.dart';

// ============================================================
// AVATAR PROFIL
// ============================================================
//
// Menampilkan foto profil bila path-nya ada dan file-nya masih
// tersimpan. Jika belum ada, menampilkan lingkaran berisi huruf
// pertama nama pengguna.

class ProfileAvatar extends StatelessWidget {
  final String nama;
  final String? fotoPath;
  final double radius;
  final Color backgroundColor;

  const ProfileAvatar({
    super.key,
    required this.nama,
    required this.fotoPath,
    this.radius = 50,
    this.backgroundColor = const Color(0xFF0F8A7D),
  });

  @override
  Widget build(BuildContext context) {
    final path = fotoPath;

    final fotoAda = path != null && path.isNotEmpty && File(path).existsSync();

    if (!fotoAda) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Text(
          nama.isNotEmpty ? nama[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: FileImage(File(path)),
    );
  }
}
