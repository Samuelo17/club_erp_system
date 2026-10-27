// lib/features/pos/presentation/checkout_screen.dart
//
// Pantalla de Checkout y Pagos Compartidos (Split Payments) Mobile-First.
// Permite:
//   - Visualizar el Total y el Faltante por Pagar (USD y VES)
//   - Abonar pagos parciales con múltiples métodos de pago activos de Drift
//   - Formularios dinámicos condicionales (banco, referencia)
//   - Completar la orden atómicamente en Drift una vez cubierto el total al 100%

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/cart_provider.dart';
import '../providers/checkout_provider.dart';
import '../providers/exchange_rate_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    // Inicializar estado de checkout al entrar con los valores actuales del carrito
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartTotal = ref.read(cartTotalProvider);
      final rate = ref.read(exchangeRateProvider).value?.rate ?? 0.0;
      ref
          .read(checkoutProvider.notifier)
          .initialize(totalUsd: cartTotal.totalUsd, exchangeRate: rate);
    });
  }

  /// Mapea el método de pago a un ícono visual y color característico
  ({IconData icon, Color color}) _methodVisual(PaymentMethod method) {
    final name = method.name.toLowerCase();
    if (name.contains('pago móvil') || name.contains('pagomovil')) {
      return (
        icon: Icons.smartphone_rounded,
        color: const Color(0xFF3B82F6),
      );
    } else if (name.contains('pos') || name.contains('tarjeta')) {
      return (
        icon: Icons.credit_card_rounded,
        color: const Color(0xFF7C3AED),
      );
    } else if (name.contains('divisas') || name.contains('dólar')) {
      return (
        icon: Icons.attach_money_rounded,
        color: const Color(0xFF10B981),
      );
    } else {
      return (
        icon: Icons.payments_outlined,
        color: const Color(0xFFF59E0B),
      );
    }
  }

  /// Muestra el modal para registrar un pago parcial con el método seleccionado
  void _openAddPaymentDialog(PaymentMethod method) {
    final checkoutState = ref.read(checkoutProvider);
    if (checkoutState.remainingUsd <= 0.005) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La orden ya está completamente pagada (\$0.00 restante).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _AddPaymentModal(
        method: method,
        remainingUsd: checkoutState.remainingUsd,
        remainingVes: checkoutState.remainingVes,
        exchangeRate: checkoutState.exchangeRate,
        onAdd: (amountUsd, amountVes, bank, reference) {
          final success = ref.read(checkoutProvider.notifier).addPayment(
                method: method,
                amountUsd: amountUsd,
                amountVes: amountVes,
                bank: bank,
                reference: reference,
              );
          if (success) {
            Navigator.of(dialogCtx).pop();
          }
        },
      ),
    );
  }

  /// Ejecuta la finalización de la orden y navegación
  Future<void> _handleCompleteOrder() async {
    final notifier = ref.read(checkoutProvider.notifier);
    final success = await notifier.completeCheckout();

    if (!mounted) return;

    if (success) {
      final state = ref.read(checkoutProvider);
      // Diálogo de éxito y confirmación
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '¡Orden Completada!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'La comanda ha sido enviada a cocina (KDS) y los pagos han sido registrados en Drift.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (state.completedOrderId != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCanvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Orden #${state.completedOrderId!.substring(0, 8)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    // Retornar al POS limpio
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Nueva Venta',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final state = ref.read(checkoutProvider);
      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkoutProvider);
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.backgroundCard,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Checkout & Cobro',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Pagos Compartidos Multimoneda',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (state.exchangeRate > 0)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.currency_exchange_rounded,
                      size: 13, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Bs. ${state.exchangeRate.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Tarjeta de Totales y Saldo Restante ───────────────────────────
          _BalanceCard(state: state),

          const SizedBox(height: 20),

          // ── Lista de Pagos Parciales Registrados ──────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pagos Registrados',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (state.payments.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: state.isFullyPaid
                        ? AppColors.successLight
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.payments.length} ${state.payments.length == 1 ? 'abono' : 'abonos'}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: state.isFullyPaid
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (state.payments.isEmpty)
            _EmptyPaymentsNotice()
          else
            ...state.payments.map((draft) {
              final visual = _methodVisual(draft.method);
              return _PaymentDraftTile(
                draft: draft,
                visual: visual,
                onDelete: () {
                  ref
                      .read(checkoutProvider.notifier)
                      .removePayment(draft.id);
                },
              );
            }),

          const SizedBox(height: 24),

          // ── Botonera de Métodos de Pago ──────────────────────────────────
          const Text(
            'Agregar Método de Pago',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Selecciona un método para abonar al saldo pendiente',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          methodsAsync.when(
            data: (methods) {
              if (methods.isEmpty) {
                return const Center(
                  child: Text(
                    'No hay métodos de pago activos configurados.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.55,
                ),
                itemCount: methods.length,
                itemBuilder: (context, index) {
                  final method = methods[index];
                  final visual = _methodVisual(method);
                  return _MethodButton(
                    method: method,
                    visual: visual,
                    isFullyPaid: state.isFullyPaid,
                    onTap: () => _openAddPaymentDialog(method),
                  );
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text(
                'Error al cargar métodos: $e',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Botón Inferior: Completar Orden (Activado solo con saldo 0) ──────
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            border: const Border(
              top: BorderSide(color: AppColors.border, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!state.isFullyPaid)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Text(
                        'Resta \$${state.remainingUsd.toStringAsFixed(2)} por cobrar para completar',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: state.isFullyPaid && !state.isProcessing
                      ? _handleCompleteOrder
                      : null,
                  icon: state.isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 22),
                  label: Text(
                    state.isProcessing
                        ? 'GUARDANDO ORDEN...'
                        : 'COMPLETAR ORDEN',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: state.isFullyPaid ? 2 : 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: _BalanceCard (Cabecera de Totales y Saldo Restante)
// ─────────────────────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final CheckoutState state;

  const _BalanceCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDone = state.isFullyPaid;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone ? AppColors.success : AppColors.border,
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDone
                ? AppColors.success.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total de la Orden
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total a Pagar',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${state.totalUsd.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (state.exchangeRate > 0)
                    Text(
                      'Bs. ${state.totalVes.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),

          // Faltante por Pagar (Saldo Restante)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.successLight
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDone
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.pending_actions_rounded,
                      color: isDone ? AppColors.success : AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDone ? '¡Completado!' : 'Faltante por Pagar',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDone
                                ? AppColors.success
                                : AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          isDone
                              ? 'Cuenta saldada'
                              : 'Saldo pendiente de cobro',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: isDone
                                ? AppColors.success.withValues(alpha: 0.8)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${state.remainingUsd.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDone ? AppColors.success : AppColors.primary,
                      ),
                    ),
                    if (state.exchangeRate > 0)
                      Text(
                        'Bs. ${state.remainingVes.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDone
                              ? AppColors.success.withValues(alpha: 0.9)
                              : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: _EmptyPaymentsNotice
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyPaymentsNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_outlined,
              size: 40,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'No hay pagos agregados aún',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Selecciona un método abajo para registrar el primer abono',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: _PaymentDraftTile (Fila de pago parcial agregado)
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentDraftTile extends StatelessWidget {
  final PaymentDraft draft;
  final ({IconData icon, Color color}) visual;
  final VoidCallback onDelete;

  const _PaymentDraftTile({
    required this.draft,
    required this.visual,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(visual.icon, color: visual.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.method.name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (draft.bank != null || draft.reference != null)
                  Text(
                    [
                      if (draft.bank != null) draft.bank,
                      if (draft.reference != null) 'Ref: ${draft.reference}',
                    ].join(' • '),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${draft.amountUsd.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Bs. ${draft.amountVes.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            onPressed: onDelete,
            tooltip: 'Eliminar pago',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: _MethodButton (Botón de método de pago)
// ─────────────────────────────────────────────────────────────────────────────

class _MethodButton extends StatelessWidget {
  final PaymentMethod method;
  final ({IconData icon, Color color}) visual;
  final bool isFullyPaid;
  final VoidCallback onTap;

  const _MethodButton({
    required this.method,
    required this.visual,
    required this.isFullyPaid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isFullyPaid ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isFullyPaid
                ? AppColors.border.withValues(alpha: 0.3)
                : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFullyPaid
                  ? AppColors.border
                  : visual.color.withValues(alpha: 0.3),
            ),
            boxShadow: isFullyPaid
                ? null
                : [
                    BoxShadow(
                      color: visual.color.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: visual.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(visual.icon, color: visual.color, size: 18),
                  ),
                  const Icon(Icons.add_circle_outline_rounded,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
              Text(
                method.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isFullyPaid
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL: _AddPaymentModal (Diálogo con formularios dinámicos)
// ─────────────────────────────────────────────────────────────────────────────

class _AddPaymentModal extends StatefulWidget {
  final PaymentMethod method;
  final double remainingUsd;
  final double remainingVes;
  final double exchangeRate;
  final void Function(
    double amountUsd,
    double amountVes,
    String? bank,
    String? reference,
  ) onAdd;

  const _AddPaymentModal({
    required this.method,
    required this.remainingUsd,
    required this.remainingVes,
    required this.exchangeRate,
    required this.onAdd,
  });

  @override
  State<_AddPaymentModal> createState() => _AddPaymentModalState();
}

class _AddPaymentModalState extends State<_AddPaymentModal> {
  final _amountController = TextEditingController();
  final _bankController = TextEditingController();
  final _refController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Moneda activa de entrada: true = USD ($), false = VES (Bs.)
  bool _isCurrencyUsd = true;

  @override
  void initState() {
    super.initState();
    // Por defecto, sugerir el monto total restante
    _amountController.text = widget.remainingUsd.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankController.dispose();
    _refController.dispose();
    super.dispose();
  }

  void _onCurrencyChanged(bool isUsd) {
    if (_isCurrencyUsd == isUsd) return;

    final currentVal = double.tryParse(_amountController.text) ?? 0.0;
    setState(() {
      _isCurrencyUsd = isUsd;
      if (isUsd) {
        // Estaba en VES, pasar a USD
        final usd = widget.exchangeRate > 0
            ? currentVal / widget.exchangeRate
            : currentVal;
        _amountController.text = usd.toStringAsFixed(2);
      } else {
        // Estaba en USD, pasar a VES
        final ves = currentVal * widget.exchangeRate;
        _amountController.text = ves.toStringAsFixed(2);
      }
    });
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final rawAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (rawAmount <= 0) return;

    double amountUsd;
    double amountVes;

    if (_isCurrencyUsd) {
      amountUsd = rawAmount;
      amountVes = widget.exchangeRate > 0 ? rawAmount * widget.exchangeRate : 0.0;
    } else {
      amountVes = rawAmount;
      amountUsd = widget.exchangeRate > 0 ? rawAmount / widget.exchangeRate : 0.0;
    }

    widget.onAdd(
      amountUsd,
      amountVes,
      widget.method.requiresBank ? _bankController.text : null,
      widget.method.requiresReference ? _refController.text : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abonar con ${widget.method.name}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Saldo pendiente: \$${widget.remainingUsd.toStringAsFixed(2)} '
                  '${widget.exchangeRate > 0 ? "(Bs. ${widget.remainingVes.toStringAsFixed(2)})" : ""}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Selector de moneda de ingreso: [$ USD] | [Bs. VES]
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.backgroundCanvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onCurrencyChanged(true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isCurrencyUsd
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Dólares (\$ USD)',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isCurrencyUsd
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onCurrencyChanged(false),
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_isCurrencyUsd
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Bolívares (Bs. VES)',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: !_isCurrencyUsd
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Campo de Monto
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: _isCurrencyUsd
                      ? 'Monto a pagar en USD (\$)'
                      : 'Monto a pagar en Bs.',
                  prefixText: _isCurrencyUsd ? '\$ ' : 'Bs. ',
                  suffixIcon: TextButton(
                    onPressed: () {
                      _amountController.text = _isCurrencyUsd
                          ? widget.remainingUsd.toStringAsFixed(2)
                          : widget.remainingVes.toStringAsFixed(2);
                    },
                    child: const Text('Todo',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa un monto';
                  }
                  final amount = double.tryParse(val.trim());
                  if (amount == null || amount <= 0) {
                    return 'Monto inválido';
                  }
                  final maxAllowed = _isCurrencyUsd
                      ? widget.remainingUsd
                      : widget.remainingVes;
                  if (amount > maxAllowed + 0.05) {
                    return 'Excede el saldo pendiente';
                  }
                  return null;
                },
              ),

              // Formulario Dinámico: Banco (si requiresBank == true)
              if (widget.method.requiresBank) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankController,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Banco Emisor',
                    hintText: 'Ej. Banesco, Mercantil, Venezuela',
                    prefixIcon: const Icon(Icons.account_balance_rounded,
                        size: 20, color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ingresa el banco emisor';
                    }
                    return null;
                  },
                ),
              ],

              // Formulario Dinámico: Referencia (si requiresReference == true)
              if (widget.method.requiresReference) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _refController,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Número de Referencia',
                    hintText: 'Ej. Últimos 4 o 6 dígitos',
                    prefixIcon: const Icon(Icons.tag_rounded,
                        size: 20, color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ingresa la referencia';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar',
                    style: TextStyle(fontFamily: 'Poppins')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleSubmit,
                child: const Text(
                  'Agregar Pago',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
