import 'package:club_erp_system/core/local_db/sqlite_helper.dart';
import 'package:club_erp_system/features/pos/data/models/category_model.dart';
import 'package:club_erp_system/features/pos/data/models/product_model.dart';
import 'package:club_erp_system/features/pos/domain/entities/category.dart';
import 'package:club_erp_system/features/pos/domain/entities/product.dart';
import 'package:club_erp_system/features/pos/domain/repositories/catalog_repository.dart';

/// Implementación concreta de [CatalogRepository] usando SQLite.
/// Convierte los registros de la base de datos en entidades de dominio puras.
class CatalogRepositoryImpl implements CatalogRepository {
  @override
  Future<List<Category>> getCategories() async {
    final db = await SQLiteHelper.instance.database;

    final result = await db.query(
      'categories',
      where: 'is_active = ?',
      whereArgs: [1],
    );

    return result.map((map) => CategoryModel.fromMap(map)).toList();
  }

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    final db = await SQLiteHelper.instance.database;

    final result = await db.query(
      'products',
      where: 'category_id = ? AND is_active = ?',
      whereArgs: [categoryId, 1],
    );

    return result.map((map) => ProductModel.fromMap(map)).toList();
  }
}
