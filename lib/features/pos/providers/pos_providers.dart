// lib/features/pos/providers/pos_providers.dart
//
// Providers de Riverpod para el módulo POS: catálogo y filtros.
// Siguen la arquitectura reactiva: Drift (Stream) → Provider → UI.
// Permiten filtrar productos por categoría y búsqueda de texto.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS DE DATOS (Streams desde Drift)
// ─────────────────────────────────────────────────────────────────────────────

/// Stream reactivo de categorías activas desde Drift.
/// La UI renderiza chips de filtro a partir de este provider.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchActiveCategories();
});

/// Stream reactivo de todos los productos disponibles desde Drift.
/// Usado como fuente base para el filtrado.
final productsProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAvailableProducts();
});

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIERS DE FILTRO (UI State)
// Riverpod 3.x: reemplaza StateProvider con Notifier para estado simple.
// ─────────────────────────────────────────────────────────────────────────────

/// Notifier para la categoría seleccionada actualmente.
/// null = "Todos" (sin filtro de categoría).
class SelectedCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? categoryId) => state = categoryId;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String?>(
  SelectedCategoryNotifier.new,
);

/// Notifier para el texto de búsqueda.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER DERIVADO (Filtrado combinado)
// ─────────────────────────────────────────────────────────────────────────────

/// Provider que combina los filtros de categoría y búsqueda sobre la lista
/// completa de productos. Reactivo: se recalcula cuando cualquier dependencia
/// emite un nuevo valor.
final filteredProductsProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final selectedCategoryId = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();

  return productsAsync.when(
    data: (products) {
      var result = products;

      // Filtrar por categoría seleccionada
      if (selectedCategoryId != null) {
        result = result
            .where((p) => p.categoryId == selectedCategoryId)
            .toList();
      }

      // Filtrar por texto de búsqueda
      if (query.isNotEmpty) {
        result = result
            .where((p) => p.name.toLowerCase().contains(query))
            .toList();
      }

      return result;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});
