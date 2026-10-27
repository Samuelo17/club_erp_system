// lib/features/admin/presentation/widgets/admin_menu_view.dart
//
// Gestor de Menú (CRUD) para la Encargada.
// Permite:
//   - Ver el catálogo agrupado por categorías
//   - Crear nuevas categorías y productos mediante el FAB
//   - Editar nombre, precio, disponibilidad o eliminar productos (soft delete)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/admin_providers.dart';

class AdminMenuView extends ConsumerWidget {
  const AdminMenuView({super.key});

  /// Muestra el modal para crear un nuevo producto
  void _openCreateProductDialog(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories,
  ) {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero debes crear al menos una categoría.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => _ProductFormDialog(
        categories: categories,
        title: 'Nuevo Producto',
        onSave: (name, price, categoryId, isAvailable) async {
          final success =
              await ref.read(menuAdminProvider.notifier).createProduct(
                    name: name,
                    priceUsd: price,
                    categoryId: categoryId,
                    isAvailable: isAvailable,
                  );
          if (dialogCtx.mounted && success) {
            Navigator.of(dialogCtx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Producto "$name" creado exitosamente'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  /// Muestra el modal para editar o eliminar un producto existente
  void _openEditProductDialog(
    BuildContext context,
    WidgetRef ref,
    Product product,
    List<Category> categories,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _ProductFormDialog(
        categories: categories,
        title: 'Editar Producto',
        initialProduct: product,
        onSave: (name, price, categoryId, isAvailable) async {
          final success =
              await ref.read(menuAdminProvider.notifier).updateProduct(
                    id: product.id,
                    name: name,
                    priceUsd: price,
                    categoryId: categoryId,
                    isAvailable: isAvailable,
                  );
          if (dialogCtx.mounted && success) {
            Navigator.of(dialogCtx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Producto "$name" actualizado'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onDelete: () async {
          final success =
              await ref.read(menuAdminProvider.notifier).deleteProduct(product.id);
          if (dialogCtx.mounted && success) {
            Navigator.of(dialogCtx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Producto "${product.name}" eliminado'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  /// Muestra el diálogo para crear una nueva categoría
  void _openCreateCategoryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Nueva Categoría',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Ej. Cafés, Postres, Pizzas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar', style: TextStyle(fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final success =
                  await ref.read(menuAdminProvider.notifier).createCategory(name);
              if (dialogCtx.mounted && success) {
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Categoría "$name" creada exitosamente'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Crear', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Despliega el menú del FAB para elegir qué agregar
  void _showAddMenu(BuildContext context, WidgetRef ref, List<Category> categories) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fastfood_rounded, color: AppColors.primary),
              ),
              title: const Text(
                'Agregar Nuevo Producto',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Nombre, precio, categoría y estado'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _openCreateProductDialog(context, ref, categories);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.category_rounded, color: Color(0xFF2563EB)),
              ),
              title: const Text(
                'Agregar Nueva Categoría',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Clasificación para agrupar productos'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _openCreateCategoryDialog(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(adminCategoriesProvider);
    final productsAsync = ref.watch(adminProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      floatingActionButton: categoriesAsync.when(
        data: (categories) => FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => _showAddMenu(context, ref, categories),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Agregar',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
          ),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant_menu_rounded,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay categorías creadas',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => _openCreateCategoryDialog(context, ref),
                    child: const Text('Crear Primera Categoría'),
                  ),
                ],
              ),
            );
          }

          return productsAsync.when(
            data: (products) {
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                physics: const BouncingScrollPhysics(),
                itemCount: categories.length,
                itemBuilder: (context, catIndex) {
                  final category = categories[catIndex];
                  final categoryProducts = products
                      .where((p) => p.categoryId == category.id)
                      .toList();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabecera de Categoría
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${categoryProducts.length} ${categoryProducts.length == 1 ? "ítem" : "ítems"}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Lista de Productos de esta Categoría
                        if (categoryProducts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Sin productos en esta categoría. Usa el botón (+) para agregar uno.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        else
                          ...categoryProducts.map((product) {
                            return InkWell(
                              onTap: () => _openEditProductDialog(
                                context,
                                ref,
                                product,
                                categories,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.divider,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: product.isAvailable
                                                      ? AppColors.successLight
                                                      : AppColors.errorLight,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  product.isAvailable
                                                      ? 'Disponible'
                                                      : 'Agotado',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: product.isAvailable
                                                      ? AppColors.success
                                                      : AppColors.error,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '\$${product.priceUsd.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error cargando productos: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error cargando categorías: $e')),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO: _ProductFormDialog (Crear o Editar Producto)
// ─────────────────────────────────────────────────────────────────────────────

class _ProductFormDialog extends StatefulWidget {
  final List<Category> categories;
  final String title;
  final Product? initialProduct;
  final void Function(
    String name,
    double price,
    String categoryId,
    bool isAvailable,
  ) onSave;
  final VoidCallback? onDelete;

  const _ProductFormDialog({
    required this.categories,
    required this.title,
    this.initialProduct,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late String _selectedCategoryId;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      _nameController.text = widget.initialProduct!.name;
      _priceController.text = widget.initialProduct!.priceUsd.toStringAsFixed(2);
      _selectedCategoryId = widget.initialProduct!.categoryId;
      _isAvailable = widget.initialProduct!.isAvailable;
    } else {
      _selectedCategoryId = widget.categories.first.id;
      _isAvailable = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    widget.onSave(
      _nameController.text.trim(),
      price,
      _selectedCategoryId,
      _isAvailable,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialProduct != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Nombre del Producto',
                  hintText: 'Ej. Hamburguesa Doble Especial',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa el nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Precio en USD (\$)',
                  prefixText: '\$ ',
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa el precio';
                  }
                  final price = double.tryParse(val.trim());
                  if (price == null || price <= 0) {
                    return 'Precio debe ser mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: widget.categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat.id,
                    child: Text(cat.name,
                        style: const TextStyle(fontFamily: 'Poppins')),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategoryId = val);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Disponible para venta',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                ),
                subtitle: Text(
                  _isAvailable ? 'Aparece en el POS' : 'Oculto o agotado',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11),
                ),
                value: _isAvailable,
                onChanged: (val) => setState(() => _isAvailable = val),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            if (isEditing && widget.onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                tooltip: 'Eliminar producto',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (confirmCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      title: const Text('¿Eliminar producto?'),
                      content: const Text(
                        'El producto se marcará como eliminado del menú.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(confirmCtx).pop(),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(confirmCtx).pop();
                            widget.onDelete!();
                          },
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar',
                  style: TextStyle(fontFamily: 'Poppins')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _handleSubmit,
              child: Text(
                isEditing ? 'Guardar' : 'Crear',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
