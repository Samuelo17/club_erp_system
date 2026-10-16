import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/features/exchange_rate/presentation/providers/exchange_rate_provider.dart';
import 'package:club_erp_system/features/payments/domain/entities/payment_method.dart';
import 'package:club_erp_system/features/payments/domain/repositories/payment_repository.dart';
import 'package:club_erp_system/features/payments/presentation/providers/payment_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES DE ESTILO (alineadas con UI_STYLE_GUIDE.md)
// ─────────────────────────────────────────────────────────────────────────────
const _kOrange = Color(0xFFFF8C00);
const _kOrangeDark = Color(0xFFFF6B00);
const _kBackground = Color(0xFFF5F5F7);
const _kSurface = Colors.white;
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF757575);
const _kSuccess = Color(0xFF2E7D32);
const _kError = Color(0xFFD32F2F);
const _kRadius = 16.0;

/// ============================================================================
/// CHECKOUT BOTTOM SHEET — Modal de Cobro (US-2.2)
/// ============================================================================
///
/// Flujo completo de registro de pago:
/// 1. Muestra el total de la orden en USD y su equivalente en VES.
/// 2. Selector visual de 4 métodos de pago (chips táctiles grandes).
/// 3. Formulario reactivo:
///    - Efectivo: solo campo de monto.
///    - Pago Móvil / POS: muestra también Banco + Referencia con validación.
/// 4. Botón naranja "REGISTRAR PAGO" que valida el Form y guarda en SQLite.
///
/// **Parámetros requeridos**:
/// - [orderId]: UUID de la orden activa.
/// - [totalUsd]: Total de la orden en USD (para pre-rellenar el monto).
/// - [paymentRepository]: Repositorio inyectado para el [PaymentProvider].
/// ============================================================================
class CheckoutBottomSheet extends StatelessWidget {
  final String orderId;
  final double totalUsd;
  final PaymentRepository paymentRepository;

  const CheckoutBottomSheet({
    super.key,
    required this.orderId,
    required this.totalUsd,
    required this.paymentRepository,
  });

  /// Abre el [CheckoutBottomSheet] como un modal draggable.
  static Future<void> show({
    required BuildContext context,
    required String orderId,
    required double totalUsd,
    required PaymentRepository paymentRepository,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckoutBottomSheet(
        orderId: orderId,
        totalUsd: totalUsd,
        paymentRepository: paymentRepository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PaymentProvider(repository: paymentRepository),
      child: _CheckoutForm(
        orderId: orderId,
        totalUsd: totalUsd,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET INTERNO CON ESTADO
// ─────────────────────────────────────────────────────────────────────────────

class _CheckoutForm extends StatefulWidget {
  final String orderId;
  final double totalUsd;

  const _CheckoutForm({
    required this.orderId,
    required this.totalUsd,
  });

  @override
  State<_CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends State<_CheckoutForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankController = TextEditingController();
  final _referenceController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Pre-rellenar el monto con el total de la orden
    _amountController.text = widget.totalUsd.toStringAsFixed(2);

    // Animación de fade para los campos condicionales
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankController.dispose();
    _referenceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// Actualiza la animación cuando cambia el método de pago.
  void _onMethodSelected(PaymentMethod method, PaymentProvider provider) {
    provider.selectMethod(method);
    if (method.requiresReference) {
      _fadeController.forward();
    } else {
      _fadeController.reverse();
      // Limpiar campos de banco/referencia al cambiar a efectivo
      _bankController.clear();
      _referenceController.clear();
    }
    // Re-validar el formulario para actualizar errores visibles
    _formKey.currentState?.validate();
  }

  Future<void> _handleSubmit(
    BuildContext context,
    PaymentProvider paymentProvider,
    ExchangeRateProvider exchangeProvider,
  ) async {
    // Forzar validación de todos los campos
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final exchangeRate = exchangeProvider.rateValue;

    final success = await paymentProvider.processPayment(
      orderId: widget.orderId,
      amount: amount,
      exchangeRate: exchangeRate,
      bankName: paymentProvider.requiresReference
          ? _bankController.text.trim()
          : null,
      referenceNumber: paymentProvider.requiresReference
          ? _referenceController.text.trim()
          : null,
    );

    if (!context.mounted) return;

    if (success) {
      if (navigator.canPop()) navigator.pop();
      messenger.showSnackBar(_buildSnackBar(
        icon: Icons.check_circle_rounded,
        message: '✅ Pago registrado exitosamente.',
        color: _kSuccess,
      ));
    } else {
      messenger.showSnackBar(_buildSnackBar(
        icon: Icons.error_outline_rounded,
        message: paymentProvider.errorMessage ?? 'Error al registrar el pago.',
        color: _kError,
      ));
    }
  }

  SnackBar _buildSnackBar({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PaymentProvider, ExchangeRateProvider>(
      builder: (context, paymentProvider, exchangeProvider, _) {
        // Actualizar animación según el método actual
        if (paymentProvider.requiresReference &&
            _fadeController.status == AnimationStatus.dismissed) {
          _fadeController.forward();
        } else if (!paymentProvider.requiresReference &&
            _fadeController.status == AnimationStatus.completed) {
          _fadeController.reverse();
        }

        return Padding(
          // Desplazar el sheet hacia arriba cuando el teclado aparece
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            decoration: const BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle de arrastre ──────────────────────────────────────
                _DragHandle(),

                // ── Encabezado ──────────────────────────────────────────────
                _SheetHeader(),

                // ── Cuerpo scrolleable ──────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Resumen del Total ───────────────────────────
                          _OrderSummaryCard(
                            totalUsd: widget.totalUsd,
                            exchangeProvider: exchangeProvider,
                          ),
                          const SizedBox(height: 24),

                          // ── Selector de Método de Pago ──────────────────
                          _SectionLabel(label: 'Método de Pago'),
                          const SizedBox(height: 10),
                          if (paymentProvider.isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  color: _kOrange,
                                ),
                              ),
                            )
                          else
                            _MethodSelector(
                              methods: paymentProvider.paymentMethods,
                              selected: paymentProvider.selectedMethod,
                              onSelected: (m) =>
                                  _onMethodSelected(m, paymentProvider),
                            ),
                          const SizedBox(height: 24),

                          // ── Campo Monto ─────────────────────────────────
                          _SectionLabel(
                            label:
                                'Monto a Cobrar (${paymentProvider.selectedMethod?.naturalCurrency ?? 'USD'})',
                          ),
                          const SizedBox(height: 10),
                          _AmountField(
                            controller: _amountController,
                            currency: paymentProvider.selectedMethod
                                    ?.naturalCurrency ??
                                'USD',
                            totalUsd: widget.totalUsd,
                            exchangeRate: exchangeProvider.rateValue,
                          ),
                          const SizedBox(height: 20),

                          // ── Campos Condicionales: Banco + Referencia ────
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SizeTransition(
                              sizeFactor: _fadeAnimation,
                              alignment: Alignment.topCenter,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SectionLabel(label: 'Datos de Referencia'),
                                  const SizedBox(height: 10),
                                  _BankField(
                                    controller: _bankController,
                                    requiresValidation:
                                        paymentProvider.requiresReference,
                                  ),
                                  const SizedBox(height: 12),
                                  _ReferenceField(
                                    controller: _referenceController,
                                    requiresValidation:
                                        paymentProvider.requiresReference,
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Footer: Botón REGISTRAR PAGO ────────────────────────────
                _SubmitButton(
                  isProcessing: paymentProvider.isProcessing,
                  onTap: paymentProvider.isProcessing
                      ? null
                      : () => _handleSubmit(
                            context,
                            paymentProvider,
                            exchangeProvider,
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS PRIVADOS DE COMPOSICIÓN
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kOrange, _kOrangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar Pago',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Selecciona el método y completa los datos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Resumen del Total de la Orden ───────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  final double totalUsd;
  final ExchangeRateProvider exchangeProvider;

  const _OrderSummaryCard({
    required this.totalUsd,
    required this.exchangeProvider,
  });

  @override
  Widget build(BuildContext context) {
    final hasRate = exchangeProvider.hasRate;
    final totalVes = hasRate ? totalUsd * exchangeProvider.rateValue : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(
          color: _kOrange.withValues(alpha: 0.20),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            color: _kOrange,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total de la Orden',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _kTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$ ${totalUsd.toStringAsFixed(2)} USD',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (totalVes != null) ...[
            const VerticalDivider(
              width: 24,
              thickness: 1,
              color: Color(0xFFE0E0E0),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '≈ Bs.',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kOrange.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  totalVes.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kOrange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Etiqueta de sección ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: _kTextSecondary,
      ),
    );
  }
}

// ─── Selector de Método de Pago ───────────────────────────────────────────────

class _MethodSelector extends StatelessWidget {
  final List<PaymentMethod> methods;
  final PaymentMethod? selected;
  final ValueChanged<PaymentMethod> onSelected;

  const _MethodSelector({
    required this.methods,
    required this.selected,
    required this.onSelected,
  });

  IconData _iconFor(String name) {
    if (name.contains('USD')) return Icons.attach_money_rounded;
    if (name.contains('VES')) return Icons.currency_exchange_rounded;
    if (name.contains('Móvil')) return Icons.smartphone_rounded;
    if (name.contains('Punto')) return Icons.credit_card_rounded;
    return Icons.payment_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: methods.map((method) {
        final isSelected = selected?.id == method.id;
        return _MethodChip(
          method: method,
          icon: _iconFor(method.name),
          isSelected: isSelected,
          onTap: () => onSelected(method),
        );
      }).toList(),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final PaymentMethod method;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodChip({
    required this.method,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? _kOrange : _kBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? _kOrange
              : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: _kOrange.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : _kTextSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  method.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : _kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Campo Monto ──────────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String currency;
  final double totalUsd;
  final double exchangeRate;

  const _AmountField({
    required this.controller,
    required this.currency,
    required this.totalUsd,
    required this.exchangeRate,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _kTextPrimary,
      ),
      decoration: _inputDecoration(
        hint: '0.00',
        prefix: currency == 'VES' ? 'Bs.' : '\$',
        icon: Icons.monetization_on_outlined,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ingresa el monto a cobrar';
        }
        final amount = double.tryParse(value.trim());
        if (amount == null || amount <= 0) {
          return 'El monto debe ser mayor a cero';
        }
        return null;
      },
    );
  }
}

// ─── Campo Banco ──────────────────────────────────────────────────────────────

class _BankField extends StatelessWidget {
  final TextEditingController controller;
  final bool requiresValidation;

  const _BankField({
    required this.controller,
    required this.requiresValidation,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: _kTextPrimary,
      ),
      decoration: _inputDecoration(
        hint: 'Ej: Banco de Venezuela, Banesco...',
        label: 'Banco Emisor',
        icon: Icons.account_balance_rounded,
      ),
      validator: requiresValidation
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El banco es obligatorio para este método';
              }
              if (value.trim().length < 3) {
                return 'Ingresa al menos 3 caracteres';
              }
              return null;
            }
          : null,
    );
  }
}

// ─── Campo Referencia ─────────────────────────────────────────────────────────

class _ReferenceField extends StatelessWidget {
  final TextEditingController controller;
  final bool requiresValidation;

  const _ReferenceField({
    required this.controller,
    required this.requiresValidation,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: _kTextPrimary,
        letterSpacing: 1.2,
      ),
      decoration: _inputDecoration(
        hint: 'Últimos 8+ dígitos de la operación',
        label: 'N° de Referencia',
        icon: Icons.tag_rounded,
      ),
      validator: requiresValidation
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'La referencia es obligatoria para este método';
              }
              if (value.trim().length < 4) {
                return 'Ingresa al menos 4 caracteres de referencia';
              }
              return null;
            }
          : null,
    );
  }
}

// ─── Botón REGISTRAR PAGO ─────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback? onTap;

  const _SubmitButton({
    required this.isProcessing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: Container(
            decoration: BoxDecoration(
              gradient: onTap != null
                  ? const LinearGradient(
                      colors: [_kOrange, _kOrangeDark],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: onTap == null ? Colors.grey.shade300 : null,
              borderRadius: BorderRadius.circular(_kRadius),
              boxShadow: onTap != null
                  ? [
                      BoxShadow(
                        color: _kOrange.withValues(alpha: 0.40),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(_kRadius),
                child: Center(
                  child: isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              color: onTap != null
                                  ? Colors.white
                                  : Colors.grey.shade500,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'REGISTRAR PAGO',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: onTap != null
                                    ? Colors.white
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER DE DECORACIÓN DE INPUTS
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
  String? label,
  String? prefix,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix != null ? '$prefix  ' : null,
    prefixIcon: Icon(icon, color: _kOrange, size: 20),
    filled: true,
    fillColor: _kBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: const TextStyle(
      color: _kTextSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(
      color: Colors.grey.shade400,
      fontSize: 14,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kOrange, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kError, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kError, width: 2),
    ),
    errorStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: _kError,
    ),
  );
}
