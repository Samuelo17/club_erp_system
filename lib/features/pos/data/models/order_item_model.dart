import 'package:club_erp_system/features/pos/domain/entities/order_item.dart';

/// Modelo de datos que extiende la entidad [OrderItem].
/// Encapsula la lógica de mapeo hacia SQLite.
///
/// **Inmutabilidad Financiera**: [unitPrice] es la copia congelada del
/// `currentPrice` del producto al momento de crear la orden.
class OrderItemModel extends OrderItem {
  const OrderItemModel({
    required super.id,
    required super.orderId,
    required super.productId,
    required super.quantity,
    required super.unitPrice,
    super.productName,
  });

  /// Convierte la entidad en un [Map] compatible con `db.insert('order_items', ...)`.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Deserializa una fila de SQLite (con posible JOIN de products) a [OrderItemModel].
  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      productId: map['product_id'] as String,
      quantity: (map['quantity'] as num).toInt(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      productName: (map['product_name'] ?? map['name']) as String?,
    );
  }

  /// Crea un [OrderItemModel] directamente desde una entidad [OrderItem] de dominio.
  factory OrderItemModel.fromEntity(OrderItem item) {
    return OrderItemModel(
      id: item.id,
      orderId: item.orderId,
      productId: item.productId,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      productName: item.productName,
    );
  }
}
