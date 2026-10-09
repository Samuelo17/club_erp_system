/// Entidad de dominio que representa un ítem individual de una orden.
///
/// Mapea directamente la tabla `order_items` del DDL.
///
/// **Inmutabilidad Financiera**: [unitPrice] es una copia congelada del
/// `currentPrice` del producto en el instante exacto de la compra.
/// Si el precio del producto cambia en el futuro, esta orden NO se ve afectada.
class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPrice;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });
}
