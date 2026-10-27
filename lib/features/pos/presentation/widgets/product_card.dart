// lib/features/pos/presentation/widgets/product_card.dart
//
// Tarjeta individual de producto para el catálogo POS Mobile-First.
// Diseñada para GridView de 2 columnas en pantalla vertical (Portrait).
// Muestra:
//   - Ícono de categoría y badge de cantidad en carrito (si ya fue agregado)
//   - Nombre del producto
//   - Precio principal en dólares ($) resaltado
//   - Precio equivalente en bolívares (Bs.) calculado dinámicamente con la tasa del día
//   - Botón ergonómico (+) para agregar al carrito

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/cart_provider.dart';
import '../../providers/exchange_rate_provider.dart';

/// Mapeo de categoría a ícono y color para feedback visual inmediato.
({IconData icon, Color color}) _categoryVisual(String categoryId) {
  switch (categoryId) {
    case 'cat-bebidas-001':
      return (
        icon: Icons.local_cafe_rounded,
        color: const Color(0xFF3B82F6),
      );
    case 'cat-comida-001':
      return (
        icon: Icons.lunch_dining_rounded,
        color: const Color(0xFFEF6C00),
      );
    case 'cat-licores-001':
      return (
        icon: Icons.wine_bar_rounded,
        color: const Color(0xFF7C3AED),
      );
    case 'cat-postres-001':
      return (
        icon: Icons.cake_rounded,
        color: const Color(0xFFEC4899),
      );
    default:
      return (
        icon: Icons.restaurant_menu_rounded,
        color: const Color(0xFF64748B),
      );
  }
}

class ProductCard extends ConsumerWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = _categoryVisual(product.categoryId);
    final rateAsync = ref.watch(exchangeRateProvider);
    final rate = rateAsync.value?.rate ?? 0.0;
    final priceVes = product.priceUsd * rate;

    // Verificar si el producto ya está en el carrito para mostrar badge de cantidad
    final cartItems = ref.watch(cartProvider);
    final cartIndex =
        cartItems.indexWhere((item) => item.product.id == product.id);
    final inCartQty = cartIndex >= 0 ? cartItems[cartIndex].qty : 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: inCartQty > 0
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5)
            : Border.all(color: AppColors.border.withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            ref.read(cartProvider.notifier).addProduct(product);
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${product.name} agregado',
                        style: const TextStyle(fontFamily: 'Poppins'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 700),
                behavior: SnackBarBehavior.floating,
                width: 260,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.12),
          highlightColor: AppColors.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabecera: Ícono de categoría + Badge en carrito ────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: visual.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(visual.icon, color: visual.color, size: 22),
                    ),
                    if (inCartQty > 0)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$inCartQty en pedido',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // ── Nombre del producto ───────────────────────────────────────
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                // ── Precios multimoneda + Botón agregar (+) ───────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Columna de precios (USD destacado + VES debajo)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Precio USD resaltado
                          Text(
                            '\$${product.priceUsd.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          // Precio en Bs. equivalente
                          Text(
                            rate > 0
                                ? 'Bs. ${priceVes.toStringAsFixed(2)}'
                                : 'Bs. --',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Botón + circular ergonómico
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
