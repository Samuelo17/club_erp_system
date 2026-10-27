// lib/features/kds/providers/kds_providers.dart
//
// Providers de Riverpod para el módulo KDS (Kitchen Display System).
// Arquitectura reactiva: Drift Stream (SQLite) → Riverpod StreamProvider → KdsScreen.
// Escucha en tiempo real comandas entrantes y permite actualizar su estado.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STREAM PROVIDER: Comandas de Cocina
// ─────────────────────────────────────────────────────────────────────────────

/// Escucha en tiempo real la cola de comandas de cocina ('pending' o 'cooking')
/// con sus respectivos ítems y nombres de productos.
///
/// Cada vez que la Cajera completa una orden en el POS o el Cocinero cambia el estado,
/// este StreamProvider emite automáticamente la nueva lista ordenada cronológicamente.
final kdsOrdersProvider = StreamProvider<List<KdsOrderData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchKdsOrders();
});

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLLER: Acciones sobre las Comandas
// ─────────────────────────────────────────────────────────────────────────────

/// Controlador para cambiar el estado de las órdenes en la cocina.
class KdsController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Avanza el estado de la comanda:
  /// - 'pending' -> 'cooking' ("INICIAR PREPARACIÓN")
  /// - 'cooking' -> 'ready' ("MARCAR LISTO")
  ///
  /// Al cambiar a 'ready', la orden desaparece automáticamente de la pantalla
  /// porque el query solo observa 'pending' y 'cooking'.
  Future<bool> advanceOrderStatus({
    required String orderId,
    required String currentStatus,
  }) async {
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      final nextStatus = currentStatus == 'pending' ? 'cooking' : 'ready';
      await db.updateOrderStatus(orderId, nextStatus);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

/// Provider para interactuar con las acciones de cocina.
final kdsControllerProvider =
    NotifierProvider<KdsController, AsyncValue<void>>(KdsController.new);
