import 'package:club_erp_system/features/pos/domain/entities/product.dart';

/// Representa un ítem dentro del carrito de compras (ticket dinámico).
///
/// Contiene una referencia inmutable al [Product] y una [quantity] mutable
/// que se actualiza desde el [CartProvider].
///
/// **Restricción US-1.2**: este objeto vive exclusivamente en memoria.
/// La persistencia en SQLite se implementará en US-1.3.
class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  /// Subtotal = precio unitario × cantidad.
  double get subtotal => product.currentPrice * quantity;
}
