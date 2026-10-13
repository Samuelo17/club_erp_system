import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:club_erp_system/core/auth/auth_provider.dart';
import 'package:club_erp_system/features/exchange_rate/presentation/providers/exchange_rate_provider.dart';

/// ============================================================================
/// DASHBOARD DE TASA DE CAMBIO — PANTALLA EXCLUSIVA DE LA ENCARGADA
/// ============================================================================
///
/// Criterios de Aceptación (US-2.1):
/// - Pantalla simple para ingresar la nueva tasa de cambio del día.
/// - Inserta un nuevo registro en exchange_rates (NUNCA update).
/// - Muestra la tasa activa actual con fecha/hora del último registro.
///
/// UI/UX según UI_STYLE_GUIDE.md:
/// - Fondo gris claro (#F5F5F7).
/// - Tarjetas blancas con bordes redondeados (12px) y sombras suaves.
/// - Botón de acción principal en Naranja Vibrante (#FF8C00).
/// - Tipografía grande y negrita para la tasa actual.
/// - Input numérico táctil optimizado.
/// ============================================================================

class ExchangeRateDashboardPage extends StatefulWidget {
  const ExchangeRateDashboardPage({super.key});

  @override
  State<ExchangeRateDashboardPage> createState() =>
      _ExchangeRateDashboardPageState();
}

class _ExchangeRateDashboardPageState extends State<ExchangeRateDashboardPage> {
  final _rateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _saveRate() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final exchangeProvider = context.read<ExchangeRateProvider>();

    final employeeId = (authProvider.currentUser?.id != null &&
            authProvider.currentUser!.id.isNotEmpty)
        ? authProvider.currentUser!.id
        : '00000000-0000-0000-0000-000000000000';
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
                'Tasa actualizada a ${value.toStringAsFixed(2)} Bs/USD',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.currency_exchange_rounded,
              color: Color(0xFFFF8C00),
              size: 24,
            ),
            SizedBox(width: 10),
            Text(
              'Tasa de Cambio',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Consumer<ExchangeRateProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF8C00),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== TARJETA: TASA ACTUAL =====
                _buildCurrentRateCard(provider),

                const SizedBox(height: 24),

                // ===== TARJETA: FORMULARIO NUEVA TASA =====
                _buildNewRateForm(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Tarjeta superior que muestra la tasa de cambio vigente.
  Widget _buildCurrentRateCard(ExchangeRateProvider provider) {
    final hasRate = provider.hasRate;
    final rate = provider.currentRate;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFFFF8C00),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Tasa Vigente',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
              const Spacer(),
              // Indicador de estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasRate
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.10)
                      : Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hasRate ? 'Activa' : 'Sin tasa',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: hasRate ? const Color(0xFF2E7D32) : Colors.red,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Valor de la tasa (grande y destacado)
          Center(
            child: Text(
              hasRate
                  ? '${rate!.rateValue.toStringAsFixed(2)} Bs/USD'
                  : '—',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Fecha y hora del último registro
          if (hasRate)
            Center(
              child: Text(
                'Registrada el ${_formatDate(rate!.createdAt)}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Tarjeta con formulario para ingresar nueva tasa.
  Widget _buildNewRateForm(ExchangeRateProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            const Text(
              'Registrar Nueva Tasa',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ingresa el valor actual del dólar en bolívares.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),

            const SizedBox(height: 20),

            // Input numérico
            TextFormField(
              controller: _rateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
              ],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade300,
                ),
                suffixText: 'Bs/USD',
                suffixStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF8C00),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.red.shade400,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa un valor para la tasa.';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'La tasa debe ser un número mayor a 0.';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Botón de guardar — Naranja Vibrante (UI_STYLE_GUIDE)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: provider.isSaving ? null : _saveRate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  disabledBackgroundColor:
                      const Color(0xFFFF8C00).withValues(alpha: 0.50),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: provider.isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Guardar Tasa',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formatea un DateTime a un string legible en español.
  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month $year a las $hour:$minute';
  }
}
