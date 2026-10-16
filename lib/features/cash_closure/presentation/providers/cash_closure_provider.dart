import 'package:flutter/foundation.dart';

import 'package:club_erp_system/features/cash_closure/domain/entities/cash_session.dart';
import 'package:club_erp_system/features/cash_closure/domain/repositories/cash_session_repository.dart';
import 'package:club_erp_system/features/payments/domain/entities/payment.dart';

/// Provider para la gestión reactiva del Arqueo y Cierre de Caja (US-3.4).
class CashClosureProvider extends ChangeNotifier {
  final CashSessionRepository repository;

  CashClosureProvider({required this.repository});

  CashSessionRepository get _repository => repository;

  CashSession? _activeSession;
  Map<String, double> _totalsByMethod = {
    'Efectivo USD': 0.0,
    'Efectivo VES': 0.0,
    'Pago Móvil': 0.0,
    'Punto de Venta': 0.0,
  };

  bool _isLoading = false;
  bool _isClosing = false;
  String? _errorMessage;

  // Estado del modal de detalle por método
  String? _selectedMethod;
  List<Payment> _selectedMethodPayments = [];
  bool _isLoadingDetails = false;

  CashSession? get activeSession => _activeSession;
  Map<String, double> get totalsByMethod => _totalsByMethod;
  bool get isLoading => _isLoading;
  bool get isClosing => _isClosing;
  String? get errorMessage => _errorMessage;

  String? get selectedMethod => _selectedMethod;
  List<Payment> get selectedMethodPayments => _selectedMethodPayments;
  bool get isLoadingDetails => _isLoadingDetails;

  /// Carga la sesión activa y calcula los totales por método
  Future<void> loadSessionData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activeSession = await _repository.getActiveSession();

      if (_activeSession != null) {
        _totalsByMethod =
            await _repository.getSessionTotalsByMethod(_activeSession!.id);
      } else {
        _errorMessage = 'No se encontró una sesión de caja abierta.';
      }
    } catch (e) {
      _errorMessage = 'Error al cargar arqueo de caja: $e';
      debugPrint('❌ [CashClosureProvider] $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga la lista detallada de pagos para un método seleccionado
  Future<List<Payment>> loadMethodPayments(String methodNameOrId) async {
    _selectedMethod = methodNameOrId;
    _isLoadingDetails = true;
    _selectedMethodPayments = [];
    notifyListeners();

    try {
      if (_activeSession != null) {
        _selectedMethodPayments = await _repository.getPaymentsBySessionAndMethod(
          _activeSession!.id,
          methodNameOrId,
        );
      }
    } catch (e) {
      debugPrint('❌ [CashClosureProvider] Error al obtener detalle de pagos: $e');
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }

    return _selectedMethodPayments;
  }

  /// Ejecuta el cierre de caja para la sesión activa
  Future<bool> closeCurrentSession() async {
    if (_activeSession == null) return false;

    _isClosing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.closeSession(_activeSession!.id);
      _activeSession = null;
      return true;
    } catch (e) {
      _errorMessage = 'Error al cerrar la sesión: $e';
      debugPrint('❌ [CashClosureProvider] $e');
      return false;
    } finally {
      _isClosing = false;
      notifyListeners();
    }
  }
}
