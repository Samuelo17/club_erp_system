// lib/main.dart
//
// Punto de entrada principal del sistema Happy House ERP/POS.
// Inicializa Flutter, Riverpod y arranca la app en la AuthScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientación estrictamente vertical (Portrait) — optimizado para móviles Mobile-First
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Estilo de la barra de estado del sistema
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    // ProviderScope envuelve toda la app para habilitar Riverpod
    const ProviderScope(
      child: HappyHouseApp(),
    ),
  );
}

class HappyHouseApp extends StatelessWidget {
  const HappyHouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Happy House ERP/POS',
      debugShowCheckedModeBanner: false,
      // Aplica el tema definido en UI_STYLE_GUIDE
      theme: AppTheme.lightTheme,
      // La app siempre arranca en la pantalla de autenticación por PIN
      home: const AuthScreen(),
    );
  }
}
