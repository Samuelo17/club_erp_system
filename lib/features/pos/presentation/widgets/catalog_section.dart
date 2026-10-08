import 'package:flutter/material.dart';

import 'package:club_erp_system/features/pos/data/repositories_impl/catalog_repository_impl.dart';
import 'package:club_erp_system/features/pos/domain/entities/category.dart';
import 'package:club_erp_system/features/pos/domain/entities/product.dart';
import 'package:club_erp_system/features/pos/domain/repositories/catalog_repository.dart';
import 'package:club_erp_system/features/pos/presentation/widgets/category_chip.dart';
import 'package:club_erp_system/features/pos/presentation/widgets/product_card.dart';

/// Sección principal del catálogo: categorías (filtro horizontal) + grid de productos.
///
/// Maneja estado async con [StatefulWidget]:
/// - Carga categorías al iniciar.
/// - Al seleccionar una categoría, carga sus productos.
/// - Layout 100% vertical, optimizado para teléfonos móviles.
class CatalogSection extends StatefulWidget {
  const CatalogSection({super.key});

  @override
  State<CatalogSection> createState() => _CatalogSectionState();
}

class _CatalogSectionState extends State<CatalogSection> {
  final CatalogRepository _repository = CatalogRepositoryImpl();

  // --- Estado ---
  List<Category> _categories = [];
  List<Product> _products = [];
  Category? _selectedCategory;
  bool _isLoadingCategories = true;
  bool _isLoadingProducts = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  /// Carga las categorías desde SQLite y selecciona la primera automáticamente.
  Future<void> _loadCategories() async {
    try {
      final categories = await _repository.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });

      // Seleccionar la primera categoría por defecto
      if (categories.isNotEmpty) {
        _onCategorySelected(categories.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
        _errorMessage = 'Error al cargar categorías: $e';
      });
    }
  }

  /// Callback al tocar una categoría: actualiza selección y carga productos.
  Future<void> _onCategorySelected(Category category) async {
    setState(() {
      _selectedCategory = category;
      _isLoadingProducts = true;
      _products = [];
    });

    try {
      final products = await _repository.getProductsByCategory(category.id);
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _errorMessage = 'Error al cargar productos: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Estado de error global
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== BARRA DE CATEGORÍAS (Filtros rápidos horizontales) =====
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: _isLoadingCategories
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected =
                        _selectedCategory?.id == category.id;

                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < _categories.length - 1 ? 10 : 0,
                      ),
                      child: CategoryChip(
                        category: category,
                        isSelected: isSelected,
                        onTap: () => _onCategorySelected(category),
                      ),
                    );
                  },
                ),
        ),

        const SizedBox(height: 16),

        // ===== GRID DE PRODUCTOS =====
        Expanded(
          child: _buildProductsGrid(),
        ),
      ],
    );
  }

  /// Construye el Grid de productos con manejo de estados vacío/loading/data.
  Widget _buildProductsGrid() {
    if (_isLoadingProducts) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF8C00),
          strokeWidth: 2.5,
        ),
      );
    }

    if (_selectedCategory == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Selecciona una categoría',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Sin productos en esta categoría',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        return ProductCard(
          product: _products[index],
          onTap: () {
            // TODO: US-1.2 — Agregar producto al carrito
          },
        );
      },
    );
  }
}
