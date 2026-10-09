import 'package:flutter/material.dart';

import 'package:club_erp_system/features/pos/presentation/widgets/catalog_section.dart';
import 'package:club_erp_system/features/pos/presentation/widgets/cart_summary_bar.dart';

/// Página principal del módulo POS (Terminal de Cobro).
///
/// Layout vertical optimizado para TELÉFONOS MÓVILES:
/// - Arriba: [CatalogSection] expandida (categorías + grid de productos).
/// - Abajo: [CartSummaryBar] flotante (visible solo cuando hay ítems en carrito).
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
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              'Terminal POS',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
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
