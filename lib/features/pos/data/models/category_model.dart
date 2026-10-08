import 'package:club_erp_system/features/pos/domain/entities/category.dart';

/// Modelo de datos que extiende la entidad [Category].
/// Encapsula la lógica de mapeo desde/hacia SQLite.
class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.name,
    super.isActive,
  });

  /// Crea un [CategoryModel] a partir de un [Map] proveniente de SQLite.
  /// SQLite almacena booleanos como INTEGER (1 = true, 0 = false).
  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      isActive: (map['is_active'] as int) == 1,
    );
  }
}
