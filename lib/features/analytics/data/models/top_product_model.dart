import '../../domain/entities/top_product_item.dart';

/// Modelo de datos que extiende [TopProductItem] con deserialización desde SQLite.
class TopProductModel extends TopProductItem {
  const TopProductModel({
    required super.productId,
    required super.name,
    required super.quantity,
    required super.revenue,
  });

  factory TopProductModel.fromMap(Map<String, dynamic> map) {
    return TopProductModel(
      productId: map['product_id'] as String? ?? '',
      name: (map['product_name'] ?? map['name'] ?? 'Producto') as String,
      quantity: (map['total_quantity'] as num?)?.toInt() ?? 0,
      revenue: (map['total_revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
