import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/core/auth/auth_provider.dart';
import 'package:club_erp_system/features/auth/presentation/pages/login_page.dart';
import 'package:club_erp_system/features/cash_closure/presentation/pages/cash_closure_page.dart';
import 'package:club_erp_system/features/exchange_rate/presentation/providers/exchange_rate_provider.dart';
import 'package:club_erp_system/features/pos/presentation/widgets/catalog_section.dart';
import 'package:club_erp_system/features/pos/presentation/widgets/cart_summary_bar.dart';
import 'package:club_erp_system/features/pos/presentation/widgets/orders_history_modal.dart';

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
    final authProvider = context.watch<AuthProvider>();
    final cashierName = authProvider.currentUser?.name ?? 'Cajera';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFEA580C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person_rounded,
                  color: Color(0xFFFF8C00),
                  size: 36,
                ),
              ),
              accountName: Text(
                cashierName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              accountEmail: const Text(
                'Turno de Caja Activo • En Línea',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF374151)),
              title: const Text('Historial de Órdenes del Día'),
              subtitle: const Text('Ver ventas completadas hoy'),
              onTap: () {
                Navigator.of(context).pop();
                OrdersHistoryModal.show(context);
              },
            ),
            const Divider(),
            // US-3.4: Botón prominente de Cierre de Caja
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: ListTile(
                leading: const Icon(Icons.lock_clock_rounded, color: Color(0xFFB45309)),
                title: const Text(
                  'Cierre de Caja',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                subtitle: const Text(
                  'Arqueo de turno y cuadre de totales',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFB45309),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CashClosurePage()),
                  );
                },
              ),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.read<AuthProvider>().logout();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.point_of_sale_rounded,
              color: Color(0xFFFF8C00),
              size: 20,
            ),
            SizedBox(width: 6),
            Text(
              'POS',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // US-3.3 (AC): Botón en el POS para abrir el Historial
          IconButton(
            tooltip: 'Órdenes del Día (Historial)',
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF374151),
              size: 21,
            ),
            onPressed: () => OrdersHistoryModal.show(context),
          ),
          const SizedBox(width: 4),

          // US-3.4 (AC): Botón de Cierre de Caja (Arqueo) en AppBar
          IconButton(
            tooltip: 'Cierre de Caja',
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.lock_clock_rounded,
              color: Color(0xFFD97706),
              size: 21,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CashClosurePage()),
              );
            },
          ),
          const SizedBox(width: 4),

          // US-3.1 (TAREA 2): Tasa de cambio de SOLO LECTURA (sin InkWell, sin navegación)
          Consumer<ExchangeRateProvider>(
            builder: (context, rateProvider, _) {
              final hasRate = rateProvider.hasRate;
              final rateText = hasRate
                  ? 'Bs. ${rateProvider.rateValue.toStringAsFixed(2)}'
                  : 'Sin Tasa';

              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasRate
                        ? const Color(0xFFFF8C00).withValues(alpha: 0.10)
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
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
                        size: 13,
                        color: hasRate
                            ? const Color(0xFFFF8C00)
                            : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rateText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: hasRate
                            ? const Color(0xFFFF8C00)
                            : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),

          // Botón Cerrar Sesión para la Cajera
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Cerrar Sesión',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
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
