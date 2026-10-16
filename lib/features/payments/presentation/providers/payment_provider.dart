import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:club_erp_system/features/payments/domain/entities/payment.dart';
import 'package:club_erp_system/features/payments/domain/entities/payment_method.dart';
import 'package:club_erp_system/features/payments/domain/repositories/payment_repository.dart';

/// ============================================================================
/// PAYMENT PROVIDER — Estado reactivo del formulario de cobro (US-2.2)
/// ============================================================================
///
/// Responsabilidades:
/// 1. Cargar los métodos de pago disponibles desde SQLite.
/// 2. Mantener el método seleccionado y reconstruir la UI reactivamente.
/// 3. Ejecutar el registro del pago en SQLite con la tasa de cambio congelada.
///
/// **Inmutabilidad Financiera**: La tasa de cambio se pasa como parámetro
/// en [processPayment] y se congela en ese instante exacto.
/// ============================================================================
class PaymentProvider extends ChangeNotifier {
  final PaymentRepository _repository;
  static const _uuid = Uuid();

  // Estado interno
  List<PaymentMethod> _paymentMethods = [];
  PaymentMethod? _selectedMethod;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  // Estado para Validación de Pagos (US-3.1 - Rol Encargada)
  List<Payment> _pendingPayments = [];
  bool _isLoadingPending = false;
  String? _approvingPaymentId;

  PaymentProvider({required PaymentRepository repository})
      // ignore: prefer_initializing_formals
      : _repository = repository {
    _loadPaymentMethods();
    loadPendingPayments();
  }

  // ---------------------------------------------------------------------------
  // ACCESORES PÚBLICOS
  // ---------------------------------------------------------------------------

  /// Lista de métodos de pago disponibles.
  List<PaymentMethod> get paymentMethods => List.unmodifiable(_paymentMethods);

  /// Método de pago actualmente seleccionado.
  PaymentMethod? get selectedMethod => _selectedMethod;

  /// `true` si el método seleccionado requiere Banco + Referencia.
  bool get requiresReference => _selectedMethod?.requiresReference ?? false;

  /// `true` mientras se cargan los métodos de pago.
  bool get isLoading => _isLoading;

  /// `true` mientras se persiste el pago en SQLite.
  bool get isProcessing => _isProcessing;

  /// Mensaje de error legible, o `null` si no hay error.
  String? get errorMessage => _errorMessage;

  /// Lista de pagos digitales con estado 'PENDING_VALIDATION'.
  List<Payment> get pendingPayments => List.unmodifiable(_pendingPayments);

  /// `true` mientras se cargan los pagos pendientes desde SQLite.
  bool get isLoadingPending => _isLoadingPending;

  /// ID del pago que se está aprobando actualmente (para mostrar spinner específico).
  String? get approvingPaymentId => _approvingPaymentId;

  /// Cantidad de pagos pendientes de validación.
  int get pendingCount => _pendingPayments.length;

  // ---------------------------------------------------------------------------
  // SELECCIÓN DE MÉTODO
  // ---------------------------------------------------------------------------

  /// Actualiza el método de pago seleccionado y notifica a la UI.
  void selectMethod(PaymentMethod method) {
    _selectedMethod = method;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CARGA INICIAL
  // ---------------------------------------------------------------------------

  Future<void> _loadPaymentMethods() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _paymentMethods = await _repository.getPaymentMethods();
      // Seleccionar "Efectivo USD" por defecto (primer ítem)
      if (_paymentMethods.isNotEmpty) {
        _selectedMethod = _paymentMethods.first;
      }
    } catch (e) {
      _errorMessage = 'Error al cargar métodos de pago: $e';
      debugPrint('❌ [PaymentProvider] $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // REGISTRO DE PAGO
  // ---------------------------------------------------------------------------

  /// Genera y persiste un [Payment] en SQLite.
  ///
  /// Parámetros:
  /// - [orderId]: UUID de la orden a cobrar.
  /// - [amount]: Monto ingresado por la cajera.
  /// - [exchangeRate]: Tasa de cambio activa **congelada en este instante**.
  /// - [referenceNumber]: Referencia del banco (solo para Pago Móvil / POS).
  /// - [bankName]: Banco emisor (solo para Pago Móvil / POS).
  ///
  /// Retorna `true` si el registro fue exitoso, `false` si falló.
  Future<bool> processPayment({
    required String orderId,
    required double amount,
    required double exchangeRate,
    String? referenceNumber,
    String? bankName,
  }) async {
    if (_selectedMethod == null) return false;

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final method = _selectedMethod!;

      // Determinar el estado según el tipo de método de pago (AC US-2.2)
      final status = method.requiresReference
          ? 'PENDING_VALIDATION'
          : 'CONCILIADO';

      final payment = Payment(
        id: _uuid.v4(),
        orderId: orderId,
        paymentMethodId: method.id,
        amount: amount,
        currency: method.naturalCurrency,
        exchangeRate: exchangeRate, // ← Tasa congelada en este momento exacto
        referenceNumber: referenceNumber,
        bankName: bankName,
        status: status,
        createdAt: now,
      );

      await _repository.processPayment(payment);

      // Si el pago es digital, se agrega a la lista reactiva de pendientes (US-3.1)
      if (status == 'PENDING_VALIDATION') {
        _pendingPayments.insert(0, payment);
      }

      _isProcessing = false;
      notifyListeners();

      debugPrint(
        '✅ [PaymentProvider] Pago ${payment.id} registrado. '
        'Estado: $status | Tasa congelada: $exchangeRate',
      );
      return true;
    } catch (e) {
      _isProcessing = false;
      _errorMessage = 'Error al registrar el pago: $e';
      notifyListeners();
      debugPrint('❌ [PaymentProvider] Error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // VALIDACIÓN DE PAGOS (US-3.1 — ROL ENCARGADA)
  // ---------------------------------------------------------------------------

  /// Carga todos los pagos en estado 'PENDING_VALIDATION' desde SQLite.
  Future<void> loadPendingPayments() async {
    _isLoadingPending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _pendingPayments = await _repository.getPendingPayments();
    } catch (e) {
      _errorMessage = 'Error al cargar pagos pendientes: $e';
      debugPrint('❌ [PaymentProvider] $_errorMessage');
    } finally {
      _isLoadingPending = false;
      notifyListeners();
    }
  }

  /// Aprueba un pago digital cambiando su estado a 'CONCILIADO' en SQLite
  /// y remueve el ítem de la lista reactivamente (AC US-3.1).
  Future<bool> approvePayment(String paymentId) async {
    _approvingPaymentId = paymentId;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.approvePayment(paymentId);

      // Remover reactivamente de la lista en memoria
      _pendingPayments.removeWhere((p) => p.id == paymentId);
      _approvingPaymentId = null;
      notifyListeners();

      debugPrint('✅ [PaymentProvider] Pago $paymentId aprobado y conciliado.');
      return true;
    } catch (e) {
      _approvingPaymentId = null;
      _errorMessage = 'Error al aprobar el pago: $e';
      notifyListeners();
      debugPrint('❌ [PaymentProvider] $_errorMessage');
      return false;
    }
  }
}
