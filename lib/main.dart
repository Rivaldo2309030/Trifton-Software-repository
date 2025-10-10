import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'package:distribuidora/screens/WelcomeScreen.dart';
import 'package:distribuidora/screens/auth.dart';

// sqflite FFI (solo escritorio)
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa sqflite FFI solo en ESCRITORIO (no Web)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TritonSoftware',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Segoe UI'),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
      // Opcional: ayuda a detectar rutas mal configuradas
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}
