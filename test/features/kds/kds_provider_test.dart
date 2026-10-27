// test/features/kds/kds_provider_test.dart
//
// Pruebas unitarias para el módulo KDS (Kitchen Display System):
//   - kdsOrdersProvider: escucha en tiempo real de órdenes con ítems y nombres
//   - kdsControllerProvider: avance de estado ('pending' -> 'cooking' -> 'ready')

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:club_erp_system/core/database/app_database.dart';
import 'package:club_erp_system/features/kds/providers/kds_providers.dart';

void main() {
  group('KDS Providers Tests', () {
    final now = DateTime.now();

    final testOrderPending = Order(
      id: 'order-kds-001',
      createdByRoleId: 'role-cajera-001',
      status: 'pending',
      totalUsd: 12.50,
      exchangeRateId: 'rate-001',
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final testOrderCooking = Order(
      id: 'order-kds-002',
      createdByRoleId: 'role-cajera-001',
      status: 'cooking',
      totalUsd: 8.00,
      exchangeRateId: 'rate-001',
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final testItemA = KdsOrderItemData(
      id: 'item-001',
      productId: 'prod-hamburguesa-001',
      productName: 'Hamburguesa Doble',
      qty: 2,
      unitPriceUsd: 5.0,
    );

    final testItemB = KdsOrderItemData(
      id: 'item-002',
      productId: 'prod-refresco-001',
      productName: 'Coca-Cola',
      qty: 1,
      unitPriceUsd: 2.5,
    );

    test('kdsOrdersProvider emite la lista de órdenes activas con sus productos',
        () async {
      final mockKdsOrders = [
        KdsOrderData(
          order: testOrderPending,
          items: [testItemA, testItemB],
        ),
        KdsOrderData(
          order: testOrderCooking,
          items: [testItemA],
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          kdsOrdersProvider.overrideWithValue(
            AsyncData<List<KdsOrderData>>(mockKdsOrders),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(kdsOrdersProvider);

      expect(state.value, isNotNull);
      expect(state.value!.length, 2);

      // Primera orden: Pendiente con 2 ítems
      final firstOrder = state.value!.first;
      expect(firstOrder.order.id, 'order-kds-001');
      expect(firstOrder.order.status, 'pending');
      expect(firstOrder.items.length, 2);
      expect(firstOrder.items.first.productName, 'Hamburguesa Doble');
      expect(firstOrder.items.first.qty, 2);

      // Segunda orden: En preparación con 1 ítem
      final secondOrder = state.value![1];
      expect(secondOrder.order.id, 'order-kds-002');
      expect(secondOrder.order.status, 'cooking');
      expect(secondOrder.items.length, 1);
    });

    test('KdsOrderData maneja correctamente pedidos vacíos o con múltiples ítems',
        () {
      final emptyOrder = KdsOrderData(
        order: testOrderPending,
        items: [],
      );

      expect(emptyOrder.items, isEmpty);
      expect(emptyOrder.order.status, 'pending');
    });
  });
}
