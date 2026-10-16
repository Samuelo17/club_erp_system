import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/core/auth/auth_provider.dart';
import 'package:club_erp_system/features/auth/presentation/pages/login_page.dart';
import 'package:club_erp_system/features/cash_closure/presentation/providers/cash_closure_provider.dart';

/// ============================================================================
/// CASH CLOSURE PAGE — Arqueo y Cierre de Caja (US-3.4)
/// ============================================================================
///
/// Permite a la cajera:
/// 1. Visualizar los totales agrupados por los 4 métodos de pago del turno actual.
/// 2. Tocar cualquier tarjeta para abrir un BottomSheet con el desglose exacto
///    de las transacciones ([Hora] - Orden #ID_Corto - Monto).
/// 3. Cerrar el turno actual cambiando la sesión a 'CLOSED', registrando la hora
///    de término, cerrando la sesión del usuario y regresando al LoginPage.
/// ============================================================================
class CashClosurePage extends StatefulWidget {
  const CashClosurePage({super.key});

  @override
  State<CashClosurePage> createState() => _CashClosurePageState();
}

class _CashClosurePageState extends State<CashClosurePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashClosureProvider>().loadSessionData();
    });
  }

  // ---------------------------------------------------------------------------
  // FORMATO DE FECHA / HORA
  // ---------------------------------------------------------------------------
  String _formatDateTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month • $hour:$minute $period';
  }

  // ---------------------------------------------------------------------------
  // MODAL BOTTOM SHEET: DESGLOSE DE TRANSACCIONES POR MÉTODO
  // ---------------------------------------------------------------------------
  void _showTransactionsBottomSheet(
    BuildContext context,
    String methodName,
    double totalAmount,
  ) {
    final closureProvider = context.read<CashClosureProvider>();
    closureProvider.loadMethodPayments(methodName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalContext).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre superior
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Cabecera del modal
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          methodName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Detalle de transacciones del turno',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.of(modalContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              // Lista de Pagos
              Expanded(
                child: Consumer<CashClosureProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoadingDetails) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF8C00),
                        ),
                      );
                    }

                    final payments = provider.selectedMethodPayments;

                    if (payments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sin transacciones en $methodName',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'No se registraron cobros con este método en este turno.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: payments.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        color: Color(0xFFF3F4F6),
                      ),
                      itemBuilder: (context, index) {
                        final payment = payments[index];
                        final isVes = payment.currency == 'VES';
                        final amountFormatted = isVes
                            ? 'Bs. ${payment.amount.toStringAsFixed(2)}'
                            : '\$${payment.amount.toStringAsFixed(2)} USD';

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Row(
                            children: [
                              // Icono de hora
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // [Hora] - Orden #ID_Corto
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          payment.formattedTime,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                        const Text(
                                          ' • ',
                                          style: TextStyle(color: Color(0xFF9CA3AF)),
                                        ),
                                        Text(
                                          'Orden #${payment.orderShortId}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1F2937),
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (payment.referenceNumber != null || payment.bankName != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        '${payment.bankName ?? "Banco"} • Ref: ${payment.referenceNumber ?? "N/A"}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Monto
                              Text(
                                amountFormatted,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Total en el footer del modal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL DEL MÉTODO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      methodName == 'Efectivo USD'
                          ? '\$${totalAmount.toStringAsFixed(2)} USD'
                          : 'Bs. ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF8C00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DIÁLOGO DE CONFIRMACIÓN DE CIERRE DE CAJA
  // ---------------------------------------------------------------------------
  Future<void> _handleCloseTurno() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
              SizedBox(width: 8),
              Text(
                'Confirmar Cierre',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            '¿Estás segura? Esta acción es irreversible y te desconectará del sistema.',
            style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.4),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'CERRAR Y SALIR',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final closureProvider = context.read<CashClosureProvider>();
    final authProvider = context.read<AuthProvider>();

    final success = await closureProvider.closeCurrentSession();

    if (!mounted) return;

    if (success) {
      authProvider.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            closureProvider.errorMessage ?? 'Error al cerrar el turno.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // INTERFAZ PRINCIPAL
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final closureProvider = context.watch<CashClosureProvider>();
    final activeSession = closureProvider.activeSession;
    final totals = closureProvider.totalsByMethod;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arqueo de Caja',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              'Turno Actual',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar montos',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF374151)),
            onPressed: () => closureProvider.loadSessionData(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E7EB), height: 1),
        ),
      ),
      body: closureProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF8C00),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner de estado de la sesión activa
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_open_rounded,
                            size: 18,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sesión de Caja Abierta',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                activeSession != null
                                    ? 'Apertura: ${_formatDateTime(activeSession.openedAt)}'
                                    : 'Sesión activa en curso',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'EN LÍNEA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Título de la sección de tarjetas
                  const Text(
                    'Totales por Método de Pago',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toca cualquier tarjeta para ver el listado de transacciones.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),

                  const SizedBox(height: 14),

                  // GRID RESPONSIVO DE 4 TARJETAS
                  // - Tarjeta 1: Efectivo USD
                  // - Tarjeta 2: Efectivo VES
                  // - Tarjeta 3: Pago Móvil
                  // - Tarjeta 4: Punto de Venta
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      _buildMethodCard(
                        title: 'Efectivo USD',
                        amount: totals['Efectivo USD'] ?? 0.0,
                        isUsd: true,
                        icon: Icons.attach_money_rounded,
                        accentColor: const Color(0xFF047857),
                        bgColor: const Color(0xFFDCFCE7),
                        onTap: () => _showTransactionsBottomSheet(
                          context,
                          'Efectivo USD',
                          totals['Efectivo USD'] ?? 0.0,
                        ),
                      ),
                      _buildMethodCard(
                        title: 'Efectivo VES',
                        amount: totals['Efectivo VES'] ?? 0.0,
                        isUsd: false,
                        icon: Icons.payments_rounded,
                        accentColor: const Color(0xFFEA580C),
                        bgColor: const Color(0xFFFFEDD5),
                        onTap: () => _showTransactionsBottomSheet(
                          context,
                          'Efectivo VES',
                          totals['Efectivo VES'] ?? 0.0,
                        ),
                      ),
                      _buildMethodCard(
                        title: 'Pago Móvil',
                        amount: totals['Pago Móvil'] ?? 0.0,
                        isUsd: false,
                        icon: Icons.phone_android_rounded,
                        accentColor: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFDBEAFE),
                        onTap: () => _showTransactionsBottomSheet(
                          context,
                          'Pago Móvil',
                          totals['Pago Móvil'] ?? 0.0,
                        ),
                      ),
                      _buildMethodCard(
                        title: 'Punto de Venta',
                        amount: totals['Punto de Venta'] ?? 0.0,
                        isUsd: false,
                        icon: Icons.credit_card_rounded,
                        accentColor: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFEDE9FE),
                        onTap: () => _showTransactionsBottomSheet(
                          context,
                          'Punto de Venta',
                          totals['Punto de Venta'] ?? 0.0,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // BOTÓN GIGANTE: CERRAR TURNO
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626), // Rojo prominente
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: closureProvider.isClosing
                          ? null
                          : () => _handleCloseTurno(),
                      icon: closureProvider.isClosing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_rounded, size: 22),
                      label: Text(
                        closureProvider.isClosing ? 'CERRANDO TURNO...' : 'CERRAR TURNO',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Al cerrar turno se congelarán los totales y se desconectará el usuario.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET: TARJETA DE MÉTODO DE PAGO
  // ---------------------------------------------------------------------------
  Widget _buildMethodCard({
    required String title,
    required double amount,
    required bool isUsd,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    final formattedAmount = isUsd
        ? '\$${amount.toStringAsFixed(2)}'
        : 'Bs. ${amount.toStringAsFixed(2)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: accentColor),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formattedAmount,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Row(
                children: [
                  Text(
                    'Ver detalle',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
