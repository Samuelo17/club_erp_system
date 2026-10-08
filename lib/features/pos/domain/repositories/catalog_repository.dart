import 'package:club_erp_system/features/pos/domain/entities/category.dart';
import 'package:club_erp_system/features/pos/domain/entities/product.dart';

/// Contrato abstracto para el repositorio del catálogo.
/// La capa de Domain define QUÉ necesita, sin importar el CÓMO.
abstract class CatalogRepository {
  /// Obtiene todas las categorías activas del catálogo.
  Future<List<Category>> getCategories();

  /// Obtiene todos los productos activos de una categoría específica.
  Future<List<Product>> getProductsByCategory(String categoryId);
}
