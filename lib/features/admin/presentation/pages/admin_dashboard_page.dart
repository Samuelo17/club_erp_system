import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/core/auth/auth_provider.dart';
import 'package:club_erp_system/features/auth/presentation/pages/login_page.dart';
import 'package:club_erp_system/features/exchange_rate/presentation/providers/exchange_rate_provider.dart';
import 'package:club_erp_system/features/payments/domain/entities/payment.dart';
import 'package:club_erp_system/features/payments/presentation/providers/payment_provider.dart';

/// ============================================================================
/// ADMIN DASHBOARD PAGE — Panel de la Encargada / Gerencia (US-3.1)
/// ============================================================================
///
/// Responsabilidades:
/// 1. Validación de Pagos Online: Muestra los pagos en estado 'PENDING_VALIDATION'
///    (Pago Móvil y Punto de Venta) con monto en VES y USD, Banco, Referencia y Hora.
/// 2. Conciliación reactiva: Al presionar 'APROBAR', actualiza el estado a 'CONCILIADO'
///    y desaparece de la lista inmediatamente.
/// 3. Gestión de Tasa de Cambio (US-2.1): Permite fijar y monitorear la tasa activa.
/// 4. Cierre de sesión y control de acceso restringido a Encargada.
/// ============================================================================
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _rateController = TextEditingController();
  final _rateFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Cargar pagos pendientes al entrar a la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadPendingPayments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // FORMATO DE FECHA / HORA SIN DEPENDENCIAS EXTERNAS
  // ---------------------------------------------------------------------------
  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day/$month/$year';
  }

  // ---------------------------------------------------------------------------
  // ACCIONES
  // ---------------------------------------------------------------------------
  void _handleLogout() {
    context.read<AuthProvider>().logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _approvePayment(Payment payment) async {
    final paymentProvider = context.read<PaymentProvider>();
    final success = await paymentProvider.approvePayment(payment.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pago Ref: ${payment.referenceNumber ?? "N/A"} CONCILIADO exitosamente.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentProvider.errorMessage ?? 'Error al conciliar el pago.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _saveRate() async {
    if (!_rateFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final exchangeProvider = context.read<ExchangeRateProvider>();

    final employeeId = (authProvider.currentUser?.id != null &&
            authProvider.currentUser!.id.isNotEmpty)
        ? authProvider.currentUser!.id
        : 'emp-encargada-5678';
    final value = double.tryParse(_rateController.text.trim());

    if (value == null || value <= 0) return;

    final success = await exchangeProvider.registerRate(value, employeeId);

    if (!mounted) return;

    if (success) {
      _rateController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tasa oficial actualizada a Bs. ${value.toStringAsFixed(2)} / USD',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exchangeProvider.errorMessage ?? 'Error al guardar la tasa.',
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // INTERFAZ DE USUARIO
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final paymentProvider = context.watch<PaymentProvider>();
    final currentUserName = authProvider.currentUser?.name ?? 'Carmen (Encargada)';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Panel de Gerencia',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  currentUserName,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Botón Refrescar
          IconButton(
            tooltip: 'Actualizar lista',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF374151)),
            onPressed: () => paymentProvider.loadPendingPayments(),
          ),
          // Botón Cerrar Sesión
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Cerrar Sesión',
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              onPressed: _handleLogout,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF8C00),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFFFF8C00),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text('Validación de Pagos'),
                  if (paymentProvider.pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${paymentProvider.pendingCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.currency_exchange_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Tasa de Cambio'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // PESTAÑA 1: Validación de Pagos Móviles (US-3.1)
          _buildValidationTab(paymentProvider),

          // PESTAÑA 2: Tasa de Cambio (US-2.1)
          _buildExchangeRateTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 1: VALIDACIÓN DE PAGOS DIGITALES (US-3.1)
  // ===========================================================================
  Widget _buildValidationTab(PaymentProvider provider) {
    if (provider.isLoadingPending) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF8C00),
        ),
      );
    }

    final pending = provider.pendingPayments;

    return RefreshIndicator(
      color: const Color(0xFFFF8C00),
      onRefresh: () => provider.loadPendingPayments(),
      child: pending.isEmpty
          ? _buildEmptyPendingState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              itemBuilder: (context, index) {
                final payment = pending[index];
                return _buildPendingPaymentCard(payment, provider);
              },
            ),
    );
  }

  Widget _buildEmptyPendingState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '¡Todo Conciliado!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'No hay pagos móviles ni puntos de venta pendientes de validación bancaria.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF374151),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                onPressed: () => context.read<PaymentProvider>().loadPendingPayments(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Comprobar de nuevo'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingPaymentCard(Payment payment, PaymentProvider provider) {
    final isApproving = provider.approvingPaymentId == payment.id;
    final timeStr = _formatTime(payment.createdAt);
    final dateStr = _formatDate(payment.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Tag de estado + Hora de la transacción
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFB45309)),
                      SizedBox(width: 4),
                      Text(
                        'POR VALIDAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text(
                      '$dateStr • $timeStr',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Sección de Montos (VES prominente + USD equivalente)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monto en Bolívares',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Bs. ${payment.amountInVes.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Equivalente USD',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '\$${payment.amountInUsd.toStringAsFixed(2)} USD',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF047857),
                        ),
                      ),
                      Text(
                        'Tasa: Bs. ${payment.exchangeRate.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Datos Bancarios: Banco + Código de Referencia exacto
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_rounded, size: 16, color: Color(0xFF4B5563)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          payment.bankName ?? 'Banco no especificado',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 5),
                      Text(
                        'Ref: ${payment.referenceNumber ?? "S/R"}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          if (payment.referenceNumber != null) {
                            Clipboard.setData(ClipboardData(text: payment.referenceNumber!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Referencia copiada al portapapeles'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        child: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // BOTÓN VERDE PROMINENTE: APROBAR
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isApproving ? null : () => _approvePayment(payment),
                icon: isApproving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  isApproving ? 'APROBANDO...' : 'APROBAR',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 2: GESTIÓN DE TASA DE CAMBIO (US-2.1)
  // ===========================================================================
  Widget _buildExchangeRateTab() {
    return Consumer<ExchangeRateProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarjeta Tasa Actual
              _buildCurrentRateCard(provider),

              const SizedBox(height: 16),

              // Formulario Nueva Tasa
              _buildNewRateFormCard(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentRateCard(ExchangeRateProvider provider) {
    final hasRate = provider.hasRate;
    final rate = provider.currentRate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: Color(0xFFFF8C00), size: 20),
              SizedBox(width: 8),
              Text(
                'Tasa Oficial Vigente',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasRate && rate != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Bs. ${rate.rateValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '/ USD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Última actualización: ${_formatDate(rate.createdAt)} • ${_formatTime(rate.createdAt)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ] else ...[
            const Text(
              'Sin tasa registrada',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Es obligatorio ingresar una tasa para habilitar los cálculos en bolívares.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewRateFormCard(ExchangeRateProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Form(
        key: _rateFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_calendar_rounded, color: Color(0xFFFF8C00), size: 20),
                SizedBox(width: 8),
                Text(
                  'Fijar Nueva Tasa del Día',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Al guardar, se insertará un nuevo registro inmutable en SQLite y se sincronizará automáticamente con todas las terminales POS.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Monto de la Tasa (Bs / USD)',
                hintText: 'Ej. 54.50',
                prefixText: 'Bs. ',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingresa el valor de la tasa';
                }
                final numVal = double.tryParse(val.trim());
                if (numVal == null || numVal <= 0) {
                  return 'El valor debe ser mayor a 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: provider.isSaving ? null : _saveRate,
                icon: provider.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  provider.isSaving ? 'GUARDANDO...' : 'ACTUALIZAR TASA',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
