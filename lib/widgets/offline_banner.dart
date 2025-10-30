import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        bool isOffline = true; // Asumir offline por defecto
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          // Si la lista contiene solo 'none', estamos offline.
          // Si contiene 'wifi' o 'mobile', etc., estamos online.
          isOffline = snapshot.data!.every((result) => result == ConnectivityResult.none);
        }

        if (isOffline) {
          return Container(
            width: double.infinity,
            color: Colors.blueGrey.shade700,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Modo sin conexión',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        } else {
          return const SizedBox.shrink(); // No mostrar nada si hay conexión
        }
      },
    );
  }
}
