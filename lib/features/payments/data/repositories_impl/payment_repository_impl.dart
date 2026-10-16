import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:club_erp_system/core/local_db/sqlite_helper.dart';
import 'package:club_erp_system/features/payments/data/models/payment_method_model.dart';
import 'package:club_erp_system/features/payments/data/models/payment_model.dart';
import 'package:club_erp_system/features/payments/domain/entities/payment.dart';
import 'package:club_erp_system/features/payments/domain/entities/payment_method.dart';
import 'package:club_erp_system/features/payments/domain/repositories/payment_repository.dart';

/// Implementación concreta de [PaymentRepository] usando SQLite directo.
///
/// El módulo de pagos usa [SQLiteHelper] (no PowerSync) porque el schema
/// de payment_methods y payments ya está declarado en el schema PowerSync
/// pero los métodos de pago son datos de configuración que se seed localmente.
///
/// **Seeding Automático**: Si la tabla `payment_methods` está vacía, se
/// insertan los 4 métodos de pago del MVP automáticamente.
class PaymentRepositoryImpl implements PaymentRepository {

  /// Fijos para garantizar idempotencia en el seeding.
  static const String _idEfectivoUsd = 'pm-0000-0000-0000-efusd0000001';
  static const String _idEfectivoVes = 'pm-0000-0000-0000-efves0000002';
  static const String _idPagoMovil = 'pm-0000-0000-0000-pmovil000003';
  static const String _idPuntoVenta = 'pm-0000-0000-0000-pventa000004';

  /// Los 4 métodos de pago del MVP del club de piscina.
  static final List<Map<String, dynamic>> _defaultMethods = [
    {
      'id': _idEfectivoUsd,
      'name': 'Efectivo USD',
      'is_active': 1,
    },
    {
      'id': _idEfectivoVes,
      'name': 'Efectivo VES',
      'is_active': 1,
    },
    {
      'id': _idPagoMovil,
      'name': 'Pago Móvil',
      'is_active': 1,
    },
    {
      'id': _idPuntoVenta,
      'name': 'Punto de Venta',
      'is_active': 1,
    },
  ];

  @override
  Future<List<PaymentMethod>> getPaymentMethods() async {
    final db = await SQLiteHelper.instance.database;

    // Asegurar que las tablas de pago existan y tengan datos semilla
    await _ensurePaymentTablesAndSeed(db);

    final results = await db.query(
      'payment_methods',
      where: 'is_active = ? AND deleted_at IS NULL',
      whereArgs: [1],
      orderBy: 'name ASC',
    );

    return results
        .map((row) => PaymentMethodModel.fromMap(row))
        .toList();
  }

  @override
  Future<void> processPayment(Payment payment) async {
    final db = await SQLiteHelper.instance.database;

    final model = PaymentModel.fromEntity(payment);
    final map = model.toMap();

    await db.insert(
      'payments',
      map,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    debugPrint(
      '✅ [PaymentRepo] Pago registrado: '
      '${payment.currency} ${payment.amount.toStringAsFixed(2)} '
      '| Método: ${payment.paymentMethodId} '
      '| Estado: ${payment.status} '
      '| Ref: ${payment.referenceNumber ?? "N/A"}',
    );
  }

  @override
  Future<List<Payment>> getPendingPayments() async {
    final db = await SQLiteHelper.instance.database;
    await _ensurePaymentTablesAndSeed(db);

    final results = await db.query(
      'payments',
      where: 'status = ? AND deleted_at IS NULL',
      whereArgs: ['PENDING_VALIDATION'],
      orderBy: 'created_at DESC',
    );

    return results.map((row) => PaymentModel.fromMap(row)).toList();
  }

  @override
  Future<void> approvePayment(String paymentId) async {
    final db = await SQLiteHelper.instance.database;
    await _ensurePaymentTablesAndSeed(db);

    final now = DateTime.now().toIso8601String();
    final count = await db.update(
      'payments',
      {
        'status': 'CONCILIADO',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [paymentId],
    );

    if (count == 0) {
      throw Exception('No se encontró el pago $paymentId para conciliar.');
    }

    debugPrint('✅ [PaymentRepo] Pago $paymentId conciliado a CONCILIADO.');
  }

  // ---------------------------------------------------------------------------
  // PRIVADO — Ensure tablas y seeding
  // ---------------------------------------------------------------------------

  /// Crea las tablas de pagos en SQLite (si aún no existen) y siembra
  /// los métodos de pago por defecto si la tabla está vacía.
  ///
  /// Esto es necesario porque la DB principal se crea con [SQLiteHelper]
  /// en versión 2, y las tablas de pagos se agregan en la versión 3.
  Future<void> _ensurePaymentTablesAndSeed(Database db) async {
    // Crear tabla payment_methods si no existe
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_methods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');

    // Crear tabla payments si no existe
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
        deleted_at TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id),
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id)
      )
    ''');

    // Sembrar métodos de pago por defecto si la tabla está vacía
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM payment_methods'),
    );

    if (count == 0) {
      final now = DateTime.now().toIso8601String();
      for (final method in _defaultMethods) {
        await db.insert(
          'payment_methods',
          {
            ...method,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      debugPrint(
        '🎯 [PaymentRepo] Seeding: ${_defaultMethods.length} métodos de pago insertados.',
      );
    }
  }
}
