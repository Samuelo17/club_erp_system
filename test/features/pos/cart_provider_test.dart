// test/features/pos/cart_provider_test.dart
//
// Pruebas unitarias para la lógica de estado del Carrito POS:
//   - cartProvider: agregar, incrementar, decrementar, eliminar, vaciar
//   - cartTotalProvider: cálculo cruzado USD y VES con la tasa de cambio

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:club_erp_system/core/database/app_database.dart';
import 'package:club_erp_system/features/pos/providers/cart_provider.dart';
import 'package:club_erp_system/features/pos/providers/exchange_rate_provider.dart';

void main() {
  group('cartProvider & cartTotalProvider Tests', () {
    final testProductA = Product(
      id: 'prod-001',
      categoryId: 'cat-comida-001',
      name: 'Hamburguesa Doble',
      priceUsd: 6.50,
      isAvailable: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final testProductB = Product(
      id: 'prod-002',
      categoryId: 'cat-bebidas-001',
      name: 'Refresco 355ml',
      priceUsd: 1.50,
      isAvailable: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final mockRate = ExchangeRate(
      id: 'rate-001',
      rate: 40.0,
      createdByRoleId: 'role-encargada-001',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    ProviderContainer createContainer({ExchangeRate? rate}) {
      return ProviderContainer(
        overrides: [
          exchangeRateProvider.overrideWithValue(
            AsyncData<ExchangeRate?>(rate),
          ),
        ],
      );
    }

    test('Carrito inicia vacío', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final items = container.read(cartProvider);
      final total = container.read(cartTotalProvider);

      expect(items, isEmpty);
      expect(total.isEmpty, isTrue);
      expect(total.itemCount, 0);
      expect(total.totalUsd, 0.0);
      expect(total.totalVes, 0.0);
    });

    test('Agregar producto nuevo lo añade con cantidad 1', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addProduct(testProductA);

      final items = container.read(cartProvider);
      expect(items.length, 1);
      expect(items.first.product.id, 'prod-001');
      expect(items.first.qty, 1);
      expect(items.first.unitPriceUsd, 6.50);
      expect(items.first.subtotalUsd, 6.50);
    });

    test('Agregar producto existente incrementa su cantidad', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addProduct(testProductA);
      container.read(cartProvider.notifier).addProduct(testProductA);

      final items = container.read(cartProvider);
      expect(items.length, 1);
      expect(items.first.qty, 2);
      expect(items.first.subtotalUsd, 13.00);
    });

    test('Decrementar cantidad reduce el valor y elimina al llegar a 0', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addProduct(testProductA);
      container.read(cartProvider.notifier).addProduct(testProductA);

      // 2 -> 1
      container.read(cartProvider.notifier).decrementQty('prod-001');
      expect(container.read(cartProvider).first.qty, 1);

      // 1 -> 0 (eliminado)
      container.read(cartProvider.notifier).decrementQty('prod-001');
      expect(container.read(cartProvider), isEmpty);
    });

    test('removeItem elimina el producto sin importar la cantidad', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addProduct(testProductA);
      container.read(cartProvider.notifier).addProduct(testProductA);
      container.read(cartProvider.notifier).addProduct(testProductB);

      container.read(cartProvider.notifier).removeItem('prod-001');

      final items = container.read(cartProvider);
      expect(items.length, 1);
      expect(items.first.product.id, 'prod-002');
    });

    test('clearCart vacía toda la lista', () {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(cartProvider.notifier).addProduct(testProductA);
      container.read(cartProvider.notifier).addProduct(testProductB);

      container.read(cartProvider.notifier).clearCart();
      expect(container.read(cartProvider), isEmpty);
    });

    test('cartTotalProvider calcula correctamente USD y VES cruzado con tasa',
        () {
      final container = createContainer(rate: mockRate);
      addTearDown(container.dispose);

      // Agregar 2 hamburguesas ($6.50 c/u = $13.00) y 1 refresco ($1.50)
      container.read(cartProvider.notifier).addProduct(testProductA);
      container.read(cartProvider.notifier).addProduct(testProductA);
      container.read(cartProvider.notifier).addProduct(testProductB);

      final total = container.read(cartTotalProvider);

      expect(total.itemCount, 3);
      expect(total.productCount, 2);
      expect(total.totalUsd, 14.50);
      expect(total.exchangeRate, 40.0);
      // 14.50 USD * 40.00 = 580.00 VES
      expect(total.totalVes, 580.0);
    });
  });
}
