// lib/features/pos/providers/cashier_report_provider.dart
//
// Provider para el reporte de Arqueo de Caja y Cierre de Turno de la Cajera.
// Consulta reactivamente en Drift todos los pagos del día actual con estado
// 'approved' o 'pending_validation' y los agrupa por método de pago.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import 'exchange_rate_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: CashierShiftReport (Reporte de Turno)
// ─────────────────────────────────────────────────────────────────────────────

class CashierShiftReport {
  /// Hora de apertura de la caja o de la primera transacción del turno.
  final DateTime shiftStartTime;

  /// Cantidad total de transacciones cobradas en el turno.
  final int totalTransactions;

  /// Total acumulado en Efectivo USD (en dólares físicos en caja).
  final double totalEfectivoUsd;

  /// Total acumulado en Efectivo VES (en bolívares en efectivo).
  final double totalEfectivoVes;

  /// Total acumulado por transferencias de Pago Móvil (en bolívares).
  final double totalPagoMovilVes;

  /// Total acumulado por Punto de Venta / Tarjetas de Débito-Crédito (en bolívares).
  final double totalPuntoDeVentaVes;

  /// Total consolidado del turno en dólares ($).
  final double grandTotalUsd;

  /// Total consolidado del turno en bolívares (Bs.).
  final double grandTotalVes;

  /// Lista de todos los pagos que componen este reporte.
  final List<PaymentWithMethod> payments;

  const CashierShiftReport({
    required this.shiftStartTime,
    required this.totalTransactions,
    required this.totalEfectivoUsd,
    required this.totalEfectivoVes,
    required this.totalPagoMovilVes,
    required this.totalPuntoDeVentaVes,
    required this.grandTotalUsd,
    required this.grandTotalVes,
    required this.payments,
  });

  static CashierShiftReport empty() {
    final now = DateTime.now();
    return CashierShiftReport(
      shiftStartTime: DateTime(now.year, now.month, now.day, 8, 0),
      totalTransactions: 0,
      totalEfectivoUsd: 0.0,
      totalEfectivoVes: 0.0,
      totalPagoMovilVes: 0.0,
      totalPuntoDeVentaVes: 0.0,
      grandTotalUsd: 0.0,
      grandTotalVes: 0.0,
      payments: const [],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER: cashierReportProvider
// ─────────────────────────────────────────────────────────────────────────────

/// StreamProvider reactivo que emite el estado del arqueo de caja del turno actual.
///
/// Cada vez que se completa un cobro en el POS o se aprueba un pago en Drift,
/// este provider recalcula instantáneamente los totales agrupados por método.
final cashierReportProvider = StreamProvider<CashierShiftReport>((ref) {
  final db = ref.watch(databaseProvider);
  final rateAsync = ref.watch(exchangeRateProvider);
  final currentRate = rateAsync.value?.rate ?? 0.0;

  return db.watchPaymentsToday().map((payments) {
    if (payments.isEmpty) {
      return CashierShiftReport.empty();
    }

    double totalEfectivoUsd = 0.0;
    double totalEfectivoVes = 0.0;
    double totalPagoMovilVes = 0.0;
    double totalPuntoDeVentaVes = 0.0;
    double grandTotalUsd = 0.0;
    double grandTotalVes = 0.0;

    // La lista viene ordenada descendente por fecha: el último es el primero del día
    final shiftStartTime = payments.last.payment.createdAt;

    for (final item in payments) {
      final payment = item.payment;
      final methodName = item.method.name.toLowerCase();

      grandTotalUsd += payment.amountUsd;
      grandTotalVes += payment.amountVes;

      // ── Clasificación por Método de Pago ──
      if (methodName.contains('pago móvil') || methodName.contains('pagomovil')) {
        totalPagoMovilVes += payment.amountVes;
      } else if (methodName.contains('pos') ||
          methodName.contains('tarjeta') ||
          methodName.contains('punto')) {
        totalPuntoDeVentaVes += payment.amountVes;
      } else if (methodName.contains('efectivo')) {
        // Distinguir entre Efectivo en Divisas ($ USD) o Efectivo en Bolívares (VES)
        if (methodName.contains('usd') ||
            methodName.contains('divisas') ||
            methodName.contains('dólar') ||
            item.method.id == 'pm-efectivo-001' ||
            item.method.id == 'pm-divisas-001') {
          totalEfectivoUsd += payment.amountUsd;
        } else {
          totalEfectivoVes += payment.amountVes;
        }
      } else {
        // Método genérico o no clasificado: sumar a VES o USD según corresponda
        if (payment.amountVes > 0) {
          totalEfectivoVes += payment.amountVes;
        } else {
          totalEfectivoUsd += payment.amountUsd;
        }
      }
    }

    // Si no hubo tasa explícita guardada y grandTotalVes es 0, estimar con tasa actual
    if (grandTotalVes == 0.0 && currentRate > 0) {
      grandTotalVes = grandTotalUsd * currentRate;
    }

    return CashierShiftReport(
      shiftStartTime: shiftStartTime,
      totalTransactions: payments.length,
      totalEfectivoUsd: totalEfectivoUsd,
      totalEfectivoVes: totalEfectivoVes,
      totalPagoMovilVes: totalPagoMovilVes,
      totalPuntoDeVentaVes: totalPuntoDeVentaVes,
      grandTotalUsd: grandTotalUsd,
      grandTotalVes: grandTotalVes,
      payments: payments,
    );
  });
});
