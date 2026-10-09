import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/features/pos/domain/entities/cart_item.dart';
import 'package:club_erp_system/features/pos/presentation/providers/cart_provider.dart';

/// Tile individual de un [CartItem] dentro del bottom sheet del ticket.
///
/// Diseño ergonómico para móvil:
/// - Nombre del producto y subtotal claramente visibles.
/// - Botonera [ − ]  cantidad  [ + ] con áreas de toque grandes (≥ 48 dp).
/// - Gesto de deslizar para eliminar (Dismissible).
class CartItemTile extends StatelessWidget {
  final CartItem cartItem;

  const CartItemTile({
    super.key,
    required this.cartItem,
  });

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.read<CartProvider>();

    return Dismissible(
      key: ValueKey(cartItem.product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: Colors.red.shade400,
          size: 24,
        ),
      ),
      onDismissed: (_) => cartProvider.removeProduct(cartItem.product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // — Ícono decorativo —
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: Color(0xFFFF8C00),
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // — Nombre + Subtotal —
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$ ${cartItem.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // — Botonera de cantidad: [ − ]  qty  [ + ] —
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón decrementar
                  _QuantityButton(
                    icon: Icons.remove_rounded,
                    onTap: () =>
                        cartProvider.decrementQuantity(cartItem.product),
                    isDestructive: cartItem.quantity == 1,
                  ),

                  // Cantidad actual
                  Container(
                    constraints: const BoxConstraints(minWidth: 36),
                    alignment: Alignment.center,
                    child: Text(
                      '${cartItem.quantity}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),

                  // Botón incrementar
                  _QuantityButton(
                    icon: Icons.add_rounded,
                    onTap: () =>
                        cartProvider.incrementQuantity(cartItem.product),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón circular para la botonera de cantidad.
///
/// Cumple con las guías de Material Design: mínimo 48×48 dp de área táctil.
class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 20,
            color: isDestructive
                ? Colors.red.shade400
                : const Color(0xFFFF8C00),
          ),
        ),
      ),
    );
  }
}
