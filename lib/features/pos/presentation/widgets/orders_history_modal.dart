import 'package:flutter/material.dart';

import 'package:club_erp_system/features/pos/data/repositories_impl/order_repository_impl.dart';
import 'package:club_erp_system/features/pos/domain/entities/order.dart';
import 'package:club_erp_system/features/pos/domain/entities/order_item.dart';
import 'package:club_erp_system/features/pos/domain/repositories/order_repository.dart';

/// ============================================================================
/// MODAL DE HISTORIAL DE ÓRDENES DEL DÍA — (US-3.3)
/// ============================================================================
///
/// Características:
/// - Consulta las órdenes de la fecha actual en SQLite (filtradas por fecha 'hoy').
/// - Muestra cabecera con ID Corto (...xxxxxx), Hora de creación (HH:mm) y Monto.
/// - Detalle expandible con `ExpansionTile` para ver los ítems con sus nombres (JOIN).
/// - **Estrictamente SOLO LECTURA**: Sin botones de cancelar, editar ni reembolsar.
/// ============================================================================
class OrdersHistoryModal extends StatefulWidget {
  final OrderRepository? repository;

  const OrdersHistoryModal({super.key, this.repository});

  /// Abre el modal como un Bottom Sheet deslizable y adaptado a móviles.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OrdersHistoryModal(),
    );
  }

  @override
  State<OrdersHistoryModal> createState() => _OrdersHistoryModalState();
}

class _OrdersHistoryModalState extends State<OrdersHistoryModal> {
  late final OrderRepository _repository;

  bool _isLoading = true;
  String? _errorMessage;
  List<Order> _orders = [];

  /// Caché en memoria para los ítems de órdenes ya expandidas.
  /// Evita consultas redundantes a SQLite al colapsar y volver a expandir.
  final Map<String, List<OrderItem>> _itemsCache = {};

  /// Conjunto de IDs de órdenes cuyos ítems se están cargando en este instante.
  final Set<String> _loadingOrderIds = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OrderRepositoryImpl();
    _loadTodayOrders();
  }

  Future<void> _loadTodayOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _repository.getTodayCompletedOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar el historial: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadItemsForOrder(String orderId) async {
    if (_itemsCache.containsKey(orderId) || _loadingOrderIds.contains(orderId)) {
      return;
    }

    setState(() {
      _loadingOrderIds.add(orderId);
    });

    try {
      final items = await _repository.getOrderItemsWithDetails(orderId);
      if (!mounted) return;
      setState(() {
        _itemsCache[orderId] = items;
        _loadingOrderIds.remove(orderId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOrderIds.remove(orderId);
      });
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle de arrastre
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Encabezado
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8C00).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFFF8C00),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Órdenes del Día (Historial)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Solo lectura • Transparencia de caja',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),

            // Contenido principal
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFFF8C00),
            ),
            SizedBox(height: 14),
            Text(
              'Cargando órdenes de hoy...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF374151), fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadTodayOrders,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFFFF8C00),
        onRefresh: _loadTodayOrders,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: const [
            SizedBox(height: 40),
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 16),
            Text(
              'Sin órdenes registradas hoy',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Las órdenes procesadas en el terminal durante el día actual aparecerán listadas aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    // Calcular monto total acumulado del día para el resumen superior
    final totalSales = _orders.fold<double>(
      0.0,
      (sum, order) => sum + order.totalAmount,
    );

    return RefreshIndicator(
      color: const Color(0xFFFF8C00),
      onRefresh: _loadTodayOrders,
      child: Column(
        children: [
          // Banner resumen informativo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: const Color(0xFFF3F4F6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.insights_rounded,
                      size: 15,
                      color: Color(0xFF4B5563),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_orders.length} ${_orders.length == 1 ? "orden" : "órdenes"} hoy',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Total: \$${totalSales.toStringAsFixed(2)} USD',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),

          // Lista de Órdenes
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = _orders[index];
                return _buildOrderCard(order);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final orderId = order.id;
    final isDetailLoading = _loadingOrderIds.contains(orderId);
    final items = _itemsCache[orderId];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          // Quitar bordes divisorios por defecto de ExpansionTile
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            onExpansionChanged: (isExpanded) {
              if (isExpanded) {
                _loadItemsForOrder(orderId);
              }
            },
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 20,
              ),
            ),
            // CABECERA SIEMPRE VISIBLE (AC):
            // 1. ID Corto (...a4f9b2)
            // 2. Hora de la orden (HH:MM)
            // 3. totalAmount destacado en verde / negrita
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    order.shortId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(order.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            trailing: Text(
              '\$${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF16A34A),
              ),
            ),

            // CONTENIDO DESPLEGABLE (DETALLE):
            // Muestra una lista minimalista: [Cantidad] x [Nombre del Producto] - [Subtotal]
            children: [
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.format_list_bulleted_rounded,
                    size: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'DETALLE DE ÍTEMS'.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (isDetailLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF8C00),
                      ),
                    ),
                  ),
                )
              else if (items == null || items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No hay ítems registrados para esta orden.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                )
              else
                Column(
                  children: items.map((item) {
                    final pName = item.productName ?? 'Producto';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // [Cantidad] x [Nombre del Producto]
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${item.quantity}x ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFFFF8C00),
                                    ),
                                  ),
                                  TextSpan(
                                    text: pName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // [Subtotal]
                          Text(
                            '\$${item.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
