import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:club_erp_system/core/local_db/sqlite_helper.dart';
import '../../domain/entities/daily_analytics_summary.dart';
import '../../domain/entities/top_product_item.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../models/daily_analytics_summary_model.dart';
import '../models/top_product_model.dart';

/// Implementación concreta de [AnalyticsRepository] con agregaciones puras en SQLite (US-3.2).
///
/// **Reglas Estrictas de Eficiencia**:
/// 1. Los cálculos matemáticos (SUM, COUNT) se ejecutan directamente en SQLite.
/// 2. Cero procesamiento pesado en el hilo de Dart.
/// 3. Filtro estricto por la fecha actual (`DATE(created_at) = DATE('now', 'localtime')`).
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  @override
  Future<DailyAnalyticsSummary> getTodayAnalytics() async {
    final db = await SQLiteHelper.instance.database;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    // Asegurar que la tabla payments existe antes de consultar
    await _ensurePaymentsTableExists(db);

    // -------------------------------------------------------------------------
    // QUERY 1: Órdenes Hoy (COUNT) e Ingreso USD (SUM)
    // -------------------------------------------------------------------------
    int ordersCount = 0;
    double totalUsd = 0.0;

    try {
      final ordersResult = await db.rawQuery('''
        SELECT 
          COALESCE(COUNT(*), 0) AS orders_count,
          COALESCE(SUM(total_amount), 0.0) AS total_usd
        FROM orders
        WHERE deleted_at IS NULL
          AND status != 'CANCELED'
          AND (
            DATE(created_at) = ?
            OR DATE(created_at) = DATE('now', 'localtime')
          )
      ''', [todayStr]);

      if (ordersResult.isNotEmpty) {
        final row = ordersResult.first;
        ordersCount = (row['orders_count'] as num?)?.toInt() ?? 0;
        totalUsd = (row['total_usd'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('⚠️ [AnalyticsRepo] Error al calcular órdenes/USD: $e');
    }

    // -------------------------------------------------------------------------
    // QUERY 2: Ingreso VES (SUM en tabla payments donde currency = 'VES')
    // -------------------------------------------------------------------------
    double totalVes = 0.0;

    try {
      final paymentsResult = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(amount), 0.0) AS total_ves
        FROM payments
        WHERE deleted_at IS NULL
          AND currency = 'VES'
          AND (
            DATE(created_at) = ?
            OR DATE(created_at) = DATE('now', 'localtime')
          )
      ''', [todayStr]);

      if (paymentsResult.isNotEmpty) {
        final row = paymentsResult.first;
        totalVes = (row['total_ves'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('⚠️ [AnalyticsRepo] Error al calcular total VES: $e');
    }

    // -------------------------------------------------------------------------
    // QUERY 3: Top 3 de productos más vendidos (JOIN + GROUP BY + LIMIT 3)
    // -------------------------------------------------------------------------
    final List<TopProductItem> topProducts = [];

    try {
      final topResult = await db.rawQuery('''
        SELECT 
          p.id AS product_id,
          COALESCE(p.name, 'Producto') AS product_name,
          CAST(COALESCE(SUM(oi.quantity), 0) AS INTEGER) AS total_quantity,
          COALESCE(SUM(oi.quantity * oi.unit_price), 0.0) AS total_revenue
        FROM order_items oi
        JOIN products p ON oi.product_id = p.id
        JOIN orders o ON oi.order_id = o.id
        WHERE oi.deleted_at IS NULL
          AND o.deleted_at IS NULL
          AND o.status != 'CANCELED'
          AND (
            DATE(o.created_at) = ?
            OR DATE(o.created_at) = DATE('now', 'localtime')
          )
        GROUP BY p.id, p.name
        ORDER BY total_quantity DESC
        LIMIT 3
      ''', [todayStr]);

      for (final row in topResult) {
        topProducts.add(TopProductModel.fromMap(row));
      }
    } catch (e) {
      debugPrint('⚠️ [AnalyticsRepo] Error al calcular top 3 productos: $e');
    }

    debugPrint(
      '📊 [AnalyticsRepo] Resumen de hoy calculado en SQLite: '
      'Órdenes: $ordersCount | USD: \$${totalUsd.toStringAsFixed(2)} | '
      'VES: Bs. ${totalVes.toStringAsFixed(2)} | Top productos: ${topProducts.length}',
    );

    return DailyAnalyticsSummaryModel.fromAggregates(
      totalUsd: totalUsd,
      totalVes: totalVes,
      ordersCount: ordersCount,
      topProducts: topProducts,
    );
  }

  Future<void> _ensurePaymentsTableExists(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        payment_method_id TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL CHECK (currency IN ('USD', 'VES')),
        exchange_rate REAL NOT NULL,
        reference_number TEXT,
        status TEXT NOT NULL CHECK (status IN ('PENDING_VALIDATION', 'APROBADO_VISUALMENTE', 'CONCILIADO')),
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
  }
}
