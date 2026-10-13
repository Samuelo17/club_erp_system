import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/features/exchange_rate/presentation/providers/exchange_rate_provider.dart';
import 'package:club_erp_system/features/pos/domain/entities/product.dart';

/// Tarjeta visual de un producto en el catálogo.
///
/// Sigue el [UI_STYLE_GUIDE]:
/// - Card blanca con esquinas redondeadas (12.0) y sombra suave difuminada.
/// - Nombre: negro negrita, máximo 2 líneas con ellipsis.
/// - Precio: tamaño grande, negrita, color Naranja Vibrante.
/// - Layout vertical optimizado para móvil: fácil de tocar con el pulgar.
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono decorativo del producto
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Color(0xFFFF8C00),
                  size: 22,
                ),
              ),

              const SizedBox(height: 12),

              // Nombre del producto
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 8),

              // Precio en Naranja con equivalente en Bs
              Consumer<ExchangeRateProvider>(
                builder: (context, rateProvider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$ ${product.currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF8C00),
                        ),
                      ),
                      if (rateProvider.hasRate)
                        Text(
                          'Bs. ${(product.currentPrice * rateProvider.rateValue).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
