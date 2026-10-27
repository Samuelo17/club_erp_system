// lib/features/admin/providers/admin_providers.dart
//
// Providers de Riverpod para el Dashboard de Administración (Rol Encargada).
// Controla:
//   - Actualización de la Tasa de Cambio (ExchangeRates)
//   - CRUD del Menú: Categorías y Productos (Categories & Products)
//   - Centro de Validación de Pagos (Payments en estado 'pending_validation')

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../auth/providers/auth_provider.dart';

const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// 1. GESTIÓN DE TASA DE CAMBIO
// ─────────────────────────────────────────────────────────────────────────────

/// Stream reactivo del historial reciente de tasas de cambio registradas.
final exchangeRateHistoryProvider =
    StreamProvider<List<ExchangeRate>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchExchangeRatesHistory();
});

/// Controlador para registrar una nueva tasa de cambio en Drift.
class ExchangeRateAdminNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Inserta una nueva tasa de cambio en Drift.
  /// Cualquier cambio actualiza automáticamente toda la app gracias a [exchangeRateProvider].
  Future<bool> updateRate(double newRate) async {
    if (newRate <= 0) return false;

    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      final auth = ref.read(authProvider);
      final roleId = auth.currentRole?.id ?? 'role-encargada-001';

      await db.insertExchangeRate(
        id: _uuid.v4(),
        rate: newRate,
        createdByRoleId: roleId,
      );

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final exchangeRateAdminProvider =
    NotifierProvider<ExchangeRateAdminNotifier, AsyncValue<void>>(
  ExchangeRateAdminNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. GESTIÓN DEL MENÚ (CRUD: Categorías y Productos)
// ─────────────────────────────────────────────────────────────────────────────

/// Stream reactivo de todas las categorías no eliminadas.
final adminCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllCategories();
});

/// Stream reactivo de todos los productos no eliminados.
final adminProductsProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllProducts();
});

/// Controlador para operaciones CRUD del catálogo.
class MenuAdminNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  // ── Operaciones de Categorías ──

  Future<bool> createCategory(String name) async {
    if (name.trim().isEmpty) return false;
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now();

      await db.createCategory(
        CategoriesCompanion.insert(
          id: _uuid.v4(),
          name: name.trim(),
          isActive: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.pendingInsert),
        ),
      );

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> updateCategory(String id, String name, bool isActive) async {
    if (name.trim().isEmpty) return false;
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now();

      await db.updateCategory(
        CategoriesCompanion(
          id: Value(id),
          name: Value(name.trim()),
          isActive: Value(isActive),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.pendingUpdate),
        ),
      );

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      await db.softDeleteCategory(id);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  // ── Operaciones de Productos ──

  Future<bool> createProduct({
    required String name,
    required double priceUsd,
    required String categoryId,
    bool isAvailable = true,
  }) async {
    if (name.trim().isEmpty || priceUsd <= 0) return false;
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now();

      await db.createProduct(
        ProductsCompanion.insert(
          id: _uuid.v4(),
          categoryId: categoryId,
          name: name.trim(),
          priceUsd: priceUsd,
          isAvailable: Value(isAvailable),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.pendingInsert),
        ),
      );

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> updateProduct({
    required String id,
    required String name,
    required double priceUsd,
    required String categoryId,
    required bool isAvailable,
  }) async {
    if (name.trim().isEmpty || priceUsd <= 0) return false;
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now();

      await db.updateProduct(
        ProductsCompanion(
          id: Value(id),
          categoryId: Value(categoryId),
          name: Value(name.trim()),
          priceUsd: Value(priceUsd),
          isAvailable: Value(isAvailable),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.pendingUpdate),
        ),
      );

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      await db.softDeleteProduct(id);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final menuAdminProvider =
    NotifierProvider<MenuAdminNotifier, AsyncValue<void>>(
  MenuAdminNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// 3. CENTRO DE VALIDACIÓN DE PAGOS (Pago Móvil)
// ─────────────────────────────────────────────────────────────────────────────

/// Stream reactivo de todos los pagos con estado 'pending_validation'.
final pendingPaymentsProvider = StreamProvider<List<Payment>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchPendingPayments();
});

/// Controlador para validar y aprobar pagos.
class PaymentValidationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Aprueba un pago, cambiando su estado a 'approved' en Drift.
  /// Al cambiar de estado, desaparece inmediatamente del stream [pendingPaymentsProvider].
  Future<bool> approve(String paymentId) async {
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      await db.approvePayment(paymentId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final paymentValidationProvider =
    NotifierProvider<PaymentValidationNotifier, AsyncValue<void>>(
  PaymentValidationNotifier.new,
);
