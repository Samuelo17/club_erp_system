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

  @override
  Future<List<Order>> getTodayCompletedOrders() async {
    final db = await SQLiteHelper.instance.database;
    // Fecha local del cliente en formato YYYY-MM-DD
    final todayDateStr = DateTime.now().toIso8601String().substring(0, 10);

    // Consulta en SQLite ignorando la hora (comparación estricta por fecha YYYY-MM-DD)
    final results = await db.rawQuery('''
      SELECT DISTINCT o.*
      FROM orders o
      LEFT JOIN payments p ON o.id = p.order_id
      WHERE o.deleted_at IS NULL
        AND (o.status = 'COMPLETED' OR p.id IS NOT NULL OR o.status != 'CANCELED')
        AND (
          date(o.created_at) = ?
          OR date(o.created_at) = date('now', 'localtime')
        )
      ORDER BY o.created_at DESC
    ''', [todayDateStr]);

    return results.map((row) => OrderModel.fromMap(row)).toList();
  }

  @override
  Future<List<OrderItem>> getOrderItemsWithDetails(String orderId) async {
    final db = await SQLiteHelper.instance.database;

    // JOIN entre order_items y products para obtener el nombre del producto
    final results = await db.rawQuery('''
      SELECT 
        oi.id,
        oi.order_id,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        oi.created_at,
        COALESCE(p.name, 'Producto') AS product_name
      FROM order_items oi
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
        AND oi.deleted_at IS NULL
      ORDER BY oi.created_at ASC
    ''', [orderId]);

    return results.map((row) => OrderItemModel.fromMap(row)).toList();
  }
}
