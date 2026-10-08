import 'package:club_erp_system/features/pos/domain/entities/product.dart';

/// Modelo de datos que extiende la entidad [Product].
/// Encapsula la lógica de mapeo desde/hacia SQLite.
class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.categoryId,
    required super.name,
    required super.currentPrice,
    super.isActive,
  });

  /// Crea un [ProductModel] a partir de un [Map] proveniente de SQLite.
  /// SQLite almacena booleanos como INTEGER (1 = true, 0 = false).
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      currentPrice: (map['current_price'] as num).toDouble(),
      isActive: (map['is_active'] as int) == 1,
    );
  }
}
