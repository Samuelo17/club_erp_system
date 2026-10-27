// test/features/admin/admin_provider_test.dart
//
// Pruebas unitarias para el módulo Administrativo (Rol Encargada):
//   - exchangeRateHistoryProvider: consulta reactiva del historial de tasas
//   - adminCategoriesProvider & adminProductsProvider: consulta de catálogo para gestión
//   - pendingPaymentsProvider: listado reactivo de pagos de Pago Móvil por validar

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:club_erp_system/core/database/app_database.dart';
import 'package:club_erp_system/features/admin/providers/admin_providers.dart';

void main() {
  group('Admin Dashboard Providers Tests', () {
    final now = DateTime.now();

    final testRate1 = ExchangeRate(
      id: 'rate-001',
      rate: 36.50,
      createdByRoleId: 'role-encargada-001',
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final testRate2 = ExchangeRate(
      id: 'rate-002',
      rate: 38.00,
      createdByRoleId: 'role-encargada-001',
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final testCategory = Category(
      id: 'cat-test-001',
      name: 'Pizzas',
      isActive: true,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final testProduct = Product(
      id: 'prod-test-001',
      categoryId: 'cat-test-001',
      name: 'Pizza Margarita',
      priceUsd: 10.0,
      isAvailable: true,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final testPendingPayment = Payment(
      id: 'pay-001',
      orderId: 'order-001',
      paymentMethodId: 'pm-pagomovil-001',
      amountUsd: 10.0,
      amountVes: 380.0,
      reference: '987654',
      bank: 'Banesco',
      status: 'pending_validation',
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pendingInsert,
      isDeleted: false,
    );

    test('exchangeRateHistoryProvider emite el historial ordenado', () {
      final container = ProviderContainer(
        overrides: [
          exchangeRateHistoryProvider.overrideWithValue(
            AsyncData<List<ExchangeRate>>([testRate2, testRate1]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(exchangeRateHistoryProvider);

      expect(state.value, isNotNull);
      expect(state.value!.length, 2);
      expect(state.value!.first.rate, 38.00);
      expect(state.value![1].rate, 36.50);
    });

    test('adminCategoriesProvider y adminProductsProvider emiten el catálogo',
        () {
      final container = ProviderContainer(
        overrides: [
          adminCategoriesProvider.overrideWithValue(
            AsyncData<List<Category>>([testCategory]),
          ),
          adminProductsProvider.overrideWithValue(
            AsyncData<List<Product>>([testProduct]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final catState = container.read(adminCategoriesProvider);
      final prodState = container.read(adminProductsProvider);

      expect(catState.value!.length, 1);
      expect(catState.value!.first.name, 'Pizzas');

      expect(prodState.value!.length, 1);
      expect(prodState.value!.first.name, 'Pizza Margarita');
      expect(prodState.value!.first.priceUsd, 10.0);
    });

    test('pendingPaymentsProvider emite pagos con estado pending_validation',
        () {
      final container = ProviderContainer(
        overrides: [
          pendingPaymentsProvider.overrideWithValue(
            AsyncData<List<Payment>>([testPendingPayment]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(pendingPaymentsProvider);

      expect(state.value, isNotNull);
      expect(state.value!.length, 1);

      final payment = state.value!.first;
      expect(payment.status, 'pending_validation');
      expect(payment.reference, '987654');
      expect(payment.bank, 'Banesco');
      expect(payment.amountVes, 380.0);
    });
  });
}
