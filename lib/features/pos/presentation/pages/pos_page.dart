import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/core/auth/auth_provider.dart';
import 'package:club_erp_system/features/auth/presentation/pages/login_page.dart';
import 'package:club_erp_system/features/exchange_rate/presentation/providers/exchange_rate_provider.dart';
import 'package:club_erp_system/features/pos/presentation/widgets/catalog_section.dart';
import 'package:club_erp_system/features/pos/presentation/widgets/cart_summary_bar.dart';

/// Página principal del módulo POS (Terminal de Cobro).
///
/// Layout vertical optimizado para TELÉFONOS MÓVILES:
/// - Arriba: [CatalogSection] expandida (categorías + grid de productos).
/// - Abajo: [CartSummaryBar] flotante (visible solo cuando hay ítems en carrito).
///
/// **Seguridad (US-3.1 - TAREA 2)**: La tasa de cambio es estrictamente
/// de SOLO LECTURA. No existe ningún botón ni acción para que la cajera
/// modifique la tasa.
///
/// Estilo según [UI_STYLE_GUIDE]:
/// - Fondo gris muy claro (#F5F5F7).
/// - Barra inferior con gradiente naranja y bordes redondeados arriba.
class PosPage extends StatelessWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Row(
          children: [
            Icon(
              Icons.point_of_sale_rounded,
              color: Color(0xFFFF8C00),
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Terminal POS',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // US-3.1 (TAREA 2): Tasa de cambio de SOLO LECTURA (sin InkWell, sin navegación)
          Consumer<ExchangeRateProvider>(
            builder: (context, rateProvider, _) {
              final hasRate = rateProvider.hasRate;
              final rateText = hasRate
                  ? 'Bs. ${rateProvider.rateValue.toStringAsFixed(2)}'
                  : 'Sin Tasa';

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: hasRate
                          ? const Color(0xFFFF8C00).withValues(alpha: 0.10)
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasRate
                            ? const Color(0xFFFF8C00).withValues(alpha: 0.35)
                            : Colors.amber.shade400,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.currency_exchange_rounded,
                          size: 14,
                          color: hasRate
                              ? const Color(0xFFFF8C00)
                              : Colors.amber.shade800,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          rateText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hasRate
                                ? const Color(0xFFFF8C00)
                                : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Botón Cerrar Sesión para la Cajera
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Cerrar Sesión',
              icon: const Icon(
                Icons.logout_rounded,
                color: Color(0xFF6B7280),
                size: 20,
              ),
              onPressed: () {
                context.read<AuthProvider>().logout();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey.shade200,
            height: 1,
          ),
        ),
      ),

      body: const Stack(
        children: [
          // ===== ÁREA DEL CATÁLOGO (ocupa todo el fondo) =====
          // Padding inferior para que la barra del carrito no tape el último producto
          Positioned.fill(
            bottom: 0,
            child: CatalogSection(),
          ),

          // ===== BARRA RESUMEN DEL CARRITO (flota sobre el catálogo) =====
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CartSummaryBar(),
          ),
        ],
      ),
    );
  }
}
