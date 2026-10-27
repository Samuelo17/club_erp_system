// lib/features/pos/presentation/pos_screen.dart
//
// Pantalla principal del Terminal POS (Point of Sale) Mobile-First.
// Optimizada estrictamente para smartphones en orientación vertical (Portrait).
//
// Reglas estrictas:
//   - Exclusiva para el rol de Cajera
//   - Sin menú lateral (Drawer) ni Sidebars
//   - Única salida: botón "Cerrar Sesión" en el AppBar que devuelve a AuthScreen (PIN)
//   - AppBar con título, badge de Tasa de Cambio del día y botón de salida
//   - Catálogo vertical con buscador, categorías en píldoras y GridView de 2 columnas
//   - Carrito dinámico desplegable mediante Bottom Sheet activado por la barra inferior

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/exchange_rate_provider.dart';
import 'arqueo_screen.dart';
import 'widgets/cart_bottom_bar.dart';
import 'widgets/product_catalog.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  /// Diálogo de confirmación para cerrar sesión y volver a la pantalla de PIN
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
          '¿Estás segura de que deseas salir del Terminal de Caja? Tu pedido actual se limpiará.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.textSecondary,
              ),
            ),
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

              // Limpiar estado de autenticación y carrito
              ref.read(authProvider.notifier).logout();
              ref.read(cartProvider.notifier).clearCart();

              // Navegar de vuelta a la pantalla del PIN sin permitir volver atrás
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Salir a PIN',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateAsync = ref.watch(exchangeRateProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: AppBar(
        // Garantizar que no se muestre botón de drawer o back
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
                Icons.point_of_sale_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Happy House',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Caja • Mobile POS',
                  style: TextStyle(
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
          // ── Badge de Tasa de Cambio del Día ──────────────────────────────
          rateAsync.when(
            data: (rateData) {
              if (rateData == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.currency_exchange_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Bs. ${rateData.rate.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // ── Botón de Arqueo de Caja / Cierre de Turno ───────────────────────
          IconButton(
            icon: const Icon(
              Icons.point_of_sale_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
            tooltip: 'Arqueo de Caja',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ArqueoScreen()),
              );
            },
          ),

          const SizedBox(width: 4),

          // ── Botón Superior de Cerrar Sesión (Única salida al PIN) ────────
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
          child: Container(
            color: AppColors.border,
            height: 1,
          ),
        ),
      ),
      body: const SafeArea(
        bottom: false,
        child: ProductCatalog(),
      ),
      bottomNavigationBar: const CartBottomBar(),
    );
  }
}
