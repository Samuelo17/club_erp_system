/// Entidad de dominio que representa un producto en el Top de ventas del día.
class TopProductItem {
  final String productId;
  final String name;
  final int quantity;
  final double revenue;

  const TopProductItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  String get productName => name;
  int get totalQuantity => quantity;
}
