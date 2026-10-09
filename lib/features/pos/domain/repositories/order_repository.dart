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
}
