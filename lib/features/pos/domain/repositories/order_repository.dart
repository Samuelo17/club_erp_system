import 'package:club_erp_system/features/pos/domain/entities/order.dart';
import 'package:club_erp_system/features/pos/domain/entities/order_item.dart';

/// Contrato abstracto para el repositorio de órdenes.
/// La capa de Domain define QUÉ necesita, sin importar el CÓMO.
abstract class OrderRepository {
  /// Persiste una orden completa con todos sus ítems de forma atómica.
  ///
  /// Si la inserción de cualquier ítem falla, toda la transacción
  /// se revierte automáticamente (rollback) para garantizar consistencia.
  Future<void> createOrder(Order order, List<OrderItem> items);

  /// Obtiene todas las órdenes pagadas/completadas de la fecha de hoy (US-3.3).
  ///
  /// Ignora la hora para agrupar por el día actual en SQLite.
  Future<List<Order>> getTodayCompletedOrders();

  /// Obtiene los ítems individuales de una orden con los detalles de producto (JOIN) (US-3.3).
  ///
  /// Incluye `productName` para mostrar la descripción en la UI.
  Future<List<OrderItem>> getOrderItemsWithDetails(String orderId);
}
