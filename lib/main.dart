import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/core/local_db/powersync_helper.dart';
import 'package:club_erp_system/core/auth/auth_provider.dart';
import 'package:club_erp_system/features/analytics/data/repositories_impl/analytics_repository_impl.dart';
import 'package:club_erp_system/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:club_erp_system/features/auth/data/repositories_impl/auth_repository_impl.dart';
import 'package:club_erp_system/features/auth/presentation/pages/login_page.dart';
import 'package:club_erp_system/features/cash_closure/data/repositories_impl/cash_session_repository_impl.dart';
import 'package:club_erp_system/features/cash_closure/presentation/providers/cash_closure_provider.dart';
import 'package:club_erp_system/features/exchange_rate/data/repositories_impl/exchange_rate_repository_impl.dart';
import 'package:club_erp_system/features/exchange_rate/presentation/providers/exchange_rate_provider.dart';
import 'package:club_erp_system/features/payments/data/repositories_impl/payment_repository_impl.dart';
import 'package:club_erp_system/features/payments/presentation/providers/payment_provider.dart';
import 'package:club_erp_system/features/pos/data/repositories_impl/order_repository_impl.dart';
import 'package:club_erp_system/features/pos/presentation/providers/cart_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar PowerSync y Supabase (Offline-First)
  try {
    await PowerSyncHelper.instance.initialize();
  } catch (e, stackTrace) {
    debugPrint('💥 [Main] Error crítico durante initialize: $e\n$stackTrace');
  }

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authRepository: AuthRepositoryImpl(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(
            orderRepository: OrderRepositoryImpl(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ExchangeRateProvider(
            repository: ExchangeRateRepositoryImpl(),
          ),
        ),
        // US-2.2: Proveedor de pagos (métodos + estado del formulario de cobro)
        ChangeNotifierProvider(
          create: (_) => PaymentProvider(
            repository: PaymentRepositoryImpl(),
          ),
        ),
        // US-3.2: Proveedor de analítica gerencial (KPIs en SQLite)
        ChangeNotifierProvider(
          create: (_) => AnalyticsProvider(
            repository: AnalyticsRepositoryImpl(),
          ),
        ),
        // US-3.4: Proveedor de arqueo y cierre de caja
        ChangeNotifierProvider(
          create: (_) => CashClosureProvider(
            repository: CashSessionRepositoryImpl(),
          ),
        ),
      ],
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
        home: const LoginPage(),
      ),
    );
  }
}
