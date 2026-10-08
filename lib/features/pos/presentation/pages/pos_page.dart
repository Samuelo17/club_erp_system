import 'package:flutter/material.dart';

import 'package:club_erp_system/features/pos/presentation/widgets/catalog_section.dart';

/// Página principal del módulo POS (Terminal de Cobro).
///
/// Layout vertical optimizado para TELÉFONOS MÓVILES:
/// - Arriba: [CatalogSection] expandida (categorías + grid de productos).
/// - Abajo: Panel resumen fijo (placeholder para US-1.2 Carrito).
///
/// Estilo según [UI_STYLE_GUIDE]:
/// - Fondo gris muy claro (#F5F5F7).
/// - Panel inferior blanco con sombra superior y bordes redondeados arriba.
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

      body: Stack(
        children: [
          // ===== ÁREA DEL CATÁLOGO (Fondo) =====
          // Damos padding en la parte inferior para que el panel colapsado no tape el último producto
          const Positioned.fill(
            bottom: 90, 
            child: CatalogSection(),
          ),

          // ===== PANEL RESUMEN INFERIOR (Deslizable) =====
          DraggableScrollableSheet(
            initialChildSize: 0.12, // Altura inicial (colapsado)
            minChildSize: 0.12,     // Altura mínima
            maxChildSize: 0.75,     // Altura máxima al expandirse (75% de la pantalla)
            snap: true,             // Hace que haga "snap" a los bordes
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Indicador de drag (handle visual)
                              Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),

                              // Texto placeholder US-1.2
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Módulo de Carrito (US-1.2)',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              Text(
                                'Deslizar hacia arriba o tocar',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              
                              const SizedBox(height: 40),
                              
                              // Contenido extra al deslizar
                              Icon(
                                Icons.construction_rounded,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'El contenido del carrito irá aquí...',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
