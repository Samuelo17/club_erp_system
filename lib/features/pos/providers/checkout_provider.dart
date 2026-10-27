// lib/features/pos/providers/checkout_provider.dart
//
// Gestor de estado del proceso de Checkout y Pagos Compartidos (Split Payments).
// Maneja en memoria los pagos parciales, calcula el saldo restante multimoneda
// (USD y VES) y persiste la transacción completa (Order + OrderItems + Payments)
// de forma atómica en Drift (SQLite).

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'cart_provider.dart';
import 'exchange_rate_provider.dart';

// Generador de identificadores UUID v4
const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: PaymentDraft (Borrador de pago temporal)
// ─────────────────────────────────────────────────────────────────────────────

/// Representa un pago parcial registrado temporalmente en memoria antes
/// de confirmar la orden en la base de datos local.
class PaymentDraft {
  final String id;
  final PaymentMethod method;
  final double amountUsd;
  final double amountVes;
  final String? reference;
  final String? bank;

  const PaymentDraft({
    required this.id,
    required this.method,
    required this.amountUsd,
    required this.amountVes,
    this.reference,
    this.bank,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: CheckoutState
// ─────────────────────────────────────────────────────────────────────────────

/// Estado inmutable del proceso de checkout y cobro.
class CheckoutState {
  /// Monto total de la orden en USD.
  final double totalUsd;

  /// Tasa de cambio vigente para conversiones USD -> VES.
  final double exchangeRate;

  /// Lista de pagos parciales aplicados a esta orden.
  final List<PaymentDraft> payments;

  /// Indica si la transacción se está guardando en Drift.
  final bool isProcessing;

  /// Mensaje de error en caso de fallo en la validación o persistencia.
  final String? errorMessage;

  /// ID de la orden generada tras un cobro exitoso.
  final String? completedOrderId;

  const CheckoutState({
    this.totalUsd = 0.0,
    this.exchangeRate = 0.0,
    this.payments = const [],
    this.isProcessing = false,
    this.errorMessage,
    this.completedOrderId,
  });

  /// Total de la orden en Bolívares.
  double get totalVes => totalUsd * exchangeRate;

  /// Total acumulado en USD de los pagos ya registrados.
  double get paidUsd =>
      payments.fold<double>(0.0, (sum, p) => sum + p.amountUsd);

  /// Total acumulado en VES de los pagos ya registrados.
  double get paidVes =>
      payments.fold<double>(0.0, (sum, p) => sum + p.amountVes);

  /// Saldo restante por pagar en USD.
  /// Se redondea a 0 si la diferencia es insignificante por precisión de coma flotante.
  double get remainingUsd {
    final remaining = totalUsd - paidUsd;
    return remaining < 0.005 ? 0.0 : remaining;
  }

  /// Saldo restante por pagar en VES (calculado con la tasa vigente).
  double get remainingVes {
    if (exchangeRate <= 0) return 0.0;
    final ves = remainingUsd * exchangeRate;
    return ves < 0.01 ? 0.0 : ves;
  }

  /// Indica si la cuenta ya está saldada en su totalidad ($0.00 restantes).
  bool get isFullyPaid => remainingUsd <= 0.005 && payments.isNotEmpty;

  CheckoutState copyWith({
    double? totalUsd,
    double? exchangeRate,
    List<PaymentDraft>? payments,
    bool? isProcessing,
    String? errorMessage,
    bool clearError = false,
    String? completedOrderId,
  }) {
    return CheckoutState(
      totalUsd: totalUsd ?? this.totalUsd,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      payments: payments ?? this.payments,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      completedOrderId: completedOrderId ?? this.completedOrderId,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER: CheckoutNotifier
// ─────────────────────────────────────────────────────────────────────────────

class CheckoutNotifier extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    // Inicializar estado con los valores del carrito y la tasa actual
    final cartTotal = ref.watch(cartTotalProvider);
    final rateAsync = ref.watch(exchangeRateProvider);
    final rate = rateAsync.value?.rate ?? 0.0;

    return CheckoutState(
      totalUsd: cartTotal.totalUsd,
      exchangeRate: rate,
      payments: const [],
    );
  }

  /// Reinicia el proceso de checkout con nuevos valores de total y tasa.
  void initialize({required double totalUsd, required double exchangeRate}) {
    state = CheckoutState(
      totalUsd: totalUsd,
      exchangeRate: exchangeRate,
      payments: const [],
    );
  }

  /// Agrega un pago parcial a la cuenta.
  /// Valida que el monto no exceda el saldo pendiente.
  bool addPayment({
    required PaymentMethod method,
    required double amountUsd,
    required double amountVes,
    String? reference,
    String? bank,
  }) {
    if (amountUsd <= 0) {
      state = state.copyWith(errorMessage: 'El monto a pagar debe ser mayor a 0');
      return false;
    }

    // Permitir pequeño margen de tolerancia (0.01) para redondeo de centavos
    if (amountUsd > state.remainingUsd + 0.01) {
      state = state.copyWith(
        errorMessage: 'El monto ingresado (\$${amountUsd.toStringAsFixed(2)}) '
            'excede el saldo restante (\$${state.remainingUsd.toStringAsFixed(2)})',
      );
      return false;
    }

    // Si el monto es virtualmente el restante, ajustarlo exactamente
    final finalAmountUsd = (amountUsd >= state.remainingUsd - 0.005)
        ? state.remainingUsd
        : amountUsd;
    final finalAmountVes = (state.exchangeRate > 0)
        ? finalAmountUsd * state.exchangeRate
        : amountVes;

    final draft = PaymentDraft(
      id: _uuid.v4(),
      method: method,
      amountUsd: finalAmountUsd,
      amountVes: finalAmountVes,
      reference: reference?.trim().isEmpty ?? true ? null : reference?.trim(),
      bank: bank?.trim().isEmpty ?? true ? null : bank?.trim(),
    );

    state = state.copyWith(
      payments: [...state.payments, draft],
      clearError: true,
    );

    return true;
  }

  /// Elimina un pago parcial de la lista, restaurando el saldo restante.
  void removePayment(String paymentId) {
    state = state.copyWith(
      payments: state.payments.where((p) => p.id != paymentId).toList(),
      clearError: true,
    );
  }

  /// Limpia todos los pagos registrados.
  void reset() {
    final cartTotal = ref.read(cartTotalProvider);
    final rateAsync = ref.read(exchangeRateProvider);
    final rate = rateAsync.value?.rate ?? 0.0;

    state = CheckoutState(
      totalUsd: cartTotal.totalUsd,
      exchangeRate: rate,
      payments: const [],
    );
  }

  /// Ejecuta la transacción atómica en Drift:
  ///   1. Inserta la orden en `Orders`
  ///   2. Inserta cada ítem del carrito en `OrderItems`
  ///   3. Inserta cada pago registrado en `Payments`
  ///      - Pago Móvil se marca como `pending_validation`
  ///      - Los demás métodos se marcan como `approved`
  ///   4. Vacía el carrito (`cartProvider`)
  Future<bool> completeCheckout() async {
    if (!state.isFullyPaid) {
      state = state.copyWith(
        errorMessage: 'Aún queda saldo pendiente por pagar: \$${state.remainingUsd.toStringAsFixed(2)}',
      );
      return false;
    }

    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      state = state.copyWith(errorMessage: 'El carrito no contiene productos');
      return false;
    }

    final authState = ref.read(authProvider);
    final currentRoleId = authState.currentRole?.id ?? 'role-cajera-001';
    final rateAsync = ref.read(exchangeRateProvider);
    final currentRate = rateAsync.value;

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final db = ref.read(databaseProvider);
      final now = DateTime.now();
      final orderId = _uuid.v4();

      // ── 1. Companions de la Orden ───────────────────────────────────────
      final orderCompanion = OrdersCompanion.insert(
        id: orderId,
        createdByRoleId: currentRoleId,
        status: const Value('pending'), // 'pending' para que entre a cola de cocina KDS
        totalUsd: Value(state.totalUsd),
        exchangeRateId: Value(currentRate?.id),
        createdAt: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value(SyncStatus.pendingInsert),
      );

      // ── 2. Companions de los Ítems ──────────────────────────────────────
      final orderItemCompanions = cartItems.map((cartItem) {
        return OrderItemsCompanion.insert(
          id: _uuid.v4(),
          orderId: orderId,
          productId: cartItem.product.id,
          qty: Value(cartItem.qty),
          unitPriceUsd: cartItem.unitPriceUsd,
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.pendingInsert),
        );
      }).toList();

      // ── 3. Companions de los Pagos ──────────────────────────────────────
      final paymentCompanions = state.payments.map((draft) {
        // Regla: Pago Móvil se marca como pending_validation, otros approved
        final isPagoMovil = draft.method.name.toLowerCase().contains('pago móvil') ||
            draft.method.name.toLowerCase().contains('pagomovil') ||
            draft.method.id.contains('pagomovil');
        final paymentStatus = isPagoMovil ? 'pending_validation' : 'approved';

        return PaymentsCompanion.insert(
          id: draft.id,
          orderId: orderId,
          paymentMethodId: draft.method.id,
          amountUsd: draft.amountUsd,
          amountVes: draft.amountVes,
          reference: Value(draft.reference),
          bank: Value(draft.bank),
          status: Value(paymentStatus),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value(SyncStatus.pendingInsert),
        );
      }).toList();

      // ── 4. Transacción Atómica en Drift ─────────────────────────────────
      await db.createOrderWithItemsAndPayments(
        order: orderCompanion,
        items: orderItemCompanions,
        payments: paymentCompanions,
      );

      // ── 5. Limpieza del Carrito y Estado de Checkout ────────────────────
      ref.read(cartProvider.notifier).clearCart();

      state = state.copyWith(
        isProcessing: false,
        completedOrderId: orderId,
        clearError: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Error al registrar la orden en la base de datos: $e',
      );
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS GLOBALES
// ─────────────────────────────────────────────────────────────────────────────

/// Provider principal del proceso de checkout y pagos compartidos.
final checkoutProvider =
    NotifierProvider<CheckoutNotifier, CheckoutState>(CheckoutNotifier.new);

/// Stream reactivo de los métodos de pago activos desde Drift.
final paymentMethodsProvider = StreamProvider<List<PaymentMethod>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchActivePaymentMethods();
});
