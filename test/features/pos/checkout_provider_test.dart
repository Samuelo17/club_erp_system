// test/features/pos/checkout_provider_test.dart
//
// Pruebas unitarias para el proceso de Checkout y Pagos Compartidos (Split Payments):
//   - Inicialización y cálculo de saldo restante (USD y VES)
//   - Agregado de pagos parciales y validación de montos
//   - Eliminación de pagos y restauración de saldo
//   - Condición isFullyPaid (saldo restante exactamente 0)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:club_erp_system/core/database/app_database.dart';
import 'package:club_erp_system/features/pos/providers/checkout_provider.dart';
import 'package:club_erp_system/features/pos/providers/exchange_rate_provider.dart';

void main() {
  group('CheckoutNotifier & Split Payments Tests', () {
    final mockMethodCash = PaymentMethod(
      id: 'pm-efectivo-001',
      name: 'Efectivo USD',
      requiresBank: false,
      requiresReference: false,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final mockMethodPagoMovil = PaymentMethod(
      id: 'pm-pagomovil-001',
      name: 'Pago Móvil',
      requiresBank: true,
      requiresReference: true,
      isActive: true,
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

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          exchangeRateProvider.overrideWithValue(
            AsyncData<ExchangeRate?>(mockRate),
          ),
        ],
      );
    }

    test('Inicialización calcula total y saldo restante correctamente', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(checkoutProvider.notifier);
      notifier.initialize(totalUsd: 20.0, exchangeRate: 40.0);

      final state = container.read(checkoutProvider);

      expect(state.totalUsd, 20.0);
      expect(state.totalVes, 800.0);
      expect(state.remainingUsd, 20.0);
      expect(state.remainingVes, 800.0);
      expect(state.paidUsd, 0.0);
      expect(state.isFullyPaid, isFalse);
      expect(state.payments, isEmpty);
    });

    test('Agregar pago parcial actualiza el saldo restante en USD y VES', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(checkoutProvider.notifier);
      notifier.initialize(totalUsd: 10.0, exchangeRate: 40.0);

      // Abono 1: $6.00 en Efectivo USD
      final added = notifier.addPayment(
        method: mockMethodCash,
        amountUsd: 6.0,
        amountVes: 240.0,
      );

      expect(added, isTrue);

      final state = container.read(checkoutProvider);
      expect(state.paidUsd, 6.0);
      expect(state.remainingUsd, 4.0);
      expect(state.remainingVes, 160.0);
      expect(state.isFullyPaid, isFalse);
      expect(state.payments.length, 1);
    });

    test('Pago compartido: agregar segundo abono que completa la orden', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(checkoutProvider.notifier);
      notifier.initialize(totalUsd: 10.0, exchangeRate: 40.0);

      // Abono 1: $6.00 en Efectivo
      notifier.addPayment(
        method: mockMethodCash,
        amountUsd: 6.0,
        amountVes: 240.0,
      );

      // Abono 2: $4.00 con Pago Móvil
      final addedSecond = notifier.addPayment(
        method: mockMethodPagoMovil,
        amountUsd: 4.0,
        amountVes: 160.0,
        bank: 'Banesco',
        reference: '123456',
      );

      expect(addedSecond, isTrue);

      final state = container.read(checkoutProvider);
      expect(state.paidUsd, 10.0);
      expect(state.remainingUsd, 0.0);
      expect(state.remainingVes, 0.0);
      expect(state.isFullyPaid, isTrue);
      expect(state.payments.length, 2);
    });

    test('Rechaza montos mayores al saldo restante o menores o iguales a 0', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(checkoutProvider.notifier);
      notifier.initialize(totalUsd: 10.0, exchangeRate: 40.0);

      // Monto negativo o cero
      final zeroResult = notifier.addPayment(
        method: mockMethodCash,
        amountUsd: 0.0,
        amountVes: 0.0,
      );
      expect(zeroResult, isFalse);

      // Monto que excede los $10.00
      final exceedResult = notifier.addPayment(
        method: mockMethodCash,
        amountUsd: 15.0,
        amountVes: 600.0,
      );
      expect(exceedResult, isFalse);
      expect(container.read(checkoutProvider).payments, isEmpty);
    });

    test('removePayment elimina el abono y restaura el saldo restante', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(checkoutProvider.notifier);
      notifier.initialize(totalUsd: 10.0, exchangeRate: 40.0);

      notifier.addPayment(
        method: mockMethodCash,
        amountUsd: 5.0,
        amountVes: 200.0,
      );

      final paymentId = container.read(checkoutProvider).payments.first.id;
      expect(container.read(checkoutProvider).remainingUsd, 5.0);

      // Eliminar el pago
      notifier.removePayment(paymentId);

      final stateAfter = container.read(checkoutProvider);
      expect(stateAfter.payments, isEmpty);
      expect(stateAfter.paidUsd, 0.0);
      expect(stateAfter.remainingUsd, 10.0);
      expect(stateAfter.isFullyPaid, isFalse);
    });
  });
}
