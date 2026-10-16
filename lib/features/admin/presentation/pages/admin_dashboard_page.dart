import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/core/auth/auth_provider.dart';
import 'package:club_erp_system/features/analytics/domain/entities/top_product_item.dart';
import 'package:club_erp_system/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:club_erp_system/features/auth/presentation/pages/login_page.dart';
import 'package:club_erp_system/features/exchange_rate/presentation/providers/exchange_rate_provider.dart';
import 'package:club_erp_system/features/payments/domain/entities/payment.dart';
import 'package:club_erp_system/features/payments/presentation/providers/payment_provider.dart';

/// ============================================================================
/// ADMIN DASHBOARD PAGE — Panel de la Encargada / Gerencia (US-3.1 & US-3.2)
/// ============================================================================
///
/// Responsabilidades:
/// 1. Dashboard de Estadísticas Gerenciales (US-3.2):
///    - KPIs del día: Órdenes Hoy (Negro), Ingreso USD (Verde oscuro), Ingreso VES (Naranja).
///    - Top 3 de productos más vendidos hoy con barras de progreso.
/// 2. Validación de Pagos Online (US-3.1):
///    - Muestra pagos en 'PENDING_VALIDATION' (Pago Móvil y Punto de Venta).
///    - Conciliación reactiva al presionar 'APROBAR'.
/// 3. Gestión de Tasa de Cambio (US-2.1): Permite fijar y auditar la tasa activa.
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
    // Cargar pagos pendientes y estadísticas del día al entrar a la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadPendingPayments();
      context.read<AnalyticsProvider>().loadTodayAnalytics();
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
      // Refrescar reactivamente las estadísticas del día
      context.read<AnalyticsProvider>().loadTodayAnalytics();

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
            tooltip: 'Actualizar datos',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF374151)),
            onPressed: () {
              paymentProvider.loadPendingPayments();
              context.read<AnalyticsProvider>().loadTodayAnalytics();
            },
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
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_outlined, size: 16),
                  const SizedBox(width: 4),
                  const Text('Validar Pagos'),
                  if (paymentProvider.pendingCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.currency_exchange_rounded, size: 16),
                  SizedBox(width: 4),
                  Text('Tasa del Día'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // PESTAÑA 1: Resumen del Día (US-3.2) + Validación de Pagos Móviles (US-3.1)
          _buildValidationTab(paymentProvider),

          // PESTAÑA 2: Tasa de Cambio (US-2.1)
          _buildExchangeRateTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 1: RESUMEN DEL DÍA (US-3.2) + VALIDACIÓN DE PAGOS DIGITALES (US-3.1)
  // ===========================================================================
  Widget _buildValidationTab(PaymentProvider provider) {
    final analyticsProvider = context.watch<AnalyticsProvider>();

    return RefreshIndicator(
      color: const Color(0xFFFF8C00),
      onRefresh: () async {
        await Future.wait([
          provider.loadPendingPayments(),
          analyticsProvider.loadTodayAnalytics(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // -------------------------------------------------------------------
          // SECCIÓN SUPERIOR: RESUMEN DEL DÍA (US-3.2)
          // -------------------------------------------------------------------
          _buildDailySummarySection(analyticsProvider),

          const SizedBox(height: 24),

          // -------------------------------------------------------------------
          // SECCIÓN INFERIOR: BANDEJA DE VALIDACIÓN DE PAGOS (US-3.1)
          // -------------------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: Color(0xFF111827),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Validación de Pagos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              if (provider.pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    '${provider.pendingCount} pendientes',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (provider.isLoadingPending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF8C00),
                ),
              ),
            )
          else if (provider.pendingPayments.isEmpty)
            _buildEmptyPendingState()
          else
            ...provider.pendingPayments.map(
              (payment) => _buildPendingPaymentCard(payment, provider),
            ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET: SECCIÓN "RESUMEN DEL DÍA" (US-3.2)
  // ---------------------------------------------------------------------------
  Widget _buildDailySummarySection(AnalyticsProvider analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de la Sección Resumen del Día
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 16,
                    color: Color(0xFFFF8C00),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Resumen del Día',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF6B7280)),
                  SizedBox(width: 4),
                  Text(
                    'Hoy',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Estado de Carga / Error / Datos
        if (analytics.isLoading)
          _buildSummaryLoadingState()
        else if (analytics.errorMessage != null)
          _buildSummaryErrorState(analytics)
        else ...[
          // Grid / Column responsivo con las 3 Tarjetas de KPIs solicitadas
          _buildKpiCards(analytics),

          const SizedBox(height: 14),

          // Tarjeta de Top 3 Productos Más Vendidos
          _buildTopProductsCard(analytics.summary.topProducts),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET: ESTADO DE CARGA ELEGANTE PARA EL RESUMEN DEL DÍA
  // ---------------------------------------------------------------------------
  Widget _buildSummaryLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFFFF8C00),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Calculando métricas del día...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET: ESTADO DE ERROR DE ANALYTICS
  // ---------------------------------------------------------------------------
  Widget _buildSummaryErrorState(AnalyticsProvider analytics) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              analytics.errorMessage ?? 'Error al cargar resumen del día.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFFDC2626)),
            onPressed: () => analytics.loadTodayAnalytics(),
            tooltip: 'Reintentar',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET: TARJETAS DE KPIS (DISEÑO MÓVIL RESPONSIVO)
  // - Tarjeta 1: "Órdenes Hoy" (Texto grande, color Negro #111827).
  // - Tarjeta 2: "Ingreso USD" (Texto grande, color Verde oscuro #047857).
  // - Tarjeta 3: "Ingreso VES" (Texto grande, color Naranja #EA580C).
  // ---------------------------------------------------------------------------
  Widget _buildKpiCards(AnalyticsProvider analytics) {
    final summary = analytics.summary;

    return Column(
      children: [
        // Fila Superior (2 Columnas): Órdenes Hoy + Ingreso USD
        Row(
          children: [
            // TARJETA 1: Órdenes Hoy (Negro)
            Expanded(
              child: _buildSingleKpiCard(
                title: 'Órdenes Hoy',
                value: '${summary.ordersCount}',
                valueColor: const Color(0xFF111827),
                icon: Icons.receipt_long_rounded,
                iconBg: const Color(0xFFF3F4F6),
                iconColor: const Color(0xFF374151),
                subtitle: 'completadas',
              ),
            ),
            const SizedBox(width: 10),
            // TARJETA 2: Ingreso USD (Verde oscuro)
            Expanded(
              child: _buildSingleKpiCard(
                title: 'Ingreso USD',
                value: '\$${summary.totalUsd.toStringAsFixed(2)}',
                valueColor: const Color(0xFF047857),
                icon: Icons.attach_money_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                subtitle: 'total ventas',
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Fila Inferior (Ancho Completo): Ingreso VES (Naranja)
        _buildHorizontalKpiCard(
          title: 'Ingreso VES',
          value: 'Bs. ${summary.totalVes.toStringAsFixed(2)}',
          valueColor: const Color(0xFFEA580C),
          icon: Icons.payments_rounded,
          iconBg: const Color(0xFFFFEDD5),
          iconColor: const Color(0xFFEA580C),
          subtitle: 'pagos en bolívares',
        ),
      ],
    );
  }

  // Tarjeta de KPI individual compacta
  Widget _buildSingleKpiCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String subtitle,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: valueColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta de KPI horizontal para montos largos
  Widget _buildHorizontalKpiCard({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String subtitle,
  }) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
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
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET: SECCIÓN "MÁS VENDIDOS HOY" (TOP 3 PRODUCTOS)
  // ---------------------------------------------------------------------------
  Widget _buildTopProductsCard(List<TopProductItem> topProducts) {
    final maxQuantity = topProducts.isEmpty
        ? 1
        : topProducts.map((p) => p.quantity).fold<int>(0, (prev, curr) => curr > prev ? curr : prev);

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          // Cabecera de la tarjeta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Más vendidos hoy',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Top 3',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (topProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'No hay ventas registradas aún hoy.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            Column(
              children: topProducts.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                final ratio = maxQuantity > 0
                    ? (product.quantity / maxQuantity)
                    : 0.0;
                final isLast = index == topProducts.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${index + 1}.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFF8C00),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${product.quantity} ${product.quantity == 1 ? "und" : "unds"}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.08, 1.0),
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF3F4F6),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF8C00),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET: ESTADO VACÍO CUANDO NO HAY PAGOS PENDIENTES
  // ---------------------------------------------------------------------------
  Widget _buildEmptyPendingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '¡Todo Conciliado!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No hay pagos pendientes de validación bancaria.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
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
