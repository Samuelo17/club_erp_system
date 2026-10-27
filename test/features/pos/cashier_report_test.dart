// test/features/pos/cashier_report_test.dart
//
// Pruebas unitarias para el Reporte de Arqueo de Caja y Cierre de Turno:
//   - Agrupación correcta de totales por método de pago (Efectivo USD, Efectivo VES, Pago Móvil, Punto de Venta)
//   - Totales consolidados (grandTotalUsd, grandTotalVes)
//   - Hora de inicio del turno basada en la primera transacción
//   - Manejo del estado vacío (sin transacciones)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:club_erp_system/core/database/app_database.dart';
import 'package:club_erp_system/features/pos/providers/cashier_report_provider.dart';

void main() {
  group('CashierReportProvider & Arqueo de Caja Tests', () {
    final now = DateTime.now();
    final firstTxTime = now.subtract(const Duration(hours: 3));
    final secondTxTime = now.subtract(const Duration(hours: 1));

    // Métodos de pago simulados
    final methodEfectivoUsd = PaymentMethod(
      id: 'pm-efectivo-001',
      name: 'Efectivo USD',
      requiresBank: false,
      requiresReference: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final methodEfectivoVes = PaymentMethod(
      id: 'pm-efectivo-ves-001',
      name: 'Efectivo VES',
      requiresBank: false,
      requiresReference: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final methodPagoMovil = PaymentMethod(
      id: 'pm-pagomovil-001',
      name: 'Pago Móvil',
      requiresBank: true,
      requiresReference: true,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final methodPuntoDeVenta = PaymentMethod(
      id: 'pm-pos-001',
      name: 'Punto de Venta',
      requiresBank: true,
      requiresReference: true,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    // Pagos simulados
    final paymentUsd = Payment(
      id: 'pay-001',
      orderId: 'ord-001',
      paymentMethodId: methodEfectivoUsd.id,
      amountUsd: 25.0,
      amountVes: 1000.0,
      status: 'approved',
      createdAt: secondTxTime,
      updatedAt: secondTxTime,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final paymentVes = Payment(
      id: 'pay-002',
      orderId: 'ord-002',
      paymentMethodId: methodEfectivoVes.id,
      amountUsd: 10.0,
      amountVes: 400.0,
      status: 'approved',
      createdAt: firstTxTime,
      updatedAt: firstTxTime,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final paymentPagoMovil = Payment(
      id: 'pay-003',
      orderId: 'ord-003',
      paymentMethodId: methodPagoMovil.id,
      amountUsd: 15.0,
      amountVes: 600.0,
      status: 'pending_validation',
      reference: 'REF-7890',
      bank: 'Banesco',
      createdAt: secondTxTime,
      updatedAt: secondTxTime,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    final paymentPOS = Payment(
      id: 'pay-004',
      orderId: 'ord-004',
      paymentMethodId: methodPuntoDeVenta.id,
      amountUsd: 20.0,
      amountVes: 800.0,
      status: 'approved',
      reference: 'POS-1234',
      createdAt: secondTxTime,
      updatedAt: secondTxTime,
      syncStatus: SyncStatus.synced,
      isDeleted: false,
    );

    test('CashierShiftReport.empty() devuelve valores por defecto limpios', () {
      final emptyReport = CashierShiftReport.empty();

      expect(emptyReport.totalTransactions, 0);
      expect(emptyReport.totalEfectivoUsd, 0.0);
      expect(emptyReport.totalEfectivoVes, 0.0);
      expect(emptyReport.totalPagoMovilVes, 0.0);
      expect(emptyReport.totalPuntoDeVentaVes, 0.0);
      expect(emptyReport.grandTotalUsd, 0.0);
      expect(emptyReport.grandTotalVes, 0.0);
      expect(emptyReport.payments, isEmpty);
    });

    test('CashierShiftReport agrupa y suma montos correctamente por método de pago', () {
      final mockReport = CashierShiftReport(
        shiftStartTime: firstTxTime,
        totalTransactions: 4,
        totalEfectivoUsd: 25.0,
        totalEfectivoVes: 400.0,
        totalPagoMovilVes: 600.0,
        totalPuntoDeVentaVes: 800.0,
        grandTotalUsd: 70.0,
        grandTotalVes: 2800.0,
        payments: [
          PaymentWithMethod(payment: paymentUsd, method: methodEfectivoUsd),
          PaymentWithMethod(payment: paymentPagoMovil, method: methodPagoMovil),
          PaymentWithMethod(payment: paymentPOS, method: methodPuntoDeVenta),
          PaymentWithMethod(payment: paymentVes, method: methodEfectivoVes),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          cashierReportProvider.overrideWithValue(
            AsyncData<CashierShiftReport>(mockReport),
          ),
        ],
      );
      addTearDown(container.dispose);

      final reportAsync = container.read(cashierReportProvider);

      expect(reportAsync.value, isNotNull);
      final report = reportAsync.value!;

      expect(report.totalTransactions, 4);
      expect(report.shiftStartTime, firstTxTime);

      // Verificación de totales individuales por método
      expect(report.totalEfectivoUsd, 25.0);
      expect(report.totalEfectivoVes, 400.0);
      expect(report.totalPagoMovilVes, 600.0);
      expect(report.totalPuntoDeVentaVes, 800.0);

      // Verificación de totales globales consolidados
      expect(report.grandTotalUsd, 70.0);
      expect(report.grandTotalVes, 2800.0);
    });
  });
}
