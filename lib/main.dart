import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/features/pos/data/repositories_impl/order_repository_impl.dart';
import 'package:club_erp_system/features/pos/presentation/pages/pos_page.dart';
import 'package:club_erp_system/features/pos/presentation/providers/cart_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientación vertical forzada (optimizado para teléfonos móviles)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ClubErpApp());
}

class ClubErpApp extends StatelessWidget {
  const ClubErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartProvider(
        orderRepository: OrderRepositoryImpl(),
      ),
      child: MaterialApp(
        title: 'Club ERP - Terminal POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF8C00), // Naranja Vibrante (Style Guide)
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F5F7),
          fontFamily: 'Roboto',
        ),
        home: const PosPage(),
      ),
    );
  }
}
