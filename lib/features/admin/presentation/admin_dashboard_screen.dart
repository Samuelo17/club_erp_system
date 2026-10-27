// lib/features/admin/presentation/admin_dashboard_screen.dart
//
// Pantalla principal del Dashboard Administrativo para el rol de Encargada.
// Mobile-First:
//   - Sin menús laterales (Drawers) ni sidebars
//   - BottomNavigationBar ergonómico con 3 pestañas: "Tasa", "Menú", "Validaciones"
//   - Badge reactivo con el conteo de pagos pendientes por validar
//   - Botón superior de Cerrar Sesión para volver a la pantalla de PIN

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_providers.dart';
import 'widgets/admin_exchange_rate_view.dart';
import 'widgets/admin_menu_view.dart';
import 'widgets/admin_payment_validation_view.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _currentIndex = 0;

  final _titles = const [
    'Tasa de Cambio',
    'Gestor de Menú',
    'Validación de Pagos',
  ];

  final _subtitles = const [
    'Control de cambio USD / VES',
    'Catálogo, precios y disponibilidad',
    'Verificación de Pago Móvil',
  ];

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              'Cerrar Sesión',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          '¿Deseas salir del panel gerencial? Deberás ingresar el PIN para volver a acceder.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar',
                style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Salir a PIN',
              style: TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingPaymentsAsync = ref.watch(pendingPaymentsProvider);
    final pendingCount = pendingPaymentsAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.backgroundCard,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _titles[_currentIndex],
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  _subtitles[_currentIndex],
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.error,
              size: 22,
            ),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _confirmLogout(context, ref),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          AdminExchangeRateView(),
          AdminMenuView(),
          AdminPaymentValidationView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: AppColors.backgroundCard,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.currency_exchange_rounded),
            selectedIcon: Icon(Icons.currency_exchange_rounded,
                color: AppColors.primary),
            label: 'Tasa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_rounded),
            selectedIcon: Icon(Icons.restaurant_menu_rounded,
                color: AppColors.primary),
            label: 'Menú',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.verified_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.verified_rounded,
                  color: AppColors.primary),
            ),
            label: 'Validaciones',
          ),
        ],
      ),
    );
  }
}
