// lib/features/pos/providers/exchange_rate_provider.dart
//
// Provider global que expone la tasa de cambio activa como Stream reactivo.
// Cualquier cambio en la tasa actualiza automáticamente los precios en VES
// en toda la app (cartTotalProvider, display de precios, etc.).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

/// Stream reactivo de la tasa de cambio más reciente desde Drift.
///
/// Emite automáticamente cuando se registra una nueva tasa en la DB.
/// Retorna null si aún no existe ninguna tasa registrada.
final exchangeRateProvider = StreamProvider<ExchangeRate?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchLatestExchangeRate();
});
