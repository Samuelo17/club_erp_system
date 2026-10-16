import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:club_erp_system/core/local_db/sqlite_helper.dart';
import 'package:club_erp_system/features/cash_closure/domain/entities/cash_session.dart';
import 'package:club_erp_system/features/cash_closure/domain/repositories/cash_session_repository.dart';
import 'package:club_erp_system/features/payments/data/models/payment_model.dart';
import 'package:club_erp_system/features/payments/domain/entities/payment.dart';

/// Implementación concreta de [CashSessionRepository] usando SQLite directo (Offline-First).
class CashSessionRepositoryImpl implements CashSessionRepository {
  /// Asegura que la tabla cash_sessions tenga la columna ended_at si es requerida.
  Future<void> _ensureSchemaCompatibility(Database db) async {
    try {
      await db.execute('ALTER TABLE cash_sessions ADD COLUMN ended_at TEXT');
    } catch (_) {
      // Ignorar si la columna ya existe
    }
  }

  @override
  Future<CashSession?> getActiveSession() async {
    final db = await SQLiteHelper.instance.database;
    await _ensureSchemaCompatibility(db);

    final results = await db.query(
      'cash_sessions',
      where: 'status = ?',
      whereArgs: ['OPEN'],
      orderBy: 'opened_at DESC',
      limit: 1,
    );

    if (results.isEmpty) {
      // Si por alguna razón no hay sesión abierta en el MVP, intentamos reactivar la sesión dummy
      final now = DateTime.now().toIso8601String();
      await db.insert('cash_sessions', {
        'id': dummySessionId,
        'employee_id': dummyEmployeeId,
        'opened_at': now,
        'status': 'OPEN',
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      return CashSession(
        id: dummySessionId,
        employeeId: dummyEmployeeId,
        openedAt: DateTime.now(),
        status: 'OPEN',
      );
    }

    final row = results.first;
    return CashSession(
      id: row['id'] as String,
      employeeId: row['employee_id'] as String,
      openedAt: DateTime.tryParse(row['opened_at'] as String? ?? '') ?? DateTime.now(),
      closedAt: row['closed_at'] != null ? DateTime.tryParse(row['closed_at'] as String) : null,
      status: row['status'] as String,
    );
  }

  @override
  Future<Map<String, double>> getSessionTotalsByMethod(String sessionId) async {
    final db = await SQLiteHelper.instance.database;

    // Inicializar los 4 métodos de pago estándar con 0.0 para garantizar estructura
    final Map<String, double> totals = {
      'Efectivo USD': 0.0,
      'Efectivo VES': 0.0,
      'Pago Móvil': 0.0,
      'Punto de Venta': 0.0,
    };

    // Consulta SQL con SUM(amount) agrupado por método de pago para la sesión actual
    // usando JOIN entre payments, orders y payment_methods
    const sql = '''
      SELECT 
        pm.name as method_name,
        COALESCE(SUM(p.amount), 0.0) as total_amount
      FROM payments p
      INNER JOIN orders o ON p.order_id = o.id
      INNER JOIN payment_methods pm ON p.payment_method_id = pm.id
      WHERE o.cash_session_id = ?
        AND p.status != 'CANCELLED'
        AND o.status != 'CANCELLED'
      GROUP BY pm.id, pm.name;
    ''';

    final results = await db.rawQuery(sql, [sessionId]);

    for (final row in results) {
      final methodName = row['method_name'] as String?;
      final total = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
      if (methodName != null) {
        totals[methodName] = total;
      }
    }

    debugPrint('📊 [CashClosure] Totales por método para sesión $sessionId: $totals');
    return totals;
  }

  @override
  Future<List<Payment>> getPaymentsBySessionAndMethod(
    String sessionId,
    String methodId,
  ) async {
    final db = await SQLiteHelper.instance.database;

    // Query con JOIN entre payments, orders y payment_methods para filtrar por sesión y método
    const sql = '''
      SELECT 
        p.id,
        p.order_id,
        p.payment_method_id,
        p.amount,
        p.currency,
        p.exchange_rate,
        p.reference_number,
        p.bank_name,
        p.status,
        p.created_at
      FROM payments p
      INNER JOIN orders o ON p.order_id = o.id
      INNER JOIN payment_methods pm ON p.payment_method_id = pm.id
      WHERE o.cash_session_id = ?
        AND (pm.id = ? OR pm.name = ?)
        AND p.status != 'CANCELLED'
      ORDER BY p.created_at DESC;
    ''';

    final results = await db.rawQuery(sql, [sessionId, methodId, methodId]);

    final payments = results.map((row) => PaymentModel.fromMap(row)).toList();
    debugPrint(
      '📋 [CashClosure] ${payments.length} transacciones encontradas para método $methodId en sesión $sessionId',
    );
    return payments;
  }

  @override
  Future<void> closeSession(String sessionId) async {
    final db = await SQLiteHelper.instance.database;
    await _ensureSchemaCompatibility(db);

    final nowIso = DateTime.now().toIso8601String();

    // UPDATE en cash_sessions seteando status = 'CLOSED' y ended_at / closed_at = CURRENT_TIMESTAMP
    await db.rawUpdate('''
      UPDATE cash_sessions 
      SET status = 'CLOSED', 
          closed_at = ?,
          ended_at = ?,
          updated_at = ?
      WHERE id = ?
    ''', [nowIso, nowIso, nowIso, sessionId]);

    debugPrint('🔒 [CashClosure] Sesión de caja $sessionId CERRADA formalmente.');
  }
}
