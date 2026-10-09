import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/offline_service.dart';

void main() {
  // Memastikan binding Flutter siap sebelum menjalankan aplikasi.
  WidgetsFlutterBinding.ensureInitialized();

  // Pasang sinkronisasi otomatis + hook offline (cache, ping, replay).
  ApiService.setupOfflineHooks();
  OfflineService.instance.startAutoSync();

  runApp(const LabRentApp());
}

class LabRentApp extends StatelessWidget {
  const LabRentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIPALAB',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor:
              Colors.teal, // Warna yang lebih khas untuk SIALAB/Laboratorium
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      // Banner status sinkronisasi di semua layar.
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: OfflineService.instance.isOffline,
          builder: (context, offline, _) {
            if (!offline) return child ?? const SizedBox.shrink();

            return Column(
              children: [
                Material(
                  color: const Color(0xFFB3261E),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mode Offline — data tampil dari HP ini. '
                              'Perubahan disinkronkan otomatis saat terhubung.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            );
          },
        );
      },
      home: const LoginScreen(),
    );
  }
}
