import 'package:flutter/foundation.dart';

import 'package:club_erp_system/core/local_db/sqlite_helper.dart';
import 'package:club_erp_system/features/pos/data/models/order_model.dart';
import 'package:club_erp_system/features/pos/data/models/order_item_model.dart';
import 'package:club_erp_system/features/pos/domain/entities/order.dart';
import 'package:club_erp_system/features/pos/domain/entities/order_item.dart';
import 'package:club_erp_system/features/pos/domain/repositories/order_repository.dart';

/// Implementación concreta de [OrderRepository] usando SQLite.
///
/// **Transaccionalidad**: Usa `db.transaction()` para garantizar que la
/// inserción de la orden y TODOS sus ítems sea atómica. Si algo falla,
/// SQLite hace rollback automático y no queda data huérfana.
class OrderRepositoryImpl implements OrderRepository {
  @override
  Future<void> createOrder(Order order, List<OrderItem> items) async {
    final db = await SQLiteHelper.instance.database;

    await db.transaction((txn) async {
      // 1. Insertar la orden principal
      final orderModel = OrderModel.fromEntity(order);
      await txn.insert('orders', orderModel.toMap());

      // 2. Insertar cada ítem de la orden dentro de la misma transacción
      for (final item in items) {
        final itemModel = OrderItemModel.fromEntity(item);
        await txn.insert('order_items', itemModel.toMap());
      }

      debugPrint(
        '✅ Orden ${order.id} persistida con ${items.length} ítem(s). '
        'Total: \$${order.totalAmount.toStringAsFixed(2)}',
      );
    });
  }
}
