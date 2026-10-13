import 'package:flutter/foundation.dart';

import 'package:club_erp_system/core/local_db/powersync_helper.dart';
import 'package:club_erp_system/features/exchange_rate/data/models/exchange_rate_model.dart';
import 'package:club_erp_system/features/exchange_rate/domain/entities/exchange_rate.dart';
import 'package:club_erp_system/features/exchange_rate/domain/repositories/exchange_rate_repository.dart';

/// ============================================================================
/// IMPLEMENTACIÓN DEL REPOSITORIO DE TASAS DE CAMBIO (POWERSYNC / SQLITE)
/// ============================================================================
///
/// REGLA INQUEBRANTABLE DE INMUTABILIDAD:
///   Solo se ejecutan operaciones INSERT INTO exchange_rates.
///   NUNCA UPDATE. Cada tasa nueva genera un registro fresco para
///   preservar el historial completo de auditoría.
///
/// REACTIVIDAD OFFLINE-FIRST:
///   watchLatestExchangeRate() usa db.watch() de PowerSync, que emite
///   automáticamente cada vez que la tabla muta (INSERT local o
///   sincronización remota desde otro dispositivo).
/// ============================================================================

class ExchangeRateRepositoryImpl implements ExchangeRateRepository {
  /// Query reutilizada para obtener la tasa más reciente.
  ///
  /// Ordena por created_at DESC y limita a 1, respetando soft deletes.
  static const String _latestRateQuery = '''
    SELECT id, rate_value, created_by, created_at, updated_at
    FROM exchange_rates
    WHERE deleted_at IS NULL
    ORDER BY created_at DESC
    LIMIT 1
  ''';

  @override
  Future<void> saveExchangeRate(ExchangeRate rate) async {
    final db = PowerSyncHelper.instance.database;
    final model = ExchangeRateModel.fromEntity(rate);
    final map = model.toMap();

    await db.execute(
      'INSERT INTO exchange_rates(id, rate_value, created_by, created_at, updated_at) '
      'VALUES(?, ?, ?, ?, ?)',
      [
        map['id'],
        map['rate_value'],
        map['created_by'],
        map['created_at'],
        map['updated_at'],
      ],
    );

    debugPrint(
      '✅ [ExchangeRateRepo] Tasa registrada: '
      '${rate.rateValue} VES/USD (id: ${rate.id})',
    );
  }

  @override
  Future<ExchangeRate?> getLatestExchangeRate() async {
    final db = PowerSyncHelper.instance.database;
    final results = await db.execute(_latestRateQuery);

    if (results.isEmpty) return null;

    return ExchangeRateModel.fromMap(results.first).toEntity();
  }

  @override
  Stream<ExchangeRate?> watchLatestExchangeRate() {
    final db = PowerSyncHelper.instance.database;

    // db.watch() emite una nueva lista de filas cada vez que la tabla
    // exchange_rates sufre cualquier cambio (INSERT local o sync remoto).
    return db.watch(_latestRateQuery).map((rows) {
      if (rows.isEmpty) return null;
      return ExchangeRateModel.fromMap(rows.first).toEntity();
    });
  }
}
